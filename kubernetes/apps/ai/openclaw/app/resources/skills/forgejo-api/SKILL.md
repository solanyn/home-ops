---
name: forgejo-api
description: Interact with Forgejo (Gitea-compatible) REST API for repos, commits, branches, issues, files, releases, and mirror status. Use when asked about Forgejo, self-hosted git, or repos on forgejo.goyangi.io. Admin-scoped token — read-only / merge-only by default. Triggers on forgejo, gitea, self-hosted git, repo mirror, forgejo issues.
---

# Forgejo REST API Skill

Forgejo instance at `forgejo.goyangi.io` (public) + `forgejo-http.default.svc.cluster.local:3000` (in-cluster). Gitea-compatible REST API v1.
Version: 14.0.3+gitea-1.22.0

> **fj CLI won't work** — requires glibc 2.39, container has 2.36. Use curl directly.

## Authentication

```bash
# Get token from 1Password
TOKEN=$(op read "op://kubernetes/forgejo/FORGEJO_TOKEN")
API="http://forgejo-http.default.svc.cluster.local:3000/api/v1"

# All requests use this header
curl -s -H "Authorization: token $TOKEN" "$API/..."
```

**Token scope warning:** the token at `op://kubernetes/forgejo/FORGEJO_TOKEN` is the `andrew` admin account — full repo, user, and org-management capabilities. Treat as **read-only / merge-only by default**, exactly like the work-ghe PAT. Never destructive actions (repo deletion, force-push, user removal) without explicit Andrew approval.

**Public URL (from outside the cluster, e.g. Mac, scripts on a server, browser):** `https://forgejo.goyangi.io/` — same token works, just swap the base URL.
- `https://forgejo.goyangi.io/api/v1/...` (external HTTPS)
- `http://forgejo-http.default.svc.cluster.local:3000/api/v1/...` (in-cluster HTTP)

**Host health gotcha:** the instance runs as a single replica (see `kubernetes/apps/default/forgejo/app/helmrelease.yaml` in `solanyn/home-ops`) backed by DragonflyDB for sessions/cache. If Forgejo returns 503, check Dragonfly first (`kubectl -n storage get dragonfly,pods -l app.kubernetes.io/part-of=dragonfly`). Dragonfly outage will surface as Forgejo 503s because session/cache writes fail. Observed 2026-07-21.

## Shell Helper

For multi-call sessions, set up once:

```bash
export FORGEJO_TOKEN=$(op read "op://kubernetes/forgejo/FORGEJO_TOKEN")
export FORGEJO_API="http://forgejo-http.default.svc.cluster.local:3000/api/v1"
alias fapi='curl -s -H "Authorization: token $FORGEJO_TOKEN"'
# Usage: fapi "$FORGEJO_API/repos/andrew/hawow-shmawow"
```

## Key Repos

| Owner/Repo | Type | Notes |
|---|---|---|
| `andrew/hawow-shmawow` | Own | Workspace repo |
| `andrew/nix-darwin` | Own (private) | Mac config |
| `andrew/learning` | Own | Code submissions — **DO NOT overwrite files** |
| **`andrew/obsidian`** | **Own (private)** | **Obsidian vault — git-synced source of truth** (see "Obsidian vault workflow" below) |
| `work/mono` | Mirror | GitLab mirror — **READ ONLY** |
| `work/api-gateway` | Mirror | SPG — READ ONLY |
| `work/asrt` | Mirror | ASRT automation — READ ONLY |

All `work/*` repos are GitLab mirrors. Do not push to them.

## Obsidian vault workflow (the most common forgejo use case)

The Obsidian vault lives in **`andrew/obsidian`** (private). The Obsidian app on Andrew's Mac syncs to this repo via the Obsidian Git plugin. The same repo is reachable from any Hermes pod via git over HTTPS using the `FORGEJO_TOKEN`.

### Rule: always `git pull` before writing

The vault is **multi-writer**: Obsidian writes from the Mac, Hermes writes from the pod, Obsidian writes again. A stale local clone will produce a non-fast-forward push. **Always pull before committing any new file.**

```bash
# one-time per session: refresh the local clone
cd /path/to/andrew/obsidian  # wherever you've cloned it
git pull --rebase --autostash
```

### Clone the vault into a pod

```bash
TOKEN=$(op read 'op://kubernetes/forgejo/FORGEJO_TOKEN')
URL='https://x-access-token:'"$TOKEN"'@forgejo.goyangi.io/andrew/obsidian.git'

# shallow clone is fine for read/append work
GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$URL" /tmp/obsidian-vault
```

### Read notes from the vault

Prefer the existing `obsidian` skill (filesystem-style read/search/edit) over the API once the vault is locally cloned — the skill assumes a vault path on disk and operates on it directly.

### Write to the vault from a pod

After pulling, edit files locally, then:

```bash
cd /tmp/obsidian-vault
# write_file / patch from the obsidian skill — they operate on the local checkout
git add <file>
git commit -m "<reason>"
git push origin main
```

**The git API tarball endpoint on this forgejo instance is unreliable** (returns 500 on `/api/v1/repos/{owner}/{repo}/archive/main.tar.gz`). For bulk file extraction, **always use `git clone` rather than the API tarball**.

### Find the vault via API

```bash
fapi "$FORGEJO_API/user/repos?limit=50" | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    if 'obsidian' in r['full_name']: print(r['full_name'], r['private'])
"
```

The vault is private — it won't show in `repos/search` or `repos/search?q=obsidian`. Use `user/repos` (the authenticated user's own repos, includes private).

## Tarball fallback for non-Obsidian repos

For non-vault repos where you need actual file contents (not metadata), the API tarball works fine:

```bash
curl -sk --cert ~/.devops/client.pem --key ~/.devops/client-key.pem \
  -H "PRIVATE-TOKEN: $(op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN')" \
  -o /tmp/repo.tar.gz \
  "https://gitlab.rosetta.ericssondevops.com/api/v4/projects/${PROJECT_ID}/repository/archive.tar.gz"
```

But on **forgejo**, this endpoint fails (see Obsidian section). For forgejo file extraction, use `git clone` instead — token-in-URL works.

## API Reference

### List Repos

```bash
# All accessible repos (paginated)
fapi "$FORGEJO_API/repos/search?limit=50&page=1"

# Repos for a specific owner
fapi "$FORGEJO_API/repos/search?limit=50&owner=andrew"
fapi "$FORGEJO_API/repos/search?limit=50&owner=work"

# Current user's repos
fapi "$FORGEJO_API/user/repos?limit=50"
```

Response: `{"ok": true, "data": [<repo objects>]}`

### Get Repo Details

```bash
fapi "$FORGEJO_API/repos/{owner}/{repo}"
```

Key fields: `name`, `full_name`, `private`, `mirror`, `mirror_interval`, `mirror_updated`, `original_url`, `default_branch`, `empty`, `size`, `language`, `archived`

### Commits

```bash
# Recent commits (default branch)
fapi "$FORGEJO_API/repos/{owner}/{repo}/commits?limit=10"

# Commits on a specific branch
fapi "$FORGEJO_API/repos/{owner}/{repo}/commits?sha=develop&limit=10"

# Single commit
fapi "$FORGEJO_API/repos/{owner}/{repo}/git/commits/{sha}"
```

### Branches

```bash
# List branches
fapi "$FORGEJO_API/repos/{owner}/{repo}/branches"

# Get specific branch
fapi "$FORGEJO_API/repos/{owner}/{repo}/branches/{branch}"

# Create branch
fapi -X POST -H "Content-Type: application/json" \
  -d '{"new_branch_name": "feature/xyz", "old_branch_name": "main"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/branches"

# Delete branch
fapi -X DELETE "$FORGEJO_API/repos/{owner}/{repo}/branches/{branch}"
```

### Tags

```bash
# List tags
fapi "$FORGEJO_API/repos/{owner}/{repo}/tags"

# Create tag
fapi -X POST -H "Content-Type: application/json" \
  -d '{"tag_name": "v1.0.0", "target": "main", "message": "Release v1.0.0"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/tags"
```

### Issues

```bash
# List open issues
fapi "$FORGEJO_API/repos/{owner}/{repo}/issues?state=open&limit=20"

# List closed issues
fapi "$FORGEJO_API/repos/{owner}/{repo}/issues?state=closed&limit=20"

# Get single issue
fapi "$FORGEJO_API/repos/{owner}/{repo}/issues/{number}"

# Create issue
fapi -X POST -H "Content-Type: application/json" \
  -d '{"title": "Bug title", "body": "Description here", "labels": [1]}' \
  "$FORGEJO_API/repos/{owner}/{repo}/issues"

# Update issue
fapi -X PATCH -H "Content-Type: application/json" \
  -d '{"state": "closed"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/issues/{number}"

# List issue comments
fapi "$FORGEJO_API/repos/{owner}/{repo}/issues/{number}/comments"

# Add comment
fapi -X POST -H "Content-Type: application/json" \
  -d '{"body": "Comment text"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/issues/{number}/comments"
```

### Labels

```bash
# List repo labels
fapi "$FORGEJO_API/repos/{owner}/{repo}/labels"

# Create label
fapi -X POST -H "Content-Type: application/json" \
  -d '{"name": "bug", "color": "#ee0701"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/labels"
```

### File Operations

```bash
# List directory contents
fapi "$FORGEJO_API/repos/{owner}/{repo}/contents/{path}"
# Root: fapi "$FORGEJO_API/repos/{owner}/{repo}/contents/"

# Read file (content is base64-encoded)
fapi "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}" | python3 -c "
import sys,json,base64
d = json.load(sys.stdin)
print(base64.b64decode(d['content']).decode())
"

# Read file at specific ref
fapi "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}?ref=develop"

# Create file
fapi -X POST -H "Content-Type: application/json" \
  -d '{
    "content": "'$(echo -n "file content" | base64)'",
    "message": "Add new file"
  }' \
  "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}"

# Update file (requires current SHA)
SHA=$(fapi "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
fapi -X PUT -H "Content-Type: application/json" \
  -d '{
    "content": "'$(echo -n "updated content" | base64)'",
    "message": "Update file",
    "sha": "'$SHA'"
  }' \
  "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}"

# Delete file
fapi -X DELETE -H "Content-Type: application/json" \
  -d '{"message": "Remove file", "sha": "'$SHA'"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/contents/{filepath}"
```

> **andrew/learning**: DO NOT create/update/delete files — code submissions only.

### Raw File Content

```bash
# Get raw file without base64 decoding
fapi "$FORGEJO_API/repos/{owner}/{repo}/raw/{filepath}"
fapi "$FORGEJO_API/repos/{owner}/{repo}/raw/{filepath}?ref=develop"
```

### Releases

```bash
# List releases
fapi "$FORGEJO_API/repos/{owner}/{repo}/releases"

# Create release
fapi -X POST -H "Content-Type: application/json" \
  -d '{
    "tag_name": "v1.0.0",
    "target_commitish": "main",
    "name": "v1.0.0",
    "body": "Release notes here",
    "draft": false,
    "prerelease": false
  }' \
  "$FORGEJO_API/repos/{owner}/{repo}/releases"

# Upload release attachment
fapi -X POST \
  -F "attachment=@/path/to/file" \
  "$FORGEJO_API/repos/{owner}/{repo}/releases/{id}/assets?name=filename.tar.gz"

# Delete release
fapi -X DELETE "$FORGEJO_API/repos/{owner}/{repo}/releases/{id}"
```

### Repo Management

```bash
# Create repo (for current user)
fapi -X POST -H "Content-Type: application/json" \
  -d '{
    "name": "new-repo",
    "description": "My new repo",
    "private": true,
    "auto_init": true,
    "default_branch": "main"
  }' \
  "$FORGEJO_API/user/repos"

# Create repo in an org
fapi -X POST -H "Content-Type: application/json" \
  -d '{"name": "new-repo", "private": true}' \
  "$FORGEJO_API/orgs/{org}/repos"

# Delete repo
fapi -X DELETE "$FORGEJO_API/repos/{owner}/{repo}"

# Edit repo settings
fapi -X PATCH -H "Content-Type: application/json" \
  -d '{"description": "Updated description", "has_issues": true}' \
  "$FORGEJO_API/repos/{owner}/{repo}"
```

### Mirror Status

```bash
# Check mirror sync status
fapi "$FORGEJO_API/repos/{owner}/{repo}" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(f'Mirror: {d[\"mirror\"]}')
print(f'Interval: {d.get(\"mirror_interval\", \"N/A\")}')
print(f'Last sync: {d.get(\"mirror_updated\", \"N/A\")}')
print(f'Source: {d.get(\"original_url\", \"N/A\")}')
"

# Trigger mirror sync (admin or repo owner)
fapi -X POST "$FORGEJO_API/repos/{owner}/{repo}/mirror-sync"
```

### Search

```bash
# Search repos
fapi "$FORGEJO_API/repos/search?q=keyword&limit=20"

# Search within repo (code search, if enabled)
fapi "$FORGEJO_API/repos/{owner}/{repo}/topics"
```

### Pull Requests

```bash
# List PRs
fapi "$FORGEJO_API/repos/{owner}/{repo}/pulls?state=open"

# Create PR
fapi -X POST -H "Content-Type: application/json" \
  -d '{
    "title": "PR title",
    "body": "Description",
    "head": "feature-branch",
    "base": "main"
  }' \
  "$FORGEJO_API/repos/{owner}/{repo}/pulls"

# Merge PR
fapi -X POST -H "Content-Type: application/json" \
  -d '{"Do": "merge"}' \
  "$FORGEJO_API/repos/{owner}/{repo}/pulls/{number}/merge"
```

> Note: `work/*` mirror repos have PRs disabled (`has_pull_requests: false`).

## Pagination

All list endpoints support `?page=1&limit=50` (max limit: 50). Check `x-total-count` response header for total items.

```bash
# Get total count from headers
curl -sI -H "Authorization: token $FORGEJO_TOKEN" "$FORGEJO_API/repos/search?limit=1" | grep -i x-total-count
```

## Safety Rules

1. **`work/*` repos are READ ONLY** — mirrored from GitLab. Never push, create files, issues, or PRs.
2. **`andrew/learning`** — read only. Do not overwrite or modify files.
3. **Prefer read operations** — always confirm with Andrew before write operations on any repo.

## API Response Quirks

A few endpoint behaviours that have bitten past sessions:

- **`/api/v1/repos/search` returns only public repos** by default, even when authenticated. To list your own repos including private ones (the `andrew/obsidian` vault, for example), use `GET /api/v1/user/repos?limit=50` instead. The `search` endpoint will silently hide private repos, leading to false "this doesn't exist" conclusions. The `?owner=andrew` query parameter on `/repos/search` does NOT include private repos either.
- **`/api/v1/repos/{owner}/{repo}/archive/main.tar.gz` returns 500** on this instance — the tarball endpoint is broken. Use `git clone` (with token in URL) for bulk file extraction. `git clone` over HTTPS with `https://x-access-token:<EMAIL_ADDRESS>/owner/repo.git` works reliably.
- **`/api/v1/repos/{owner}/{repo}/contents/?ref=main` requires the `?ref=` query param** even when `main` is the default branch — omitting it returns `{"message":"","url":"/api/swagger"}` (empty error). Always pass `?ref=main` explicitly.
- **Anonymous API calls return 200 with empty data** for paths that need auth (e.g. `/repos/search` returns `{"ok":true,"data":[]}` instead of 401). Don't interpret empty results as "nothing exists" — check that you're authenticated first.
