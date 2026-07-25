import {
    to = unifi_static_route.thread_mesh
    id = "69bd3746f53d50ff730adecd"
}

resource "unifi_static_route" "thread_mesh" {
    name      = "Thread mesh via OTBR"
    type      = "nexthop-route"
    network   = "fd39:b979:bba3:d01d::/64"
    next_hop  = "fd5d:a293:f321:70:22::1"
    interface = "any"
    distance  = 1
    enabled   = true
}
