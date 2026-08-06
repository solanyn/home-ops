<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" align="center" width="144px" height="144px"/>

### <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="16" height="16"> My Home Operations Repository <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f6a7/512.gif" alt="🚧" width="16" height="16">

_... managed with Flux, Renovate, and GitHub Actions_ <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="16" height="16">

</div>

<div align="center">

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;

</div>

<div align="center">

[![Home-Internet](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fconnectivity_cloudflare%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=ubiquiti&logoColor=white&label=Home%20Internet)](https://status.goyangi.io)&nbsp;&nbsp;
[![Status-Page](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fexternal_echo%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=statuspage&logoColor=white&label=Status%20Page)](https://status.goyangi.io)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fmonitoring_alertmanager%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=prometheus&logoColor=white&label=Alertmanager)](https://status.goyangi.io)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo)

</div>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a1/512.gif" alt="💡" width="20" height="20"> Overview

This is a mono repository for my home infrastructure and Kubernetes cluster. Everything runs on a three-node Talos Linux cluster at home, deployed through GitOps with FluxCD and configured as infrastructure as code with OpenTofu.

There is a template at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) if you want to follow along with some of the practices used here.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f331/512.gif" alt="🌱" width="20" height="20"> Platform Capabilities

### Networking

Dual-stack IPv4/IPv6 networking with BGP-based load balancing and Kubernetes Gateway API:

- [cilium](https://github.com/cilium/cilium) as the CNI with eBPF-based network policies, BGP peering and L2/L3 load balancing
- [envoy](https://github.com/envoyproxy/envoy) gateway with Kubernetes Gateway API for north-south traffic management
- [multus](https://github.com/k8snetworkplumbingwg/multus-cni) for cross-VLAN pod networking
- [external-dns](https://github.com/kubernetes-sigs/external-dns) for automated split-horizon DNS across Cloudflare and UniFi
- [spegel](https://github.com/spegel-org/spegel) for peer-to-peer OCI image distribution
- [tailscale](https://github.com/tailscale/tailscale) for remote access and cluster mesh

### Security & Identity

Zero-trust security model with policy enforcement and centralised identity:

- [pocket-id](https://github.com/pocket-id/pocket-id) as the OIDC provider with passkey-based SSO (no passwords)
- [external-secrets](https://github.com/external-secrets/external-secrets) with [1Password Connect](https://github.com/1Password/connect) for secret injection
- [cert-manager](https://github.com/cert-manager/cert-manager) for automated TLS certificate lifecycle

### Observability

Full-stack monitoring with unified metrics, logs and tracing:

- [victoria-metrics](https://github.com/VictoriaMetrics/VictoriaMetrics) for metrics collection, storage and alerting (replaced Prometheus + Thanos — ~7x less memory, 90d local retention)
- [victoria-logs](https://github.com/VictoriaMetrics/VictoriaMetrics) for log aggregation and storage
- [grafana](https://github.com/grafana/grafana) for dashboarding across metrics, logs and traces
- [gatus](https://github.com/TwiN/gatus) for endpoint health monitoring and status pages
- [blackbox-exporter](https://github.com/prometheus/blackbox_exporter), [smartctl-exporter](https://github.com/prometheus-community/smartctl_exporter) and [unpoller](https://github.com/unpoller/unpoller) for infrastructure probing
- [silence-operator](https://github.com/giantswarm/silence-operator) and [kromgo](https://github.com/kashalls/kromgo) for alert management and badge generation

### Storage & Databases

Distributed and local storage with operator-managed databases:

- [miroir](https://github.com/home-operations/miroir) for distributed block storage with DRBD replication
- [kopiur](https://github.com/home-operations/kopiur) for encrypted backup orchestration with kopia
- [cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg) for production PostgreSQL with automated backups and failover
- [dragonfly](https://github.com/dragonflydb/dragonfly) as a high-performance Redis-compatible in-memory store
- [garage](https://github.com/deuxfleurs-org/garage) for S3-compatible distributed object storage (backups, Thanos, CNPG WAL archival)
- [mariadb](https://github.com/mariadb-operator/mariadb-operator) operator for MySQL-compatible workloads
- [influxdb](https://github.com/influxdata/influxdb) for time-series data and IoT metrics
- [vernemq](https://github.com/vernemq/vernemq) as an MQTT broker for IoT device communication

### Infrastructure Provisioning & GitOps

Declarative cluster management with dependency-aware deployments:

- [flux](https://github.com/fluxcd/flux2) for Git-based state reconciliation with drift detection and self-healing
- [tofu-controller](https://github.com/flux-iac/tofu-controller) for OpenTofu infrastructure as code (UniFi networking)
- [renovate](https://github.com/renovatebot/renovate) for automated dependency updates across the entire repository
- [actions-runner-controller](https://github.com/actions/actions-runner-controller) for self-hosted CI/CD runners
- [konflate](https://github.com/solanyn/konflate) for rendering Kubernetes manifests on pull requests

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f5c2_fe0f/512.gif" alt="🗂" width="20" height="20"> Repository Structure

```sh
📁 kubernetes
├── 📁 apps           # applications across namespaces
├── 📁 components     # reusable Kustomize components (alerts)
└── 📁 flux           # Flux system configuration
📁 opentofu           # OpenTofu infrastructure as code
📁 talos              # Talos Linux node configuration (Jinja2 templates)
📁 bootstrap          # cluster bootstrapping resources
```

### Dependency Management

Applications deploy in dependency order based on infrastructure requirements, preventing race conditions.

```mermaid
graph TD
    A[Kustomization: miroir] -->|Creates| B[HelmRelease: miroir]
    A[Kustomization: miroir] -->|Creates| C[HelmRelease: miroir-config]
    C[HelmRelease: miroir-config] -->|Depends on| B[HelmRelease: miroir]
    D[Kustomization: atuin] -->|Creates| E(HelmRelease: atuin)
    E[HelmRelease: atuin] -->|Depends on| C[HelmRelease: miroir-config]
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
- Dynamic DNS updates for public IP tracking via cloudflare-ddns
- Traffic segmentation through gateway-based routing (`envoy-internal`/`envoy-external`)
- Zero-touch operations with automatic record lifecycle management

This pattern enables secure service exposure whilst maintaining internal network isolation.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙" width="20" height="20"> Hardware

| Device              | OS Disk             | Data Disk             | Memory | OS            | Function            |
| ------------------- | ------------------- | --------------------- | ------ | ------------- | ------------------- |
| Dell Optiplex 7050  | Samsung PM863 960GB | Micron 7450 Pro 960GB | 32GB   | Talos         | Kubernetes          |
| Dell Optiplex 7060  | Samsung PM863 960GB | Micron 7450 Pro 960GB | 32GB   | Talos         | Kubernetes          |
| Dell Optiplex 7060  | Samsung PM863 960GB | Micron 7450 Pro 960GB | 32GB   | Talos         | Kubernetes          |
| NAS (Repurposed PC) | 512GB               | 1x12TB ZFS            | 16GB   | TrueNAS SCALE | NFS + Backup Server |
| UniFi UCG Ultra     | -                   | -                     | -      | -             | Router              |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20"> Gratitude and Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you could deploy.
