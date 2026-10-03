---
name: health-influxdb
description: Query Apple Health data from InfluxDB. Use for sleep analysis, heart rate, HRV, steps, exercise, and health coaching. Triggers on health metrics, sleep quality, fitness data, recovery status, or burnout detection.
---

# Health InfluxDB Skill

Query Apple Health data synced to InfluxDB via Health Auto Export.

## CLI Tool

```bash
health-query <metric> [-d DAYS]
```

Metrics: `sleep`, `hrv`, `rhr`, `steps`, `summary`

Examples:
```bash
health-query sleep          # 7-day sleep trend
health-query hrv -d 14      # 14-day HRV trend
health-query rhr            # resting heart rate
health-query steps          # daily step counts
health-query summary        # last 24h snapshot
```

Script: `scripts/health-query.py` (uses uv for deps)

## Connection

```bash
URL: http://influxdb.storage.svc.cluster.local:8086
Org: home
Bucket: health
Token: op read "op://kubernetes/apple-health-ingester/APPLE_HEALTH_INGESTER_INFLUXDB_TOKEN"
```

## Available Measurements

Health Auto Export changed measurement names around Mar 2026. The script handles both.

### Current (new format)
- `sleep_phases` (field: qty, tag `value`: inBed/core/deep/rem/awake/asleep)
- `heart_rate_variability_ms` (field: qty, in ms)
- `resting_heart_rate_count/min` (field: qty, in bpm)
- `heart_rate_count/min` (fields: Avg/Min/Max, in bpm)
- `walking_heart_rate_average_count/min` (field: qty)
- `step_count_count` (field: qty)

### Legacy (pre-Mar 2026)
- `sleep_analysis` (fields: inBed, asleep)
- `heart_rate_variability` (field: qty, in ms)
- `resting_heart_rate` (field: qty, in bpm)
- `heart_rate` (field: qty, in bpm)
- `walking_heart_rate_average` (field: qty)
- `step_count` (field: qty)

## Interpretation Guidelines

See [references/health-ranges.md](references/health-ranges.md) for normal ranges and coaching thresholds.

## Common Issues

- New format uses `sleep_phases` with `value` tag for sleep stages (core/deep/rem/awake)
- Old `asleep` field often shows 0 — new format is more reliable with stage breakdown
- Data syncs every 6 hours, infinite retention (data back to Feb 2025)
- Avoid `keep()` with mixed types - filter first
- If queries return empty, check both old and new measurement names
