set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f /dev/stdin

[doc('Browse a PVC')]
browse-pvc namespace claim:
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[doc('Snapshot VolSync PVCs')]
snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    done

[doc('Backup CNPG cluster')]
cnpg-backup:
    #!/usr/bin/env bash
    set -euo pipefail
    backup_name="backup-$(date +%Y%m%d%H%M%S)"
    echo "Triggering CNPG backup: $backup_name"
    kubectl apply -f - <<< '{"apiVersion":"postgresql.cnpg.io/v1","kind":"Backup","metadata":{"name":"'"$backup_name"'","namespace":"storage"},"spec":{"method":"plugin","cluster":{"name":"postgres"},"pluginConfiguration":{"name":"barman-cloud.cloudnative-pg.io"}}}'
    echo "Waiting for backup to complete..."
    kubectl wait backup -n storage "$backup_name" --for=jsonpath='{.status.phase}'=completed --timeout=600s

[doc('Suspend CNPG cluster')]
cnpg-suspend:
    kubectl annotate cluster postgres -n storage cnpg.io/hibernation=on --overwrite

[doc('Resume CNPG cluster')]
cnpg-resume:
    kubectl annotate cluster postgres -n storage cnpg.io/hibernation-

[doc('Backup and suspend: CNPG backup + suspend, VolSync snapshot')]
backup-and-suspend: cnpg-backup cnpg-suspend snapshot
    @echo "Backup and suspend complete. Safe to reset Talos cluster."

[doc('Suspend or resume Keda ScaledObjects')]
keda state:
    kubectl get scaledobjects --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite so "$name" autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}; \
    done

[doc('Suspend or resume VolSync')]
volsync state:
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Restore VolSync PVC from R2')]
restore-r2 namespace app:
    #!/usr/bin/env bash
    set -euo pipefail
    dst="{{ app }}-dst"
    echo "Scaling down {{ app }}..."
    kubectl -n {{ namespace }} scale deploy {{ app }} --replicas=0 2>/dev/null || true
    kubectl -n {{ namespace }} scale sts {{ app }} --replicas=0 2>/dev/null || true
    sleep 5
    echo "Patching $dst to use R2 repo..."
    trigger="restore-r2-$(date +%s)"
    kubectl -n {{ namespace }} patch replicationdestination "$dst" --type merge -p \
      "{\"spec\":{\"kopia\":{\"repository\":\"{{ app }}-volsync-r2-secret\",\"sourceIdentity\":{\"sourceName\":\"{{ app }}-r2\"}},\"trigger\":{\"manual\":\"$trigger\"}}}"
    echo "Waiting for restore to complete..."
    until [ "$(kubectl -n {{ namespace }} get replicationdestination "$dst" -o jsonpath='{.status.lastManualSync}')" = "$trigger" ]; do
      sleep 5
    done
    snapshot=$(kubectl -n {{ namespace }} get replicationdestination "$dst" -o jsonpath='{.status.latestImage.name}')
    echo "Restore complete. Snapshot: $snapshot"
    echo "Deleting PVC {{ app }}..."
    kubectl -n {{ namespace }} delete pvc {{ app }}
    echo "Recreating PVC from snapshot..."
    capacity=$(kubectl -n {{ namespace }} get replicationdestination "$dst" -o jsonpath='{.spec.kopia.capacity}')
    sc=$(kubectl -n {{ namespace }} get replicationdestination "$dst" -o jsonpath='{.spec.kopia.storageClassName}')
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: {{ app }}
      namespace: {{ namespace }}
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: ${capacity}
      storageClassName: ${sc}
      dataSource:
        kind: VolumeSnapshot
        apiGroup: snapshot.storage.k8s.io
        name: ${snapshot}
    EOF
    echo "Restoring local repo config..."
    kubectl -n {{ namespace }} patch replicationdestination "$dst" --type merge -p \
      "{\"spec\":{\"kopia\":{\"repository\":\"{{ app }}-volsync-secret\",\"sourceIdentity\":{\"sourceName\":\"{{ app }}\"}}}}"
    echo "PVC recreated. Scale your app back up when ready:"
    echo "  kubectl -n {{ namespace }} scale deploy {{ app }} --replicas=1"

[doc('Sync ExternalSecrets')]
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"; \
    done

[doc('Sync GitRepositories')]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync HelmReleases')]
sync-hr:
    kubectl get hr --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"; \
    done

[doc('Sync Kustomizations')]
sync-ks:
    kubectl get ks --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ks "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync OCIRepositories')]
sync-oci:
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync Terraform resources')]
terraform:
    kubectl get terraform --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite terraform "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('View a secret')]
view-secret namespace secret:
    kubectl view-secret -n {{ namespace }} {{ secret }}

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"

[doc('Add OIDC credentials to 1Password item (creates if missing)')]
create-oidc app:
    #!/usr/bin/env bash
    set -euo pipefail
    app="{{ app }}"
    prefix=$(echo "$app" | tr '[:lower:]-' '[:upper:]_')
    secret=$(openssl rand -hex 32)
    if op item get "$app" --vault kubernetes &>/dev/null; then
        # Set placeholder password if empty (CLI requires it for PASSWORD category)
        if [[ -z "$(op item get "$app" --vault kubernetes --fields password 2>/dev/null)" ]]; then
            op item edit "$app" --vault kubernetes "password= " >/dev/null
        fi
        op item edit "$app" --vault kubernetes \
            "${prefix}_CLIENT_SECRET[password]=$secret" >/dev/null
        echo "Added ${prefix}_CLIENT_SECRET to '$app'"
    else
        op item create --vault kubernetes --category login \
            --title "$app" \
            "${prefix}_CLIENT_SECRET[password]=$secret" >/dev/null
        echo "Created '$app' with ${prefix}_CLIENT_SECRET"
    fi

[doc('Sync OIDC credentials from terraform.tfvars to 1Password')]
sync-oidc:
    #!/usr/bin/env bash
    set -euo pipefail
    tfvars="{{ justfile_dir() }}/terraform/authentik/terraform.tfvars"
    apps=$(awk '/^[[:space:]]+[a-z0-9-]+[[:space:]]*=/ {print $1}' "$tfvars")
    for app in $apps; do
        prefix=$(echo "$app" | tr '[:lower:]-' '[:upper:]_')
        if op item get "$app" --vault kubernetes --fields "${prefix}_CLIENT_SECRET" &>/dev/null; then
            echo "Skipping $app - ${prefix}_CLIENT_SECRET exists"
        else
            just kube create-oidc "$app" &
        fi
    done
    wait

[doc('Create Authentik invitation link')]
invite name="invite":
    #!/usr/bin/env bash
    set -euo pipefail
    token=$(kubectl get secret -n default authentik -o jsonpath='{.data.AUTHENTIK_BOOTSTRAP_TOKEN}' | base64 -d)
    response=$(curl -s -X POST https://id.goyangi.io/api/v3/stages/invitation/invitations/ \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{"name": "{{ name }}", "flow": "enrollment-invitation"}')
    invite_id=$(echo "$response" | jq -r '.pk')
    echo "https://id.goyangi.io/if/flow/enrollment-invitation/?itoken=$invite_id"
