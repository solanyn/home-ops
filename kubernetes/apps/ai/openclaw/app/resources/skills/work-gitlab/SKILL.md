---
name: work-gitlab
description: Access Ericsson Rosetta GitLab via glab CLI with mTLS. Use for issues, merge requests, pipelines, milestones, and releases at gitlab.rosetta.ericssondevops.com (Cloudflare-Access-fronted). Triggers on gitlab, MR, merge request, pipeline, CI, issues.
---

# Work GitLab Skill (Rosetta)

Access corporate GitLab via glab CLI with mTLS authentication.

## Setup

`glab` binary: `/opt/data/homebrew/.linuxbrew/bin/glab` on Talos/Linux. Install with `brew install glab` if missing. macOS path `/home/node/.local/bin/glab` is deprecated for this skill.
Config: `~/.config/glab-cli/config.yml`
Certs: `~/.devops/client.pem` (cert) + `~/.devops/client-key.pem` (key), mode 600. Path translates from `/Users/<u>/.devops/` (macOS) to `~/.devops/` (Linux).
Token: `op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN'` — the same PAT works for the mirror bot AND as your user token. Auths as `andrew.b.chen`. **The same PAT is your user token AND the mirror bot's token** — there is no separate "user" credential at Ericsson. Be aware: any push via this token attributes commits to you, not a bot account.

### glab config.yml recipe (Talos/Linux)

```yaml
git_protocol: https
hosts:
  gitlab.rosetta.ericssondevops.com:
    api_protocol: https
    api_host: gitlab.rosetta.ericssondevops.com
    token: <GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN>
    client_cert: /opt/data/home/.devops/client.pem
    client_key: /opt/data/home/.devops/client-key.pem
  git.rosetta.ericssondevops.com:
    api_protocol: https
    api_host: gitlab.rosetta.ericssondevops.com
    token: <GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN>
    client_cert: /opt/data/home/.devops/client.pem
    client_key: /opt/data/home/.devops/client-key.pem
```

The cert+key come from `op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_CLIENT_CERT'` and `.../GITLAB_MIRROR_CLIENT_KEY` respectively. After writing the config file, `chmod 600 ~/.config/glab-cli/config.yml`.

Verify the pair works: `glab auth status --hostname gitlab.rosetta.ericssondevops.com` should print "Logged in to gitlab.rosetta.ericssondevops.com as andrew.b.chen". Smoke-test with `glab api projects/sd-moai-nbnms%2Fml-cloud%2Fmono`.

### Cloudflare Access redirect gotcha

A direct `curl https://gitlab.rosetta.ericssondevops.com/api/v4/user` returns `302 → ericssondevops.cloudflareaccess.com` — Cloudflare Access sits in front. The PAT + mTLS auth path bypasses it, but plain `curl` won't. Always go through `glab` or include the mTLS cert in curl invocations.

## State (Jul 2026)

GitLab remains source-of-truth for active work. MSDP team is migrating app repos to GitHub Enterprise Server at `ericsson.ghe.com` (org `Ericsson-BCSS-MSN`); future repos include `app-hilda` and `app-artefactaudit`. Once a repo migrates, it becomes read-only archive on GitLab. Work pace is slow, so most repos stay on GitLab for the foreseeable future.

When asked about GHE, use the `work-ghe` 1Password item (see "Credentials" below) — never the personal PAT. Always set `GH_HOST=ericsson.ghe.com` or pass `--hostname` so `gh` defaults to GHE rather than public github.com.

## Credentials

For GitLab (this skill): mTLS cert+key from `~/.devops/`, or PAT via `op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN'`.

For GitHub Enterprise (`ericsson.ghe.com`, separate from this skill but worth noting): token from `op read 'op://kubernetes/work-ghe/GITHUB_TOKEN'`. Auths as `Admin-account-for-ecehdna` (org-admin-equivalent account). Treat as **read-only / merge-only by default** — never destructive actions (force-push, branch deletion, repo removal) without explicit user approval. Always scope commands to one operation and confirm before running.

## Common Commands

```bash
export PATH="/opt/data/homebrew/.linuxbrew/bin:$PATH"

# List open MRs
glab mr list --repo sd-moai-nbnms/ml-cloud/mono

# View specific MR
glab mr view 1173 --repo sd-moai-nbnms/ml-cloud/mono

# List issues
glab issue list --repo sd-moai-nbnms/ml-cloud/mono

# List pipelines
glab ci list --repo sd-moai-nbnms/ml-cloud/mono

# View pipeline
glab ci view <pipeline-id> --repo sd-moai-nbnms/ml-cloud/mono

# API calls
glab api projects/sd-moai-syd%2Fapi-gateway
glab api projects/sd-moai-nbnms%2Fml-cloud%2Fmono/merge_requests
```

## Key Projects

- `sd-moai-nbnms/ml-cloud/mono` — Main monorepo
- `sd-moai-syd/api-gateway` — SPG (API Gateway)
- `sd-moai-nbnms/automation/asrt` — ASRT automation
- `sd-moai-syd/gke-deployments-autodev/api-gateway-deploy-gke` — GKE deployments
- `sd-moai-syd/nmtool-dev-automation/apitool` — API tool
- `sd-moai-syd/nat_project` — NAT project

## Reading Large Repos: `glab api`, Not Local Clones

For inspecting repos you don't need to modify, **always use `glab api` against the API rather than cloning locally.** The work monorepo `sd-moai-nbnms/ml-cloud/mono` is ~45 MB and contains hundreds of files; cloning wastes the PVC and slows the session.

```bash
# List recent merged MRs by author (for IPM prep, change logs, etc.)
glab api "merge_requests?author_id=<author_id>&state=merged&per_page=50&order_by=updated_at&sort=desc"

# Tarball fallback — when you need actual file contents, not just metadata
PROJECT_ID=32279  # e.g. sd-moai-nbnms/ml-cloud/mono
curl -sk --cert ~/.devops/client.pem \
  --key ~/.devops/client-key.pem \
  -H "PRIVATE-TOKEN: $(op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN')" \
  -o /tmp/repo.tar.gz \
  "https://gitlab.rosetta.ericssondevops.com/api/v4/projects/${PROJECT_ID}/repository/archive.tar.gz"
mkdir -p /opt/data/workspace/gitlab-mono
tar -xzf /tmp/repo.tar.gz -C /opt/data/workspace/gitlab-mono --strip-components=1
# (Clean up the tarball + clone when done — don't leave a 45MB tree lying around.)
```

**`git clone` and `glab repo clone --hostname` will both fail against this host.** Plain git hits the Cloudflare Access 302 redirect before the git protocol completes; `glab repo clone` doesn't accept `--hostname` and defaults to github.com. The tarball API call sidesteps both.

### Tarball endpoint path — only one works

The Forgejo/GitLab tarball endpoints differ from what you'd expect. **Only the `repository/archive.tar.gz` path works** with this host + mTLS auth. The others return errors:

- `GET /api/v4/projects/:id/repository/archive.tar.gz` ✅ 200 with tarball bytes
- `GET /api/v4/projects/:id/archive/main.tar.gz` ❌ 500 (no archive method)
- `GET /api/v4/projects/:id/archive/main` ❌ 400 (method not allowed)
- `GET /api/v4/projects/:id/git/archive/main.tar.gz` ❌ 404 (Gitea-style, not GitLab)
- `GET <host>/:owner/:repo/archive/main` ❌ 0 bytes (no auth, hits CF Access redirect)

Use exactly `repository/archive.tar.gz` with `--cert` + `--key` + `PRIVATE-TOKEN` headers.

## curl Fallback

If glab has issues, use curl directly. Cert+token auth is independent:

```bash
curl -sk --cert ~/.devops/client.pem --key ~/.devops/client-key.pem \
  -H "PRIVATE-TOKEN: $(op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN')" \
  "https://gitlab.rosetta.ericssondevops.com/api/v4/projects/sd-moai-syd%2Fapi-gateway"
```

Note: `-sk` (insecure + silent) is appropriate here because the cert+key auth path is independent of CA verification, and the Cloudflare Access redirect is handled by the cert. `-k` is safe here; drop it if you've installed the Cloudflare root CA.

### Verifying cert+key match before first use

```bash
CERT_HASH=$(openssl x509 -in ~/.devops/client.pem -noout -pubkey \
  | openssl pkey -pubin -outform DER | sha256sum | cut -d' ' -f1)
KEY_HASH=$(openssl rsa -in ~/.devops/client-key.pem -pubout \
  | openssl pkey -pubin -outform DER | sha256sum | cut -d' ' -f1)
[ "$CERT_HASH" = "$KEY_HASH" ] && echo "✓ match" || echo "✗ MISMATCH"
```

A mismatch means you're about to authenticate with mismatched credentials and get a 401 — fail fast before you waste time on the wrong host.

## URL Encoding

Project paths need URL encoding for API calls: `/` → `%2F`
- `sd-moai-syd/api-gateway` → `sd-moai-syd%2Fapi-gateway`
- `sd-moai-nbnms/ml-cloud/mono` → `sd-moai-nbnms%2Fml-cloud%2Fmono`

## Private Repos Don't Show in Search

`/repos/search` and `/repos/search?q=foo` only return **public** repos by default, even when authenticated. To list the repos you own or are a member of (including private ones like `sd-moai-nbnms/ml-cloud/mono`):

```bash
# All repos visible to the authed user (incl. private, mirrors)
glab api "user/repos?per_page=100" --hostname gitlab.rosetta.ericssondevops.com

# All repos you're a member of (not just owned)
glab api "projects?membership=true&per_page=100" --hostname gitlab.rosetta.ericssondevops.com

# Specific group's projects
glab api "groups/sd-moai-nbnms/projects?per_page=100" --hostname gitlab.rosetta.ericssondevops.com
```

`/repos/search` will **silently hide private repos** from the results. If you conclude "this repo doesn't exist" from a search, double-check with `user/repos` before assuming absence. The `?membership=true` flag is a separate concern from `?owned=true` — the former returns everything you have any role in, the latter returns repos where you are the owner.

The `user/repos` response includes `X-Total-Count` header — useful when paginating beyond the default 50 limit (e.g. `?page=2`).

## glab API Path Quirks

A few endpoints behave differently from the GitHub equivalents — these have bitten past sessions:

- `glab repo view <repo>` and `glab project view <repo>` **do not accept `--hostname`** — they default to github.com and fail with a confusing error. Use `glab api projects/<urlencoded-path>` instead, which does accept `--hostname`.
- `glab mr create` against a non-github host **silently targets github.com** if you forget `GH_HOST` or `--hostname`. Always pass `--hostname gitlab.rosetta.ericssondevops.com` explicitly.
- `glab api projects/:id/archive/main.tar.gz` returns 500; use `repository/archive.tar.gz` instead. See "Tarball endpoint path" above.
