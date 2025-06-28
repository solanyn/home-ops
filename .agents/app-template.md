# Application Deployment Pattern Guide

This document outlines the standard patterns for deploying applications in this GitOps repository. This only applies for simple applications which have a container and have no alternative helm chart or the helm charts are unsuitable.

Refer to other committed `helmrelease.yaml` files in the repository for references. Follow existing `helmrelease.yaml` formats closely.

## Directory Structure

All applications should follow this standardized directory structure:

```
kubernetes/<cluster>/apps/<namespace>/<app-name>/
├── app/                   # Directory containing application resources
│   ├── externalsecret.yaml  # If using secrets
│   ├── helmrelease.yaml     # The main Helm release definition
│   ├── kustomization.yaml   # References all resources and templates
│   └── pvc.yaml             # If using additional persistent storage
└── ks.yaml                  # Flux Kustomization resource
```

## Key Components

### 1. Flux Kustomization (ks.yaml)

This file defines an example of how Flux should deploy the application:

```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.solanyn.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app cloudnative-pg
    namespace: &namespace storage
spec:
    commonMetadata:
        labels:
            app.kubernetes.io/name: *app
    healthChecks:
        - apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          name: *app
          namespace: *namespace
    interval: 1h
    path: ./kubernetes/apps/storage/cloudnative-pg/app
    prune: true
    retryInterval: 2m
    sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
    targetNamespace: *namespace
    timeout: 5m
    wait: true
---
# yaml-language-server: $schema=https://kubernetes-schemas.solanyn.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app cloudnative-pg-cluster
    namespace: &namespace storage
spec:
    commonMetadata:
        labels:
            app.kubernetes.io/name: *app
    dependsOn:
        - name: cloudnative-pg
          namespace: storage
        - name: minio
          namespace: storage
    healthChecks:
        - apiVersion: postgresql.cnpg.io/v1
          kind: Cluster
          name: postgres17
    healthCheckExprs:
        - apiVersion: postgresql.cnpg.io/v1
          kind: Cluster
          failed: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'False')
          current: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True')
    interval: 1h
    path: ./kubernetes/apps/storage/cloudnative-pg/cluster
    prune: true
    retryInterval: 2m
    sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
    targetNamespace: *namespace
    timeout: 5m
    wait: true
```

If applications have dependencies on other Flux kustomizations it can look like:

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.solanyn.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app pocket-id
    namespace: &namespace auth
spec:
    commonMetadata:
        labels:
            app.kubernetes.io/name: *app
    components:
        - ../../../../components/gatus/guarded
        - ../../../../components/volsync
    dependsOn:
        - name: volsync
          namespace: volsync-system
        - name: cloudnative-pg-cluster
          namespace: storage
    interval: 1h
    path: ./kubernetes/apps/auth/pocket-id/app
    postBuild:
        substitute:
            APP: *app
            GATUS_SUBDOMAIN: id
    prune: true
    retryInterval: 2m
    sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
    targetNamespace: *namespace
    timeout: 5m
    wait: false
```

For applications that require filesystem to be backed up, `postBuild` the `APP` must be defined under the `substitute` section. If the domain that the app should be reachable at does not match the app name and the app requires monitoring via Gatus, the subdomain must be defined with `GATUS_SUBDOMAIN` and the `gatus` component must be defined. Externally exposed (internet-facing) should use the `gatus/external` component instead of `guarded`. If unsure, ask the operator.

### 2. Application Kustomization (app/kustomization.yaml)

This file brings together all the application resources:

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
    - ./externalsecret.yaml
    - ./helmrelease.yaml
configMapGenerator:
    - name: webhook-configmap
      files:
          - hooks.yaml=./resources/hooks.yaml
          - jellyseerr-pushover.sh=./resources/jellyseerr-pushover.sh
          - radarr-pushover.sh=./resources/radarr-pushover.sh
          - sonarr-pushover.sh=./resources/sonarr-pushover.sh
          - sonarr-refresh-series.sh=./resources/sonarr-refresh-series.sh
          - sonarr-tag-codecs.sh=./resources/sonarr-tag-codecs.sh
generatorOptions:
    disableNameSuffixHash: true
    annotations:
        kustomize.toolkit.fluxcd.io/substitute: disabled
```

Resources do not have to include configMapGenerator sections. If the `<app>/resources` exists, then a `configMapGenerator` should be added for each file in the `<app>/resources` directory and mounted.

### 3. HelmRelease (app/helmrelease.yaml)

The main application definition:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: app
spec:
    interval: 1h
    chartRef:
        kind: OCIRepository
        name: app-template
    install:
        remediation:
            retries: -1
    upgrade:
        cleanupOnFail: true
        remediation:
            strategy: rollback
            retries: 3
    values:
    # Application values here
```

## Common Patterns by Application Type

### Applications with Persistent Storage

For applications that need persistent storage, follow these patterns:

1. **Include VolSync dependencies**:

    ```yaml
    dependsOn:
        - name: rook-ceph-cluster
        - name: volsync
    ```

2. **Configure VolSync parameters**:

    ```yaml
    postBuild:
      substitute:
        APP: *app
        VOLSYNC_CAPACITY: 10Gi
        VOLSYNC_STORAGECLASS: ceph-block
        VOLSYNC_ACCESSMODES: ReadWriteOnce
    ```

3. **Reference in HelmRelease**:

    ```yaml
    persistence:
        config:
            existingClaim: app-name # Matches ${APP}
    ```

### Applications with Secrets

For applications that need secrets from 1Password:

1. **Create an ExternalSecret**:

    ```yaml
    # yaml-language-server: $schema=https://kubernetes-schemas.solanyn.dev/external-secrets.io/externalsecret_v1beta1.json
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
    name: atuin
    spec:
    secretStoreRef:
        kind: ClusterSecretStore
        name: onepassword
    target:
        name: atuin-secret
        template:
        data:
            ATUIN_DB_URI: "postgres://{{.ATUIN_POSTGRES_USER}}:{{.ATUIN_POSTGRES_PASSWORD}}@postgres17-rw.storage.svc.cluster.local:5432/atuin"
            INIT_POSTGRES_DBNAME: atuin
            INIT_POSTGRES_HOST: postgres17-rw.storage.svc.cluster.local
            INIT_POSTGRES_USER: "{{ .ATUIN_POSTGRES_USER }}"
            INIT_POSTGRES_PASS: "{{ .ATUIN_POSTGRES_PASSWORD }}"
            INIT_POSTGRES_SUPER_PASS: "{{ .POSTGRES_SUPER_PASS }}"
    dataFrom:
        - extract:
              key: atuin
        - extract:
              key: cloudnative-pg
    ```

    If an application requires a PostgreSQL database initialised then the `INIT_POSTGRES_*` fields must be populated. Generally, they follow a similar pattern to the example.

2. **Reference in HelmRelease**:

    ```yaml
    env:
        - name: SECRET_VALUE
          valueFrom:
              secretKeyRef:
                  name: app-name-secret
                  key: key-name
    ```

### Applications with Ingress

For applications that need external access:

1. **For internal access**:

    ```yaml
    route:
        app:
            hostnames:
                - "{{ .Release.Name }}.goyangi.io"
                # If alternative subdomain is required
                - join.goyangi.io
            parentRefs:
                - name: internal
                  namespace: kube-system
                  sectionName: https
    ```

2. **For external access**:

    ```yaml
    route:
        app:
            hostnames:
                - "{{ .Release.Name }}.goyangi.io"
                # If alternative subdomain is required
                - join.goyangi.io
            parentRefs:
                - name: external
                  namespace: kube-system
                  sectionName: https
    ```

## Best Practices

1. **Schema Validation**: Always include schema references at the top of your YAML files
2. **Version Pinning**: Always pin chart and image versions
3. **Resource Limits**: Always define resource limits and requests
4. **Health Probes**: Configure appropriate health checks
5. **Security Context**: Use appropriate security contexts
6. **Annotations**: Use reloader.stakater.com/auto: "true" for automatic pod restarts on config changes
7. **Dependencies**: Define all required dependencies in the Flux Kustomization
8. **Networking**: Use the appropriate route class and DNS target based on access requirements

## Template Structure

The repository maintains several shared templates:

1. **VolSync**: For persistent storage with backup capabilities
2. **Gatus**: For application monitoring
    - `guarded`: For authenticated monitoring
    - `external`: For external monitoring

These templates should be included in your application's kustomization.yaml when needed.
