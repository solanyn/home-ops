resource "unifi_dns_record" "nas" {
    name        = "nas.goyangi.io"
    record_type = "A"
    value       = "192.168.42.9"
    ttl         = "5m"
}
