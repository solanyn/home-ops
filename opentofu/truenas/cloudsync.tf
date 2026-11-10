# Off-site replication of the Kopiur kopia repository to Backblaze B2.
#
# The live repository is served by versitygw from its POSIX backend at
# /mnt/world/versitygw/data/<bucket> (VGW_BACKEND_ARGS=/mnt/data). The bucket
# directory is therefore the repository itself, which is why a file-level
# mirror produces a directly restorable copy: restore = copy the directory
# back, start versitygw, and kopia opens it unchanged.
#
# transfer_mode is deliberately "copy", not "sync". "sync" would delete at the
# destination anything missing locally, which turns this backup into a mirror:
# a damaged or accidentally pruned local repository would propagate to the
# off-site copy on the next run, destroying the thing the backup exists for.
# "copy" never deletes at the destination. Superseded kopia blobs accumulate
# in B2, which is harmless (kopia ignores unreferenced content-addressed
# blobs) and costs little because the repository is already pruned locally.

locals {
  # Bucket directory behind the versitygw POSIX backend. Keeping this derived
  # from the compose VGW_BACKEND_ARGS mount avoids inventing a second path.
  kopiur_repo_path = "/mnt/world/versitygw/data/kopiur"
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

resource "truenas_cloudsync_task" "kopiur_b2" {
  description = "Kopiur repository off-site copy to Backblaze B2"
  path        = local.kopiur_repo_path
  # id is a String and credentials is a Number; the provider coerces, but the
  # value is only known after apply so it must not be wrapped in tonumber().
  credentials   = truenas_cloudsync_credentials.b2.id
  direction     = "push"
  transfer_mode = "copy"

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

  # The previous full mirror of this data took ~12h; cap throughput so a run
  # cannot saturate the uplink for a full day.
  bwlimit   = "8M"
  transfers = 4
  enabled   = true

  # Skip versitygw internals that are not part of the repository image.
  exclude = [".sgwtmp/**", ".vgwlocks/**", ".DS_Store"]
}
