locals {
    dhcp_24h = "86400s"
}

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