# AGENTS.md

Use British English except in code. Use American English in code and manifests. Do not use Oxford commas.

Follow conventional commits. Never attribute agents in commit messages. Avoid unnecessary comments and emojis. Do not add comments to YAML manifests unless linking to upstream issues or explaining disabled components.

Use GitOps. Do not edit resources directly. Make changes to the repo, commit and push, then run `flux reconcile ks cluster-apps --with-source`.

Read `.agents/*.md` for specific scenarios.

## Commits

- Use imperative tone: `Add provisioning flowchart`
- Keep subject line under 50 characters
- Use conventional commits with scope tags: `feat(k8s):`, `fix(cilium):`, `chore(norish):`, `docs(readme):`
- **Never use `git add .`** - always specify exact files to stage
- **Only commit and push when explicitly requested by user**
- Add detailed context in commit body when needed:

```
feat(k8s): add ipv6 dual-stack

- enable IPv6 networking with ULA addresses for pods and services
- configure Cilium BGP advertisement for dual-stack routing
```

```
fix(mlmd): configure mysql_native_password for ML Metadata

Update authentication policy for MLMD compatibility.
```

```
infra: Configure mysql_native_password for ML Metadata

Update authentication policy for MLMD compatibility.
```

## IPv6 Dual-Stack Configuration

The cluster supports dual-stack IPv4/IPv6 networking with ULA (Unique Local Addresses) for internal communication.

### IPv6 Subnets
- **Nodes**: `fd5d:a293:f321:42::/64`
- **LoadBalancer**: `fd5d:a293:f321:69::/80`
- **Pods**: `fc69::/108`
- **Services**: `fc96::/108`

### Dual-Stack Services
For services that need both IPv4 and IPv6 access:

```yaml
service:
  app:
    type: LoadBalancer
    ipFamilies: [IPv4, IPv6]
    ipFamilyPolicy: PreferDualStack
    externalTrafficPolicy: Local
    annotations:
      external-dns.alpha.kubernetes.io/hostname: app.goyangi.io
      lbipam.cilium.io/ips: 192.168.69.122,fc69::122
```

### Key Configuration Points
- **ipFamilies**: `[IPv4, IPv6]` enables dual-stack
- **ipFamilyPolicy**: `PreferDualStack` prefers dual-stack but falls back to single-stack
- **lbipam.cilium.io/ips**: Comma-separated IPv4,IPv6 addresses
- **Pods automatically get dual-stack IPs** when created after dual-stack is enabled
- **Existing pods need recreation** to get IPv6 addresses

## Architecture

Single cluster Kubernetes GitOps repository with FluxCD v2. Hierarchical pattern: namespace → application. Encrypted secrets using SOPS and Age.

### Directories

- `.agents/` - Agent instructions
- `kubernetes/` - Cluster manifests
- `kubernetes/mod.just` - Just commands for cluster operations
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
  dependsOn:  # Dependencies
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

**Always include namespace in dependsOn:**
```yaml
dependsOn:
  - name: dependency-name
    namespace: target-namespace
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
  - ./pvc.yaml             # Optional - for persistent storage
  - ./prometheusrule.yaml  # Optional for monitoring
```

**Note**: 
- App-level kustomizations don't need `namespace:` field - they inherit from Flux Kustomization's `targetNamespace`
- VolSync component is added at the **ks.yaml level**, not in app kustomization
- PVC is only needed if the application requires persistent storage beyond what the Helm chart provides

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
              tag: latest@sha256:digest  # Use digests for security and reproducibility
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

**Reference upstream documentation:**
- **App-template**: https://bjw-s.github.io/helm-charts/docs/app-template/
- **Container images**: Check GitHub/Docker Hub for environment variables and configuration
- **Helm charts**: Review `values.yaml` in chart repository for available options
- **Official docs**: Always check application's official documentation for configuration options

**Database apps with CNPG managed roles (preferred):**

Uses the `database` component which creates a CNPG Database CRD, client certificate and connection secret.

1. Add managed role to CNPG cluster (`kubernetes/apps/storage/cloudnative-pg/cluster/cluster.yaml`):
```yaml
managed:
  roles:
    - name: myapp
      ensure: present
      login: true
      disablePassword: true  # For cert auth
```

2. Add component to ks.yaml:
```yaml
spec:
  targetNamespace: default
  components:
    - ../../../../components/database
  dependsOn:
    - name: cloudnative-pg-cluster
      namespace: storage
  postBuild:
    substitute:
      APP: myapp
```

3. Mount certs and use connection secret in helmrelease.yaml:
```yaml
values:
  controllers:
    myapp:
      containers:
        app:
          env:
            DATABASE_URL:
              valueFrom:
                secretKeyRef:
                  name: myapp-postgres
                  key: myapp_POSTGRES_URL
  persistence:
    postgres-certs:
      type: secret
      name: postgres-myapp-cert
      globalMounts:
        - path: /var/run/secrets/postgresql
    postgres-ca:
      type: secret
      name: cluster-ca
      globalMounts:
        - path: /var/run/secrets/root-ca
```

The component creates:
- `postgres-myapp-cert` - Client certificate for mTLS auth
- `myapp-postgres` - Secret with connection details including `myapp_POSTGRES_URL`
- CNPG Database CRD - Creates database and role in postgres cluster

Connection URL format: `postgresql://myapp@postgres-rw.storage.svc.cluster.local:5432/myapp?sslmode=verify-full&sslcert=/var/run/secrets/postgresql/tls.crt&sslkey=/var/run/secrets/postgresql/tls.key&sslrootcert=/var/run/secrets/root-ca/ca.crt`

**Database apps with init containers (legacy):**
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

**Note**: Only create separate `pvc.yaml` for cache/temp storage that doesn't need backup. For critical data, use VolSync component which creates PVCs automatically and provides backup/restore capabilities.

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

**Volume types:**
```yaml
# Persistent storage
persistence:
  config:
    existingClaim: "{{ .Release.Name }}"
  
  # NFS mounts
  media:
    type: nfs
    server: nas.internal
    path: /mnt/world/media
    globalMounts:
      - path: /media
  
  # Temporary storage
  tmp:
    type: emptyDir
```

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

**Service types:**
```yaml
# LoadBalancer with Cilium IPAM (dual-stack)
service:
  app:
    type: LoadBalancer
    ipFamilies: [IPv4, IPv6]
    ipFamilyPolicy: PreferDualStack
    externalTrafficPolicy: Local
    annotations:
      external-dns.alpha.kubernetes.io/hostname: app.goyangi.io
      lbipam.cilium.io/ips: 192.168.69.122,fc69::122
    ports:
      tcp:
        port: 50469
        protocol: TCP

# LoadBalancer with IPv4 only (legacy)
service:
  bittorrent:
    type: LoadBalancer
    annotations:
      lbipam.cilium.io/ips: 192.168.69.122
    externalTrafficPolicy: Local
    ports:
      tcp:
        port: 50469
        protocol: TCP
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

**Kustomize patches:**
```yaml
# app/kustomization.yaml
patches:
  - target:
      kind: Deployment
    patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: this-is-ignored
      spec:
        template:
          metadata:
            annotations:
              reloader.stakater.com/auto: "true"
```

**Third-party manifests:**
```yaml
# app/kustomization.yaml
resources:
  - ../../../../../third_party/kubeflow/manifests/apps/kserve/kserve
  - ./helmrelease.yaml
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
just kube browse-pvc <namespace> <claim>  # Mount PVC to temp container
just kube prune-pods                      # Delete failed/pending/succeeded pods
just kube sync-es                         # Sync ExternalSecrets
just kube snapshot                        # Snapshot VolSync PVCs
just kube cnpg-backup                     # Backup CNPG cluster
just kube backup-and-suspend              # Full backup + suspend workflow
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

Applications use Authentik (https://id.goyangi.io) for SSO authentication. Each application has different OIDC field names and requirements:

**Mealie:**
```yaml
OIDC_AUTH_ENABLED: "True"
OIDC_SIGNUP_ENABLED: "True"
OIDC_CONFIGURATION_URL: https://id.goyangi.io/.well-known/openid-configuration
OIDC_CLIENT_ID: "{{ .MEALIE_CLIENT_ID }}"
OIDC_CLIENT_SECRET: "{{ .MEALIE_CLIENT_SECRET }}"
OIDC_ADMIN_GROUP: admin
OIDC_AUTO_REDIRECT: "True"
OIDC_REMEMBER_ME: "True"
```

**Audiobookshelf:**
```yaml
OIDC_ISSUER_URL: "https://id.goyangi.io"
OIDC_CLIENT_ID: "{{ .AUDIOBOOKSHELF_CLIENT_ID }}"
OIDC_CLIENT_SECRET: "{{ .AUDIOBOOKSHELF_CLIENT_SECRET }}"
OIDC_BUTTON_TEXT: "Login with Authentik"
OIDC_AUTO_LAUNCH: "false"
```

**Grafana:**
```yaml
GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
GF_AUTH_GENERIC_OAUTH_NAME: "Authentik"
GF_AUTH_GENERIC_OAUTH_CLIENT_ID: "{{ .GRAFANA_CLIENT_ID }}"
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: "{{ .GRAFANA_CLIENT_SECRET }}"
GF_AUTH_GENERIC_OAUTH_AUTH_URL: https://id.goyangi.io/authorize
GF_AUTH_GENERIC_OAUTH_TOKEN_URL: https://id.goyangi.io/api/oidc/token
```

**Kubeflow:**
```yaml
KUBEFLOW_OIDC_CLIENT_ID: kubeflow-oidc-authservice
KUBEFLOW_OIDC_CLIENT_SECRET: "{{ .KUBEFLOW_OIDC_CLIENT_SECRET }}"
```

**GitLab:**
```yaml
# In ExternalSecret template
GITLAB_OIDC_CLIENT_ID: "{{ .GITLAB_OIDC_CLIENT_ID }}"
GITLAB_OIDC_CLIENT_SECRET: "{{ .GITLAB_OIDC_CLIENT_SECRET }}"

oidc-config: |
  name: openid_connect
  label: Authentik
  args:
    name: openid_connect
    scope: [openid, profile, email]
    response_type: code
    issuer: https://id.goyangi.io
    client_auth_method: query
    discovery: true
    uid_field: preferred_username
    client_options:
      identifier: "{{ .GITLAB_OIDC_CLIENT_ID }}"
      secret: "{{ .GITLAB_OIDC_CLIENT_SECRET }}"
      redirect_uri: https://gitlab.goyangi.io/users/auth/openid_connect/callback

# In HelmRelease values
appConfig:
  omniauth:
    enabled: true
    autoSignInWithProvider: []
    syncProfileFromProvider: [openid_connect]
    allowSingleSignOn: [openid_connect]
    allowBypassTwoFactor: [openid_connect]
    syncProfileAttributes: [email]
    blockAutoCreatedUsers: false
    providers:
      - secret: gitlab-secret
        key: oidc-config
```

## Infrastructure Integration

### SMTP Configuration

Use the internal SMTP relay for email notifications:

```yaml
# In ExternalSecret template
SMTP_HOST: smtp-relay.network.svc.cluster.local
SMTP_PORT: "25"
SMTP_FROM_NAME: <app-name>
SMTP_FROM_EMAIL: noreply@goyangi.io
SMTP_AUTH_STRATEGY: NONE

# In HelmRelease values (application-specific)
smtp:
  enabled: true
  address: smtp-relay.network.svc.cluster.local
  port: 25
  domain: goyangi.io
  authentication: none
  starttls_auto: false
```

### Storage Integration

**Garage S3 credentials** (use existing shared credentials):
```yaml
# In ExternalSecret template
S3_ACCESS_KEY: "{{ .GARAGE_ROOT_USER }}"
S3_SECRET_KEY: "{{ .GARAGE_ROOT_PASSWORD }}"
S3_ENDPOINT: garage.storage.svc.cluster.local:3900

# In dataFrom
dataFrom:
  - extract:
      key: garage
```

**Database credentials** (use existing shared credentials):
```yaml
# PostgreSQL
POSTGRES_USER: "{{ .POSTGRES_USER }}"
POSTGRES_PASSWORD: "{{ .POSTGRES_PASSWORD }}"
POSTGRES_HOST: postgres-rw.storage.svc.cluster.local

# Redis/Dragonfly
REDIS_PASSWORD: "{{ .REDIS_PASSWORD }}"
REDIS_HOST: dragonfly.storage.svc.cluster.local

# In dataFrom
dataFrom:
  - extract:
      key: cloudnative-pg
  - extract:
      key: dragonfly
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
