locals {
    dhcp_24h = "86400s"
}

resource "unifi_network" "default" {
    name        = "Default"
    purpose     = "corporate"
    subnet      = "192.168.1.1/24"
    domain_name = "localdomain"
    dhcp_server = {
        enabled   = true
        start     = "192.168.1.100"
        stop      = "192.168.1.200"
        leasetime = local.dhcp_24h
    }
}

resource "unifi_network" "trusted" {
    name        = "Trusted"
    purpose     = "corporate"
    vlan        = 10
    subnet      = "192.168.10.1/24"
    domain_name = "internal"
    dhcp_server = {
        enabled   = true
        start     = "192.168.10.100"
        stop      = "192.168.10.200"
        leasetime = local.dhcp_24h
    }
}

resource "unifi_network" "servers" {
    name        = "Servers"
    purpose     = "corporate"
    vlan        = 42
    subnet      = "192.168.42.1/24"
    domain_name = "internal"
    dhcp_server = {
        enabled   = true
        start     = "192.168.42.100"
        stop      = "192.168.42.200"
        leasetime = local.dhcp_24h
    }
}

resource "unifi_network" "guest" {
    name    = "Guest"
    purpose = "guest"
    vlan    = 50
    subnet  = "192.168.50.1/24"
    dhcp_server = {
        enabled   = true
        start     = "192.168.50.6"
        stop      = "192.168.50.254"
        leasetime = local.dhcp_24h
    }
}

resource "unifi_network" "iot" {
    name    = "IoT"
    purpose = "corporate"
    vlan    = 70
    subnet  = "192.168.70.1/24"
    dhcp_server = {
        enabled   = true
        start     = "192.168.70.100"
        stop      = "192.168.70.200"
        leasetime = local.dhcp_24h
    }
}

resource "unifi_network" "vpn" {
    name    = "VPN"
    purpose = "corporate"
    vlan    = 90
    subnet  = "192.168.90.1/24"
    dhcp_server = {
        enabled   = true
        start     = "192.168.90.100"
        stop      = "192.168.90.200"
        leasetime = local.dhcp_24h
    }
}