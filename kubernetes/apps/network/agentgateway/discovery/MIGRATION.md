# agentgateway-discovery migration plan

## Current state
- `kubernetes/apps/network/agentgateway/discovery/` runs a cronjob (`*/15 * * * *`) that fetches `/v1/models` from mlx/minimax/deepseek and writes the merged JSON to configmap `agentgateway-models`
- `kubernetes/apps/network/agentgateway/models/` runs a busybox httpd deployment that serves that configmap at `/v1/models`
- HTTPRoute in `models/httproute.yaml` routes `/v1/models` → `agentgateway-models` service

## Target state
- New Go service `ghcr.io/solanyn/agentgateway-discovery` (in `~/git/mono/agentgateway-discovery/`) that does on-demand aggregation
- `kubernetes/apps/network/agentgateway/discovery/` becomes a deployment (not cronjob) running the new image
- `kubernetes/apps/network/agentgateway/models/` deletion candidates (configmap, deployment, service, backend, httproute) once the new app owns `/v1/models`

## Steps

### 1. Build the Go service (separate session/repo)
Spec: see handoff doc (build a Go service per the cronprint template at `~/git/mono/cronprint/`)
- `~/git/mono/agentgateway-discovery/`
- Image: `ghcr.io/solanyn/agentgateway-discovery:latest` (push via `bazel run //agentgateway-discovery:push`)
- Endpoints: `GET /v1/models` (aggregated), `GET /health`
- 30s in-memory cache, 10s upstream timeout, parallel fetch

### 2. Update k8s helmrelease (this repo)
Replace `kubernetes/apps/network/agentgateway/discovery/app/helmrelease.yaml` with:
```yaml
controllers:
    discovery:
        type: deployment
        replicas: 1
        containers:
            app:
                image:
                    repository: ghcr.io/solanyn/agentgateway-discovery
                    tag: latest@sha256:<digest>  # pin digest
                env:
                    PORT: "8080"
                envFrom:
                    - secretRef: { name: minimax-auth }
                    - secretRef: { name: deepseek-auth }
                # ...probes, resources, security context...
service:
    discovery:
        controller: discovery
        ports:
            http:
                port: 8080
```
Remove the cronjob fields, persistence mount, and the `agentgateway-models` SA reference.

### 3. Add a HTTPRoute for the new service
New file `kubernetes/apps/network/agentgateway/discovery/app/httproute.yaml`:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
    name: discovery
spec:
    parentRefs:
        - name: ai
          namespace: network
    rules:
        - matches:
            - path:
                type: Exact
                value: /v1/models
          backendRefs:
            - name: agentgateway-discovery
              group: agentgateway.dev
              kind: AgentgatewayBackend
```
And add `httproute.yaml` to `discovery/app/kustomization.yaml` resources.

Wait — that requires an AgentgatewayBackend for the new service too. Or we can route directly to the Service without a backend. Let me reconsider.

### 4. Delete the now-redundant `models/` app
Once `/v1/models` is served by `agentgateway-discovery`:
- `models/deployment.yaml` — DELETE (busybox httpd no longer needed)
- `models/service.yaml` — DELETE
- `models/configmap.yaml` — DELETE (cronjob no longer writes here)
- `models/backend.yaml` — DELETE
- `models/httproute.yaml` — DELETE (replaced by new one)
- `models/policy.yaml` — KEEP (gateway-level policy)
- `models/rbac.yaml` — DELETE (SA no longer needed by anything)

### 5. Update Flux dependencies
- `discovery/ks.yaml` currently dependsOn `agentgateway-models`. Once we delete the models kustomization, update this dependency to depend on the gateway/llm apps instead.

## Open questions
- Should `/v1/models` route through AgentGateway (using AgentgatewayBackend) or directly to a Service? Direct Service is simpler but loses gateway features (auth, observability). Going through gateway keeps consistency with everything else.
- Image tag strategy: `:latest` is fine for now, can add Renovate later.

## Verification
After cutover:
```bash
curl https://gateway.goyangi.io/v1/models -H "Authorization: Bearer $API_KEY" | jq '.data | length'
# Should return ~12 models (same as current)
```