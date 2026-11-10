# Off-site replication of the cluster's backup artifacts to Backblaze B2.
#
# Data flow is one-directional: cluster -> NAS (versitygw) -> B2. The cluster is
# always the source of truth; the NAS bucket is a derived copy, and B2 mirrors
# that derived copy. Nothing is ever written back up the chain during normal
# operation, so a `sync` (delete-at-destination) is safe and keeps B2 bounded:
# both sources are already retention-pruned, so mirroring them exactly means B2
# cannot grow without bound.
#
# During a restore, disable the Cloud Sync tasks first. Otherwise the mirror
# will reconcile the restored state back toward whatever the NAS currently
# holds and can delete objects mid-restore.
#
# Paths are the versitygw POSIX backend directories, because VGW_BACKEND_ARGS
# is /mnt/data mounted from /mnt/world/versitygw/data. A file-level mirror of
# the bucket directory is therefore equivalent to mirroring the bucket itself,
# and a restore is: pull B2 -> the same directory -> start versitygw.

locals {
  # Bucket directories behind the versitygw POSIX backend. Keeping these
  # derived from the compose VGW_BACKEND_ARGS mount avoids inventing a second
  # path, and keeps both tasks visibly relative to the same root.
  versitygw_data_root = "/mnt/world/versitygw/data"
  kopiur_repo_path    = "${local.versitygw_data_root}/kopiur"
  cnpg_backup_path    = "${local.versitygw_data_root}/cloudnative-pg"
}

# Adopt the pre-existing UI-created credential rather than recreating it, so
# the key already scoped to this bucket keeps working. Id 3 is the
# `backblaze-homelab` credential that the removed UI task used; it must be
# adopted, because creating a second credential with the same name fails with
# "Object with this name already exists".
import {
  to = truenas_cloudsync_credentials.b2
  id = "3"
}

resource "truenas_cloudsync_credentials" "b2" {
  name = "backblaze-homelab"

  b2 {
    account = var.backblaze_account_id
    key     = var.backblaze_application_key
  }

  lifecycle {
    # Never destroy a credential on refresh-mode changes; it is shared state
    # that a recreated resource would lose.
    prevent_destroy = true
  }
}

# Kopiur kopia repository: snapshots of every backed-up cluster PVC.
resource "truenas_cloudsync_task" "kopiur_b2" {
  description = "Kopiur repository off-site copy to Backblaze B2"
  path        = local.kopiur_repo_path
  # id is a String and credentials is a Number; the provider coerces, but the
  # value is only known after apply so it must not be wrapped in tonumber().
  credentials   = truenas_cloudsync_credentials.b2.id
  direction     = "push"
  transfer_mode = "sync"

  # Nightly, shortly after kopia's own maintenance window (03:00 quick /
  # 06:00 full in Australia/Sydney) has settled.
  schedule {
    minute = "30"
    hour   = "4"
  }
  b2 {
    bucket = "goyangi-kopiur"
    folder = ""
  }

  # No bwlimit: TrueNAS 25.10 expects bwlimit as a schedule list
  # ([{time = "18:00", bandwidth = ...}]), which the provider still sends as a
  # plain string, so setting it fails with
  #   cloud_sync_create.bwlimit.0.time: Time should be in 24 hour format
  # Set a limit in the TrueNAS UI if the nightly run needs throttling.
  transfers = 4
  enabled   = true

  # Skip versitygw internals that are not part of the repository image.
  exclude = [".sgwtmp/**", ".vgwlocks/**", ".DS_Store"]
}

# CloudNativePG barman object store: daily base backups plus WAL, pruned to
# 14 days by barman's own retentionPolicy. Because that policy already bounds
# the source, `sync` keeps B2 at roughly the same ~23 GiB instead of growing
# by one ~1 GiB base backup per day forever.
resource "truenas_cloudsync_task" "cnpg_b2" {
  description   = "CloudNativePG backups off-site copy to Backblaze B2"
  path          = local.cnpg_backup_path
  credentials   = truenas_cloudsync_credentials.b2.id
  direction     = "push"
  transfer_mode = "sync"

  # Stagger an hour after the Kopiur task so the two do not compete for the
  # uplink. barman takes its daily base backup at 00:00 UTC.
  schedule {
    minute = "30"
    hour   = "5"
  }
  b2 {
    bucket = "goyangi-cnpg"
    folder = ""
  }

  transfers = 4
  enabled   = true

  exclude = [".sgwtmp/**", ".vgwlocks/**", ".DS_Store"]
}
