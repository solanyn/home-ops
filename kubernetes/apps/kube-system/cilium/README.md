# Cilium

## IPv6 Dual-Stack Configuration

### Subnets
- **Nodes**: `fd5d:a293:f321:42::/64`
- **LoadBalancer**: `fd5d:a293:f321:69::/80`
- **Pods**: `fd5d:a293:f321:1042::/64`
- **Services**: `fd5d:a293:f321:1043::/80`

## UniFi BGP Configuration

```sh
router bgp 64513
  bgp router-id 192.168.1.1
  bgp log-neighbor-changes
  no bgp default ipv4-unicast

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor k8s-v6 peer-group
  neighbor k8s-v6 remote-as 64514

  bgp listen range 192.168.42.0/24 peer-group k8s
  bgp listen range fd5d:a293:f321:42::/64 peer-group k8s-v6

  address-family ipv4 unicast
    neighbor k8s activate
    neighbor k8s soft-reconfiguration inbound
    network 192.168.69.0/24
  exit-address-family

  address-family ipv6 unicast
    neighbor k8s-v6 activate
    neighbor k8s-v6 soft-reconfiguration inbound
    network fd5d:a293:f321:69::/80
    network fd5d:a293:f321:1042::/64
    network fd5d:a293:f321:1043::/80
  exit-address-family
exit
```
