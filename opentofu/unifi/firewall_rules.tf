# ################################################################################
# Zone-based firewall is broken on UCG Ultra fw 5.1.19 (HTTP 500 on zone create).
# Using legacy unifi_firewall_rule instead. Migrate to zones after firmware update.
# ################################################################################

resource "unifi_firewall_rule" "drop_iot_intervlan" {
    name       = "Block IoT inter-VLAN"
    action     = "drop"
    ruleset    = "LAN_IN"
    rule_index = 20000
    protocol   = "all"

    src_network_id = unifi_network.iot.id
    # dst = all (omitted) — blocks IoT to every other VLAN
    state_new = true

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
