---
name: livesync-bridge
description: Sync and edit notes in the Obsidian vault via the forgejo-backed git repo. Use for reading/writing notes to Andrew's vault, health checks, and troubleshooting. Triggers on obsidian, vault, forgejo, sync, notes.
---

# Obsidian Vault via Forgejo (git-backed)

The Obsidian vault is a private git repo on the in-cluster Forgejo. Edits push to `main` and Obsidian's local sync plugin pulls the remote on the Mac.

## Architecture

```
Obsidian app ↔ (local file sync plugin) ↔ forgejo.goyangi.io/andrew/obsidian.git
                                                          ↑
                                            (this pod clones + edits + pushes)
```

- **Remote:** `https://forgejo.goyangi.io/andrew/obsidian.git` (private)
- **Auth:** `op read 'op://kubernetes/forgejo/FORGEJO_TOKEN'` → `x-access-token:${<EMAIL_ADDRESS>/...`
- **Vault root on disk:** the cloned `vault/` directory
- **Obsidian structure marker:** `vault/.obsidian/` (app.json, plugins/, etc.) — confirms the clone is the real vault
- **Default branch:** `main`

## Discovering the Vault

The vault is private — `repos/search` returns 0 hits. Find it via `user/repos`:

```bash
TOKEN=$(op read 'op://kubernetes/forgejo/FORGEJO_TOKEN')
curl -sk -H "Authorization: token $TOKEN" \
  "https://forgejo.goyangi.io/api/v1/user/repos?limit=50" \
  | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    if 'obsidian' in r['full_name'].lower(): print(r['full_name'])
"
# → andrew/obsidian
```

## Writing Notes — Pull-Before-Write (Critical)

**Always pull before writing.** Other processes (LiveSync on the Mac, your TUI, the curator) can land commits between pulls. If you write on a stale local, the push gets rejected and you lose work or create a merge mess.

```bash
# 1. Clone (once, if not already)
cd /opt/data/workspace
GIT_TERMINAL_PROMPT=0 git clone \
  "https://x-access-token:${<EMAIL_ADDRESS>/andrew/obsidian.git" \
  vault 2>&1 | tail -5

# 2. ALWAYS: pull before editing
cd vault
git pull --rebase origin main 2>&1 | tail -3
# (handle conflicts if any)

# 3. Edit
cat > Work/my-note.md <<'EOF'
# Title
content
EOF

# 4. Commit + push
git add Work/my-note.md
git commit -m "Add my note"
git push origin main
```

The `git push` step is the test — if it rejects with "non-fast-forward", you forgot to pull. Fix: `git pull --rebase` then re-push.

### Token redaction in bash

The token gets mangled by some redaction systems. Always use this pattern:

```bash
TOKEN=$(op read 'op://kubernetes/forgejo/FORGEJO_TOKEN')
URL='https://x-access-token:'"$TOKEN"'@forgejo.goyangi.io/andrew/obsidian.git'
GIT_TERMINAL_PROMPT=0 git clone "$URL" vault
```

The `URL='...' "$TOKEN" '...'` concatenation avoids bash variable interpolation issues inside the URL.

## Reading Notes

```bash
ls /opt/data/workspace/vault/                    # top-level folders
ls /opt/data/workspace/vault/Work/               # Work/ subfolder
find /opt/data/workspace/vault -name '*.md' | head
cat /opt/data/workspace/vault/Work/foo.md
```

**Don't use the Forgejo contents API to enumerate** — for private repos, it requires a ref query and often returns `{"message":"","url":"..."}`. Just clone (or read local clone) and use `find`/`ls`.

## Conventions (Andrew's vault structure)

- **`Work/`** — work notes, project docs, IPM prep, work context
- **`Work/Activity/`** — daily logs, time-tracking
- **`Work/Wind-down/`** — end-of-day summaries
- **`Work/Brag Doc/`** — performance review material (Q1, etc.)
- **`Hawow/`** — personal AI assistant stuff (Hawow is the personal agent name)
- **`Recipes/`, `Tech/`, `Wiki/`, `Templates/`, `Reference/`, `Personal/`** — general purpose
- **`.obsidian/`** — Obsidian app config (don't touch)

When writing for work context, use `Work/<topic>.md`. For personal agent stuff, `Hawow/`. For general knowledge, pick the matching folder.

## Health Check

```bash
ls /tmp/obsidian-pull/vault/.obsidian/   # confirm marker exists
git -C /tmp/obsidian-pull/vault log --oneline -5   # recent activity
```

If the local clone is missing or stale (`.obsidian/` absent or no recent commits), re-clone.

## Troubleshooting

### Token redaction mangles URL

If `git clone` fails with "fatal: could not read Username", the redaction system replaced your token. Use the `URL='...'"$TOKEN"'...'` concatenation pattern above. The `$TOKEN` form with curly braces `${TOKEN}` is more often mangled than the bare `$TOKEN` concat.

### API returns 0 bytes for archive

```bash
# This returns 0 bytes on private forgejo:
curl -sk -H "Authorization: token $TOKEN" \
  "https://forgejo.goyangi.io/api/v1/repos/andrew/obsidian/archive/main.tar.gz"
# → use git clone instead, not the tarball API
```

The Forgejo archive API behaves inconsistently on private repos. Just clone.

### Push rejected (non-fast-forward)

You forgot to pull. `git pull --rebase origin main` then push again. If the rebase has conflicts, your work might be on a feature branch — `git status` to see.

### Forgejo returns 503

The dragonfly-backed forgejo instance is up but the backend is degraded. Wait 30s and retry; if persistent, check the dragonfly health separately. The vault will still be there when forgejo recovers.

### `op` says "permissions too broad"

`op` requires `/opt/data/home/.config/op` mode 700 and `config` file mode 600. Fix:

```bash
chmod 700 /opt/data/home/.config/op
chmod 600 /opt/data/home/.config/op/config
```

## Cleanup

The local clone (`/opt/data/workspace/vault` or `/tmp/obsidian-pull/vault`) is large (tens of MB of markdown). After you're done with a session, **don't leave it lying around**. Either:

- `rm -rf /opt/data/workspace/vault` if you cloned to workspace
- `rm -rf /tmp/obsidian-pull` if you cloned to /tmp

The remote is the source of truth — the local clone is ephemeral. Re-clone next session if needed.

## DO NOT

- **DO NOT** edit the remote via `git push --force` to a non-personal branch
- **DO NOT** write directly to CouchDB or any sync backend — the vault repo IS the source of truth
- **DO NOT** skip `git pull` before editing — you'll lose work when push is rejected
- **DO NOT** clone the vault if it's already cloned in another working tree — use that one
- **DO NOT** treat the local clone as the source of truth — Obsidian's Mac-side copy and the forgejo remote are
