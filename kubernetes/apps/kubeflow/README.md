# Kubeflow Applications

Resource mapping for Kubeflow applications deployed via Flux Kustomizations.

## Resource Ownership

Each kustomization deploys its complete application stack (Deployment, Service, VirtualService).

| Kustomization | Deployments | Services | VirtualServices | Notes |
|---------------|-------------|----------|-----------------|-------|
| `dex` | dex | dex | dex | Auth provider, patched to fix service namespace |
| `oauth2-proxy` | oauth2-proxy, cluster-jwks-proxy | oauth2-proxy | oauth2-proxy | Auth proxy, patched to fix service namespace |
| `kubeflow-centraldashboard` | centraldashboard | centraldashboard | centraldashboard | Main UI |
| `kubeflow-notebooks` | jupyter-web-app-deployment, notebook-controller-deployment | jupyter-web-app-service, notebook-controller-service | jupyter-web-app-jupyter-web-app | Notebook management |
| `kubeflow-pipelines` | cache-server, kubeflow-pipelines-profile-controller, metadata-envoy-deployment, ml-pipeline, ml-pipeline-persistenceagent, ml-pipeline-scheduledworkflow, ml-pipeline-ui, ml-pipeline-viewer-crd, ml-pipeline-visualizationserver | Multiple pipeline services | metadata-grpc, ml-pipeline-ui | Pipeline orchestration |
| `kubeflow-katib` | katib-controller, katib-db-manager, katib-ui | katib-controller, katib-db-manager, katib-ui | katib-ui | Hyperparameter tuning |
| `kubeflow-kserve` | kserve-controller-manager, kserve-localmodel-controller-manager, kserve-models-web-app | kserve-controller-manager-metrics-service, kserve-controller-manager-service, kserve-models-web-app, kserve-webhook-server-service | kserve-models-web-app | Model serving |
| `kubeflow-model-registry` | model-registry-deployment, model-registry-ui | model-registry-service, model-registry-ui-service | model-registry, model-registry-ui | Model registry |
| `kubeflow-profiles` | profiles-deployment | profiles-kfam | profiles-kfam | Multi-tenancy |
| `kubeflow-tensorboards` | tensorboards-web-app-deployment, tensorboard-controller-controller-manager | tensorboards-web-app-service, tensorboard-controller-controller-manager-metrics-service | tensorboards-web-app-tensorboards-web-app | TensorBoard management |
| `kubeflow-volumes` | volumes-web-app-deployment | volumes-web-app-service | volumes-web-app-volumes-web-app | PVC management |
| `kubeflow-admission-webhook` | admission-webhook-deployment | admission-webhook-service | - | Admission control |
| `kubeflow-training-operator` | training-operator | training-operator | - | Distributed training |

## Istio Resources

Istio routing and security resources are managed separately:

### Gateway Resources (`istio-system/kubeflow-gateway`)
- Gateway: `kubeflow-gateway` (in kubeflow namespace)
- AuthorizationPolicies: `istio-ingressgateway`, `global-deny-all`, `istio-ingressgateway-oauth2-proxy`, `istio-ingressgateway-require-jwt`
- RequestAuthentication: `dex-jwt`, `m2m-token-issuer`
- ClusterRoles: `kubeflow-istio-admin`, `kubeflow-istio-edit`, `kubeflow-istio-view`

All resources reference upstream manifests from `third_party/kubeflow/manifests`.

## Known Patches

- **dex VirtualService**: Destination host patched from `dex.auth.svc.cluster.local` to `dex.kubeflow.svc.cluster.local`
- **oauth2-proxy VirtualService**: Destination host patched from `oauth2-proxy.oauth2-proxy.svc.cluster.local` to `oauth2-proxy.kubeflow.svc.cluster.local`

## Upstream Source

All applications use overlays from `third_party/kubeflow/manifests` with local patches for:
- ExternalSecrets integration (1Password)
- Reloader annotations
- Service namespace corrections
- Environment-specific configuration
