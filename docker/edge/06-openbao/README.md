# OpenBao on the edge VPS

OpenBao runs as a Compose service managed by Doco-CD alongside the other edge
services. It is the cluster's External Secrets source.

The cluster is migrated: `openbao` is the only ClusterSecretStore in use, and
1Password is read only from the workstation for bootstrap inputs. 1Password
Connect is no longer deployed.

## Bootstrap order

1. `mise run //docker/edge:openbao-check-secrets` — confirms the static seal key is readable
   from 1Password and is 32 bytes (64 hex chars).
2. `mise run //docker/edge:openbao-validate` — validates the Compose file and `config.hcl`
   against the VPS's own Docker Compose.
3. Add the secret to Doco-CD's external secrets (see below), commit, push.
4. `mise run //docker/edge:openbao-provision` — creates `/opt/openbao/data` with the ownership
   the unprivileged image user needs. Safe to re-run while no Raft data exists.
5. Let Doco-CD reconcile, or `mise run //docker/edge:openbao-deploy`.
6. `mise run //docker/edge:openbao-init` — **once**. Writes recovery key + root token to a
   0600 file, which you must then copy into 1Password and delete.
7. `mise run //docker/edge:openbao-status` — expect `Initialized true`, `Sealed false`.
8. Enable OIDC login (see "OIDC login via Pocket ID" below).

## Doco-CD secret wiring

`docker/edge/.doco-cd.yaml` maps 1Password references to environment variables
for the edge stack. Add:

```yaml
OPENBAO_STATIC_SEAL_KEY: op://kubernetes/openbao/OPENBAO_STATIC_SEAL_KEY
```

The compose file then consumes it with `:?`, so a missing value fails the deploy
instead of starting an unopenable instance.

Note the bootstrap ordering constraint: Doco-CD still reads its _own_
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

## ESO wiring (JWT auth, applied by hand)

External Secrets Operator needs a token to read OpenBao. It does **not** use
Kubernetes auth: OpenBao runs here on the VPS and cannot reach the cluster API
server, so it cannot perform a TokenReview. Instead it validates ESO's projected
service-account token locally against a **static copy of the cluster's
service-account signing keys** (JWKS). No bootstrap secret lives in the cluster,
nothing calls back to the API server, and there is no long-lived credential to
rotate.

`bootstrap.py` owns that config — KV v2 mount, read-only `eso-read` policy, and
the `goyangi-eso` JWT role. Apply it from the Mac mini:

```
mise run //docker/edge:openbao-bootstrap
```

It is idempotent — it creates only what is missing — and verifies its own result
on every run, failing loudly if the state does not match. That is why there is no
separate `--check` mode: `check()` runs as the post-apply verification, and with
a manual command "is it drifted?" is answered by running the apply itself.

It runs by hand, like `jfroy/etincelle` — deliberately **not** on a schedule and
**not** on deploy. Two attempts at automating it were reverted, for reasons
worth recording:

- Doco-CD resolves every `external_secrets` entry **before** deploying any
  stack, so mapping a bootstrap secret that does not exist yet aborts the whole
  poll and breaks **all six** edge stacks, not just this one.
- Doco-CD treats an exited service as failed deployment drift
  (`service bootstrap has a exited container`), so a `depends_on` one-shot fails
  every subsequent poll even when the job succeeds. A scheduled job avoids that
  but then never runs on deploy, which defeats the point.

Nothing about this config needs re-applying on a schedule: it is created once
and only changes when the JWKS rotate. Making it manual also means a broken
bootstrap can never fail a deploy.

`bootstrap.py` reads the token from 1Password itself (`op read`, falling back to
the `~/.op-token` service-account file when there is no interactive session), so
no token is stored in the cluster or in doco-cd. The JWKS is read fresh from
`kubectl` on every run rather than committed, so it cannot go stale.

### When ESO auth breaks after a cluster key rotation

The validation keys are whatever was current at the last run, so after a
service-account signing-key rotation ESO auth fails until the script is re-run:

```
mise run //docker/edge:openbao-bootstrap
```

`bootstrap.py` **merges** keys rather than replacing them, so a run can never
remove the key ESO is currently using. Pass `--replace` only for a deliberate
rotation, after confirming the new keys work.

## Verified end to end

Tested against OpenBao 2.7.2 on the VPS in a throwaway project: container healthy,
`operator init` returns 1 recovery key + root token, KV v2 write/read works, Raft
snapshot saves, and audit entries appear in `docker logs`.

Live instance confirms: auto-unseal survives a container restart, the Raft
snapshot endpoint returns a gzip archive, and Caddy serves
`https://bao.goyangi.io` with a Let's Encrypt certificate.

## OIDC login via Pocket ID

The UI and CLI log in through Pocket ID instead of the root token. The client is
a `PocketIDOIDCClient` CR (`bao`) managed by pocket-id-operator, which adopts the
external Pocket ID instance on the VPS — do not create the client by hand in the
UI, and do not call the Pocket ID API directly.

Both redirect URIs must be registered:

- `https://bao.goyangi.io/ui/vault/auth/oidc/oidc/callback` — UI login
- `http://localhost:8250/oidc/callback` — `bao login -method=oidc`

The same two URIs must appear in the OpenBao role's `allowed_redirect_uris`.

OpenBao's OIDC config endpoint takes `oidc_client_id` and `oidc_client_secret`.
Passing `client_id`/`client_secret` returns 204 and is silently ignored, leaving
`oidc_client_id` empty and breaking login with no obvious error. Read the config
back after writing it and confirm `oidc_client_id` is set.

Groups come from Pocket ID's `groups` claim (group _name_, e.g. `admin`), which
requires the `groups` scope on both the config and the role. The `admin` role maps
to the `bao-admin` policy.

## Known gaps

- **The generated root token and recovery key are not yet in 1Password.** They are
  in `~/.openbao-init.json` on the Mac mini (mode 0600) because the available
  service-account token is read-only. Add `OPENBAO_ROOT_TOKEN` and
  `OPENBAO_RECOVERY_KEY` to the `openbao` item, then delete the file.
- Backups are intentionally **not** implemented here. Planned follow-up: Doco-CD
  scheduled job running a native Raft snapshot + KV export, age-encrypted to
  `op://kubernetes/age/AGE_PUBLIC_KEY`, uploaded to the `goyangi-edge` B2 bucket,
  with an explicit retention rule and a rehearsed restore.
- No secrets, additional policies or consumers exist in OpenBao yet; 1Password
  Connect is untouched.
- Doco-CD's OpenBao secret provider is not used; the edge stack still uses its
  1Password provider.
