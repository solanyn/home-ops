output "network_ids" {
    value = {
        default = unifi_network.default.id
        trusted = unifi_network.trusted.id
        servers = unifi_network.servers.id
        guest   = unifi_network.guest.id
        iot     = unifi_network.iot.id
        vpn     = unifi_network.vpn.id
    }
}