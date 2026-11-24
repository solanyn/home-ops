# Cilium

## IPv6 Dual-Stack Configuration

### Subnets

- **Nodes**: `2404:e80:414e:42::/64`
- **Pods**: `2404:e80:414e:11::/100`, carved into per-node `/108`s
- **Services**: `2404:e80:414e:12::/64`
- **LoadBalancer**: `2404:e80:414e:69::/64`

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
  bgp listen range 2404:e80:414e:42::/64 peer-group k8s-v6

  address-family ipv4 unicast
    neighbor k8s activate
    neighbor k8s soft-reconfiguration inbound
    network 192.168.69.0/24
  exit-address-family

  address-family ipv6 unicast
    neighbor k8s-v6 activate
    neighbor k8s-v6 soft-reconfiguration inbound
    network 2404:e80:414e:69::/64
    network 2404:e80:414e:11::/100
    network 2404:e80:414e:12::/64
  exit-address-family
exit
```
