# Edge VPS (OVH)

Public edge host for towonel tunnelling, caddy layer-4 ingress, crowdsec and gatus monitoring.

## Provisioning (clickops — no Terraform)

1. Order a **VPS-1 2027** (`vps-2027-model1`) at https://www.ovhcloud.com/en-au/vps/
   - Datacenter: **SYD**
   - OS: **Ubuntu 24.04 LTS** (x64)
2. Attach the **Personal SSH Key** (1Password `kubernetes/Personal SSH Key`, ed25519) at order time.
3. Keep exactly one VPS subscription. If duplicate paid orders exist (e.g. from the abandoned Terraform flow), open a support ticket to cancel/refund the extras.

DNS is managed as IaC via the `towonel-edge` DNSEndpoint in `kubernetes/apps/network/towonel-operator/` (external-dns writes unproxied A records to Cloudflare): `towonel.goyangi.io`, `edge-doco-cd.goyangi.io`, `edge-gatus.goyangi.io` → VPS IP.

## 1Password items

| Item | Field | Value |
|------|-------|-------|
| `towonel` (new) | `TOWONEL_INVITE_HASH_KEY` | `openssl rand -base64 32` |
| `towonel` | `GATUS_HEARTBEAT_TOKEN` | `openssl rand -base64 32` |
| `pushover` (add) | `GATUS_PUSHOVER_TOKEN` | new Pushover application token (pushover.net) |

Public values (`TOWONEL_PUBLIC_URL`, `CADDY_ACME_EMAIL`) are hardcoded in the compose files, not stored in 1Password.

Create a 1Password service account scoped to read the `kubernetes` vault. Its token, plus an API secret and webhook secret, become `/opt/doco-cd/{1pw_token,api_secret,webhook_secret}`.

Reuse the existing shared service account token from the `1password` item (`op://kubernetes/1password/OP_SERVICE_ACCOUNT_TOKEN`) — it already has read access to the `kubernetes` vault and is used by hermes and the GitHub Actions workflows.

## Bootstrap

```bash
# 1. Run the bootstrap playbook (installs Docker + writes doco-cd secrets)
export OP_EDGE_SERVICE_ACCOUNT_TOKEN="$(op read "op://kubernetes/1password/OP_SERVICE_ACCOUNT_TOKEN")"
export DOCO_CD_API_SECRET="$(openssl rand -base64 32)"
export DOCO_CD_WEBHOOK_SECRET="$(openssl rand -base64 32)"
ansible-playbook -i ansible/edge/hosts.ini ansible/edge/playbook.yaml

# 2. Create the external docker network all stacks attach to
ssh ubuntu@139.99.135.40 'docker network create edge'

# 3. Start doco-cd (deploys docker/edge/* from this repo)
docker compose -f docker/edge/.doco-cd/docker-compose.app.yaml up -d
```

doco-cd polls this repo every hour and applies `docker/edge/01-04` stacks: crowdsec, towonel (hub + edge), caddy-l4, gatus.

## Verification

- `ssh ubuntu@139.99.135.40` — key auth only, password auth disabled
- `docker ps` — towonel-hub, caddy-l4, crowdsec, gatus running
- `https://edge-doco-cd.goyangi.io` — doco-cd UI
- `https://edge-gatus.goyangi.io` — status page

## Teardown

- Terminate the VPS in OVH console (Services → VPS → terminate) for prorated refund
- Delete the `towonel-edge` DNSEndpoint and the `towonel` item
