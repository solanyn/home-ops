---
name: add-app
description: Scaffold a new Flux-managed application in this home-ops repository
---

# Add New Application

Use this workflow when adding a new application under `kubernetes/apps/<namespace>/<app>`.

## Before editing

Collect or confirm:

1. Application name and namespace.
2. Container image and pinned tag or digest.
3. Helm chart source and pinned chart version.
4. Service port and whether an HTTPRoute is required.
5. OIDC, ExternalSecret, database, and persistence requirements.
6. Flux dependencies and any required CRDs.

Read one or two neighbouring applications in the same namespace before creating files. Follow the local namespace, route, probes, secret, and resource patterns.

## Required files

Create the application directory with:

- `ks.yaml`
- `app/kustomization.yaml`
- `app/helmrelease.yaml`
- `app/ocirepository.yaml`

Add only the resources the application needs, such as `oidc.yaml`, `externalsecret.yaml`, `httproute.yaml`, monitoring resources, or a Kopiur component reference.

## Flux Kustomization

Use the repository's flat app layout:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app>
spec:
  targetNamespace: <namespace>
  interval: 1h
  path: ./kubernetes/apps/<namespace>/<app>/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  wait: false
```

Add `dependsOn` only for real dependencies and always include the dependency namespace. Add the Kopiur component at the `ks.yaml` level for persistent applications.

Register the app in the namespace-level `kustomization.yaml` in alphabetical order.

## Helm and secrets

- Give every app its own `OCIRepository` in `app/ocirepository.yaml`.
- Make `spec.chartRef.name` match the OCIRepository name.
- Pin OCI charts by tag or version.
- Pin container images by digest when practical.
- Never put credentials in manifests.
- Use the existing Pocket ID CR pattern for OIDC clients.
- Use `ExternalSecret` with the `onepassword` ClusterSecretStore for 1Password-backed values.

## Validation

Before handing off:

1. Parse all changed YAML.
2. Run `git diff --check`.
3. Render the affected Flux Kustomization with the repository's configured Flate tooling when available.
4. Check the rendered RBAC, route, secret references, persistence, and workload resources.
5. Report any validation tool or live-cluster limitation explicitly.
