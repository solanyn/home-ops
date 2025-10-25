<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" align="center" width="144px" height="144px"/>

### <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="16" height="16"> My Home Operations Repository <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f6a7/512.gif" alt="🚧" width="16" height="16">

_... managed with Flux, Renovate, and GitHub Actions_ <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="16" height="16">

</div>

<div align="center">

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;

[![Renovate](https://img.shields.io/github/actions/workflow/status/solanyn/home-ops/renovate.yaml?branch=main&label=&logo=renovatebot&style=for-the-badge&color=blue)](https://github.com/solanyn/home-ops/actions/workflows/renovate.yaml)

</div>

<div align="center">

[![Home-Internet](https://img.shields.io/uptimerobot/status/m793494864-dfc695db066960233ac70f45?color=brightgreeen&label=Home%20Internet&style=for-the-badge&logo=ubiquiti&logoColor=white)](https://status.goyangi.io)&nbsp;&nbsp;
[![Status-Page](https://img.shields.io/uptimerobot/status/m793599155-ba1b18e51c9f8653acd0f5c1?color=brightgreeen&label=Status%20Page&style=for-the-badge&logo=statuspage&logoColor=white)](https://status.goyangi.io)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/uptimerobot/status/m793494864-dfc695db066960233ac70f45?color=brightgreeen&label=Alertmanager&style=for-the-badge&logo=prometheus&logoColor=white)](https://status.goyangi.io)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Power-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_power_usage&style=flat-square&label=Power)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo)

</div>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a1/512.gif" alt="💡" width="20" height="20"> Overview

This repository shows a production Kubernetes cluster running on bare metal with ML/MLOps tooling, data engineering platforms and automated operations.

- Infrastructure as Code (IaC) with declarative configuration management
- GitOps deployment workflows with automated reconciliation
- Modern security with encrypted secrets and zero-trust networking
- Production observability with comprehensive monitoring and alerting
- Automated operations including dependency management and backup orchestration

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f331/512.gif" alt="🌱" width="20" height="20"> Architecture

The cluster runs on [Talos Linux](https://www.talos.dev), a security-hardened operating system designed for Kubernetes:

- Bare metal deployment with immutable infrastructure
- Semi-hyper-converged architecture combining compute and storage resources
- Distributed storage using Rook-Ceph for persistent volumes
- Networking with Cilium CNI, BGP load balancing and Kubernetes Gateway API
- AI gateway integration with Envoy proxy for model routing
- GitOps automation with FluxCD and dependency management

There is a template at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) if you want to follow along with some of the practices used here.

### ML/MLOps Platform

- [kubeflow](https://github.com/kubeflow/kubeflow): Complete ML platform with pipelines, notebooks, model serving and experiment tracking
- [kserve](https://github.com/kserve/kserve): Production model serving with autoscaling, multi-framework support and Envoy AI Gateway integration
- [ray](https://github.com/ray-project/ray): Distributed computing for ML workloads and hyperparameter tuning
- [feast](https://github.com/feast-dev/feast): Feature store for ML feature management and serving
- [label-studio](https://github.com/heartexlabs/label-studio): Data annotation platform for ML dataset preparation
- [mlflow](https://github.com/mlflow/mlflow): MLOps platform for experiment tracking, model registry and deployment
- [katib](https://github.com/kubeflow/katib): Hyperparameter tuning and neural architecture search

### Analytics & Data Engineering

- [spark](https://github.com/apache/spark): Big data processing engine for large-scale analytics
- [dask](https://github.com/dask/dask): Parallel computing library for scalable data science
- [trino](https://github.com/trinodb/trino): Distributed SQL engine for analytics across data sources
- [kafka](https://github.com/apache/kafka): Event streaming platform for real-time data processing
- [flink](https://github.com/apache/flink): Stream processing for real-time analytics and ML inference
- [lakekeeper](https://github.com/lakekeeper/lakekeeper): Apache Iceberg REST catalog for data lakehouse operations

### Infrastructure Components

- [envoy](https://github.com/envoyproxy/envoy): API gateway with Kubernetes Gateway API implementation and AI model routing
- [istio](https://github.com/istio/istio): Service mesh for traffic management, security and observability
- [knative](https://github.com/knative/serving): Serverless workload deployment with scale-to-zero capabilities
- [rook-ceph](https://github.com/rook/rook): Cloud-native distributed storage with Ceph orchestration
- [openebs](https://github.com/openebs/openebs): Container-native storage with local PV provisioning
- [volsync](https://github.com/backube/volsync): Automated backup orchestration with cross-cluster replication
- [kopia](https://github.com/kopia/kopia): Fast and secure backup/restore with encryption and deduplication
- [spegel](https://github.com/spegel-org/spegel): Performance optimisation with distributed OCI registry mirror
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Multi-zone DNS automation with split-horizon configuration

### Security & Compliance

- [cert-manager](https://github.com/cert-manager/cert-manager): Automated TLS certificate lifecycle management
- [external-secrets](https://github.com/external-secrets/external-secrets): Centralised secret management with [1Password Connect](https://github.com/1Password/connect) integration
- [sops](https://github.com/getsops/sops): Git-committed encrypted secrets for declarative secret management
- [cilium](https://github.com/cilium/cilium): Zero-trust networking with eBPF-based security policies
- [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy): Authentication proxy for securing applications with SSO
- [dex](https://github.com/dexidp/dex): Identity provider with OIDC and OAuth2 support
- [kyverno](https://github.com/kyverno/kyverno): Policy management for security and governance enforcement

### DevOps & Development Infrastructure

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): Self-hosted CI/CD runners for secure pipeline execution
- [cloudflared](https://github.com/cloudflare/cloudflared): Zero-trust access tunnels for secure ingress
- [headlamp](https://github.com/headlamp-k8s/headlamp): User-friendly Kubernetes web UI for cluster management
- [keda](https://github.com/kedacore/keda): Event-driven autoscaling for Kubernetes workloads

### Data Storage & Databases

- [cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg): PostgreSQL operator for production database workloads
- [percona-xtradb-cluster](https://github.com/percona/percona-xtradb-cluster-operator): Highly available MySQL cluster with synchronous replication
- [dragonfly](https://github.com/dragonflydb/dragonfly): High-performance in-memory data store compatible with Redis and Memcached
- [minio](https://github.com/minio/minio): S3-compatible object storage for unstructured data

### Observability & Monitoring

- [prometheus](https://github.com/prometheus/prometheus): Metrics collection and alerting via kube-prometheus-stack
- [grafana](https://github.com/grafana/grafana): Visualisation and dashboarding for metrics and logs
- [victoria-logs](https://github.com/VictoriaMetrics/VictoriaMetrics): High-performance log aggregation and search
- [fluent-bit](https://github.com/fluent/fluent-bit): Lightweight log forwarding and processing
- [gatus](https://github.com/TwiN/gatus): Health monitoring and status page generation
- [blackbox-exporter](https://github.com/prometheus/blackbox_exporter): External endpoint monitoring and probing
- [kromgo](https://github.com/kashalls/kromgo): Prometheus metrics to badge service for status displays

### GitOps Implementation

[Flux](https://github.com/fluxcd/flux2) provides declarative cluster management through Git-based state reconciliation:

- Hierarchical resource organisation with dependency-aware deployment ordering
- Multi-tenant namespace isolation with RBAC boundary enforcement
- Automated reconciliation with drift detection and self-healing capabilities
- Release management through Git-based promotion workflows

[Renovate](https://github.com/renovatebot/renovate) provides automated dependency management across the entire repository, creating pull requests for updates and enabling continuous security patching when changes are merged.

### Directories

This Git repository contains the following directories under [Kubernetes](./kubernetes/).

```sh
📁 kubernetes
├── 📁 apps           # applications
├── 📁 components     # commonly reused components e.g., status monitoring templates + volsync backed pvc
└── 📁 flux           # flux system configuration
```

### Dependency Management

Applications deploy in dependency order based on infrastructure requirements, preventing race conditions.

```mermaid
graph TD
    A>Kustomization: rook-ceph] -->|Creates| B[HelmRelease: rook-ceph]
    A>Kustomization: rook-ceph] -->|Creates| C[HelmRelease: rook-ceph-cluster]
    C>HelmRelease: rook-ceph-cluster] -->|Depends on| B>HelmRelease: rook-ceph]
    D>Kustomization: atuin] -->|Creates| E(HelmRelease: atuin)
    E>HelmRelease: atuin] -->|Depends on| C>HelmRelease: rook-ceph-cluster]
```

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f636_200d_1f32b_fe0f/512.gif" alt="😶" width="20" height="20"> Hybrid Cloud Strategy

The setup maximises self-hosted infrastructure whilst using cloud services where appropriate.

| Service                                     | Use                                                               | Cost (AUD)    |
| ------------------------------------------- | ----------------------------------------------------------------- | ------------- |
| [1Password](https://1password.com/)         | Secrets with [External Secrets](https://external-secrets.io/)     | ~$50/yr       |
| [Cloudflare](https://www.cloudflare.com/)   | Domains and S3                                                    | ~$30/yr       |
| [GitHub](https://github.com/)               | Hosting this repository and continuous integration/deployments    | Free          |
| [Pushover](https://pushover.net/)           | Kubernetes Alerts and application notifications                   | $5 OTP        |
| [healthchecks.io](https://healthchecks.io/) | Monitoring internet connectivity and external facing applications | Free          |
|                                             |                                                                   | Total: ~$7/mo |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30e/512.gif" alt="🌎" width="20" height="20"> DNS Architecture

The cluster implements automated split-horizon DNS across multiple zones:

- Internal zone management via UniFi controller integration using webhook providers
- Public DNS automation with Cloudflare API integration
- Traffic segmentation through ingress class-based routing (`internal`/`external`)
- Zero-touch operations with automatic record lifecycle management

This pattern enables secure service exposure whilst maintaining internal network isolation.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙" width="20" height="20"> Hardware

| Device              | OS Disk             | Data Disk           | Memory | OS            | Function            |
| ------------------- | ------------------- | ------------------- | ------ | ------------- | ------------------- |
| Dell Optiplex 7050  | Samsung PM991 256GB | Samsung PM863 960GB | 32GB   | Talos         | Kubernetes          |
| Dell Optiplex 7060  | Samsung PM991 256GB | Samsung PM863 960GB | 32GB   | Talos         | Kubernetes          |
| Dell Optiplex 7060  | Samsung PM991 256GB | Samsung PM863 960GB | 32GB   | Talos         | Kubernetes          |
| NAS (Repurposed PC) | 512GB               | 1x12TB ZFS          | 16GB   | TrueNAS SCALE | NFS + Backup Server |
| UniFi UCG Ultra     | -                   | -                   | -      | -             | Router              |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20"> Gratitude and Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you could deploy.
