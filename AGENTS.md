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

**Field ordering in ks.yaml:**
```yaml
metadata:
  name: app-name
spec:
  targetNamespace: namespace     # Always first
  components:                    # Optional - before dependsOn
    - ../../../../components/volsync
  dependsOn:                     # Dependencies
    - name: cloudnative-pg-cluster
      namespace: storage
  interval: 1h                   # Standard fields
  path: ./kubernetes/apps/...
  postBuild:                     # Substitutions
    substitute:
      APP: app-name
      VOLSYNC_CAPACITY: 5Gi
  prune: true
  sourceRef:                     # Git source
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  wait: false
```

**Common dependencies:**
- **Database apps**: `cloudnative-pg-cluster` (namespace: storage)
- **Storage apps**: `rook-ceph-cluster` (namespace: rook-ceph)
- **AI apps**: May depend on model serving or gateway services

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
  - ./prometheusrule.yaml  # Optional for monitoring
```

**Note**: App-level kustomizations don't need `namespace:` field - they inherit from Flux Kustomization's `targetNamespace`.

#### Repository Patterns

**OCIRepository (preferred):**
```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: app-name
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: 4.5.0
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

**HelmRepository (fallback when OCI not available):**
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: app-name
spec:
  interval: 1h
  url: https://charts.example.com/
```

**HelmRelease references:**
- OCIRepository: `chartRef: {kind: OCIRepository, name: app-name}`
- HelmRepository: `chart: {spec: {chart: chart-name, sourceRef: {kind: HelmRepository, name: app-name}}}`

4. **Create helmrelease.yaml** with standard template:

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: "{{ .Release.Name }}"
spec:
  chartRef:
    kind: OCIRepository
    name: app-name
  interval: 1h
  install:
    remediation:
      retries: -1
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  values:
    controllers:
      app:
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/example/app
              tag: latest
            env:
              TZ: Australia/Sydney
    service:
      app:
        ports:
          http:
            port: 80
    persistence:
      config:
        existingClaim: "{{ .Release.Name }}"
```

**Database apps with init containers:**
```yaml
values:
  controllers:
    app-name:
      annotations:
        reloader.stakater.com/auto: "true"
      initContainers:
        init-db:
          image:
            repository: ghcr.io/home-operations/postgres-init
            tag: 18
          envFrom: &envFrom
            - secretRef:
                name: "{{ .Release.Name }}-secret"
      containers:
        app:
          envFrom: *envFrom  # Same secrets as init container
```

5. **Create PVC (if needed)**:

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "{{ .Release.Name }}"
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
  storageClassName: ceph-block
```

6. **Create monitoring (if needed)**:

```yaml
---
# prometheusrule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: "{{ .Release.Name }}-rules"
spec:
  groups:
    - name: "{{ .Release.Name }}.rules"
      rules:
        - alert: AppDown
          expr: up{job="{{ .Release.Name }}"} == 0
          for: 5m
          labels:
            severity: critical
```

7. **Add to namespace kustomization.yaml**:

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

#### Configuration Patterns

**ConfigMapGenerator (for files):**
```yaml
# app/kustomization.yaml
configMapGenerator:
  - name: app-configmap
    files:
      - config.yaml=./resources/config.yaml
      - script.sh=./resources/script.sh
generatorOptions:
  disableNameSuffixHash: true
  annotations:
    kustomize.toolkit.fluxcd.io/substitute: disabled
```

**App-template configMaps (for inline config):**
```yaml
# In HelmRelease values:
configMaps:
  config:
    data:
      config.toml: |-
        [section]
        key = "value"
persistence:
  config-file:
    type: configMap
    identifier: config
    globalMounts:
      - path: /app/config.toml
        subPath: config.toml
```

#### Security Patterns

- **ExternalSecret**: Reference `onepassword` ClusterSecretStore
- **Target secret**: Name as `app-name-secret`
- **Always use template**: Makes value mapping clear

**ExternalSecret template pattern (always use this):**
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-name
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: app-name-secret
    creationPolicy: Owner
    template:
      data:
        DATABASE_URL: "postgres://{{ .DB_USER }}:{{ .DB_PASS }}@host:5432/db"
        API_KEY: "{{ .API_KEY }}"
        # Use YAML anchors for shared values
        INIT_POSTGRES_HOST: &dbHost postgres-rw.storage.svc.cluster.local
        INIT_POSTGRES_USER: &dbUser "{{ .DB_USER }}"
        INIT_POSTGRES_PASS: &dbPass "{{ .DB_PASS }}"
        INIT_POSTGRES_DBNAME: *dbName
  dataFrom:
    - extract:
        key: app-name
    - extract:
        key: cloudnative-pg  # Shared database credentials
```

## Commands

```bash
task k8s:browse-pvc         # Mount PVC to temp container
task k8s:delete-failed-pods # Delete failed pods
task externalsecrets:*      # External Secrets operations
task rook:*                 # Rook-Ceph operations
task volsync:*              # VolSync operations
```

### 1Password CLI

Use `op` CLI to verify secret values during development:

```bash
# Check if secret exists in 1Password
op item get app-name --vault kubernetes

# View specific field
op item get app-name --field API_KEY --vault kubernetes

# Test secret template values
op item get cloudnative-pg --field DB_USER --vault kubernetes
```

## OIDC Integration

Applications use Pocket ID (https://id.goyangi.io) for SSO authentication:

```yaml
# Common OIDC environment variables in ExternalSecret template:
template:
  data:
    OIDC_AUTH_ENABLED: "true"
    OIDC_CONFIGURATION_URL: https://id.goyangi.io/.well-known/openid-configuration
    OIDC_ISSUER_URL: https://id.goyangi.io
    OIDC_CLIENT_ID: "{{ .APP_CLIENT_ID }}"
    OIDC_CLIENT_SECRET: "{{ .APP_CLIENT_SECRET }}"
    OIDC_REDIRECT_URI: https://app.goyangi.io/auth/callback
    OIDC_AUTO_REDIRECT: "true"
    OIDC_ADMIN_GROUP: admin
```

**Application-specific patterns:**
- **Mealie**: Uses `OIDC_SIGNUP_ENABLED`, `OIDC_REMEMBER_ME`
- **Audiobookshelf**: Uses `OIDC_BUTTON_TEXT`, `OIDC_AUTO_LAUNCH`
- **Grafana**: Uses `GF_AUTH_GENERIC_OAUTH_*` prefix
- **Kubeflow**: Uses `kubeflow-oidc-authservice` client ID

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
