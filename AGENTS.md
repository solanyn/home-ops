# AGENTS.md

This file provides guidance for AI agents when working with code in this repository.

Follow conventional commits and never attribute agents in commit messages. Keep commit messages informative only.

Read `.agents/*.md` for reference to specific scenarios.

## Project Architecture

This is a **single cluster Kubernetes GitOps repository** managed with **FluxCD v2**. The architecture follows a hierarchical pattern: namespace → application, with encrypted secrets using SOPS and Age encryption.

### Key Directory Structure

- `.agents/` - Additional instructions for agents
- `kubernetes/` - Cluster manifests
- `.taskfiles/` - Task automation definitions
- `talos/` - Talos Linux configuration
- `third_party` - Manifests synced from upstream (for `flux-local` CI checks)

### Application Deployment Pattern

Each application follows this standardized structure:

```
apps/<namespace>/<app-name>/
├── app/                    # Application resources
│   ├── helmrelease.yaml    # Main Helm chart definition
│   ├── kustomization.yaml  # Resource aggregation
│   ├── externalsecret.yaml # Secrets from 1Password
│   └── pvc.yaml            # Additional storage
└── ks.yaml                 # Flux Kustomization
```

Some apps have additional resources like `cluster` for operator and resource deployments.

## Development Commands

### Task (using `task` command)

**Kubernetes Operations:**

```bash
task k8s:browse-pvc         # Mount PVC to temp container [CLUSTER=cluster-0] [NS=default] [CLAIM=required]
task k8s:delete-failed-pods # Delete all failed pods
```

**Other Task Categories:**

```bash
task externalsecrets:*   # External Secrets operations
task rook:*             # Rook-Ceph storage operations
task volsync:*          # VolSync backup operations
```

## Security and Secrets

- **SOPS encryption:** All secrets encrypted at rest with Age keys
- **External Secrets Operator:** Runtime secret injection from 1Password
- **Never commit unencrypted secrets or sensitive data**

## GitOps Workflow

1. **FluxCD** automatically syncs changes from this repository
2. **Hierarchical reconciliation** with dependency management
3. **Pull request validation** with kubeconform and linting
4. **Renovate automation** for dependency updates

## Key Technologies

- **FluxCD v2** - GitOps engine with OCI repositories
- **Talos Linux** - Kubernetes OS
- **Cilium CNI** - Networking with BGP and Gateway API
- **Rook-Ceph** - Distributed storage
- **OpenEBS** - Host storage storage class
- **VolSync** - PV backup/recovery
- **External Secrets Operator** - Secret management
- **cert-manager** - TLS automation
