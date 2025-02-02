# Cilium

## UniFi BGP

Install:

```sh
apt install frr
sed -i -e 's/bgpd\=no/bgpd\=yes/g' /etc/frr/daemons # change bgpd=no to bgpd=yes in /etc/frr/daemons
systemctl enable frr
systemctl start frr
```

In `/etc/frr/frr.conf`:

```sh
router bgp 64513
  bgp router-id 192.168.1.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor 192.168.1.11 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```

