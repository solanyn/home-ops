# Victoria Metrics

## NAS Deployments

Deploy these on TrueNAS using Docker Compose to scrape metrics from the NAS.

### node-exporter

```yaml
services:
  node-exporter:
    command:
      - '--path.rootfs=/host/root'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.udev.data=/host/root/run/udev/data'
      - '--web.listen-address=0.0.0.0:9100'
      - >-
        --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
    image: quay.io/prometheus/node-exporter:v1.9.0
    network_mode: host
    ports:
      - '9100:9100'
    restart: always
    volumes:
      - /:/host/root:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
```

### smartctl-exporter

```yaml
services:
  smartctl-exporter:
    command:
      - '--smartctl.device-exclude=sda'
    image: quay.io/prometheuscommunity/smartctl-exporter:v0.13.0
    ports:
      - '9633:9633'
    privileged: True
    restart: always
    user: root
```

## Alertmanager

Configured via `AlertmanagerConfig` (converted to VMAlertmanagerConfig by the operator).

Receivers:
- `heartbeat` - Pings healthchecks.io on Watchdog alerts
- `pushover` - Sends critical alerts to Pushover
- `blackhole` - Drops InfoInhibitor alerts

Required 1Password items:
- `alertmanager` with `ALERTMANAGER_HEARTBEAT_URL`
- `pushover` with `ALERTMANAGER_PUSHOVER_TOKEN` and `PUSHOVER_USER_KEY`
