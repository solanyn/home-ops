import {
    to = unifi_client.k8s_0
    id = "6c:2b:59:df:10:cb"
}

import {
    to = unifi_client.k8s_1
    id = "6c:2b:59:cc:52:83"
}

import {
    to = unifi_client.k8s_2
    id = "b8:85:84:a2:5d:97"
}

import {
    to = unifi_client.nas
    id = "30:5a:3a:7c:c5:f9"
}

import {
    to = unifi_client.ps5
    id = "5c:84:3c:a6:4d:e3"
}

import {
    to = unifi_client.andrews_kobo
    id = "a4:3c:d7:31:1c:bf"
}

import {
    to = unifi_client.bluebubbles
    id = "6c:40:08:a4:6f:6c"
}

import {
    to = unifi_client.living_room
    id = "c4:f7:c1:68:2d:f7"
}

import {
    to = unifi_client.playstation_portal
    id = "9c:37:cb:31:fc:51"
}

import {
    to = unifi_client.slzb_mr2u
    id = "82:b5:4e:97:a3:4c"
}

import {
    to = unifi_client.work_laptop
    id = "10:bd:3a:60:67:7a"
}

import {
    to = unifi_client.yeelight_lamp_1
    id = "78:11:dc:8f:eb:2d"
}

import {
    to = unifi_client.yeelight_lamp_2
    id = "50:ec:50:c2:47:c3"
}

import {
    to = unifi_client.andrews_mac_mini
    id = "d0:11:e5:7b:39:53"
}

import {
    to = unifi_client.ayn_thor
    id = "be:09:cf:51:ab:a2"
}

import {
    to = unifi_client.air_purifier
    id = "84:e3:42:41:d1:2c"
}

import {
    to = unifi_client.breville_fan
    id = "24:d7:eb:c9:71:46"
}

import {
    to = unifi_client.google_home_mini
    id = "e4:f0:42:3a:dd:40"
}

import {
    to = unifi_client.google_nest_cam
    id = "20:1f:3b:c8:26:dc"
}

import {
    to = unifi_client.hue_bridge
    id = "ec:b5:fa:98:9e:93"
}

import {
    to = unifi_client.tplink_kasa_bulb
    id = "b0:95:75:f8:a4:19"
}

# Infrastructure — Servers VLAN
resource "unifi_client" "k8s_0" {
    mac        = "6c:2b:59:df:10:cb"
    fixed_ip   = "192.168.42.10"
    network_id = unifi_network.servers.id
    name       = "k8s-0"
}

resource "unifi_client" "k8s_1" {
    mac        = "6c:2b:59:cc:52:83"
    fixed_ip   = "192.168.42.11"
    network_id = unifi_network.servers.id
    name       = "k8s-1"
}

resource "unifi_client" "k8s_2" {
    mac        = "b8:85:84:a2:5d:97"
    fixed_ip   = "192.168.42.12"
    network_id = unifi_network.servers.id
    name       = "k8s-2"
}

resource "unifi_client" "nas" {
    mac        = "30:5a:3a:7c:c5:f9"
    fixed_ip   = "192.168.42.9"
    network_id = unifi_network.servers.id
    name       = "NAS"
}

# Default VLAN — consumer devices
resource "unifi_client" "ps5" {
    mac        = "5c:84:3c:a6:4d:e3"
    fixed_ip   = "192.168.1.189"
    network_id = unifi_network.default.id
    name       = "PlayStation 5"
}

resource "unifi_client" "andrews_kobo" {
    mac        = "a4:3c:d7:31:1c:bf"
    fixed_ip   = "192.168.1.181"
    network_id = unifi_network.default.id
    name       = "Andrew's Kobo"
}

resource "unifi_client" "bluebubbles" {
    mac        = "6c:40:08:a4:6f:6c"
    fixed_ip   = "192.168.1.109"
    network_id = unifi_network.default.id
    name       = "bluebubbles"
}

resource "unifi_client" "living_room" {
    mac        = "c4:f7:c1:68:2d:f7"
    fixed_ip   = "192.168.1.199"
    network_id = unifi_network.default.id
    name       = "Living-Room"
}

resource "unifi_client" "playstation_portal" {
    mac        = "9c:37:cb:31:fc:51"
    fixed_ip   = "192.168.1.190"
    network_id = unifi_network.default.id
    name       = "PlayStation Portal"
}

resource "unifi_client" "slzb_mr2u" {
    mac        = "82:b5:4e:97:a3:4c"
    fixed_ip   = "192.168.1.90"
    network_id = unifi_network.default.id
    name       = "SLZB-MR2U"
}

resource "unifi_client" "work_laptop" {
    mac        = "10:bd:3a:60:67:7a"
    fixed_ip   = "192.168.1.94"
    network_id = unifi_network.default.id
    name       = "Work Laptop"
}

resource "unifi_client" "yeelight_lamp_1" {
    mac        = "78:11:dc:8f:eb:2d"
    fixed_ip   = "192.168.1.93"
    network_id = unifi_network.default.id
    name       = "Yeelight Lamp 1"
}

resource "unifi_client" "yeelight_lamp_2" {
    mac        = "50:ec:50:c2:47:c3"
    fixed_ip   = "192.168.1.92"
    network_id = unifi_network.default.id
    name       = "Yeelight Lamp 2"
}

# Trusted VLAN — personal admin devices
resource "unifi_client" "andrews_mac_mini" {
    mac        = "d0:11:e5:7b:39:53"
    fixed_ip   = "192.168.10.30"
    network_id = unifi_network.trusted.id
    name       = "Andrew's Mac Mini"
}

resource "unifi_client" "ayn_thor" {
    mac        = "be:09:cf:51:ab:a2"
    fixed_ip   = "192.168.10.137"
    network_id = unifi_network.trusted.id
    name       = "AYN Thor"
}

# IoT VLAN — smart home devices
resource "unifi_client" "air_purifier" {
    mac        = "84:e3:42:41:d1:2c"
    fixed_ip   = "192.168.70.140"
    network_id = unifi_network.iot.id
    name       = "Air Purifier"
}

resource "unifi_client" "breville_fan" {
    mac        = "24:d7:eb:c9:71:46"
    fixed_ip   = "192.168.70.190"
    network_id = unifi_network.iot.id
    name       = "Breville EasyAir Fan"
}

resource "unifi_client" "google_home_mini" {
    mac        = "e4:f0:42:3a:dd:40"
    fixed_ip   = "192.168.70.110"
    network_id = unifi_network.iot.id
    name       = "Google Home Mini"
}

resource "unifi_client" "google_nest_cam" {
    mac        = "20:1f:3b:c8:26:dc"
    fixed_ip   = "192.168.70.120"
    network_id = unifi_network.iot.id
    name       = "Google Nest Cam"
}

resource "unifi_client" "hue_bridge" {
    mac        = "ec:b5:fa:98:9e:93"
    fixed_ip   = "192.168.70.152"
    network_id = unifi_network.iot.id
    name       = "Hue Bridge"
}

resource "unifi_client" "tplink_kasa_bulb" {
    mac        = "b0:95:75:f8:a4:19"
    fixed_ip   = "192.168.70.100"
    network_id = unifi_network.iot.id
    name       = "TPLink Kasa Bulb"
}
