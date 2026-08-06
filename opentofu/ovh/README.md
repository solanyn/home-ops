# OVH VPS IaC

Managed by OpenTofu via [tofu-controller](https://github.com/flux-iac/tofu-controller) in flux-system. Auto-applies from main — push to change.

## What's managed

| Resource | File | Notes |
|----------|------|-------|
| VPS | `main.tf` | `vps-2027-model1` (2 vCPU / 4GB / 40GB NVMe), SYD, Debian 13, display name `edge` |

## Credentials

OVH API uses a signed three-key model. Credentials live in the `ovhcloud` item in the Kubernetes 1Password vault and are injected into the runner pod via the `ovh` ExternalSecret (`ovh-secret`).

| Purpose | 1Password property | OpenTofu env var |
|---------|--------------------|------------------|
| Terraform / VPS ordering | `OVH_TOFU_APPLICATION_KEY` / `OVH_TOFU_APPLICATION_SECRET` / `OVH_TOFU_CONSUMER_KEY` | `OVH_APPLICATION_KEY` / `OVH_APPLICATION_SECRET` / `OVH_CONSUMER_KEY` |
| DNS (external-dns-ovh) | `OVH_DNS_APPLICATION_KEY` / `OVH_DNS_APPLICATION_SECRET` / `OVH_DNS_CONSUMER_KEY` | — |
| Cert-manager webhook | `OVH_CERT_APPLICATION_KEY` / `OVH_CERT_APPLICATION_SECRET` / `OVH_CERT_CONSUMER_KEY` | — |

Endpoint is `ovh-ca` (there is no `ovh-au`; SYD and Debian 13 are orderable on the CA platform).

## Bootstrap

1. Push changes to `main` — tofu-controller plans and auto-applies the `ovh` Terraform, ordering the VPS. OVH emails the root password.
2. Run the Ansible playbook once against the VPS, passing the password OVH emailed you:

   ```bash
   ansible-playbook -i ansible/edge/hosts.ini \
     --extra-vars "ansible_ssh_pass=<password from OVH email>" \
     ansible/edge/playbook.yaml
   ```

3. The playbook installs the SSH key, locks the root password and disables password auth, then installs Docker and doco-cd.

The root password is a one-time bootstrap credential. It exists only in the OVH email — never stored in the repo or 1Password — and is dead once the playbook runs. From then on, access is SSH key + doco-cd polling the repo.

## Verification

```bash
kubectl get terraform -n network ovh -o json | jq '.status'
```

## Rollback

1. `git revert <commit>` and push
2. Flux reconciles and reverts
3. `destroyResourcesOnDeletion: false` — removing the resource does not destroy the VPS (safety)
