# AGENTS.md

Use British English except in code. Use American English in code and manifests. Do not use Oxford commas.

Follow conventional commits. Never attribute agents in commit messages. Avoid unnecessary comments and emojis.

Use GitOps. Do not edit resources directly. Make changes to the repo, commit and push, then run `flux reconcile ks cluster-apps --with-source`.

Read `.agents/*.md` for specific scenarios.

## Commits

- Use imperative tone: `Add provisioning flowchart`
- Keep messages under 50 characters
- Use conventional commits: `docs:`, `infra:`, `feat:`, `fix:`, `chore:`
- Include context when needed:

```
infra: Configure mysql_native_password for ML Metadata

Update authentication policy for MLMD compatibility.
```

## Architecture

Single cluster Kubernetes GitOps repository with FluxCD v2. Hierarchical pattern: namespace → application. Encrypted secrets using SOPS and Age.

### Directories

- `.agents/` - Agent instructions
- `kubernetes/` - Cluster manifests
- `.taskfiles/` - Task automation
- `talos/` - Talos Linux configuration
- `third_party/` - Upstream manifests (flux-local CI)

### Application Patterns

#### Standard Structure

```
apps/<namespace>/<app-name>/
├── app/                    # Application resources
│   ├── helmrelease.yaml    # Helm chart deployment
│   ├── kustomization.yaml  # Resource aggregation (always present)
│   ├── externalsecret.yaml # 1Password secrets (when needed)
│   ├── pvc.yaml           # Persistent storage (when needed)
│   ├── httproute.yaml     # Gateway API routing (web apps)
│   └── monitoring.yaml    # gatus.yaml, lokirule.yaml, prometheusrule.yaml
├── cluster/               # Infrastructure resources (databases only)
│   ├── resource.yaml      # Cluster, backup, service definitions
│   └── kustomization.yaml
└── ks.yaml                # Flux Kustomization (always present)
```

#### Creating New Applications

1. **Choose namespace** based on application type:

    - `default` - General applications, home automation
    - `ai` - Conversational AI, agents, chat interfaces
    - `ml` - Machine learning services, feature stores
    - `kubeflow` - ML platform components (core)
    - `analytics` - Data engineering (Airflow, Superset)
    - `storage` - Databases and storage systems
    - `observability` - Monitoring tools

2. **Create ks.yaml** with standard pattern:

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-name
spec:
  interval: 1h
  path: ./kubernetes/apps/namespace/app-name/app
  postBuild:
    substitute:
      APP: app-name
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: target-namespace
  wait: false
  dependsOn:  # Optional - for dependencies
    - name: dependency-name
      namespace: flux-system
  components:  # Optional - for VolSync backups
    - ../../../../components/volsync
```

**For apps with CRDs (like kagent):**
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-crds
spec:
  interval: 1h
  path: ./kubernetes/apps/namespace/app-name/crds
  prune: false  # Never prune CRDs
  targetNamespace: target-namespace
  wait: true    # Wait for CRDs to be ready
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-name
spec:
  dependsOn:
    - name: app-crds
  interval: 1h
  path: ./kubernetes/apps/namespace/app-name/app
  targetNamespace: target-namespace
```

3. **Create app/kustomization.yaml**:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: target-namespace
resources:
    - helmrelease.yaml
    - externalsecret.yaml # If needed
    - pvc.yaml # If needed
    - httproute.yaml # If web app
components:
    - ../../../../components/gatus/guarded # For monitoring
    - ../../../../components/volsync # For backups
```

**Simplified pattern (most common):**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./ocirepository.yaml
  - ./helmrelease.yaml
  - ./externalsecret.yaml  # Optional
  - ./httproute.yaml       # Optional for web apps
```

**Note**: App-level kustomizations don't need `namespace:` field - they inherit from Flux Kustomization's `targetNamespace`.

4. **Create helmrelease.yaml** with standard fields:

```yaml
spec:
    interval: 1h
    install:
        remediation:
            retries: -1
    upgrade:
        cleanupOnFail: true
        remediation:
            retries: 3
    postRenderers:
        - kustomize:
              patches:
                  - target:
                        kind: Deployment
                    patch: |
                        - op: add
                          path: /spec/template/metadata/annotations/reloader.stakater.com~1auto
                          value: "true"
```

5. **Add to namespace kustomization.yaml**:

```yaml
resources:
    - app-name/ks.yaml
```

#### Storage Patterns

- **PVC**: Use `storageClassName: ceph-block` or `openebs-hostpath`
- **VolSync**: Add component for automatic backups
- **Access modes**: Typically `["ReadWriteOnce"]`

#### Networking Patterns

- **HTTPRoute**: Use `envoy-internal` gateway for web interfaces
- **Hostnames**: `app.domain.tld` pattern
- **Services**: `app.namespace.svc.cluster.local` for internal access
- **Cross-namespace**: Update service references when moving apps between namespaces
- **App-template route field**: Use `route:` in HelmRelease instead of separate HTTPRoute

```yaml
# In HelmRelease values:
route:
  app:
    hostnames:
      - "{{ .Release.Name }}.goyangi.io"
    parentRefs:
      - name: envoy-internal
        namespace: network
```

#### Security Patterns

- **ExternalSecret**: Reference `onepassword` ClusterSecretStore
- **Target secret**: Name as `app-secret`
- **SOPS**: Use `.sops.yaml` suffix for encrypted configs

## Commands

```bash
task k8s:browse-pvc         # Mount PVC to temp container
task k8s:delete-failed-pods # Delete failed pods
task externalsecrets:*      # External Secrets operations
task rook:*                 # Rook-Ceph operations
task volsync:*              # VolSync operations
```

## Security

- SOPS encryption with Age keys
- External Secrets Operator for 1Password injection
- Never commit unencrypted secrets

## GitOps

1. FluxCD syncs changes automatically
2. Hierarchical reconciliation with dependencies
3. PR validation with kubeconform and linting
4. Renovate automation for updates

## Technologies

**Core:** FluxCD v2, Talos Linux, Cilium CNI, Envoy Gateway

**ML/Data:** Kubeflow, KServe, Ray, Airflow, Kafka, Flink, Milvus

**Storage:** Rook-Ceph, OpenEBS, VolSync

**Operations:** External Secrets, cert-manager
