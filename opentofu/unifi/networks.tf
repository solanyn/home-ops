import {
    to = unifi_network.default
    id = "677fb0df1ba9a91370f7eed2"
}

import {
    to = unifi_network.trusted
    id = "679c2c6ad05e5917b0e59457"
}

import {
    to = unifi_network.servers
    id = "679c2c3dd05e5917b0e5943c"
}

import {
    to = unifi_network.guest
    id = "68b32a7b837ef51624765d60"
}

import {
    to = unifi_network.iot
    id = "68b32aba837ef51624765d95"
}

import {
    to = unifi_network.vpn
    id = "68dce56f4e52f6793f1d3fc3"
}

resource "unifi_network" "default" {
    name                           = "Default"
    purpose                        = "corporate"
    subnet                         = "192.168.1.1/24"
    domain_name                    = "localdomain"
    auto_scale                     = false
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "none"
    ipv6_ra                        = false
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = false
    dhcp_server = {
        enabled           = true
        start             = "192.168.1.100"
        stop              = "192.168.1.200"
        leasetime         = "24h0m0s"
        dns_servers       = ["1.1.1.1", "1.0.0.1"]
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }

}

resource "unifi_network" "trusted" {
    name                           = "Trusted"
    purpose                        = "corporate"
    vlan                           = 10
    subnet                         = "192.168.10.1/24"
    domain_name                    = "internal"
    auto_scale                     = false
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "pd"
    ipv6_pd_auto_prefixid_enabled = true
    ipv6_pd_interface             = "wan"
    ipv6_ra                        = true
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = false
    dhcp_server = {
        enabled           = true
        start             = "192.168.10.100"
        stop              = "192.168.10.200"
        leasetime         = "24h0m0s"
        dns_servers       = ["192.168.1.1"]
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }
}

resource "unifi_network" "servers" {
    name                           = "Servers"
    purpose                        = "corporate"
    vlan                           = 42
    subnet                         = "192.168.42.1/24"
    domain_name                    = "internal"
    auto_scale                     = false
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "pd"
    ipv6_pd_auto_prefixid_enabled = true
    ipv6_pd_interface             = "wan"
    ipv6_ra                        = true
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = false
    dhcp_server = {
        enabled           = true
        start             = "192.168.42.100"
        stop              = "192.168.42.200"
        leasetime         = "24h0m0s"
        dns_servers       = ["192.168.1.1", "1.1.1.1", "1.0.0.1"]
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }
}

resource "unifi_network" "guest" {
    name                           = "Guest"
    purpose                        = "guest"
    vlan                           = 50
    subnet                         = "192.168.50.1/24"
    auto_scale                     = true
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "static"
    ipv6_static_subnet             = "2404:e80:414e:50::/64"
    ipv6_pd_auto_prefixid_enabled = true
    ipv6_ra                        = true
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = false
    dhcp_server = {
        enabled           = true
        start             = "192.168.50.6"
        stop              = "192.168.50.254"
        leasetime         = "24h0m0s"
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }
}

resource "unifi_network" "iot" {
    name                           = "IoT"
    purpose                        = "corporate"
    vlan                           = 70
    subnet                         = "192.168.70.1/24"
    auto_scale                     = false
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "pd"
    ipv6_pd_auto_prefixid_enabled = true
    ipv6_pd_interface             = "wan"
    ipv6_ra                        = true
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = false
    dhcp_server = {
        enabled           = true
        start             = "192.168.70.100"
        stop              = "192.168.70.200"
        leasetime         = "24h0m0s"
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }
}

resource "unifi_network" "vpn" {
    name                           = "VPN"
    purpose                        = "corporate"
    vlan                           = 90
    subnet                         = "192.168.90.1/24"
    auto_scale                     = false
    setting_preference             = "manual"
    igmp_snooping                  = false
    internet_access                = true
    multicast_dns                  = true
    lte_lan                        = true
    enabled                        = true
    gateway_type                   = "default"
    third_party_gateway            = false
    ipv6_client_address_assignment = "slaac"
    ipv6_interface_type            = "pd"
    ipv6_pd_auto_prefixid_enabled = true
    ipv6_pd_interface             = "wan"
    ipv6_ra                        = true
    ipv6_ra_preferred_lifetime     = "4h0m0s"
    ipv6_ra_priority               = "high"
    network_isolation              = true
    dhcp_server = {
        enabled           = true
        start             = "192.168.90.100"
        stop              = "192.168.90.200"
        leasetime         = "24h0m0s"
        conflict_checking = true
        dns_enabled       = false
        gateway_enabled   = false
        ntp_enabled       = false
        time_offset_enabled = false
        boot = { enabled = false }
        wins = { enabled = false }
    }
    dhcp_guarding = { enabled = false }
    dhcp_relay    = { enabled = false }
}