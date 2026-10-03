---
name: kubectl
description: Manage Kubernetes cluster via SSH to mac.internal AND introspect the current deployment from inside a pod (where kubectl may exist but lack auth). Use for pod operations, Flux GitOps, resource monitoring, debugging, storage (Ceph/VolSync), Liqo virtual nodes, initContainer diagnosis when you have no service-account token, and treating the GitOps repo (e.g. solanyn/home-ops) as authoritative source-of-truth. Triggers on kubectl, pods, deployments, flux, reconcile, ceph, liqo, kubernetes, k8s, cluster, initcontainer, "check my deployment", "what's installed in this pod".
tags: []
related_skills: []
---

Manage the home-ops Kubernetes cluster (Talos Linux + Flux GitOps) via SSH to mac.internal AND introspect the current deployment from inside a pod (where the agent may already be running in the cluster).

## Access Pattern

kubectl and flux are not in the default SSH PATH. Always use this wrapper:

```bash
ssh mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl <command>"
```

For flux commands:

```bash
ssh mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig flux <command>"
```

### Shell Helper

Define this function at the top of scripts or multi-command sessions to reduce boilerplate:

```bash
k() { ssh mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl $*"; }
fl() { ssh mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig flux $*"; }
```

Then use: `k get pods -n default` or `fl get ks`.

**Important:** Quote arguments with spaces or special chars carefully. For complex commands, wrap the entire remote command in a single string.

## Key Namespaces

| Namespace | Purpose |
|---|---|
| `default` | Main apps (overcrowded — many services here) |
| `ai` | AI/ML workloads |
| `observability` | Monitoring, Grafana, Prometheus |
| `storage` | Storage services |
| `network` | Networking (kgateway, chisel, etc.) |
| `kubeflow` | ML pipelines |
| `rook-ceph` | Ceph storage operator |
| `flux-system` | Flux GitOps controllers |
| `kube-system` | Core k8s components |
| `liqo-system` | Liqo multi-cluster |

## Common Pod Operations

### List pods
```bash
# All pods in a namespace
k get pods -n default

# All pods across all namespaces
k get pods -A

# Wide output (node, IP)
k get pods -n default -o wide

# Filter by label
k get pods -n default -l app.kubernetes.io/name=fusion
```

### Logs
```bash
# Tail logs
k logs -n default deploy/fusion -f --tail=100

# Previous container (crashed)
k logs -n default <pod-name> --previous

# All containers in pod
k logs -n default <pod-name> --all-containers
```

### Exec into pod
```bash
k exec -n default -it deploy/fusion -- /bin/sh
```

**Note:** For exec/attach with `-it`, you may need `ssh -t` for TTY allocation:
```bash
ssh -t mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl exec -n default -it deploy/fusion -- /bin/sh"
```

### Restart deployment
```bash
k rollout restart -n default deploy/fusion
```

### Describe
```bash
k describe pod -n default <pod-name>
k describe deploy -n default fusion
```

## Flux GitOps Operations

### Check status
```bash
# All Kustomizations
fl get ks

# All HelmReleases
fl get hr -A

# Specific
fl get ks <name>
fl get hr -n <namespace> <name>
```

### Reconcile (force sync)
```bash
# Kustomization
fl reconcile ks <name>

# HelmRelease
fl reconcile hr -n <namespace> <name>

# Source (git repo)
fl reconcile source git flux-system
```

### Suspend / Resume
```bash
fl suspend ks <name>
fl resume ks <name>
fl suspend hr -n <namespace> <name>
fl resume hr -n <namespace> <name>
```

### Check failed resources
```bash
fl get ks --status-selector ready=false
fl get hr -A --status-selector ready=false
```

## Resource Monitoring

```bash
# Node resource usage
k top nodes

# Pod resource usage
k top pods -n default --sort-by=memory
k top pods -A --sort-by=cpu

# All pods sorted by memory (cluster-wide)
k top pods -A --sort-by=memory | head -20
```

## Debugging

### Events
```bash
# Namespace events (sorted by time)
k get events -n default --sort-by='.lastTimestamp'

# All warning events
k get events -A --field-selector type=Warning

# Watch events
k get events -n default -w
```

### Pod issues
```bash
# CrashLoopBackOff pods
k get pods -A --field-selector status.phase!=Running | grep -v Completed

# Describe for scheduling/pull issues
k describe pod -n default <pod-name>

# Previous container logs (after crash)
k logs -n default <pod-name> --previous
```

### Resource details with jsonpath
```bash
# Pod restart counts
k get pods -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}'

# Images running in namespace
k get pods -n default -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Pod IPs
k get pods -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Node allocatable resources
k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}cpu:{.status.allocatable.cpu}{"\t"}mem:{.status.allocatable.memory}{"\n"}{end}'
```

## Storage Operations

### PVC status
```bash
k get pvc -A
k get pvc -n default
k describe pvc -n default <pvc-name>
```

### Ceph health (rook-ceph)
```bash
# Ceph cluster status
k -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
k -n rook-ceph exec deploy/rook-ceph-tools -- ceph health detail

# OSD status
k -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd status
k -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd df

# Pool usage
k -n rook-ceph exec deploy/rook-ceph-tools -- ceph df

# Rook operator logs
k logs -n rook-ceph deploy/rook-ceph-operator --tail=50
```

**Note:** For ceph exec, use `ssh -t` if needed for TTY.

### VolSync (PVC backups)
```bash
# Check ReplicationSource status
k get replicationsource -A
k describe replicationsource -n <namespace> <name>

# Check ReplicationDestination
k get replicationdestination -A

# Last sync time
k get replicationsource -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.lastSyncTime}{"\n"}{end}'
```

## Liqo (Multi-Cluster)

### Virtual node status
```bash
# Check virtual node
k get nodes | grep worker

# Describe virtual node
k describe node worker
```

### Offloaded pods
```bash
# Pods running on Liqo virtual node
k get pods -A --field-selector spec.nodeName=worker

# Liqo system status
k get pods -n liqo-system
```

### Liqo peering
```bash
k get foreignclusters -n liqo-system
k describe foreignclusters -n liqo-system
```

## Useful Patterns

### Quick health check
```bash
k get nodes
k top nodes
k get pods -A --field-selector status.phase!=Running --field-selector status.phase!=Succeeded
fl get ks --status-selector ready=false
```

### Find what's running where
```bash
# All pods on a specific node
k get pods -A -o wide --field-selector spec.nodeName=<node>

# Deployments in a namespace
k get deploy -n default

# All HelmReleases
k get hr -A
```

### Port-forward
```bash
# Forward local port on mac to service
ssh -t mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl port-forward -n default svc/fusion 8080:80"
```

**Note:** Port-forward blocks — run it in background or a separate session. From the sandbox, you typically access services via their cluster DNS (svc.cluster.local) directly.

### Scale
```bash
k scale deploy -n default fusion --replicas=0
k scale deploy -n default fusion --replicas=1
```

### Pitfall — when 1Password retrieval succeeds, scope the token carefully

A GitHub PAT retrieved via `op read` is the same privilege level as the PAT in
1Password. Don't embed it in git remote URLs that get logged, and don't paste
it into a chat message — use `export GITHUB_TOKEN=$(op read …)` so the token
lives in shell env, not in command history or in a script that gets committed.

---

## Notes

- The cluster runs **Talos Linux** — no SSH to nodes, no systemd, all config via Talos API
- **app-template** is the main Helm chart pattern for most apps
- **Flux** manages all deployments — prefer `flux reconcile` over manual `kubectl apply`
- The `default` namespace is overcrowded; check there first for most apps
- For interactive commands (exec, port-forward), use `ssh -t` for TTY allocation

---

## Operating From Inside the Pod (Hermes-on-home-ops deployment)

When Hermes itself runs inside the cluster (deployment in `solanyn/home-ops`, see `kubernetes/apps/ai/hermes/`), the agent has **two execution contexts**:

1. **This shell** — a shell spawned by `terminal()` inside the running gateway pod. PATH here is the bare system default (`/usr/local/bin:/usr/bin:/bin`). The pod's `app` container env sets a richer PATH via the helmrelease, but new shells don't inherit it — you must `export PATH=/opt/data/homebrew/.linuxbrew/bin:/opt/data/homebrew/.linuxbrew/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` yourself.
2. **The PID 1 process** — `hermes gateway run`, started by the entrypoint script. To see its actual env (including `OP_SERVICE_ACCOUNT_TOKEN` and other secrets), read `/proc/1/environ`:
   ```bash
   tr '\0' '\n' < /proc/1/environ | grep -E '^(OP_|OPENAI|HONCHO|MATRIX|BLUEBUBBLES)' | cut -d= -f1
   ```
   `~/.hermes/.env` is a Hermes-curated subset; the full set is only in process memory.

### Check if kubectl can actually authenticate

```bash
ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# Empty output / "No such file or directory" → no SA token mounted → 401 from apiserver
```

```bash
APISERVER=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
curl -sk --cacert "$CACERT" -H "Authorization: Bearer $TOKEN" "$APISERVER/api" 2>&1 | head -3
# 401 Unauthorized → no auth. Use the GitOps repo as source of truth instead.
```

**If 401 / no token** (common — many Helm charts don't `serviceAccountName:` by default), fall back to the GitOps repo for read access. See next section.

### GitOps repo is the source of truth — read it directly

Even without k8s auth, the public GitHub repo (e.g. `github.com/solanyn/home-ops`) is **authoritative** for what should be deployed. Pull manifests via the public REST API:

```bash
# List files in an app dir
curl -s "https://api.github.com/repos/solanyn/home-ops/contents/kubernetes/apps/ai/hermes/app" \
  | jq -r '.[] | "\(.size)\t\(.name)"'

# Read a specific manifest
curl -s "https://raw.githubusercontent.com/solanyn/home-ops/main/kubernetes/apps/ai/hermes/app/helmrelease.yaml"

# Walk a recursive tree (find RBAC, init containers, etc.)
curl -s "https://api.github.com/repos/solanyn/home-ops/git/trees/HEAD?recursive=1" \
  | jq -r '.tree[].path' | grep -iE 'rbac|serviceaccount|initcontainer'
```

Rate limit is 60 req/hr per IP unauthenticated — fine for one-off discovery, painful for cron. Use a PAT (`gh auth login` then `gh api ...`) or `op read 'op://kubernetes/github/GITHUB_TOKEN'` for the recurring case.

### Pre-merge validation with `flate` (no kubectl auth needed)

Before pushing a PR, run `flate diff images` locally — this is the same check CI runs (`.github/workflows/image-pull.yaml`). Catches chart-schema errors and image drift before the PR is reviewed.

```bash
brew tap home-operations/tap && brew install flate   # one-time, requires tap trust
flate diff images --base origin/main -p ./kubernetes/flux/cluster
```

- Exit 0 with `[]` → clean, no image or schema diff
- Lists image references (alpine, debian, hermes-agent, etc.) → chart re-rendered, image-pull workflow will trigger; usually a no-op if image tags unchanged
- `flate error: orig snapshot: reconcile completed with 1 failure(s)` → the **baseline** (origin/main) has a broken reconcile. Fix-forward in your PR; CI will go green once merged because the new reconcile is clean
- `flate error: current snapshot: ...` → your PR has a broken reconcile. Read the message carefully (`helm template ... values don't meet the specifications of the schema(s)`) and consult the chart schema

The same tool can render the whole chart locally:

```bash
flate build -p ./kubernetes/flux/cluster                  # full render of all resources
flate get helmreleases -p ./kubernetes/flux/cluster -n ai  # what would reconcile
flate test -p ./kubernetes/flux/cluster                   # reconcile status without applying
```

No `helm`, `kustomize`, or `flux` binary needed — `flate` is self-contained.

### Init-container diagnosis when kubectl logs don't work

If you can't `kubectl logs <pod> -c install-tools` (no auth), the GitOps repo usually has the answer. Look for:

- `helmrelease.yaml` `values.controllers.<name>.initContainers.<name>.command` — the script the init container runs.
- Reasoning about likely failure points:
  1. **GID mapping**: `setpriv --regid=10000` requires GID 10000 in the init image's `/etc/group`. If the init script doesn't `groupadd` first, `setpriv` fails before any work happens.
  2. **DNS / egress**: init containers run before some NetworkPolicies apply. If `curl raw.githubusercontent.com` fails, cluster egress is the issue.
  3. **Timeout**: linuxbrew bootstrap takes 5–10 min cold. If `activeDeadlineSeconds` isn't set high enough, init container gets killed mid-bootstrap.
  4. **PATH inside `setpriv`**: `env HOME=... bash -c '...'` clears PATH unless re-exported inside the inner bash.
  5. **bootstrap script hardcodes `/home/linuxbrew/.linuxbrew`**: real Homebrew install.sh ignores `HOMEBREW_PREFIX` on Linux. Manual `git clone` + `tar` extract is the workaround (see `unifi` skill and your `install-tools` init for the pattern).

### When you do have k8s auth (post-RBAC)

Once a ServiceAccount + Role/ClusterRole are wired, the standard `kubectl` flow from inside the pod works **without** SSH or kubeconfig — just ensure kubectl is on PATH:

```bash
export PATH=/opt/data/homebrew/.linuxbrew/bin:$PATH
kubectl get pods -A
kubectl get hr -A
kubectl logs -n ai <hermes-pod> -c install-tools --previous  # to see init logs
```

For TTY-required commands (`kubectl exec -it`, port-forward), you still need an interactive shell — `terminal(pty=true)` if your runtime supports it.

### GitHub API recipes for in-pod introspection

When reading the GitOps repo as source of truth (above), the API surface has subtle gotchas around pagination, rate limits, and the raw-vs-API distinction. Concrete recipes for the patterns used in this cluster (`solanyn/home-ops`):

- `references/in-pod-github-api.md` — list/read/walk/clone patterns, auth via `op`, rate-limit pitfall, when to clone vs API-call.

## Workflow preference notes (Andrew, home-ops)

- **Default to manifests, not prose.** When asked for k8s resources, output files (serviceaccount.yaml, role.yaml, etc.) — not a long explanation. Add a README.md only if asked.
- **Concise findings + asks; verbose reasoning is OK.** When reporting state or asking the user to do something, keep the bottom line short. Lead with the answer and the ask, then justify. Andrew explicitly told me to "be concise with findings and what you need from [him] and why" — verbose reasoning is allowed, but the actual ask must be tight. Don't bury the question in prose.
- **Don't over-explain.** Avoid preamble like "Great question!" or "Let me think about this" — Andrew's style is terse, mirror it.
- **Confirm before assuming state.** When something could be either-or (zerobrew vs linuxbrew, where a binary lives, what auth a token has), check before guessing. Andrew caught me twice this session for assuming state instead of verifying.
- **Least-privilege RBAC by default.** For AI-agent ServiceAccounts: read everywhere, write nowhere. Explicitly exclude `pods/exec`, `pods/portforward`, cluster-wide `secrets`, `nodes/proxy`. Future write elevation goes in a separate, auditable PR.
- **Lean manifest comments.** When writing RBAC (or any k8s manifest), keep comments short: one block-level note per `rules:` group describing *what* is in the block. Put the rationale for exclusions (exec, portforward, cluster-wide secrets, nodes/proxy, cert-manager signing) in a single top-of-file comment on the ClusterRole. No "future elevation" cheat sheets inside manifests — those belong in the PR body. Don't restate `get/list/watch` on every line.
- **Brewfile-driven init containers.** If modifying a chart's `install-tools` init container, mount the Brewfile via configMap and use `brew bundle install --no-upgrade --file=/tmp/Brewfile` — not a hardcoded `brew install` list. Easier to review, easier to reproduce. Add `gh` to the Brewfile if you need to open PRs from the pod.
- **`command -v` is not enough.** When checking if a CLI is available in a non-standard PATH deployment, also `ls /opt/data/homebrew/bin/` and use absolute paths. Many CLIs are present but not discoverable through the default PATH.

## solanyn/home-ops AGENTS.md conventions

When proposing commits to `github.com/solanyn/home-ops`, follow the project `AGENTS.md`:

- **British English in prose, American English in code/manifests.** No Oxford commas in prose.
- **Conventional commits with scope tags**: `feat(hermes):`, `fix(cilium):`, `chore(norish):`, `docs(readme):`.
- **Never attribute agents in commit messages.** No `Co-authored-by: Hermes`, no `[bot]` tags in the message body.
- **Never use `git add .`** — stage exact files only (`git add path/to/file1 path/to/file2`).
- **Only commit and push when the user explicitly requests it.** Otherwise produce diffs/patches and wait for go-ahead.
- **Subject line under 50 characters**, imperative tone. Add detailed context in commit body when non-obvious.

## Git identity: use the github-bot App, not Andrew's PAT

Two creds live in 1Password for GitHub work, and they have different purposes:

| Item | Path | Use for |
|---|---|---|
| `github` | `op://kubernetes/github/GITHUB_TOKEN` | Read-only fallback (one-off API calls, `git clone` of public repos). Personal PAT — commits made under this token get attributed to Andrew. |
| `github-bot` | `op://kubernetes/github-bot/...` (App 1109230, Install 59452502) | All `git push`, PR creation, branch operations. Commits/PRs come from `github-bot[bot]`. |

If only the personal PAT is reachable, before any `git commit`:

```bash
git config user.name 'github-bot[bot]'
git config user.email 'github-bot[bot]@users.noreply.github.com'
```

The github-bot App uses an RSA private key + JWT exchange to mint installation tokens — not a static PAT. Pull the App ID, installation ID, and private key from the 1Password item, then exchange a short-lived JWT for an installation token per session. Setup is non-trivial; until it's wired up, **treat the personal PAT path as the fallback** and never reuse the same token for push + chat (the redactor handles tokens but minimise the surface).

### Pitfall — bjw-s/app-template `serviceAccount` schema

The `app-template` chart (v5+) creates the ServiceAccount itself. The correct values path is **top-level**, NOT under `controllers.<name>`:

```yaml
spec:
  values:
    serviceAccount:                    # top-level, sibling of `controllers:`
      hermes:                          # this key becomes the SA name
        enabled: true
        annotations: {...}
    controllers:
      hermes:
        # NO serviceAccountName here — schema rejects it
        annotations:
          reloader.stakater.com/auto: "true"
```

Common mistakes (all rejected by the chart schema, caught by `flate diff images`):

- `controllers.<name>.serviceAccountName: hermes` — schema error: `at '/controllers/<name>/serviceAccountName': false schema`
- `controllers.<name>.serviceAccount.name: hermes` — also rejected; serviceAccount is not under controllers
- Defining a separate `serviceaccount.yaml` in the same kustomization — will conflict with the chart-created SA of the same name and get rejected by k8s

If you need RBAC to bind to the chart-created SA, use the chart-generated name (matches the key, e.g. `hermes`) directly in your `RoleBinding` / `ClusterRoleBinding` subject — no rename needed.

Full chart reference: https://bjw-s-labs.github.io/helm-charts/docs/app-template/reference/serviceaccount/

## Honcho v3 in-cluster (memory layer)

Hermes's Honcho plugin lives at `/opt/hermes/plugins/memory/honcho/` and reads (in order):
1. `HERMES_HONCHO_HOST` env var (explicit override)
2. `HONCHO_BASE_URL` env var
3. `HONCHO_API_KEY` env var
4. `~/.honcho/config.json` (single source of truth)

Config already declares `provider: honcho` and `honcho_url: http://honcho.ai.svc.cluster.local`. To make Honcho primary (so the system prompt's MEMORY block comes from Honcho instead of the built-in file backend), the ExternalSecret must project both `HONCHO_API_KEY` AND `HONCHO_WORKSPACE_ID` — the workspace ID is just a path-segment string (e.g. `solanyn`), not a UUID.

**Verify Honcho is actually live before relying on it:**
```bash
curl -sk --max-time 4 http://honcho.ai.svc.cluster.local/health        # expect 200
curl -sk --max-time 4 http://honcho.ai.svc.cluster.local/openapi.json | jq .info.version  # expect v3.x
```

The API uses `/v3/workspaces/{workspace_id}/...` for everything. `/health`, `/docs`, `/redoc`, `/openapi.json` are public; the rest need `HONCHO_API_KEY`. After flipping primary, restart the pod (config is read at import time) and check the system prompt's MEMORY block — it should switch from "Built-in file backend" to "Honcho Memory".

When the MEMORY block hits its cap, the right call depends on cost model:

- **Subscription / context-only billing** (Andrew's setup): raise `memory_char_limit` and `user_char_limit` to ~10-20% of model context window. Memory is the point of a personal assistant — leaving it at the 2,200-char default (~0.3% of context) wastes recall capacity. Recent bump in `solanyn/home-ops`: 2200 → 20000 / 1375 → 8000.
- **Per-token billing**: keep the cap small and offload bulky facts to `~/.hermes/memories/*.md` files (index pointers + recent items stay in MEMORY).
