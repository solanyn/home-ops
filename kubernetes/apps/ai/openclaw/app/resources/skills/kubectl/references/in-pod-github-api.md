# In-pod GitHub API Recipes

When running inside a Hermes-on-home-ops pod with **no k8s SA token** (and thus
no `kubectl auth`) but **with network egress to github.com**, the GitHub REST
API is the canonical way to read the GitOps repo as authoritative source of
truth. Same data, different transport — no cluster-side RBAC needed.

## Why this matters

`kubectl get` returns 401 when the pod lacks a ServiceAccount token. The
GitOps repo (`solanyn/home-ops` for Andrew's cluster) is **the same YAML**
that Flux reconciles — so reading it tells you exactly what the cluster
*should* be running, even when you can't query what it *is* running.

## Authentication

On the Hermes deployment, the canonical GitHub token retrieval is via
1Password service account (see `github-auth` skill Method 3):

```bash
export GITHUB_TOKEN=$(op read "op://kubernetes/github/GITHUB_TOKEN")
export GH_TOKEN="$GITHUB_TOKEN"   # gh CLI picks up automatically
```

If `op` is missing, fall back to:

```bash
# Manual: paste the token inline (one-shot, redacted by HERMES_REDACT_SECRETS)
export GITHUB_TOKEN="ghp_..."
```

Unauthenticated requests work for **public** repos at 60 req/hr per IP. Fine
for one-off discovery. **Not** fine for cron — use a token.

## Common recipes

### List files in an app dir

```bash
curl -s "https://api.github.com/repos/solanyn/home-ops/contents/kubernetes/apps/ai/hermes/app" \
  | jq -r '.[] | "\(.size)\t\(.name)"'
```

### Read a manifest

```bash
curl -s "https://raw.githubusercontent.com/solanyn/home-ops/main/kubernetes/apps/ai/hermes/app/helmrelease.yaml"
```

`raw.githubusercontent.com` returns raw text — perfect for `yq`/`jq` pipelines.

### Walk a recursive tree

```bash
curl -s "https://api.github.com/repos/solanyn/home-ops/git/trees/HEAD?recursive=1" \
  | jq -r '.tree[].path' | grep -iE 'rbac|serviceaccount|init'
```

### Find a file by name

```bash
curl -s "https://api.github.com/repos/solanyn/home-ops/git/trees/HEAD?recursive=1" \
  | jq -r '.tree[] | select(.path | endswith("helmrelease.yaml")) | .path'
```

### List recent commits affecting a path

```bash
curl -s "https://api.github.com/repos/solanyn/home-ops/commits?path=kubernetes/apps/ai/hermes/app/helmrelease.yaml&per_page=5" \
  | jq -r '.[] | "\(.sha[0:7])  \(.commit.author.date)  \(.commit.message | split("\n")[0])"'
```

### Check repo metadata + permissions

```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/solanyn/home-ops" \
  | jq '{name: .full_name, default_branch, perms: .permissions, private}'
```

## Pitfalls

- **Pagination**: `?per_page=100` is the API max; `Link` header in response gives
  the next-page URL. For tree walks >100 entries, follow the Link header or
  constrain the query.
- **Rate limit**: unauthenticated = 60 req/hr per IP; authenticated = 5000/hr.
  Set `-i` on curl to see `X-RateLimit-Remaining`. If you see `< 10`, stop and
  switch to a token.
- **`raw.githubusercontent.com` vs API**: raw returns text; the API returns
  JSON. Use raw for "I want to read this file as YAML/Markdown", use the API
  for "I want to list/walk/discover".
- **Recursive tree depth**: the `?recursive=1` flag returns the **full** tree
  including deleted files (`type=blob`). For very large repos this can be slow;
  prefer narrow queries when you know the path.
- **Reuse the token**: every call to `op read` is a network round-trip + JWT
  verification. Cache it: `export GITHUB_TOKEN=$(op read ...)` once at the top
  of the session, then reuse for the whole conversation.

## Pattern: clone + read + push

For more than a few file reads, cloning the repo locally is faster than N
API calls:

```bash
export GITHUB_TOKEN=$(op read "op://kubernetes/github/GITHUB_TOKEN")
REPO_URL="https://x-access-token:${<EMAIL_ADDRESS>/solanyn/home-ops.git"
git clone "$REPO_URL" /tmp/home-ops
cd /tmp/home-ops && git log --oneline -10
```

This is the workflow that powers in-pod PR creation (see `github-pr-workflow`
skill, Method 3 in `github-auth`). The clone happens once; subsequent
operations are local git.

## Pitfall — heredoc / write_file quoting can mangle interpolated URLs

When you build a git clone URL via shell interpolation inside a heredoc or
write_file call, the platform's content-redaction layer may replace substrings
like `solanyn` or actual email addresses with a placeholder like
`<EMAIL_ADDRESS>`. Symptom: bash throws `unexpected EOF` or
`unexpected token` because the URL ends up truncated at the placeholder.

Workaround: split the URL across two lines / two string concatenations so the
literal text isn't a single contiguous token. Example:

```bash
# BAD — single interpolated string, redactor mangles
git clone "https://x-access-token:${<EMAIL_ADDRESS>/solanyn/home-ops.git"

# GOOD — split, then concatenate at use site
REPO_URL='https://x-access-token:'"$GITHUB_TOKEN"'@github.com/solanyn/home-ops.git'
git clone "$REPO_URL" /tmp/home-ops
```

Same applies to writing scripts that embed owner/repo names with `@` in them —
use intermediate variables and string concatenation rather than embedding the
literal in one quoted string.

## Pitfall — git identity impersonates the user when using their personal PAT

If you `git clone` with a personal PAT and then `git commit` without setting
`git config user.name/email`, GitHub records the commit as the user the PAT
belongs to. Before the first commit, explicitly set a bot identity (or the
github-bot App identity) so commits don't end up attributed to Andrew:

```bash
git config user.name 'github-bot[bot]'
git config user.email 'github-bot[bot]@users.noreply.github.com'
```

For repos where the project `AGENTS.md` codifies a "no agent attribution" rule
(e.g. `solanyn/home-ops`), even the bot identity should be one that GitHub
already recognises — `github-bot[bot]` works because the App is installed on
the repo. See the `Git identity` section in this skill's SKILL.md for the
full App-auth flow.
