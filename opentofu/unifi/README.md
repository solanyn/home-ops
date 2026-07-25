# UniFi Network IaC

Managed by Terraform via [tofu-controller](https://github.com/flux-iac/tofu-controller) in flux-system. Auto-applies from main — push to change.

## What's managed

| Resource | File | Notes |
|----------|------|-------|
| Networks (6) | `networks.tf` | Default, Trusted, Servers, Guest, IoT, VPN |
| Port forwards | `port_forwards.tf` | qBittorrent, PS5 Remote Play |
| Static route (Thread) | `static_routes.tf` | `fd39:b979:bba3:d01d::/64` via OTBR |
| Client fixed IPs (21) | `clients.tf` | Infra devices across all VLANs |
| Firewall rules | `firewall_rules.tf` | Legacy rules (zone-based broken on UCG Ultra fw 5.1.19) |

## How to modify

1. Edit the relevant `.tf` file
2. `tofu validate` to check syntax
3. Commit and push to main
4. Flux reconciles, tofu-controller plans and auto-applies

## Verification

```bash
# List firewall rules
curl -sk -H "X-API-Key: $(kubectl get secret -n network unifi-secret -o jsonpath='{.data.UNIFI_API_KEY}' | base64 -d)" \
  https://192.168.10.1/proxy/network/api/s/default/rest/firewallrule

# Check Terraform controller state
kubectl get terraform -n network unifi -o json | jq '.status'
```

unifi-mcp at `https://unifi-mcp.goyangi.io` can also inspect and test rules.

## Rollback

1. `git revert <commit>` and push
2. Flux reconciles and reverts
3. Or bypass Git: `kubectl edit terraform -n network unifi` to disable a resource, or use the direct API to patch

## Known issues

Zone-based firewall (`unifi_firewall_zone` + `unifi_firewall_policy`) returns HTTP 500 on UCG Ultra fw 5.1.19 ([provider issue #314](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/314)). Using legacy `unifi_firewall_rule` instead. Migrate after firmware update.
