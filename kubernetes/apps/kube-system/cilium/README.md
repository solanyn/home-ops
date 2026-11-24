# Cilium

## IPv6 Dual-Stack Configuration

### Subnets

- **Nodes**: `${IPV6_PREFIX}:42::/64`
- **Pods**: `${IPV6_PREFIX}:11::/100`, carved into per-node `/108`s
- **Services**: `${IPV6_PREFIX}:12::/64`
- **LoadBalancer**: `${IPV6_PREFIX}:69::/64`

## UniFi BGP Configuration

```sh
router bgp 64513
  bgp router-id 192.168.1.1
  bgp log-neighbor-changes
  no bgp default ipv4-unicast
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor k8s-v6 peer-group
  neighbor k8s-v6 remote-as 64514

  bgp listen range 192.168.42.0/24 peer-group k8s
  bgp listen range ${IPV6_PREFIX}:42::/64 peer-group k8s-v6

  address-family ipv4 unicast
    neighbor k8s activate
    neighbor k8s soft-reconfiguration inbound
    network 192.168.69.0/24
  exit-address-family

  address-family ipv6 unicast
    neighbor k8s-v6 activate
    neighbor k8s-v6 soft-reconfiguration inbound
    network ${IPV6_PREFIX}:69::/64
    network ${IPV6_PREFIX}:11::/100
    network ${IPV6_PREFIX}:12::/64
  exit-address-family
exit
```

`no bgp ebgp-requires-policy` is required: without it FRR accepts the session but filters every route Cilium advertises, so the sessions show `established` while the UniFi routing table stays empty and LB/pod traffic falls through the default route.

The listen ranges must match the prefixes the VLAN actually carries. When the delegated prefix IDs are applied they are `:42::/64` for nodes and `:69::/64` for LB, matching the values here; until then the VLAN advertises whatever the UDM derived.
