#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["influxdb-client"]
# ///
"""Query Apple Health data from InfluxDB.

Handles both old and new Health Auto Export measurement names:
  Old (pre-Mar 2026)          → New
  sleep_analysis               → sleep_phases
  heart_rate_variability       → heart_rate_variability_ms
  resting_heart_rate           → resting_heart_rate_count/min
  heart_rate                   → heart_rate_count/min
  step_count                   → step_count_count
  walking_heart_rate_average   → walking_heart_rate_average_count/min
"""

import argparse
import os
import subprocess
import sys
from collections import defaultdict

from influxdb_client import InfluxDBClient

URL = "http://influxdb.storage.svc.cluster.local:8086"
ORG = "home"
BUCKET = "health"


def get_token():
    token = os.environ.get("INFLUXDB_TOKEN")
    if token:
        return token
    result = subprocess.run(
        ["op", "read", "op://kubernetes/apple-health-ingester/APPLE_HEALTH_INGESTER_INFLUXDB_TOKEN"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit(f"Failed to get token: {result.stderr}")
    return result.stdout.strip()


def _query(client, flux: str):
    return client.query_api().query(flux)


def query_sleep(client, days: int):
    # Old format: sleep_analysis with inBed/asleep fields
    q_old = f'''
    from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "sleep_analysis")
      |> filter(fn: (r) => r._field == "inBed" or r._field == "asleep")
      |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"])
    '''
    # New format: sleep_phases with value tag (inBed, core, deep, rem, awake, asleep)
    q_new = f'''
    from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "sleep_phases")
      |> filter(fn: (r) => r._field == "qty")
      |> pivot(rowKey:["_time"], columnKey: ["value"], valueColumn: "_value")
      |> sort(columns: ["_time"])
    '''

    entries = {}  # date_str -> {inBed, asleep, core, deep, rem, awake}

    for table in _query(client, q_old):
        for r in table.records:
            day = r.get_time().strftime("%a %d %b")
            key = r.get_time().strftime("%Y-%m-%d")
            in_bed = r.values.get("inBed", 0) or 0
            asleep = r.values.get("asleep", 0) or 0
            entries[key] = {"day": day, "inBed": in_bed, "asleep": asleep}

    for table in _query(client, q_new):
        for r in table.records:
            day = r.get_time().strftime("%a %d %b")
            key = r.get_time().strftime("%Y-%m-%d")
            in_bed = r.values.get("inBed", 0) or 0
            core = r.values.get("core", 0) or 0
            deep = r.values.get("deep", 0) or 0
            rem = r.values.get("rem", 0) or 0
            awake = r.values.get("awake", 0) or 0
            actual_sleep = core + deep + rem
            entries[key] = {
                "day": day, "inBed": in_bed, "asleep": actual_sleep,
                "core": core, "deep": deep, "rem": rem, "awake": awake,
            }

    print(f"Sleep (last {days} days):")
    total = 0
    count = 0
    for key in sorted(entries):
        e = entries[key]
        total += e["inBed"]
        count += 1
        parts = [f'{e["inBed"]:.1f}h in bed']
        if e.get("core"):
            parts.append(f'core {e["core"]:.1f}h, deep {e.get("deep", 0):.1f}h, rem {e.get("rem", 0):.1f}h')
        elif e.get("asleep", 0) > 0:
            parts.append(f'asleep {e["asleep"]:.1f}h')
        print(f'  {e["day"]}: {", ".join(parts)}')
    if count > 0:
        print(f"  avg: {total / count:.1f}h in bed")


def query_hrv(client, days: int):
    q = f'''
    import "experimental/array"

    old = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "heart_rate_variability")
      |> filter(fn: (r) => r._field == "qty")

    new = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "heart_rate_variability_ms")
      |> filter(fn: (r) => r._field == "qty")

    union(tables: [old, new])
      |> group(columns: ["_field"])
      |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
      |> sort(columns: ["_time"])
    '''
    tables = _query(client, q)
    print(f"HRV (last {days} days):")
    for table in tables:
        for r in table.records:
            if r.get_value() is not None:
                t = r.get_time().strftime("%a %d %b")
                print(f"  {t}: {r.get_value():.0f}ms")


def query_rhr(client, days: int):
    q = f'''
    old = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "resting_heart_rate")
      |> filter(fn: (r) => r._field == "qty")

    new = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "resting_heart_rate_count/min")
      |> filter(fn: (r) => r._field == "qty")

    union(tables: [old, new])
      |> group(columns: ["_field"])
      |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
      |> sort(columns: ["_time"])
    '''
    tables = _query(client, q)
    print(f"Resting HR (last {days} days):")
    for table in tables:
        for r in table.records:
            if r.get_value() is not None:
                t = r.get_time().strftime("%a %d %b")
                print(f"  {t}: {r.get_value():.0f} bpm")


def query_steps(client, days: int):
    q = f'''
    old = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "step_count")
      |> filter(fn: (r) => r._field == "qty")

    new = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "step_count_count")
      |> filter(fn: (r) => r._field == "qty")

    union(tables: [old, new])
      |> group(columns: ["_field"])
      |> aggregateWindow(every: 1d, fn: sum, createEmpty: false)
      |> sort(columns: ["_time"])
    '''
    tables = _query(client, q)
    print(f"Steps (last {days} days):")
    for table in tables:
        for r in table.records:
            if r.get_value() is not None:
                t = r.get_time().strftime("%a %d %b")
                print(f"  {t}: {r.get_value():,.0f}")


def query_hr(client, days: int):
    q = f'''
    old = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "heart_rate")
      |> filter(fn: (r) => r._field == "qty")

    new = from(bucket: "{BUCKET}")
      |> range(start: -{days}d)
      |> filter(fn: (r) => r._measurement == "heart_rate_count/min")
      |> filter(fn: (r) => r._field == "Avg")

    union(tables: [old, new])
      |> group(columns: ["_field"])
      |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
      |> sort(columns: ["_time"])
    '''
    tables = _query(client, q)
    print(f"Heart Rate avg (last {days} days):")
    for table in tables:
        for r in table.records:
            if r.get_value() is not None:
                t = r.get_time().strftime("%a %d %b")
                print(f"  {t}: {r.get_value():.0f} bpm")


def query_summary(client):
    """Quick 24h summary pulling from both old and new measurements."""
    metrics = {
        "Sleep (inBed)": (
            ['sleep_analysis', 'sleep_phases'],
            lambda r: r._field in ('inBed', 'qty') and r.values.get('value', '') in ('', 'inBed'),
        ),
    }
    # Simple approach: grab latest from key measurements
    queries = {
        "HRV": f'''
            old = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "heart_rate_variability") |> filter(fn: (r) => r._field == "qty")
            new = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "heart_rate_variability_ms") |> filter(fn: (r) => r._field == "qty")
            union(tables: [old, new]) |> group(columns: ["_field"]) |> last()
        ''',
        "RHR": f'''
            old = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "resting_heart_rate") |> filter(fn: (r) => r._field == "qty")
            new = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "resting_heart_rate_count/min") |> filter(fn: (r) => r._field == "qty")
            union(tables: [old, new]) |> group(columns: ["_field"]) |> last()
        ''',
        "HR": f'''
            old = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "heart_rate") |> filter(fn: (r) => r._field == "qty")
            new = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "heart_rate_count/min") |> filter(fn: (r) => r._field == "Avg")
            union(tables: [old, new]) |> group(columns: ["_field"]) |> last()
        ''',
        "Steps": f'''
            old = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "step_count") |> filter(fn: (r) => r._field == "qty")
            new = from(bucket: "{BUCKET}") |> range(start: -24h)
              |> filter(fn: (r) => r._measurement == "step_count_count") |> filter(fn: (r) => r._field == "qty")
            union(tables: [old, new]) |> group(columns: ["_field"]) |> sum()
        ''',
    }

    print("Last 24h summary:")
    for label, flux in queries.items():
        tables = _query(client, flux)
        for table in tables:
            for r in table.records:
                v = r.get_value()
                if v is not None:
                    if label == "Steps":
                        print(f"  {label}: {v:,.0f}")
                    elif label == "HRV":
                        print(f"  {label}: {v:.0f}ms")
                    else:
                        print(f"  {label}: {v:.0f} bpm")
                    break


QUERIES = {
    "sleep": query_sleep,
    "hrv": query_hrv,
    "rhr": query_rhr,
    "steps": query_steps,
    "hr": query_hr,
    "summary": query_summary,
}


def main():
    parser = argparse.ArgumentParser(description="Query Apple Health data from InfluxDB")
    parser.add_argument("metric", choices=list(QUERIES.keys()), help="Metric to query")
    parser.add_argument("-d", "--days", type=int, default=7, help="Days to look back (default: 7)")
    args = parser.parse_args()

    token = get_token()
    client = InfluxDBClient(url=URL, token=token, org=ORG)

    try:
        if args.metric == "summary":
            QUERIES[args.metric](client)
        else:
            QUERIES[args.metric](client, args.days)
    finally:
        client.close()


if __name__ == "__main__":
    main()
