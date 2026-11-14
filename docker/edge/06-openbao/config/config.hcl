ui            = true
cluster_name  = "goyangi-edge-openbao"
api_addr      = "https://bao.goyangi.io"
cluster_addr  = "http://127.0.0.1:8201"
# The container runs unprivileged, so mlock cannot be used. Raft data lives on
# the VPS disk and the seal key is injected at deploy time from 1Password.
disable_mlock = true

storage "raft" {
  path    = "/openbao/data"
  node_id = "edge-openbao-1"
}

# Plain HTTP is intentional: Caddy terminates TLS for bao.goyangi.io and proxies
# over the private `edge` Docker network. The listener is never published on the
# host, so it is not reachable from outside that network.
listener "tcp" {
  address                          = "0.0.0.0:8200"
  cluster_address                  = "127.0.0.1:8201"
  tls_disable                      = true
  x_forwarded_for_authorized_addrs = "172.18.0.0/16"
}

# Static auto-unseal: the key comes from 1Password at deploy time. If the key is
# lost, the Raft data can never be opened again -- it is part of break-glass
# material, together with the recovery key and initial root token.
seal "static" {
  current_key_id = "goyangi-v1"
  current_key    = "env://OPENBAO_STATIC_SEAL_KEY"
}

# Declared here so it cannot be lost after a restore, and so startup fails
# loudly if auditing breaks. The file device must use options.file_path; the
# older `path = ` form is rejected at init time with "file_path is required".
audit "file" "default" {
  options {
    # Docker's json-file driver with size rotation bounds disk usage; entries
    # are readable with `docker logs openbao`.
    file_path = "stdout"
  }
}
