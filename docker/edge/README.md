# Edge VPS (OVH)

Public edge host for towonel tunnelling, caddy layer-4 ingress and gatus monitoring.

## Provisioning (clickops — no Terraform)

1. Order a **VPS-1 2027** (`vps-2027-model1`) at https://www.ovhcloud.com/en-au/vps/
   - Datacenter: **SYD**
   - OS: **Ubuntu 24.04 LTS** (x64)
2. Attach the **Personal SSH Key** (1Password `kubernetes/Personal SSH Key`, ed25519) at order time.
3. On first boot, verify access: `ssh root@<VPS_IP>`
4. Keep exactly one VPS subscription. If duplicate paid orders exist (e.g. from the abandoned Terraform flow), open a support ticket to cancel/refund the extras.
5. Add DNS records in Cloudflare (all unproxied, TTL 60, A → VPS_IP):
   - `twnl.goyangi.io`
   - `edge-doco-cd.goyangi.io`
   - `edge-gatus.goyangi.io`

## 1Password items

| Item | Field | Value |
|------|-------|-------|
| `towonel-tunnel` (new) | `TOWONEL_INVITE_HASH_KEY` | `openssl rand -base64 32` |
| `towonel-tunnel` | `TOWONEL_PUBLIC_URL` | `https://twnl.goyangi.io` |
| `towonel-tunnel` | `CADDY_ACME_EMAIL` | `andrewchen1520@gmail.com` |
| `towonel-tunnel` | `VPS_IP` | VPS public IP |
| `pushover` (add) | `GATUS_PUSHOVER_TOKEN` | new Pushover application token (pushover.net) |

Create a 1Password service account scoped to read the `kubernetes` vault. Its token, plus an API secret and webhook secret, become `/opt/doco-cd/{1pw_token,api_secret,webhook_secret}`.

## Bootstrap

```bash
# 1. Point inventory at the VPS
sed -i "s|<VPS_IP>|<actual ip>|" ansible/edge/hosts.ini

# 2. Run the bootstrap playbook (installs Docker + writes doco-cd secrets)
export OP_EDGE_SERVICE_ACCOUNT_TOKEN="$(op read "op://..." )"
export DOCO_CD_API_SECRET="$(openssl rand -base64 32)"
export DOCO_CD_WEBHOOK_SECRET="$(openssl rand -base64 32)"
ansible-playbook -i ansible/edge/hosts.ini ansible/edge/playbook.yaml

# 3. Create the external docker network all stacks attach to
ssh root@<VPS_IP> 'docker network create edge'

# 4. Start doco-cd (deploys docker/edge/* from this repo)
docker compose -f docker/edge/.doco-cd/docker-compose.app.yaml up -d
```

doco-cd polls this repo every hour and applies `docker/edge/01-04` stacks: crowdsec, towonel (hub + edge), caddy-l4, gatus.

## Verification

- `ssh root@<VPS_IP>` — key auth only, password auth disabled
- `docker ps` — towonel-hub, caddy-l4, crowdsec, gatus running
- `https://edge-doco-cd.goyangi.io` — doco-cd UI
- `https://edge-gatus.goyangi.io` — status page

## Teardown

- Terminate the VPS in OVH console (Services → VPS → terminate) for prorated refund
- Delete the three DNS records and the `towonel-tunnel` item
