# ################################################################################
# Zone-based firewall is broken on UCG Ultra fw 5.1.19 (HTTP 500 on zone create).
# Using legacy unifi_firewall_rule instead. Migrate to zones after firmware update.
# ################################################################################

import {
    to = unifi_firewall_group.local_networks
    id = "6a731746eedf1cb17e331484"
}

import {
    to = unifi_firewall_rule.drop_iot_intervlan
    id = "6a64235eaaa1766c27a0c0ed"
}

import {
    to = unifi_firewall_rule.allow_default_to_nas_smb
    id = "6a6dacbdeedf1cb17e31843e"
}

import {
    to = unifi_firewall_rule.drop_default_to_servers
    id = "6a64235eaaa1766c27a0c0ea"
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

resource "unifi_firewall_rule" "drop_iot_intervlan" {
    name       = "Block IoT inter-VLAN"
    action     = "drop"
    ruleset    = "LAN_IN"
    rule_index = 20000
    protocol   = "all"

    src_network_id        = unifi_network.iot.id
    dst_firewall_group_ids = [unifi_firewall_group.local_networks.id]
    state_new             = true

    enabled = true
}

resource "unifi_firewall_rule" "allow_default_to_nas_smb" {
    name       = "Allow Default to NAS SMB"
    action     = "accept"
    ruleset    = "LAN_IN"
    rule_index = 20005
    protocol   = "tcp"

    src_network_id = unifi_network.default.id
    dst_address    = "192.168.42.9"
    dst_port       = "445"
    state_new      = true

    enabled = true
}

resource "unifi_firewall_rule" "drop_default_to_servers" {
    name       = "Block Default to Servers"
    action     = "drop"
    ruleset    = "LAN_IN"
    rule_index = 20010
    protocol   = "all"

    src_network_id = unifi_network.default.id
    dst_network_id = unifi_network.servers.id
    state_new = true

    enabled = true
}
