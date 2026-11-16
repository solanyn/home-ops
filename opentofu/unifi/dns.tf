import {
  to = unifi_dns_record.nas
  id = "93315722-5406-4c8a-b6f9-41f51d505d58"
}

resource "unifi_dns_record" "nas" {
  name        = "nas.goyangi.io"
  record_type = "A"
  value       = "192.168.42.9"
  ttl         = "5m0s"
}
