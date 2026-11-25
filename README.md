<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" align="center" width="144px" height="144px"/>

### <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="16" height="16"> My Home Operations Repository <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f6a7/512.gif" alt="🚧" width="16" height="16">

_... managed with Flux, Renovate, and GitHub Actions_ <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="16" height="16">

</div>

<div align="center">

[![Home-Internet](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fconnectivity_cloudflare%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=ubiquiti&logoColor=white&label=Home%20Internet)](https://status.goyangi.io)&nbsp;&nbsp;
[![Status-Page](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fexternal_echo%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=statuspage&logoColor=white&label=Status%20Page)](https://status.goyangi.io)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.goyangi.io%2Fapi%2Fv1%2Fendpoints%2Fmonitoring_alertmanager%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=prometheus&logoColor=white&label=Alertmanager)](https://status.goyangi.io)

</div>

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?label&logo=discord&logoColor=white&color=blue)](https://discord.gg/home-operations)&nbsp;&nbsp;
[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.goyangi.io%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;
![Renovate](https://img.shields.io/badge/enabled-blue?logo=renovate)

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

This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [OpenTofu](https://opentofu.org/), [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate), and [GitHub Actions](https://github.com/features/actions).

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f331/512.gif" alt="🌱" width="20" height="20"> Kubernetes

My Kubernetes cluster is deployed with [Talos](https://www.talos.dev). This is a semi-hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate server with ZFS for NFS shares, bulk file storage and backups.

There is a template over at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) if you want to try and follow along with some of the practices I use here.

### Core Components

- **Networking & Service Mesh**: [cilium](https://github.com/cilium/cilium) provides eBPF-based networking, BGP peering and load balancing, while [envoy](https://github.com/envoyproxy/envoy) powers north-south traffic management via the Kubernetes Gateway API. [multus](https://github.com/k8snetworkplumbingwg/multus-cni) enables cross-VLAN pod networking, and [external-dns](https://github.com/kubernetes-sigs/external-dns) keeps DNS records in sync automatically. External traffic reaches the cluster through [Towonel](https://codeberg.org/towonel/towonel), a self-hosted tunnel with an edge node on a VPS — no inbound port forwards, and the origin's TLS is passed through untouched.
- **Security & Secrets**: [cert-manager](https://github.com/cert-manager/cert-manager) automates SSL/TLS certificate management. [pocket-id](https://github.com/pocket-id/pocket-id) provides passkey-based SSO as my OIDC provider. For secrets, I use [external-secrets](https://github.com/external-secrets/external-secrets) backed by [OpenBao](https://openbao.org/) to inject secrets into Kubernetes.
- **Storage & Data Protection**: [miroir](https://github.com/home-operations/miroir) provides distributed block storage with DRBD replication, with [kopiur](https://github.com/home-operations/kopiur) handling backups and restores. [spegel](https://github.com/spegel-org/spegel) improves reliability by running a stateless, cluster-local OCI image mirror.
- **Observability**: [VictoriaMetrics](https://victoriametrics.com/) is the metrics and alerting backend. A `VMAgent` scrapes every `ServiceMonitor` and `PodMonitor` and remote-writes to a single-node `VMSingle` with 30 days of retention, while `VMAlert` evaluates my rules and `VMAlertmanager` routes them. Traces land in `VTSingle` (VictoriaTraces) and logs in [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/). [Grafana](https://grafana.com/) is the UI for all three signals, and [kromgo](https://github.com/kashalls/kromgo) serves the badges in this README. [Gatus](https://gatus.io/) runs the public [status page](https://status.goyangi.io).
- **Automation & CI/CD**: [actions-runner-controller](https://github.com/actions/actions-runner-controller) runs self-hosted GitHub Actions runners directly in the cluster for continuous integration workflows.

> **A note on Prometheus:** [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) is installed, but only for its CRDs and bundled exporters — Prometheus and Alertmanager themselves are disabled in favour of the VictoriaMetrics operator. If you are comparing this against a Prometheus-based setup, the equivalents are `VMAgent` for scraping, `VMSingle` for storage and query, `VMAlert` for rules, and `VMAlertmanager` for routing. `VMRule` plays the role of `PrometheusRule`, and `VMPodScrape`/`VMServiceScrape` that of `PodMonitor`/`ServiceMonitor`.

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches the cluster in my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my cluster based on the state of my Git repository.

The way Flux works for me here is it will recursively search the `kubernetes/apps` folder until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it. That aforementioned `kustomization.yaml` will generally only have a namespace resource and one or many Flux kustomizations (`ks.yaml`). Under the control of those Flux kustomizations there will be a `HelmRelease` or other resources related to the application which will be applied.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged Flux applies the changes to my cluster.

### Directories

This Git repository contains the following directories under [Kubernetes](./kubernetes/).

```sh
📁 kubernetes
├── 📁 apps       # applications
├── 📁 components # re-useable kustomize components
└── 📁 flux       # flux system configuration
```

Outside of it there is [docker](./docker/) for the Docker Compose stacks that run on the edge VPS under GitOps, and [ansible](./ansible/) for bootstrapping that host.

### Flux Workflow

This is a high-level look how Flux deploys my applications with dependencies. In most cases a `HelmRelease` will depend on other `HelmRelease`'s, in other cases a `Kustomization` will depend on other `Kustomization`'s, and in rare situations an app can depend on a `HelmRelease` and a `Kustomization`. The example below shows that `atuin` won't be deployed or upgrade until the `miroir` Helm release is installed or in a healthy state.

```mermaid
graph TD
    A>Kustomization: miroir] -->|Creates| B[HelmRelease: miroir]
    A>Kustomization: miroir] -->|Creates| C[HelmRelease: miroir-config]
    C>HelmRelease: miroir-config] -->|Depends on| B>HelmRelease: miroir]
    D>Kustomization: atuin] -->|Creates| E(HelmRelease: atuin)
    E>HelmRelease: atuin] -->|Depends on| C>HelmRelease: miroir-config]
```

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f636_200d_1f32b_fe0f/512.gif" alt="😶" width="20" height="20"> Cloud Dependencies

While most of my infrastructure and workloads are self-hosted I do rely upon the cloud for certain key parts of my setup. This saves me from having to worry about three things. (1) Dealing with chicken/egg scenarios, (2) services I critically need whether my cluster is online or not and (3) The "hit by a bus factor" - what happens to critical apps (e.g. Email, Password Manager, Photos) that my family relies on when I no longer around.

Alternative solutions to the first two of these problems would be to host a Kubernetes cluster in the cloud and deploy applications like [OpenBao](https://openbao.org/), [Vaultwarden](https://github.com/dani-garcia/vaultwarden), [ntfy](https://ntfy.sh/), and [Gatus](https://gatus.io/); however, maintaining another cluster and monitoring another group of workloads would be more work and probably be more or equal out to the same costs as described below.

| Service                                         | Use                                                            | Cost (AUD)     |
| ----------------------------------------------- | -------------------------------------------------------------- | -------------- |
| [1Password](https://1password.com/)             | Human credentials, passkeys and TOTP                           | ~$50/yr        |
| [Cloudflare](https://www.cloudflare.com/)       | Domains, DNS and R2 object storage                             | ~$30/yr        |
| [GitHub](https://github.com/)                   | Hosting this repository and continuous integration/deployments | Free           |
| [OVHcloud](https://www.ovhcloud.com/en-au/vps/) | Edge VPS for the Towonel tunnel, Caddy L4, CrowdSec and Gatus  | ~$12/mo        |
| [Pushover](https://pushover.net/)               | Kubernetes alerts and application notifications                | $5 OTP         |
|                                                 |                                                                | Total: ~$19/mo |

Cluster secrets live in OpenBao, not 1Password. 1Password holds the human-facing credentials, and a service account is used only where a bootstrap credential has to come from outside the cluster (for example the OpenTofu state for the NAS). See [Bootstrap](./bootstrap/) for how that is wired up.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30e/512.gif" alt="🌎" width="20" height="20"> DNS

In my cluster there are two instances of [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) running. One for syncing private DNS records to my [UniFi](https://ui.com/) controller using [ExternalDNS webhook provider for UniFi](https://github.com/kashalls/external-dns-unifi-webhook), while another instance syncs public DNS to `Cloudflare`. This setup is managed by creating HTTPRoutes with two specific Gateway classes: `internal` for private DNS and `external` for public DNS. The `external-dns` instances then sync the DNS records to their respective platforms accordingly.

A third record set is written by [cloudflare-ddns](https://github.com/favonia/cloudflare-ddns) for the handful of hostnames that must resolve to the edge VPS rather than through the tunnel.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙" width="20" height="20"> Hardware

### Compute

**Dell Optiplex 7050 / 7060 × 3** · 32 GB RAM · Talos / Kubernetes

- **k8s-0, k8s-1** — 6 vCPU
- **k8s-2** — 4 vCPU
- **OS** — Samsung PM863 960 GB SATA SSD
- **Local storage** — Micron 7450 Pro 960 GB NVMe

### Storage

**NAS (repurposed PC)** · 16 GB RAM · TrueNAS SCALE / ZFS

- **Boot** — 512 GB SSD
- **Bulk pool** — 1 × 12 TB ZFS, served over NFS for media, bulk storage and backups

### Networking — UniFi

- **UCG Ultra** — router

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20"> Gratitude and Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you could deploy.
