# TrueNAS infrastructure

This root is reconciled by tofu-controller and owns the TrueNAS custom app
that runs Doco-CD. Doco-CD remains the owner of the child Compose stacks under
`docker/truenas/` in the Git repository.

## Ownership boundary

- OpenTofu: TrueNAS custom app, datasets, buckets and Cloud Sync tasks.
- Doco-CD: every child stack discovered below `docker/truenas/`.
- Renovate: image updates in the Doco-CD bootstrap and child stack manifests.

The Doco-CD bootstrap Compose definition is stored at
`doco-cd-compose.yaml` and must clone the repository and use
`./docker/truenas/` as its deployment base directory.

Before enabling reconciliation, import the existing app:

```text
tofu import truenas_app.doco_cd doco-cd
```

The TrueNAS API key is sourced from the `TRUENAS_API_KEY` field in the `truenas` 1Password item via External Secrets. The provider uses WebSocket authentication with SSH retained as the required fallback for file operations.

`truenas_secret` contains the TrueNAS SSH credentials, the Connect credentials JSON and Connect token, plus the TrueNAS API key and Doco-CD webhook secret. The Connect credentials, token and API key are written to TrueNAS or consumed by the tofu-controller, so remote tofu-controller state must be encrypted and access-controlled.

## Off-site Kopiur replication

`cloudsync.tf` mirrors the Kopiur kopia repository to Backblaze B2 bucket
`goyangi-kopiur` so the backup survives loss of the NAS.

The live repository is served by versitygw from its POSIX backend, so the
mirrored path is `/mnt/world/versitygw/data/kopiur` (versitygw maps
`VGW_BACKEND_ARGS=/mnt/data` to `/mnt/world/versitygw/data`). Do not use
`/mnt/world/kopiur` — that holds a superseded repository manifest, not live data.

The task uses `transfer_mode = "sync"`, not `copy`. Data flows one way —
cluster -> NAS -> B2 — so the cluster is always the source of truth and the NAS
bucket is a derived copy. Mirroring it exactly keeps B2 bounded to the same
retention window instead of accumulating a base backup per day forever.

Because `sync` deletes at the destination, **disable the Cloud Sync tasks before
a restore**. Otherwise the mirror reconciles the restored state back toward what
the NAS currently holds.

Restore, in order:

1. Disable the Cloud Sync tasks, so the mirror cannot overwrite restored data.
2. Stop anything writing to the repository.
3. Pull B2 `goyangi-kopiur` back to `/mnt/world/versitygw/data/kopiur`
   (a reverse Cloud Sync task, or `rclone copy`).
4. Start versitygw, then confirm the bucket lists the expected shard prefixes.
5. Point Kopiur at the repository and restore workloads from snapshots.

versitygw is pinned by tag and digest because the on-disk shard layout is what
the restore depends on; an unexpected `:latest` upgrade could change it.
