import {
    to = unifi_port_forward.qbittorrent
    id = "67990ab0d05e5917b0e53fbe"
}

import {
    to = unifi_port_forward.ps5_remote_play
    id = "6954bc6f2157a9491ebfeaf0"
}

resource "unifi_port_forward" "qbittorrent" {
    name     = "qBittorrent"
    protocol = "tcp"
    logging  = true

    forward = {
        ip   = "192.168.69.122"
        port = "50469"
    }

    wan = {
        interface  = "wan"
        ip_address = "any"
        port       = "50469"
    }

    source_limiting = {
        enabled = false
        ip      = "any"
    }
}

resource "unifi_port_forward" "ps5_remote_play" {
    name     = "PS5 Remote Play"
    protocol = "tcp_udp"
    logging  = false

    forward = {
        ip   = "192.168.1.189"
        port = "9302,9295,9296,9297"
    }

    wan = {
        interface  = "wan"
        ip_address = "any"
        port       = "9302,9295,9296,9297"
    }

    source_limiting = {
        enabled = false
        ip      = "any"
    }
}

resource "unifi_port_forward" "livekit_turn_tcp" {
    name     = "LiveKit TURN TCP"
    protocol = "tcp"
    logging  = false

    forward = {
        ip   = "192.168.69.137"
        port = "7881"
    }

    wan = {
        interface  = "wan"
        ip_address = "any"
        port       = "7881"
    }

    source_limiting = {
        enabled = false
        ip      = "any"
    }
}

resource "unifi_port_forward" "livekit_turn_udp" {
    name     = "LiveKit TURN UDP"
    protocol = "udp"
    logging  = false

    forward = {
        ip   = "192.168.69.137"
        port = "3478"
    }

    wan = {
        interface  = "wan"
        ip_address = "any"
        port       = "3478"
    }

    source_limiting = {
        enabled = false
        ip      = "any"
    }
}
