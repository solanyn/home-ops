# Mounting NFS

This document provides NFS mounting guidelines.

Mount NFS to a pod in `app-template` helmreleases like so:

```yaml
# Other app-template values
persistence:
    config:
        existingClaim: plex
    media:
        type: nfs
        server: nas.internal
        path: /mnt/world/media
        globalMounts:
            - path: /media
              readOnly: true
```

See the `app-template` values JSON schema for reference.

# Volsync Backup and Restore

As touched on in `app-template`, applications which require local storage with backups (e.g., if applicaitons use SQLite databases) then setup the volsync component in the `ks.yaml`.
