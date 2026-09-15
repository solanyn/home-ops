import {
    to = unifi_dns_record.nas
    id = "69a4486212526bc52183348c"
}

resource "unifi_dns_record" "nas" {
    name        = "nas.goyangi.io"
    record_type = "A"
    value       = "192.168.42.9"
    ttl         = "5m"
}

resource "unifi_dns_record" "s3_versitygw" {
    name        = "s3-versitygw.goyangi.io"
    record_type = "A"
    value       = "192.168.42.9"
    ttl         = "5m"
}

resource "unifi_dns_record" "versitygw_admin" {
    name        = "versitygw-admin.goyangi.io"
    record_type = "A"
    value       = "192.168.42.9"
    ttl         = "5m"
}

resource "unifi_dns_record" "versitygw" {
    name        = "versitygw.goyangi.io"
    record_type = "A"
    value       = "192.168.42.9"
    ttl         = "5m"
}
