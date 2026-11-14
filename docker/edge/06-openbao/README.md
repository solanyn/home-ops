# OpenBao on the edge VPS

OpenBao runs as a Compose service managed by Doco-CD alongside the other edge
services. It is the eventual replacement for 1Password Connect as the cluster's
External Secrets source.

**Nothing has been migrated yet.** 1Password Connect stays in place until OpenBao
is initialized, its recovery material is stored in 1Password, and a Raft restore
has been rehearsed.

## Bootstrap order

1. `just edge openbao-check-secrets` — confirms the static seal key is readable
   from 1Password and is 32 bytes (64 hex chars).
2. `just edge openbao-validate` — validates the Compose file and `config.hcl`
   against the VPS's own Docker Compose.
3. Add the secret to Doco-CD's external secrets (see below), commit, push.
4. `just edge openbao-provision` — creates `/opt/openbao/data` with the ownership
   the unprivileged image user needs. Safe to re-run while no Raft data exists.
5. Let Doco-CD reconcile, or `just edge openbao-deploy`.
6. `just edge openbao-init` — **once**. Writes recovery key + root token to a
   0600 file, which you must then copy into 1Password and delete.
7. `just edge openbao-status` — expect `Initialized true`, `Sealed false`.

## Doco-CD secret wiring

`docker/edge/.doco-cd.yaml` maps 1Password references to environment variables
for the edge stack. Add:

```yaml
  OPENBAO_STATIC_SEAL_KEY: op://kubernetes/openbao/OPENBAO_STATIC_SEAL_KEY
```

The compose file then consumes it with `:?`, so a missing value fails the deploy
instead of starting an unopenable instance.

Note the bootstrap ordering constraint: Doco-CD still reads its *own*
configuration using its local `/opt/doco-cd/1pw_token` file. OpenBao must never be
what supplies the credentials Doco-CD needs to load the config that defines
OpenBao.

## Design notes

- **TLS is terminated by Caddy** (`bao.goyangi.io`), not OpenBao. The listener is
  plain HTTP on the private `edge` network and is never published on the host.
- **`x_forwarded_for_authorized_addrs`** is set to the Docker bridge subnet so
  OpenBao trusts the proxy header; this matters for audit logs and rate limiting.
- **Static seal from `env://`**, injected at deploy time. The key is 32 bytes of
  hex. Losing it means the Raft data can never be opened again — it is
  break-glass material alongside the recovery key and root token.
- **Recovery keys, not unseal keys.** With a static seal, `operator init` returns
  one recovery key and no unseal keys; the seal key does unsealing. Initializing
  with `-recovery-shares=1 -recovery-threshold=1` keeps that material to a single
  value stored in 1Password.
- **Audit device is declared in `config.hcl`**, so it cannot be lost after a
  restore and startup fails loudly if auditing breaks. It writes to stdout and is
  bounded by Docker's `json-file` rotation. The stanza must use
  `options.file_path`; the older `path = ` form fails init with "file_path is
  required".
- **`disable_mlock = true`** because the container runs unprivileged; `SKIP_SETCAP`
  stops the entrypoint trying to raise memlock. `no-new-privileges` is on.
- **No `-config` flag**: the image entrypoint already loads `/openbao/config`;
  passing both makes OpenBao load the file twice and warn.

## Verified end to end

Tested against OpenBao 2.7.2 on the VPS in a throwaway project: container healthy,
`operator init` returns 1 recovery key + root token, KV v2 write/read works, Raft
snapshot saves, and audit entries appear in `docker logs`.

## Known gaps

- Backups are intentionally **not** implemented here. Planned follow-up: Doco-CD
  scheduled job running a native Raft snapshot + KV export, age-encrypted to
  `op://kubernetes/age/AGE_PUBLIC_KEY`, uploaded to the `goyangi-edge` B2 bucket,
  with an explicit retention rule and a rehearsed restore.
- OpenBao has not been initialized, so no secrets, policies, auth methods or
  consumers exist yet.
- Doco-CD's OpenBao secret provider is not used; the edge stack still uses its
  1Password provider.
