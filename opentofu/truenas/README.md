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

`truenas_secret` contains the TrueNAS SSH credentials, the Connect
credentials JSON and Connect token, plus the Doco-CD webhook secret. The
Connect credentials and token are written to TrueNAS by OpenTofu, so the
remote tofu-controller state must be encrypted and access-controlled.
