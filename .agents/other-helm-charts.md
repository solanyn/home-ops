## Other Helm Charts

Pull in other helm charts like this:

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1beta2.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
    name: gha-runner-scale-set-controller
spec:
    interval: 5m
    layerSelector:
        mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
        operation: copy
    ref:
        tag: 0.12.1
    url: oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: &name actions-runner-controller
spec:
    interval: 1h
    chartRef:
        kind: OCIRepository
        name: gha-runner-scale-set-controller
    install:
        remediation:
            retries: -1
    upgrade:
        cleanupOnFail: true
        remediation:
            strategy: rollback
            retries: 3
    values:
        fullnameOverride: *name
        replicaCount: 1
    postRenderers:
        - kustomize:
              patches:
                  - target:
                        kind: Deployment
                    patch: |
                        - op: replace
                          path: /spec/template/metadata/labels/app.kubernetes.io~1version
                          value: 0.10.1
```

Prefer using the `home-operations` organisation Helm charts. If not available use an official Helm chart provider. Do not deploy any Bitnami Helm charts.

Prefer OCIRepository if available otherwise specify the HelmRepository instead. Here is an example:

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/helmrepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
    name: flink
    namespace: streaming
spec:
    interval: 12h
    url: https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.0/
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: flink
spec:
    interval: 1h
    chart:
        spec:
            chart: flink-kubernetes-operator
            version: 1.12.0
            sourceRef:
                kind: HelmRepository
                name: flink
                namespace: streaming
    install:
        remediation:
            retries: -1
    upgrade:
        cleanupOnFail: true
        remediation:
            strategy: rollback
            retries: 3
    values:
        fullnameOverride: flink
```
