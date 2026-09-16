#!/usr/bin/env bash
set -euo pipefail

# Local-only migration runner. It stores checkpoints beside the script and never
# writes migration state into Kubernetes.

STATE_DIR="${MIGRATION_STATE_DIR:-${HOME}/.local/state/garage-versitygw-migration}"
LOCK_DIR="${STATE_DIR}/migration.lock"
RCLONE_CONFIG="${STATE_DIR}/rclone.conf"
DRY_RUN=1
ACTION=""
UNIT=""

usage() {
  cat <<'EOF'
Usage: migrate-garage-versitygw.sh [--apply] <status|preflight|copy|quiesce|final-sync|cutover|verify|finalize> <forgejo|lake>

Options:
  --apply   Allow quiesce, cutover and finalize actions. Copy remains resumable.
  --state DIR  Local checkpoint directory.

Units:
  forgejo  Forgejo's forgejo bucket
  lake     Lake/Lakekeeper/VGC medallion buckets: bronze, silver, gold

The script never deletes source data unless finalize is explicitly run with
--apply --delete-source.
EOF
}

DELETE_SOURCE=0
while (($#)); do
  case "$1" in
    --apply) DRY_RUN=0; shift ;;
    --delete-source) DELETE_SOURCE=1; shift ;;
    --state) STATE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    status|preflight|copy|quiesce|final-sync|cutover|verify|finalize)
      ACTION="$1"
      shift
      if [ "$#" -gt 0 ]; then
        UNIT="$1"
        shift
      fi
      break ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$ACTION" && -n "$UNIT" ]] || { usage >&2; exit 2; }
[[ "$UNIT" == forgejo || "$UNIT" == lake ]] || { echo "invalid unit: $UNIT" >&2; exit 2; }
if (( DELETE_SOURCE )) && [[ "$ACTION" != finalize ]]; then
  echo "--delete-source is only valid with finalize" >&2; exit 2
fi
if (( DELETE_SOURCE && DRY_RUN )); then
  echo "--delete-source requires --apply" >&2; exit 2
fi

mkdir -p "$STATE_DIR"
LOCK_DIR="${STATE_DIR}/migration.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "another migration is running: $LOCK_DIR" >&2
  exit 1
fi
trap 'rmdir "$LOCK_DIR"' EXIT

require_cmd() { command -v "$1" >/dev/null || { echo "missing command: $1" >&2; exit 1; }; }
require_cmd rclone
require_cmd kubectl
require_cmd jq

checkpoint="${STATE_DIR}/${UNIT}.json"
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
read_checkpoint() { [[ -s "$checkpoint" ]] && jq -r "$1 // empty" "$checkpoint"; }
write_checkpoint() {
  local key="$1" value="$2" tmp
  tmp="${checkpoint}.tmp"
  if [[ -s "$checkpoint" ]]; then jq --arg v "$value" ".${key} = \$v" "$checkpoint" > "$tmp"; else printf '{"unit":"%s"}' "$UNIT" | jq --arg v "$value" ".${key} = \$v" > "$tmp"; fi
  mv "$tmp" "$checkpoint"
}

if [[ ! -s "$RCLONE_CONFIG" ]]; then
  umask 077
  GA="$(kubectl get secret -n default forgejo-secret -o jsonpath='{.data.GITEA__storage__MINIO_ACCESS_KEY_ID}' | base64 -d)"
  GS="$(kubectl get secret -n default forgejo-secret -o jsonpath='{.data.GITEA__storage__MINIO_SECRET_ACCESS_KEY}' | base64 -d)"
  VA="$(kubectl get secret -n storage cloudnative-pg-secret -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)"
  VS="$(kubectl get secret -n storage cloudnative-pg-secret -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)"
  cat > "$RCLONE_CONFIG" <<EOF
[garage]
type = s3
provider = Other
access_key_id = ${GA}
secret_access_key = ${GS}
endpoint = http://nas.internal:3900
force_path_style = true
[versity]
type = s3
provider = Other
access_key_id = ${VA}
secret_access_key = ${VS}
endpoint = http://nas.internal:9000
force_path_style = true
EOF
fi

buckets() { [[ "$UNIT" == forgejo ]] && printf 'forgejo\n' || printf 'bronze\nsilver\ngold\n'; }
measure() { local remote="$1"; rclone size --config "$RCLONE_CONFIG" --fast-list "$remote" --json; }
assert_target_buckets() { while read -r b; do rclone mkdir --config "$RCLONE_CONFIG" "versity:${b}"; done < <(buckets); }

copy_buckets() {
  assert_target_buckets
  while read -r b; do
    echo "COPY $b"
    rclone copy --config "$RCLONE_CONFIG" --fast-list --transfers 16 --checkers 32 --stats 30s --stats-one-line "garage:${b}" "versity:${b}"
  done < <(buckets)
}

case "$ACTION" in
  status)
    [[ -s "$checkpoint" ]] && jq . "$checkpoint" || echo '{"state":"not-started"}'
    ;;
  preflight)
    assert_target_buckets
    while read -r b; do
      echo "SOURCE $b"; measure "garage:${b}"
      echo "TARGET $b"; measure "versity:${b}"
    done < <(buckets)
    write_checkpoint preflight_at "$(now)"
    ;;
  copy)
    assert_target_buckets
    while read -r b; do
      echo "COPY $b"
      rclone copy --config "$RCLONE_CONFIG" --fast-list --transfers 16 --checkers 32 --stats 30s --stats-one-line "garage:${b}" "versity:${b}"
    done < <(buckets)
    write_checkpoint copy_at "$(now)"
    ;;
  quiesce)
    (( DRY_RUN )) && { echo "DRY RUN: would quiesce $UNIT consumers"; exit 0; }
    if [[ "$UNIT" == forgejo ]]; then
      kubectl scale deployment/forgejo -n default --replicas=0
    else
      kubectl scale deployment/lake-ingest deployment/lake-promote deployment/lake-aggregate -n default --replicas=0
      kubectl patch cronjob/vgc-pipeline -n default --type=merge -p '{"spec":{"suspend":true}}'
    fi
    write_checkpoint quiesced_at "$(now)"
    ;;
  final-sync)
    [[ -n "$(read_checkpoint '.quiesced_at')" ]] || { echo "quiesce must complete first" >&2; exit 1; }
    copy_buckets
    while read -r b; do
      src="$(measure "garage:${b}")"; dst="$(measure "versity:${b}")"
      jq -n --arg b "$b" --argjson s "$src" --argjson d "$dst" '$ARGS.named' \
        --argjson s "$src" --argjson d "$dst" >/dev/null
      [[ "$(jq -r '.count,.bytes' <<<"$src" | paste -sd:)" == "$(jq -r '.count,.bytes' <<<"$dst" | paste -sd:)" ]] || { echo "mismatch: $b" >&2; exit 1; }
    done < <(buckets)
    write_checkpoint final_sync_at "$(now)"
    ;;
  cutover)
    (( DRY_RUN )) && { echo "DRY RUN: would update GitOps endpoints/credentials for $UNIT"; exit 0; }
    echo "Cutover is intentionally manual and GitOps-owned. Update the reviewed manifests, commit, push and reconcile before running verify." >&2
    write_checkpoint cutover_requested_at "$(now)"
    ;;
  verify)
    [[ -n "$(read_checkpoint '.final_sync_at')" ]] || { echo "final-sync must complete first" >&2; exit 1; }
    kubectl get pods -n default -o wide | grep -E 'forgejo|lake-(ingest|promote|aggregate)' || true
    write_checkpoint verify_at "$(now)"
    ;;
  finalize)
    (( DELETE_SOURCE )) || { echo "refusing source deletion; pass --apply --delete-source" >&2; exit 1; }
    [[ -n "$(read_checkpoint '.verify_at')" ]] || { echo "verify must complete first" >&2; exit 1; }
    while read -r b; do
      echo "DELETE SOURCE $b"
      rclone delete --config "$RCLONE_CONFIG" --fast-list "garage:${b}"
    done < <(buckets)
    write_checkpoint finalized_at "$(now)"
    ;;
esac
