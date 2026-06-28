# Nodepool Autoscaler Controller — PRD

## Overview

A Kubernetes controller that automatically scales a Crossplane-managed GCP nodepool by patching the `spec.targetSize` field on an `XComputeNodePool` custom resource. Crossplane then reconciles the underlying GCP Managed Instance Group.

The controller watches for pods that are pending due to nodepool scheduling constraints and scales up. It scales back to zero after an idle timeout.

## Problem

The `XComputeNodePool` CR currently requires manual `targetSize` changes committed to git. NativeLink RBE workers run on the nodepool and are only needed during active builds. We need automatic scale-up on demand and scale-down when idle, without requiring git commits or human intervention.

## Architecture

```
Pending Pod (nodepool toleration)
        │
        ▼
┌─────────────────────┐
│ nodepool-autoscaler  │  (controller in-cluster)
│                      │
│ 1. Watch pending pods│
│ 2. Patch CR targetSize
│ 3. Watch idle timeout│
└─────────┬───────────┘
          │ PATCH spec.targetSize
          ▼
┌─────────────────────┐
│ XComputeNodePool CR  │  (home-ops.io/v1alpha1)
└─────────┬───────────┘
          │ Crossplane reconciles
          ▼
┌─────────────────────┐
│ GCP MIG (0-8 nodes) │
└─────────────────────┘
```

## Target CRD

```yaml
apiVersion: home-ops.io/v1alpha1
kind: XComputeNodePool
metadata:
    name: nodepool
spec:
    targetSize: 0 # Controller patches this field (0-8)
    maxSize: 8 # Controller must never exceed this
    # ... other fields (region, machineType, etc.) are not touched
```

The controller only ever patches `spec.targetSize`. It does not own or modify any other field.

## Behaviour

### Scale Up

Trigger: One or more pods exist matching ALL of:

- `status.phase == Pending`
- `status.conditions` contains `PodScheduled=False` with reason `Unschedulable`
- Pod spec has toleration `nodepool=true:NoSchedule`
- Pod spec has `nodeSelector` with `node.kubernetes.io/nodepool: "true"`

Action:

1. Count pending pods matching criteria
2. Calculate desired nodes: `ceil(sum(pending pod CPU requests) / allocatable_cpu_per_node)` where `allocatable_cpu_per_node` is configurable (default: 7000m for e2-standard-8 minus system overhead)
3. Clamp to `[1, spec.maxSize]`
4. If `desired > current spec.targetSize`, PATCH `spec.targetSize = desired`

Debounce: Wait 10s after first pending pod detected before acting (configurable). This avoids thrashing if pods are being scheduled normally.

### Scale Down

Trigger: No pods matching the nodepool selector are in `Pending` state AND all running pods on nodepool nodes have been idle (no new pods scheduled) for the idle timeout duration.

Idle definition: No pods with `nodeSelector: node.kubernetes.io/nodepool: "true"` have been created or transitioned to `Running` within the idle window.

Action: PATCH `spec.targetSize = 0`

Idle timeout: 15 minutes (configurable). This gives time for sequential build actions that may have gaps between them.

### Leader Election

Use standard `client-go` leader election with a Lease in the controller's namespace. Only one replica should be active.

## Configuration

Environment variables or flags:

| Name                         | Default             | Description                           |
| ---------------------------- | ------------------- | ------------------------------------- |
| `NODEPOOL_NAME`              | `nodepool`          | Name of XComputeNodePool CR to manage |
| `NODEPOOL_NAMESPACE`         | `crossplane-system` | Namespace of the CR                   |
| `ALLOCATABLE_CPU_MILLICORES` | `7000`              | Usable CPU per node (millicores)      |
| `SCALE_UP_DEBOUNCE`          | `10s`               | Wait before scaling up                |
| `IDLE_TIMEOUT`               | `15m`               | Idle duration before scaling to zero  |
| `RECONCILE_INTERVAL`         | `30s`               | How often to re-evaluate state        |
| `MAX_SIZE`                   | `8`                 | Hard cap (also read from CR)          |

## RBAC

```yaml
rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["nodes"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["home-ops.io"]
      resources: ["xcomputenodepools"]
      verbs: ["get", "list", "watch", "patch"]
    - apiGroups: ["coordination.k8s.io"]
      resources: ["leases"]
      verbs: ["get", "create", "update"]
```

## Deployment Manifest

Deploy using the bjw-s app-template Helm chart in the home-ops repo. The controller runs on the **home cluster** (not the nodepool) so it's always available to scale up.

Expected deployment location: `kubernetes/apps/crossplane-system/nodepool-autoscaler/`

```yaml
# helmrelease.yaml (app-template pattern)
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: nodepool-autoscaler
spec:
    chartRef:
        kind: OCIRepository
        name: app-template
    interval: 10m
    values:
        controllers:
            app:
                annotations:
                    reloader.stakater.com/auto: "true"
                strategy: Recreate
                containers:
                    app:
                        image:
                            repository: ghcr.io/OWNER/nodepool-autoscaler
                            tag: VERSION
                        env:
                            NODEPOOL_NAME: nodepool
                            NODEPOOL_NAMESPACE: crossplane-system
                            ALLOCATABLE_CPU_MILLICORES: "7000"
                            IDLE_TIMEOUT: "15m"
                            SCALE_UP_DEBOUNCE: "10s"
                        resources:
                            requests:
                                cpu: 10m
                                memory: 64Mi
                            limits:
                                memory: 128Mi
                        probes:
                            liveness:
                                enabled: true
                                custom: true
                                spec:
                                    httpGet:
                                        path: /healthz
                                        port: 8080
                            readiness:
                                enabled: true
                                custom: true
                                spec:
                                    httpGet:
                                        path: /readyz
                                        port: 8080
        serviceAccount:
            create: true
            name: nodepool-autoscaler
```

## Observability

### Metrics (Prometheus, port 8080 at /metrics)

| Metric                                   | Type    | Description                               |
| ---------------------------------------- | ------- | ----------------------------------------- |
| `nodepool_autoscaler_target_size`        | Gauge   | Current targetSize the controller has set |
| `nodepool_autoscaler_pending_pods`       | Gauge   | Number of pending nodepool pods           |
| `nodepool_autoscaler_scale_up_total`     | Counter | Number of scale-up events                 |
| `nodepool_autoscaler_scale_down_total`   | Counter | Number of scale-down events               |
| `nodepool_autoscaler_last_scale_up_time` | Gauge   | Unix timestamp of last scale-up           |
| `nodepool_autoscaler_idle_seconds`       | Gauge   | Seconds since last pod activity           |

### Health Endpoints

- `GET /healthz` — liveness (process alive, leader election healthy)
- `GET /readyz` — readiness (can reach API server, CR exists)
- `GET /metrics` — Prometheus metrics

## Implementation

### Language

Go. Use `controller-runtime` (sigs.k8s.io/controller-runtime) for the reconciler pattern, client, and leader election.

### Project Structure

```
cmd/
  main.go                 # Entrypoint, flag parsing, manager setup
internal/
  controller/
    autoscaler.go         # Main reconcile loop
    autoscaler_test.go    # Unit tests with fake client
  nodepool/
    types.go              # XComputeNodePool unstructured helpers
    patch.go              # Patch logic
    patch_test.go         # Patch unit tests
  metrics/
    metrics.go            # Prometheus metric definitions
```

### Key Logic (autoscaler.go)

```go
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. List pending pods with nodepool toleration + nodeSelector
    // 2. If pending > 0 and debounce elapsed:
    //      - Calculate desired size from CPU requests
    //      - Clamp to maxSize
    //      - Patch XComputeNodePool if targetSize < desired
    // 3. If no pending pods and no recent activity:
    //      - Check idle timeout
    //      - If exceeded, patch targetSize = 0
    // 4. Requeue after RECONCILE_INTERVAL
    return ctrl.Result{RequeueAfter: r.reconcileInterval}, nil
}
```

The controller watches Pods (with a field selector or label filter for efficiency) and requeues on changes.

## Tests

### Unit Tests

1. **Scale-up calculation** — Given N pending pods with various CPU requests, assert correct `targetSize` is computed
2. **Clamping** — Assert targetSize never exceeds maxSize
3. **Debounce** — Assert no patch occurs within debounce window
4. **Scale-down idle** — Assert targetSize set to 0 after idle timeout with no pending pods
5. **No-op** — Assert no patch when targetSize already matches desired
6. **Pod filtering** — Assert only pods with correct toleration AND nodeSelector are counted

Use `controller-runtime`'s `envtest` or a fake client for unit tests.

### Integration Tests

1. **End-to-end with envtest** — Create fake XComputeNodePool CR, create pending pods, assert CR gets patched
2. **Scale-down timer** — Create running pods, delete them, wait idle timeout, assert targetSize = 0
3. **Rapid pod churn** — Create and delete pods rapidly, assert no thrashing (debounce works)

### Test Commands

```bash
go test ./...                          # Unit tests
go test ./internal/controller/ -v      # Controller tests verbose
go test -race ./...                    # Race detection
```

## Edge Cases

1. **Spot preemption** — Nodes disappear, pods go back to Pending. Controller should detect and maintain targetSize (not scale down then up again). The idle timer resets on new pending pods.
2. **CR not found** — Log error, requeue with backoff. Don't crash.
3. **Crossplane slow** — Nodes take 3-5 minutes to join. Controller should not keep incrementing targetSize while waiting. Use `spec.targetSize` as source of truth for "what we asked for", not node count.
4. **Multiple pending pods arrive simultaneously** — Single reconcile should handle all of them in one patch.
5. **Controller restart** — Stateless. Reads current CR state and pending pods on startup. No persistent state needed.

## Out of Scope

- Node draining or cordoning (Talos handles graceful shutdown)
- Per-pod scheduling decisions (kube-scheduler handles this)
- Cost budgets or spending limits
- Multi-pool support (single pool for now)
- Git commit of targetSize changes (controller patches live CR; git stays at 0)

## Acceptance Criteria

1. Pending pod with nodepool toleration triggers scale-up within debounce + reconcile interval (~40s)
2. targetSize never exceeds maxSize
3. Pool scales to 0 after idle timeout with no nodepool workloads
4. Controller uses <128Mi memory, <50m CPU steady state
5. All unit tests pass, integration tests pass with envtest
6. Prometheus metrics are exposed and scrapeable
7. Controller recovers gracefully from API server disconnection
