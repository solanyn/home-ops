---
name: grafana
description: Query Grafana HTTP API for dashboards, datasources, Prometheus queries, alerts, and annotations. Use when checking cluster observability, dashboard status, alert states, or running PromQL queries via Grafana proxy. Triggers on grafana, dashboards, alerts, prometheus, metrics, observability.
---

# Grafana Skill

Query Grafana via its HTTP API. SA token has Editor role.

## Connection

```bash
GRAFANA_URL="http://grafana-service.observability.svc.cluster.local:3000"
GRAFANA_TOKEN=$(op read "op://kubernetes/grafana/GRAFANA_SA_TOKEN")
```

All requests use:
```bash
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL/api/..."
```

## Auth Helper

Prefix every curl with this (or export once per session):

```bash
export GRAFANA_URL="http://grafana-service.observability.svc.cluster.local:3000"
export GRAFANA_TOKEN=$(op read "op://kubernetes/grafana/GRAFANA_SA_TOKEN")
alias gcurl='curl -s -H "Authorization: Bearer $GRAFANA_TOKEN"'
```

## Dashboards

### List all dashboards

```bash
# Search all dashboards
gcurl "$GRAFANA_URL/api/search?type=dash-db" | jq '.[] | {uid, title, url}'

# Search by name
gcurl "$GRAFANA_URL/api/search?query=flux&type=dash-db"

# List by folder
gcurl "$GRAFANA_URL/api/search?type=dash-db&folderIds=0"

# List folders
gcurl "$GRAFANA_URL/api/search?type=dash-folder"
```

### Get dashboard by UID

```bash
# Full dashboard model (panels, templating, etc.)
gcurl "$GRAFANA_URL/api/dashboards/uid/<DASHBOARD_UID>" | jq '.dashboard.title, .dashboard.panels[].title'

# List panels with their IDs and types
gcurl "$GRAFANA_URL/api/dashboards/uid/<DASHBOARD_UID>" | jq '.dashboard.panels[] | {id, title, type}'
```

### Query panel data (via dashboard query API)

```bash
# Get panel data — requires datasource UID and panel targets
# First get the panel's query config:
gcurl "$GRAFANA_URL/api/dashboards/uid/<DASHBOARD_UID>" | jq '.dashboard.panels[] | select(.id == <PANEL_ID>) | .targets'

# Then use /api/ds/query to execute it (see Prometheus section below)
```

## Datasources

```bash
# List all datasources
gcurl "$GRAFANA_URL/api/datasources" | jq '.[] | {id, uid, name, type, url}'

# Get datasource by ID
gcurl "$GRAFANA_URL/api/datasources/<ID>"

# Get datasource by UID
gcurl "$GRAFANA_URL/api/datasources/uid/<UID>"

# Get datasource by name
gcurl "$GRAFANA_URL/api/datasources/name/<NAME>"

# Health check a datasource
gcurl "$GRAFANA_URL/api/datasources/uid/<UID>/health"
```

## Prometheus Queries (via Grafana Proxy)

Grafana proxies requests to datasources. Find the Prometheus datasource ID first.

```bash
# Find Prometheus datasource ID
PROM_ID=$(gcurl "$GRAFANA_URL/api/datasources" | jq '.[] | select(.type == "prometheus") | .id')

# Instant query
gcurl "$GRAFANA_URL/api/datasources/proxy/$PROM_ID/api/v1/query?query=up"

# Range query (last 1h, 60s step)
gcurl "$GRAFANA_URL/api/datasources/proxy/$PROM_ID/api/v1/query_range?query=up&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)&step=60"

# Label values
gcurl "$GRAFANA_URL/api/datasources/proxy/$PROM_ID/api/v1/label/__name__/values" | jq '.data[:20]'

# Series metadata
gcurl "$GRAFANA_URL/api/datasources/proxy/$PROM_ID/api/v1/series?match[]=up"
```

### Alternative: /api/ds/query (unified query endpoint)

```bash
# POST query through unified endpoint (works for all datasource types)
gcurl -X POST "$GRAFANA_URL/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": {"uid": "<DATASOURCE_UID>", "type": "prometheus"},
      "expr": "up",
      "instant": true
    }],
    "from": "now-1h",
    "to": "now"
  }'
```

### Common PromQL Patterns

```bash
# Cluster node status
query="up"

# CPU usage by pod
query="sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)"

# Memory usage by namespace
query="sum(container_memory_working_set_bytes) by (namespace)"

# Disk usage
query="node_filesystem_avail_bytes / node_filesystem_size_bytes"

# Pod restart count
query="kube_pod_container_status_restarts_total"
```

## Alert Rules

```bash
# List all alert rules (Grafana-managed)
gcurl "$GRAFANA_URL/api/v1/provisioning/alert-rules" | jq '.[] | {uid, title, condition, folderUID}'

# Get specific alert rule
gcurl "$GRAFANA_URL/api/v1/provisioning/alert-rules/<RULE_UID>"

# List Prometheus/Mimir alert rules (ruler API)
gcurl "$GRAFANA_URL/api/ruler/grafana/api/v1/rules" | jq 'keys'

# Get alert rule groups by namespace (folder)
gcurl "$GRAFANA_URL/api/ruler/grafana/api/v1/rules/<FOLDER_NAME>"

# Current alert instances (firing/pending/normal)
gcurl "$GRAFANA_URL/api/alertmanager/grafana/api/v2/alerts" | jq '.[] | {labels: .labels, state: .status.state}'

# Silences
gcurl "$GRAFANA_URL/api/alertmanager/grafana/api/v2/silences" | jq '.[] | {id, status: .status.state, comment, matchers}'
```

## Annotations

```bash
# List recent annotations (last 24h)
gcurl "$GRAFANA_URL/api/annotations?from=$(( $(date +%s) * 1000 - 86400000 ))&to=$(( $(date +%s) * 1000 ))" | jq '.[] | {id, text, dashboardId, time: (.time/1000 | todate)}'

# Search by tag
gcurl "$GRAFANA_URL/api/annotations?tags=deployment&limit=10"

# Search by dashboard ID
gcurl "$GRAFANA_URL/api/annotations?dashboardId=<ID>&limit=20"

# Create annotation
gcurl -X POST "$GRAFANA_URL/api/annotations" \
  -H "Content-Type: application/json" \
  -d '{"text": "Deployment v1.2.3", "tags": ["deployment"], "time": '$(( $(date +%s) * 1000 ))'}'
```

## Snapshots

```bash
# List snapshots
gcurl "$GRAFANA_URL/api/dashboard/snapshots" | jq '.[] | {key, name, expires}'

# Get snapshot by key
gcurl "$GRAFANA_URL/api/snapshots/<KEY>"

# Create snapshot (requires full dashboard model)
DASH=$(gcurl "$GRAFANA_URL/api/dashboards/uid/<UID>" | jq '.dashboard')
gcurl -X POST "$GRAFANA_URL/api/snapshots" \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $DASH, \"name\": \"snapshot-$(date +%Y%m%d)\", \"expires\": 3600}"
```

## Rendering (Screenshots)

Grafana can render panels as PNG if the image renderer plugin is installed.

```bash
# Render a panel as PNG (requires grafana-image-renderer plugin)
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
  "$GRAFANA_URL/render/d-solo/<DASHBOARD_UID>/<DASHBOARD_SLUG>?orgId=1&panelId=<PANEL_ID>&width=1000&height=500&from=now-6h&to=now" \
  -o panel.png

# Check if renderer is available
gcurl "$GRAFANA_URL/api/plugins/grafana-image-renderer"
```

Note: Image rendering requires the `grafana-image-renderer` plugin. If not installed, this will 404. Snapshots (above) are the alternative.

## Org & Health

```bash
# Current org
gcurl "$GRAFANA_URL/api/org"

# Grafana health
gcurl "$GRAFANA_URL/api/health"

# Grafana version/build info
gcurl "$GRAFANA_URL/api/frontend/settings" | jq '{version: .buildInfo.version, edition: .buildInfo.edition}'

# List installed plugins
gcurl "$GRAFANA_URL/api/plugins?embedded=0" | jq '.[] | {id, name, type}'
```

## Notes

- Annotation timestamps are in milliseconds (Unix epoch × 1000)
- Proxy endpoint `/api/datasources/proxy/<id>/...` passes requests directly to the datasource
- The unified `/api/ds/query` endpoint is preferred for new integrations but proxy still works
- SA token has Editor role — can create annotations and snapshots but not admin operations
- Dashboard UIDs are stable across imports; IDs are instance-specific
