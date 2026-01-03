# Kubeflow 1.11 Migration Plan

Migration from Istio-based Kubeflow 1.10.2 to Envoy Gateway-based Kubeflow 1.11 using app-template HelmReleases.

## Goals

1. Remove Istio dependency entirely
2. Use Envoy Gateway for ingress and OIDC authentication with Authentik
3. Convert kustomize manifests to app-template HelmReleases where possible
4. Use official Helm charts where available
5. Enable Renovate to track all image and chart versions
6. Delete `third_party/kubeflow/manifests` vendored directory

## Architecture Change

### Before (Istio)

```
Browser → Istio Gateway → oauth2-proxy → dex → Pocket ID
              ↓
         VirtualService
              ↓
         Pod (with sidecar)
```

### After (Envoy Gateway)

```
Browser → Envoy Gateway → centraldashboard → k8s services
              ↓
        SecurityPolicy
         (OIDC direct)
              ↓
          Authentik
```

Key simplification: centraldashboard acts as reverse proxy to all Kubeflow UIs internally via standard Kubernetes service DNS. Only one HTTPRoute and one SecurityPolicy needed.

## Components to Remove

- `kubernetes/apps/istio-system/` (entire namespace)
- `kubernetes/apps/kubeflow/oauth2-proxy/`
- `kubernetes/apps/kubeflow/dex/`
- `third_party/kubeflow/manifests/` (entire directory)

## Component Deployment Strategy

### Use Official Helm Charts

| Component | Chart Source | Notes |
|-----------|--------------|-------|
| KServe | `oci://ghcr.io/kserve/charts/kserve-crd` + `kserve` | CRDs separate |
| Trainer v2 | `oci://ghcr.io/kubeflow/charts/kubeflow-trainer` | New in 1.11 |
| Spark Operator | `oci://ghcr.io/kubeflow/charts/spark-operator` | Already using |

### Use app-template HelmReleases

| Component | Containers | Complexity |
|-----------|------------|------------|
| centraldashboard | 1 | Simple |
| profiles (+ KFAM) | 1 | Simple |
| jupyter-web-app | 1 | Simple |
| notebook-controller | 1 | Simple - set `USE_ISTIO=false` |
| volumes-web-app | 1 | Simple |
| tensorboards-web-app | 1 | Simple |
| tensorboard-controller | 1 | Simple |
| admission-webhook | 1 | Simple |
| katib | 3 (controller, db-manager, ui) | Medium |
| model-registry | 2 (api, ui) | Medium |
| pipelines | 8+ deployments | Complex - use multi-controller pattern |

## Directory Structure

```
kubernetes/apps/kubeflow/
├── kustomization.yaml
├── namespace.yaml
├── auth/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── httproute.yaml
│       └── securitypolicy.yaml
├── dashboard/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       ├── helmrelease.yaml
│       └── externalsecret.yaml
├── profiles/
│   ├── ks.yaml
│   ├── crds/
│   │   └── kustomization.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
├── notebooks/
│   ├── ks.yaml
│   ├── crds/
│   │   └── kustomization.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
├── pipelines/
│   ├── ks.yaml
│   ├── crds/
│   │   └── kustomization.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       ├── helmrelease.yaml
│       └── externalsecret.yaml
├── katib/
│   ├── ks.yaml
│   ├── crds/
│   │   └── kustomization.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
├── kserve/
│   ├── ks.yaml
│   ├── crds/
│   │   └── kustomization.yaml
│   └── app/
│       ├── kustomization.yaml
│       └── helmrelease.yaml
├── trainer/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       └── helmrelease.yaml
├── training-operator/
│   ├── ks.yaml
│   └── app/
│       └── ... (keep for legacy jobs, or remove)
├── spark/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       └── helmrelease.yaml
├── model-registry/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
├── volumes/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
├── tensorboards/
│   ├── ks.yaml
│   └── app/
│       ├── kustomization.yaml
│       ├── ocirepository.yaml
│       └── helmrelease.yaml
└── admission-webhook/
    ├── ks.yaml
    └── app/
        ├── kustomization.yaml
        ├── ocirepository.yaml
        └── helmrelease.yaml
```

## Auth Configuration

### HTTPRoute

Single entry point for all Kubeflow UIs:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kubeflow
  namespace: kubeflow
spec:
  parentRefs:
    - name: envoy-internal
      namespace: network
      sectionName: https
  hostnames:
    - kubeflow.goyangi.io
  rules:
    - backendRefs:
        - name: centraldashboard
          port: 80
```

### SecurityPolicy

OIDC authentication with Authentik, injecting `kubeflow-userid` header:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: kubeflow-oidc
  namespace: kubeflow
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: kubeflow
  oidc:
    provider:
      issuer: https://id.goyangi.io/application/o/kubeflow/
    clientID: kubeflow
    clientSecret:
      name: kubeflow-oidc-secret
    scopes:
      - openid
      - profile
      - email
    redirectURL: https://kubeflow.goyangi.io/oauth2/callback
    forwardAccessToken: true
    claimToHeaders:
      - claim: email
        header: kubeflow-userid
      - claim: groups
        header: kubeflow-groups
```

### Authentik Setup

Create OAuth2/OpenID Provider in Authentik:
- Name: kubeflow
- Client ID: kubeflow
- Redirect URIs: `https://kubeflow.goyangi.io/oauth2/callback`
- Scopes: openid, profile, email

Store client secret in 1Password under `kubeflow` item with key `KUBEFLOW_CLIENT_SECRET`.

## Example HelmReleases

### centraldashboard

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: centraldashboard
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
  interval: 1h
  values:
    controllers:
      dashboard:
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kubeflow/central-dashboard
              tag: v1.11.0
            env:
              USERID_HEADER: kubeflow-userid
              USERID_PREFIX: ""
              PROFILES_KFAM_SERVICE_HOST: profiles-kfam.kubeflow.svc.cluster.local
              REGISTRATION_FLOW: "false"
              DASHBOARD_CONFIGMAP: centraldashboard-config
              LOGOUT_URL: /oauth2/sign_out
              POD_NAMESPACE:
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
            probes:
              liveness:
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /healthz
                    port: 8082
                  initialDelaySeconds: 30
                  periodSeconds: 30
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: { drop: ["ALL"] }
    defaultPodOptions:
      securityContext:
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
    service:
      app:
        ports:
          http:
            port: 80
            targetPort: 8082
    configMaps:
      config:
        data:
          settings: |
            {"DASHBOARD_FORCE_IFRAME": true}
          links: |
            {
              "menuLinks": [
                {"icon": "book", "link": "/jupyter/", "text": "Notebooks", "type": "item"},
                {"icon": "assessment", "link": "/tensorboards/", "text": "TensorBoards", "type": "item"},
                {"icon": "device:storage", "link": "/volumes/", "text": "Volumes", "type": "item"},
                {"icon": "kubeflow:katib", "link": "/katib/", "text": "Katib Experiments", "type": "item"},
                {"icon": "kubeflow:pipeline-centered", "link": "/pipeline/", "text": "Pipelines", "type": "item"},
                {"icon": "social:group", "link": "/models/", "text": "Models", "type": "item"}
              ],
              "externalLinks": [],
              "quickLinks": [
                {"text": "Create a Notebook", "desc": "Kubeflow Notebooks", "link": "/jupyter/new"},
                {"text": "Upload a Pipeline", "desc": "Kubeflow Pipelines", "link": "/pipeline/#/pipelines"}
              ],
              "documentationItems": [
                {"text": "Kubeflow Docs", "desc": "Documentation", "link": "https://www.kubeflow.org/docs/"}
              ]
            }
    persistence:
      config:
        type: configMap
        name: centraldashboard-config
        globalMounts:
          - path: /etc/config
    serviceAccount:
      create: true
      name: centraldashboard
```

### notebook-controller

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: notebooks
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
  interval: 1h
  values:
    controllers:
      web-app:
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kubeflow/jupyter-web-app
              tag: v1.11.0
            env:
              APP_PREFIX: /jupyter
              UI: default
              USERID_HEADER: kubeflow-userid
              USERID_PREFIX: ""
              APP_SECURE_COOKIES: "true"
            ports:
              - containerPort: 5000
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: { drop: ["ALL"] }
      controller:
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kubeflow/notebook-controller
              tag: v1.11.0
            command: ["/manager"]
            env:
              USE_ISTIO: "false"
              CLUSTER_DOMAIN: cluster.local
              ENABLE_CULLING: "false"
            probes:
              liveness:
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /healthz
                    port: 8081
              readiness:
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /readyz
                    port: 8081
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: { drop: ["ALL"] }
    service:
      web-app:
        controller: web-app
        ports:
          http:
            port: 80
            targetPort: 5000
      controller:
        controller: controller
        ports:
          http:
            port: 8080
```

### pipelines (multi-controller)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: pipelines
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
  interval: 1h
  values:
    controllers:
      api-server:
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-api-server
              tag: 2.15.0
            env:
              DBCONFIG_DRIVER: mysql
              DBCONFIG_HOST:
                valueFrom:
                  secretKeyRef:
                    name: pipelines-secret
                    key: MYSQL_HOST
              # ... additional env vars
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: { drop: ["ALL"] }
      ui:
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-frontend
              tag: 2.15.0
            env:
              VIEWER_TENSORBOARD_POD_TEMPLATE_SPEC_PATH: /etc/config/viewer-pod-template.json
              DEPLOYMENT: KUBEFLOW
              ARTIFACTS_SERVICE_PROXY_NAME: ml-pipeline
              ARTIFACTS_SERVICE_PROXY_PORT: "8888"
              ARTIFACTS_SERVICE_PROXY_ENABLED: "true"
              ENABLE_AUTHZ: "true"
              KUBEFLOW_USERID_HEADER: kubeflow-userid
      persistence-agent:
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-persistence-agent
              tag: 2.15.0
      scheduled-workflow:
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-scheduledworkflow
              tag: 2.15.0
      cache-server:
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-cache-server
              tag: 2.15.0
      metadata-grpc:
        containers:
          app:
            image:
              repository: ghcr.io/kubeflow/kfp-metadata-grpc
              tag: 2.15.0
    service:
      api-server:
        controller: api-server
        ports:
          http:
            port: 8888
          grpc:
            port: 8887
      ui:
        controller: ui
        ports:
          http:
            port: 80
            targetPort: 3000
      # ... additional services
```

### KServe (official Helm)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kserve
spec:
  chart:
    spec:
      chart: kserve
      version: 0.15.2
      sourceRef:
        kind: HelmRepository
        name: kserve
  interval: 1h
  values:
    kserve:
      controller:
        gateway:
          ingressGateway: kourier  # or envoy
```

### Trainer v2 (official Helm)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: trainer
spec:
  chart:
    spec:
      chart: kubeflow-trainer
      version: 2.1.0
      sourceRef:
        kind: OCIRepository
        name: kubeflow-trainer
  interval: 1h
  install:
    crds: CreateReplace
  upgrade:
    crds: CreateReplace
```

## Database Configuration

Continue using existing PXC cluster for MySQL-dependent components:
- Pipelines (kfp_pipelines, kfp_cache, kfp_metadata)
- Katib (katib)
- Model Registry (model_registry)

Connection via `pxc-cluster-haproxy.storage.svc.cluster.local:3306`.

## Migration Phases

### Phase 1: Auth + Dashboard
1. Create Authentik OAuth2 provider for Kubeflow
2. Store client secret in 1Password
3. Deploy `kubeflow/auth/` (HTTPRoute + SecurityPolicy)
4. Deploy `kubeflow/dashboard/` via app-template
5. Verify login flow works

### Phase 2: Simple UIs
1. Deploy profiles
2. Deploy notebooks (web-app + controller)
3. Deploy volumes-web-app
4. Deploy tensorboards (web-app + controller)
5. Deploy admission-webhook

### Phase 3: Helm Charts
1. Deploy KServe via official Helm chart
2. Deploy Trainer v2 via official Helm chart
3. Deploy Spark Operator via official Helm chart

### Phase 4: Complex Components
1. Deploy Katib (3 containers)
2. Deploy Model Registry (2 containers)
3. Deploy Pipelines (8+ containers)

### Phase 5: Cleanup
1. Remove `kubernetes/apps/istio-system/`
2. Remove `kubernetes/apps/kubeflow/oauth2-proxy/`
3. Remove `kubernetes/apps/kubeflow/dex/`
4. Remove `third_party/kubeflow/manifests/`
5. Update AGENTS.md to remove Istio references

## CRDs

Components with CRDs need separate Kustomizations with `wait: true`:

- **notebooks**: Notebook CRD
- **pipelines**: Pipeline, PipelineVersion CRDs
- **katib**: Experiment, Trial, Suggestion CRDs
- **kserve**: InferenceService, etc. (handled by Helm)
- **trainer**: TrainJob CRD (handled by Helm)
- **profiles**: Profile CRD

Pattern:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: notebooks-crds
spec:
  path: ./kubernetes/apps/kubeflow/notebooks/crds
  prune: false
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: notebooks
spec:
  dependsOn:
    - name: notebooks-crds
  path: ./kubernetes/apps/kubeflow/notebooks/app
```

## Renovate Configuration

With app-template HelmReleases, Renovate automatically tracks:
- Image tags in `image.repository` + `image.tag` fields
- Helm chart versions in OCIRepository `ref.tag`
- Official Helm chart versions

No additional Renovate configuration needed beyond existing setup.

## Rollback Plan

If migration fails:
1. Git revert the changes
2. Re-apply old manifests
3. Istio and oauth2-proxy/dex will be restored

Since current Kubeflow is non-functional, rollback is low priority.

## Open Questions

1. **KServe ingress**: Use Kourier or configure for Envoy Gateway?
2. **Ray integration**: Keep or defer to later?
3. **Training Operator v1**: Keep for existing jobs or remove entirely?
4. **Knative**: Required for KServe - deploy separately or use KServe's bundled version?

## References

- [Kubeflow 1.11 Release Notes](https://www.kubeflow.org/docs/kubeflow-platform/releases/kubeflow-1.11/)
- [Envoy Gateway OIDC](https://gateway.envoyproxy.io/docs/tasks/security/oidc/)
- [app-template docs](https://bjw-s.github.io/helm-charts/docs/app-template/)
- [KServe Helm Charts](https://github.com/kserve/kserve/tree/master/charts)
- [Kubeflow Trainer Helm](https://github.com/kubeflow/trainer/tree/master/manifests/charts)
