---
name: unifi
description: Query and manage UniFi Network via REST API. Use for client lists, device status, network/VLAN config, port forwarding, traffic stats, DPI data, and site health. Also covers Unifi config-as-code via the ubiquiti-community/unifi Terraform provider and tofu-controller for GitOps reconciliation. Triggers on "connected devices", "network status", "wifi clients", "port forward", "VLAN", "UniFi", "unifi terraform", "tofu-controller", "ubiquiti-community/unifi".
---

# UniFi Network API

REST API access to UniFi Network Application. Cookie-based auth with CSRF token.

## Authentication

```bash
# Login (returns session cookie + CSRF token)
UNIFI_URL="https://192.168.1.1"  # or wherever the controller is
UNIFI_USER=$(op read "op://kubernetes/unifi/UNIFI_USERNAME" 2>/dev/null || echo "admin")
UNIFI_PASS=$(op read "op://kubernetes/unifi/UNIFI_PASSWORD")

# UDM/UDM-Pro uses /api/auth/login
curl -sk -c /tmp/unifi-cookies.txt \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$UNIFI_USER\",\"password\":\"$UNIFI_PASS\"}" \
  "$UNIFI_URL/api/auth/login"

# Extract CSRF token from cookies
CSRF=$(grep -oP 'csrf_token\s+\K\S+' /tmp/unifi-cookies.txt)

# Helper alias
alias ucurl='curl -sk -b /tmp/unifi-cookies.txt -H "X-CSRF-Token: $CSRF"'
```

Note: UDM-based controllers use `/api` prefix. Standalone controllers use `/api/s/{site}/` (default site is `default`).

### 1Password Dependency

The skill assumes `op` is installed and signed in. If `op read` fails (binary missing OR not on PATH), the credential expansion silently falls back to `echo "admin"` — which then fails at login. Check before starting:

```bash
command -v op && op whoami 2>&1 | head -1 || echo "op not available — install or paste creds directly"
```

**PATH gotcha — check `/opt/data/homebrew/.linuxbrew/bin/op` even when `command -v op` fails.** On Hermes deployments in `solanyn/home-ops` (initContainer + linuxbrew bootstrap pattern), `op` and other CLIs are installed into a Linuxbrew prefix at `/opt/data/homebrew/.linuxbrew/` that is NOT on the default `PATH` (`/usr/local/bin:/usr/bin:/bin`). `command -v op` returns nothing even though the binary is there. Either use the absolute path (`/opt/data/homebrew/.linuxbrew/bin/op …`) or prepend `PATH=/opt/data/homebrew/.linuxbrew/bin:/opt/data/homebrew/.linuxbrew/sbin:$PATH` for the call. Before concluding `op` is missing, also `ls /opt/data/homebrew/.linuxbrew/bin/` — other dropped-in CLIs (`gh`, `glab`, `kubectl`, `flux`, etc.) follow the same convention.

Install options:
- **Canonical on this deployment**: `/opt/data/homebrew/.linuxbrew/bin/brew install 1password-cli` (after linuxbrew bootstrap lands) → lands `op` at `/opt/data/homebrew/.linuxbrew/bin/op`
- macOS dev box: `brew install 1password-cli`
- Other: `sudo apt install 1password-cli` (Debian/Ubuntu), `apk add 1password-cli` (Alpine)

Or paste the Unifi admin creds directly into the curl command for a session-scoped approach — they stay in env vars, never on disk.

## UDM-Pro vs Classic Controller

Same API surface, but a few differences matter:

- **Auth path**: UDM-Pro uses `/api/auth/login`; classic controllers use `/api/login`.
- **Firewall rules**: UDM-Pro uses the new ruleset format (`firewallrule` endpoints exist for both, but `ruleset` is the modern UDM shape). If extracting config for Terraform, plan to translate.
- **Some settings only in the v2 API** (`/proxy/network/v2/api/site/default/...`) — undocumented, changes between firmware versions.
- **Always export a `.unf` backup** before any config-extraction work. The REST API doesn't cover everything (IPS/IDS details, Smart Queues, advanced WiFi radio settings), and the backup is ground truth.

## Config-as-Code (Terraform + Reconciliation)

For managing Unifi config via GitOps:

- **Provider**: [`ubiquiti-community/unifi`](https://registry.terraform.io/providers/ubiquiti-community/unifi/latest) — full coverage for networks, VLANs, firewall rules, port forwards, WLANs, DNS, users.
- **Controller**: [`tofu-controller`](https://github.com/flux-iac/tofu-controller) runs Terraform from a Flux GitRepository on a schedule. Pair with `applyOnDecline: false` so every apply needs explicit approval.
- **Auth**: long-lived local admin on the UDM, stored via SOPS/age/1Password in TF state and provider env. Never plaintext in repo.
- **Audit first**: before codifying anything, dump live config via this skill's REST API and audit (1) what's *actually configured* vs defaulted, (2) what changes often (DNS records, port forwards) vs never (VLANs), (3) what genuinely benefits from drift detection vs what would just create "cluster broke the network" outages.

**UDM-Pro provider gotchas**: the provider was historically best on classic controllers. UDM-Pro support is "works for most things" but IPS/IDS, traffic rules in the new ruleset format, and Smart Queues either need raw API calls or are broken. Check the issue tracker before committing.

## Site Health

```bash
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/health"
```

## Connected Clients

```bash
# All active clients
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/sta" | jq '.data[] | {name, hostname, ip, mac, network: .network, rx_bytes, tx_bytes}'

# Client count
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/sta" | jq '.data | length'

# Search by name/hostname
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/sta" | jq '.data[] | select(.hostname // .name | test("iphone"; "i"))'
```

## Devices (APs, Switches, Gateway)

```bash
# All devices
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/device" | jq '.data[] | {name, model, type, ip, version: .version, uptime, status: (if .state == 1 then "connected" else "disconnected" end)}'

# Device details by MAC
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/device/$MAC"
```

## Networks / VLANs

```bash
# List networks
ucurl "$UNIFI_URL/proxy/network/api/s/default/rest/networkconf" | jq '.data[] | {_id, name, vlan_enabled, vlan, subnet: .ip_subnet, purpose}'
```

## Port Forwarding

```bash
# List rules
ucurl "$UNIFI_URL/proxy/network/api/s/default/rest/portforward" | jq '.data[] | {name, dst_port, fwd, fwd_port, proto, enabled}'
```

## Firewall Rules

```bash
ucurl "$UNIFI_URL/proxy/network/api/s/default/rest/firewallrule" | jq '.data[] | {name, action, ruleset, enabled, src_address, dst_address}'
```

## Traffic / DPI Stats

```bash
# DPI stats (last 24h)
ucurl -X POST "$UNIFI_URL/proxy/network/api/s/default/stat/sitedpi" \
  -H "Content-Type: application/json" \
  -d '{"type":"by_app","attrs":["rx_bytes","tx_bytes"]}' | jq '.data[:10]'

# Client traffic history
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/report/hourly.site" | jq '.data[-24:]'
```

## DNS Settings

```bash
ucurl "$UNIFI_URL/proxy/network/api/s/default/rest/setting" | jq '.data[] | select(.key == "usg") | .dns'
```

## System Info

```bash
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/sysinfo" | jq '.data[0]'
```

## Events / Alerts

```bash
# Recent events
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/event?_limit=20" | jq '.data[] | {datetime, msg, key}'

# Alarms
ucurl "$UNIFI_URL/proxy/network/api/s/default/stat/alarm" | jq '.data[] | {datetime, msg, archived}'
```

## Known Limitations

- IGMP querier changes via API return `rc: ok` but don't actually apply — must use UI
- Some settings require the new Settings API (`/proxy/network/v2/api/site/default/...`) which is undocumented
- Rate limiting: no official limits but avoid rapid polling
- Self-signed cert: use `-k` flag with curl
- UDM firmware updates can change API paths

## API Path Reference

| UDM/UDM-Pro | Standalone Controller |
|---|---|
| `/api/auth/login` | `/api/login` |
| `/proxy/network/api/s/{site}/...` | `/api/s/{site}/...` |

## Credentials

Check 1Password for `unifi` item. If not found, the controller may use local-only credentials.
