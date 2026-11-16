# ################################################################################
# Zone-based firewall policies (UniFi Network 8.x+/OS 6.x).
#
# These were originally written as legacy `unifi_firewall_rule` LAN_IN rules because
# zone creation returned HTTP 500 on UCG Ultra fw 5.1.19. The controller has since
# migrated to zone-based firewall and the legacy firewallrule API now returns zero
# objects, while the intended state lives on as zone policies (one legacy rule
# expanded into one policy per destination zone). The resources below import and
# manage those live policies directly.
# ################################################################################

# Legacy LAN_IN rules. The UniFi controller migrated these to the zone-based
# policies below and the legacy firewallrule API now returns an empty list, so the
# objects no longer exist. Forget them from state (destroy = false) rather than
# removing the resources outright, which would emit a destroy call on apply.
removed {
  from = unifi_firewall_rule.drop_iot_intervlan
  lifecycle {
    destroy = false
  }
}

removed {
  from = unifi_firewall_rule.allow_default_to_nas_smb
  lifecycle {
    destroy = false
  }
}

removed {
  from = unifi_firewall_rule.allow_default_to_nas_web
  lifecycle {
    destroy = false
  }
}

removed {
  from = unifi_firewall_rule.drop_default_to_servers
  lifecycle {
    destroy = false
  }
}

import {
  to = unifi_firewall_group.local_networks
  id = "ce664d06-6a6e-410b-9f69-917bfdf43ef7"
}

data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

data "unifi_firewall_zone" "external" {
  name = "External"
}

data "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"
}

data "unifi_firewall_zone" "vpn" {
  name = "Vpn"
}

locals {
  # Destination zone per legacy-rule expansion, keyed by zone name.
  zones = {
    internal = data.unifi_firewall_zone.internal.id
    external = data.unifi_firewall_zone.external.id
    hotspot  = data.unifi_firewall_zone.hotspot.id
    vpn      = data.unifi_firewall_zone.vpn.id
  }

  # Live policy IDs produced by the controller's legacy->zone migration.
  iot_intervlan_policies = {
    internal = "1168b3da-6dfc-4153-87a8-bd5bc147c7e4"
    hotspot  = "76e0bfc7-bdfd-4a72-9c44-7b8092ccc678"
    external = "255f9339-b787-442b-829f-ee2d6f13036a"
    vpn      = "8f992f18-edd4-4e76-aabb-c1bfdeddb1c9"
  }

  nas_smb_policies = {
    internal = "ec5c0ed0-77dd-41cf-bd37-54db9b4a35dd"
    hotspot  = "c8fe82e8-5ace-4c39-a7e4-5be2a3bbb5be"
    external = "9d153be4-2a51-4c54-a6ab-8a414f0806bf"
    vpn      = "2146a67d-4499-4a6f-b7bd-c36a0c3c0576"
  }

  nas_web_policies = {
    internal = "2d2032ba-a1b6-4f7e-b06c-89eb31cfe07b"
    hotspot  = "175bb702-f49e-4cb1-9abe-c012ede56414"
    external = "408f5764-42e5-4d6f-ad9d-c99d7cdcc27a"
    vpn      = "c55cbf3e-f0f6-44a5-9205-1db9ec4e4f71"
  }
}

resource "unifi_firewall_group" "local_networks" {
  name = "RFC1918 Local Networks"
  type = "address-group"

  members = [
    "192.168.1.0/24",
    "192.168.10.0/24",
    "192.168.42.0/24",
    "192.168.50.0/24",
    "192.168.90.0/24",
  ]
}

# ------------------------------------------------------------------------------
# Block IoT -> every other local zone.
# ------------------------------------------------------------------------------

import {
  for_each = local.iot_intervlan_policies
  to       = unifi_firewall_policy.drop_iot_intervlan[each.key]
  id       = each.value
}

resource "unifi_firewall_policy" "drop_iot_intervlan" {
  for_each = local.iot_intervlan_policies

  name     = "Block IoT inter-VLAN"
  action   = "BLOCK"
  protocol = "all"
  enabled  = true

  source = {
    zone_id         = local.zones.internal
    matching_target = "NETWORK"
    network_ids     = [unifi_network.iot.id]
  }

  destination = {
    zone_id         = local.zones[each.key]
    matching_target = "IP"
    ip_group_id     = unifi_firewall_group.local_networks.id
  }
}

# ------------------------------------------------------------------------------
# Allow Default -> NAS SMB (445).
# ------------------------------------------------------------------------------

import {
  for_each = local.nas_smb_policies
  to       = unifi_firewall_policy.allow_default_to_nas_smb[each.key]
  id       = each.value
}

resource "unifi_firewall_policy" "allow_default_to_nas_smb" {
  for_each = local.nas_smb_policies

  name     = "Allow Default to NAS SMB"
  action   = "ALLOW"
  protocol = "tcp"
  enabled  = true

  source = {
    zone_id         = local.zones.internal
    matching_target = "NETWORK"
    network_ids     = [unifi_network.default.id]
  }

  destination = {
    zone_id            = local.zones[each.key]
    matching_target    = "IP"
    ips                = ["192.168.42.9"]
    port               = "445"
    port_matching_type = "SPECIFIC"
  }
}

# ------------------------------------------------------------------------------
# Allow Default -> NAS web (80,443).
# ------------------------------------------------------------------------------

import {
  for_each = local.nas_web_policies
  to       = unifi_firewall_policy.allow_default_to_nas_web[each.key]
  id       = each.value
}

resource "unifi_firewall_policy" "allow_default_to_nas_web" {
  for_each = local.nas_web_policies

  name     = "Allow Default to NAS Web"
  action   = "ALLOW"
  protocol = "tcp"
  enabled  = true

  source = {
    zone_id         = local.zones.internal
    matching_target = "NETWORK"
    network_ids     = [unifi_network.default.id]
  }

  destination = {
    zone_id            = local.zones[each.key]
    matching_target    = "IP"
    ips                = ["192.168.42.9"]
    port               = "80,443"
    port_matching_type = "SPECIFIC"
  }
}

# ------------------------------------------------------------------------------
# Block Default -> Servers.
# ------------------------------------------------------------------------------

import {
  to = unifi_firewall_policy.drop_default_to_servers
  id = "1e562200-d26b-4c42-9994-c89caa839c78"
}

resource "unifi_firewall_policy" "drop_default_to_servers" {
  name     = "Block Default to Servers"
  action   = "BLOCK"
  protocol = "all"
  enabled  = true

  source = {
    zone_id         = local.zones.internal
    matching_target = "NETWORK"
    network_ids     = [unifi_network.default.id]
  }

  destination = {
    zone_id         = local.zones.internal
    matching_target = "NETWORK"
    network_ids     = [unifi_network.servers.id]
  }
}
