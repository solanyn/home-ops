# MCP Server Deployment Patterns

## Structure

```
apps/<namespace>/<mcp-name>/
├── app/
│   ├── kustomization.yaml       # Always present
│   ├── ocirepository.yaml       # Always present (bjw-s app-template OCI)
│   ├── helmrelease.yaml         # Always present
│   └── externalsecret.yaml      # Only if secrets needed
├── ks.yaml                      # Flux Kustomization
```

## OCIRepository (bjw-s app-template)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
    name: <mcp-name>
spec:
    interval: 15m
    layerSelector:
        mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
        operation: copy
    ref:
        tag: 5.0.1
    url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

## HelmRelease Patterns

### App-template (duckdb-mcp, grafana-mcp)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: <mcp-name>
spec:
    chartRef:
        kind: OCIRepository
        name: <mcp-name>
    interval: 1h
    values:
        controllers:
            <controller-name>:
                annotations:
                    reloader.stakater.com/auto: "true"
                containers:
                    app:
                        image:
                            repository: <image>
                            tag: <tag>
                        command: [...]       # optional
                        args: [...]          # transport + CLI args
                        env:
                            VAR: value
                        envFrom:
                            - secretRef:
                                  name: <mcp-name>-secret
                        resources:
                            requests:
                                cpu: 10m
                                memory: 64Mi
                            limits:
                                memory: 256Mi
                        securityContext:
                            allowPrivilegeEscalation: false
                            capabilities: { drop: ["ALL"] }
        defaultPodOptions:
            securityContext:
                runAsNonRoot: true
                runAsUser: 1000
                runAsGroup: 1000
                seccompProfile: { type: RuntimeDefault }
        service:
            app:
                controller: <controller-name>  # only if name != controller name
                ports:
                    http:
                        port: <mcp-port>
```

### Upstream chart (flux-operator-mcp)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: flux-operator-mcp
spec:
    chartRef:
        kind: OCIRepository
        name: flux-operator-mcp
    interval: 1h
    values:
        transport: http
        readonly: false
        extraArgs:
            - --mask-secrets=true
        networkPolicy:
            create: false
```

## Container Images

| MCP Server | Image | Command/Args |
|---|---|---|
| `grafana-mcp` | `grafana/mcp-grafana` | `-t streamable-http --address 0.0.0.0:8000` |
| `duckdb-mcp` | `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` | `uvx mcp-server-motherduck --transport sse` |
| `unifi-mcp` | `ghcr.io/sirkirby/unifi-network-mcp` | (default entrypoint, streamable-http on `0.0.0.0:3000`) |

## Transports

- **SSE**: Port 8080, `--transport sse` (duckdb-mcp pattern)
- **Streamable HTTP**: Port 8000, `-t streamable-http` (grafana-mcp pattern)

## Secrets

Use ExternalSecret with `ClusterSecretStore: onepassword-connect`, target name `<mcp-name>-secret`, and `envFrom` in the container spec.

## Exposure

MCP servers can be exposed via HTTPRoute through the envoy-internal gateway. Use the app-template `route:` field to generate an HTTPRoute:

```yaml
    route:
        app:
            hostnames:
                - mcp-name.goyangi.io
            parentRefs:
                - name: envoy-internal
                  namespace: network
```

Then add a remote MCP entry in OpenCode config:

```json
"mcp": {
    "mcp-name": {
        "type": "remote",
        "url": "https://mcp-name.goyangi.io"
    }
}
```
