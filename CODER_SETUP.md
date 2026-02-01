# Coder DevContainer Setup for home-ops

## Overview

This setup replaces the persistent `dev-sandbox` with **Coder** and **devcontainer.json**, enabling truly reproducible development environments that can be spun up and torn down on-demand without needing persistent backups.

## Why Coder + devcontainer.json?

### Problems with the old approach:
- 50Gi PVC with VolSync backups for a single ephemeral dev environment
- Environment state accumulated over time (harder to reproduce issues)
- Backup/restore overhead for disposable workspaces

### Benefits of this approach:
- ✅ **Reproducible**: Environment defined in version control (`devcontainer.json`)
- ✅ **Ephemeral**: Spin up fresh workspaces on-demand, tear down without backup concerns
- ✅ **Scalable**: Multiple developers can have isolated workspaces
- ✅ **IDE Choice**: Support VS Code, JetBrains, SSH terminal
- ✅ **Version Controlled**: All configuration tracked in Git
- ✅ **Kubernetes Native**: Workspaces run as Kubernetes pods

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Coder Control Plane                    │
│  - Helm Release in 'coder' namespace             │
│  - PostgreSQL backend (CloudNative-PG)           │
│  - HTTPRoute: coder.goyangi.io                   │
└─────────────────────────────────────────────────┘
                      │
        Creates & Manages Workspaces
                      │
         ┌────────────┴────────────┐
         │                         │
   ┌──────────────┐        ┌──────────────┐
   │  Dev Workspace 1      │  Dev Workspace 2
   │  (Kubernetes Pod)     │  (Kubernetes Pod)
   │  - 50Gi PVC           │  - 50Gi PVC
   │  - devcontainer.json  │  - devcontainer.json
   │    setup              │    setup
   │  - Coder Agent        │  - Coder Agent
   └──────────────┘        └──────────────┘
```

## Components

### 1. **devcontainer.json** (`.devcontainer/devcontainer.json`)

Defines the development environment specification:
- Base image: `ubuntu:24.04`
- Features: Git, GitHub CLI, Docker, Kubernetes tools
- Post-create script: Installs additional tools (Go, k9s, kustomize, flux, talos, helm plugins)
- Port forwarding: 4096 (IDE), 7681 (Terminal)

### 2. **Coder Kubernetes Deployment** (`kubernetes/apps/dev/coder/`)

#### PostgreSQL Backend
- CloudNative-PG cluster with 1 instance
- 10Gi storage via ceph-block
- Managed credentials via 1Password ExternalSecret

#### Coder Application
- Helm-based deployment from OCI registry
- HTTPRoute for HTTPS access at `coder.goyangi.io`
- Access URL: `https://coder.goyangi.io`
- Wildcard URL for workspace access: `*.coder.goyangi.io`

#### Workspace Templates
- Kubernetes provider (creates pods in `coder-workspaces` namespace)
- 50Gi PVC per workspace (ceph-block)
- 500m CPU request, 1Gi memory request
- 2000m CPU limit, 4Gi memory limit
- Docker socket access for buildkit integration
- Non-root user (uid: 1000)

### 3. **Workspace Features**
- **Terminal**: Web-based terminal via ttyd
- **VS Code Server**: Web-based IDE access
- **Code Server**: Full VS Code functionality in browser
- **Docker Access**: Can interact with cluster buildkit and container tools
- **Git Integration**: Full git support with GitHub CLI

## Setup Instructions

### Prerequisites
- CloudNative-PG already installed (✓ You have this)
- Ceph block storage available (✓ You have this)
- 1Password integration configured (✓ You have this)

### Step 1: Add PostgreSQL Secret to 1Password

Create a secret in 1Password called `coder-postgres` with:
```
username: postgres
password: <your-secure-password>
```

### Step 2: Deploy Coder

The Coder deployment is already integrated into your Flux GitOps:

```bash
# Push the changes
git add kubernetes/apps/dev/
git commit -m "feat: add Coder with devcontainer.json support"
git push origin claude/explore-coder-kubernetes-3Azey
```

Flux will automatically deploy:
1. `coder` namespace
2. PostgreSQL cluster
3. Coder Helm release
4. HTTPRoute for `coder.goyangi.io`

### Step 3: Create Your First Workspace

1. Navigate to `https://coder.goyangi.io`
2. Set up initial admin account
3. Create a new workspace from the Kubernetes template
4. Select the repo: `home-ops`
5. Coder will:
   - Create a pod in `coder-workspaces` namespace
   - Mount the workspace volume
   - Run the post-create script from `devcontainer.json`
   - Launch the Coder agent

### Step 4: Access the Workspace

**Web Terminal:**
- Access via Coder's web interface
- Full bash terminal with all tools available

**Web IDE:**
- VS Code Server at `code-server` app in Coder
- Full VS Code features in the browser

**SSH:**
```bash
# Get SSH config from Coder
coder config-ssh

# Connect directly
ssh <workspace-name>.coder.goyangi.io
```

## Environment Variables & Configuration

The workspace includes:
- `TZ=Australia/Sydney`
- `CODER_AGENT_TOKEN` (automatically injected)
- `CODER_AGENT_URL` (automatically injected)
- Docker socket access to `tcp://buildkit.default.svc.cluster.local:1234`

## Tools Available in Workspaces

### Kubernetes Management
- `kubectl` with shell completion
- `helm` with shell completion + plugins (helm-diff, helm-secrets)
- `kustomize` for manifest management
- `flux` for GitOps management
- `talosctl` for Talos node management
- `k9s` for Kubernetes dashboard

### Development
- `git` and `gh` (GitHub CLI)
- `go` (latest version)
- Standard build tools (gcc, make, etc.)
- `docker` CLI with buildkit access
- `jq` and `yq` for JSON/YAML processing

### IDEs
- VS Code Server (browser-based)
- TTY web terminal
- SSH access

## Migration from dev-sandbox

### Current State (dev-sandbox)
```
kubernetes/apps/default/dev-sandbox/
├── app/
│   ├── sandbox.yaml          # Agent Sandbox CRD
│   ├── pvc.yaml              # 50Gi persistent claim
│   ├── service.yaml
│   ├── rbac.yaml
│   ├── httproute.yaml
│   └── externalsecret.yaml
```

### New State (Coder)
```
kubernetes/apps/dev/coder/
├── app/
│   ├── helmrelease.yaml      # Coder Helm deployment
│   ├── postgres-cluster.yaml # CloudNative-PG backend
│   ├── workspace-template.yaml # Terraform workspace template
│   ├── httproute.yaml
│   └── externalsecret.yaml
├── crds/
│   └── kustomization.yaml

.devcontainer/
├── devcontainer.json         # Dev environment spec
└── post-create.sh            # Setup script
```

### Migration Steps

1. **Verify Coder Deployment**
   ```bash
   kubectl get pods -n coder
   kubectl get pvc -n coder
   ```

2. **Create Initial Workspace**
   - Via `https://coder.goyangi.io`
   - All environment setup is automated

3. **Remove dev-sandbox** (once verified Coder is working)
   ```bash
   kubectl delete namespace default --selector app=dev-sandbox
   # Or remove from git:
   rm -rf kubernetes/apps/default/dev-sandbox/
   git add -A && git commit -m "remove: retire dev-sandbox in favor of Coder"
   ```

4. **Deprecate VolSync** (for dev environments)
   - Remove dev-sandbox from volsync config if it was backed up
   - Other apps still using VolSync are unaffected

## Troubleshooting

### Coder Pod Not Starting
```bash
kubectl logs -n coder deployment/coder
kubectl describe pod -n coder -l app=coder
```

### PostgreSQL Connection Issues
```bash
# Check cluster status
kubectl get cluster -n coder
kubectl logs -n coder -l app=coder -c postgresql

# Verify secret
kubectl get secret -n coder coder-postgres-secret -o yaml
```

### Workspace Pod Not Ready
```bash
kubectl get pods -n coder-workspaces
kubectl logs -n coder-workspaces <workspace-pod>
kubectl describe pod -n coder-workspaces <workspace-pod>
```

### Coder Agent Connection
```bash
# Check agent status in workspace pod
kubectl exec -it -n coder-workspaces <pod> -- coder stat
```

## Next Steps

### Optional Enhancements
1. **Workspace Auto-Scaling**: Configure Kubernetes KEDA for automatic workspace scaling
2. **Backup Strategy**: Consider VolSync for workspace data if needed
3. **Network Policies**: Add network policies for `coder-workspaces` namespace
4. **Resource Quotas**: Set namespace quotas to prevent runaway workspaces
5. **Multiple Workspace Templates**: Create templates for different project types
6. **IDE Customization**: Add extensions to VS Code Server deployment

### Cost Optimization
- Configure workspace auto-stop after inactivity
- Set resource limits per workspace type
- Implement namespace cleanup for abandoned workspaces

## References

- [Coder Kubernetes Docs](https://coder.com/docs/install/kubernetes)
- [Dev Containers Spec](https://containers.dev)
- [CloudNative-PG Docs](https://cloudnative-pg.io)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
