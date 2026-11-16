# Zone-based firewall policies for port forwards whose target does not belong to a
# UniFi network. The Cilium LoadBalancer pool (192.168.69.0/24) is advertised to the
# gateway over BGP and is not a managed network, so UniFi cannot auto-create the
# allow policy it normally generates for a port forward. Without these policies the
# forwards match the External -> Internal block and are unreachable from the WAN.
#
# Zone data sources are declared in firewall_rules.tf.

resource "unifi_firewall_policy" "allow_qbittorrent" {
  name                 = "Allow Port Forward qBittorrent"
  action               = "ALLOW"
  protocol             = "tcp_udp"
  logging              = false
  create_allow_respond = true
  enabled              = true

  source = {
    zone_id         = data.unifi_firewall_zone.external.id
    matching_target = "ANY"
  }

  destination = {
    zone_id            = data.unifi_firewall_zone.internal.id
    matching_target    = "IP"
    ips                = ["192.168.69.122"]
    port               = "50469"
    port_matching_type = "SPECIFIC"
  }
}

resource "unifi_firewall_policy" "allow_livekit_turn" {
  name                 = "Allow Port Forward LiveKit TURN"
  action               = "ALLOW"
  protocol             = "tcp_udp"
  logging              = false
  create_allow_respond = true
  enabled              = true

  source = {
    zone_id         = data.unifi_firewall_zone.external.id
    matching_target = "ANY"
  }

  destination = {
    zone_id            = data.unifi_firewall_zone.internal.id
    matching_target    = "IP"
    ips                = ["192.168.69.137"]
    port               = "3478,7881"
    port_matching_type = "SPECIFIC"
  }
}
