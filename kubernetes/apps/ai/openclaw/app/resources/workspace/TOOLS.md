# TOOLS.md - Local Notes

Skills = how tools work. This file = your specifics, unique to setup.

---

### Fusion (RSS Reader)
- **URL:** `http://fusion.default.svc.cluster.local`
- **Auth:** Session cookie. `POST /api/sessions` with `{"password":""}` → `Set-Cookie: session=...`
- **Password:** Empty (FUSION_ALLOW_EMPTY_PASSWORD=true). If breaks, check FUSION_PASSWORD.
- **Endpoints:**
  - `POST /api/sessions` — login
  - `GET /api/feeds` — feeds + unread counts
  - `GET /api/items?limit=N&unread=true` — items
  - `GET /api/items?feed_id=N` — feed items
  - `GET /api/search?q=term` — search
  - `PATCH /api/items/-/read` — mark read (`{"ids": [1,2,3]}`)
- **All calls need:** `-H "Cookie: session=<token>"`
- **Session expiry:** 30 days
- **Notes:** Many feeds have DNS issues from cluster (i/o timeout).

### File Locations
- **hawow/** — Andrew's dropbox, slow NFS
  - `bank/commbank/shared/` — CommBank shared OFX
  - `bank/westpac/loan/` — Westpac mortgage OFX
  - `bank/westpac/offset/` — Westpac offset OFX
  - Format: OFX (SGML v102). Access: `ssh mac.internal "cat /Volumes/hawow/bank/..."`
- **workspace/** — Fast local disk, actual work

### Obsidian (via Git)
- **Vault:** `/workspace/obsidian-vault/`
- **Sync:** `scripts/obsidian-sync.sh` (bidirectional git)
- **My folder:** `obsidian-vault/Hawow/`
- **Remote:** `git@ssh.forgejo.goyangi.io:andrew/obsidian.git`
- **Conflicts:** Prefers remote. Git identity: `bot-goyangi[bot]`

### OpenCode (dev environment)
- **URL:** `http://mac.internal:4096`
- **SDK:** `scripts/opencode-sdk.mjs`
- **Endpoints:** `/session`, `/session/{id}/message`, `/event` (SSE)
- **Project-scoped:** Add `?projectID=<hash>` to message endpoint. Get hash from `/project`
- **Preferred sessions (REUSE):**
  - **home-ops:** `ses_39c584cf8ffe2GPLj5AplvPoIx` — ⚠️ CONTEXT LIMIT
  - **mono:** `ses_39c584ce3ffeaeUfbBOJ8GZq84` (project: d58bfc594e7bc7312f57c0635f4b9c135654bb8f)
  - **yield (latest):** `ses_3254df15effeMFDY306E64emRu` — Nix+Bazel done, clean
  - **yield (stuck):** `ses_3258b5b25ffe9v1Md5HO8w32hl` — deadlock, don't reuse
  - **yield (original):** `ses_3267262e3ffeyNktR6ZgrmK6ki` — superseded
- **Notes:** REUSE sessions. Check with Andrew before messaging.
- **Work OpenCode:** removed (chisel tunnel dropped during headscale→tailscale migration). Previously `http://work.opencode.goyangi.io` via SOCKS `chisel.network.svc.cluster.local:1080`.
- **Detailed notes:** `memory/opencode-notes.md`

### OpenClaw Nodes
- **Exec:** `tools.exec.node` unbound — target either with `node=Mac Mini` or `node=Work Mac`
- **YOLO mode:** Both nodes have `exec-approvals.json` with `security: full, ask: off, askFallback: full`

**Mac Mini** (personal)
- **Device hash:** `438c3e57...`
- **LaunchAgent:** `ai.openclaw.node`
- **Gateway:** `127.0.0.1:18789` (via port-forward `com.local.openclaw-portforward`)
- **Status:** Paired, connected, YOLO exec ✅

**Work Mac** (Ericsson, user `ecehdna`)
- **NO openclaw node** — removed due to CrowdStrike Falcon + Jamf + Palo Alto GlobalProtect on device
- **NO remote access** — `ssh work.internal` removed (relied on chisel, ripped out cluster-side too). Falcon flagged chisel as C2 (Katelynn from security DM'd 2026-05-02)
- **Only path:** Andrew physically at the laptop. Anything that needs work mac = ask Andrew to run it

**In-cluster kubectl fallback** (when sandbox loses ssh + `host=node` disconnected)
- Sandbox pod has SA token at `/var/run/secrets/kubernetes.io/serviceaccount/token`
- Pod namespace: `ai`, SA: `openclaw`
- Works via cluster API: `10.43.0.1:443`
- Pattern:
  ```bash
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  kubectl --token=$TOKEN --certificate-authority=$CA --server=https://10.43.0.1:443 get hr -A
  ```
- Permissions: broad read, some patch (deploys, HRs), NO delete on PVCs/volsync/pocketid CRDs — escalate to mac.internal for those

### Mac Mini Local Models
- **LLM:** `http://mac.internal:8080` — `mlx-community/Qwen3.5-9B-4bit` (Qwen 3.5 9B 4-bit, mlx_vlm 0.6.3)
  - Served model name: `mlx-community/Qwen3.5-9B-4bit`
  - Features: vision, tool calling (qwen3.5 parser), thinking mode, continuous batching, prefix cache
  - ~6GB model weight, safe up to ~8-10K context on 16GB Mac Mini
  - OpenAI + Anthropic API compatible
  - LaunchAgent: `com.mlx.llm` (mlx_vlm.server)
  - Previous: gemma-4-12B-it-qat-4bit (caused kernel panics from memory exhaustion at long contexts)
- **STT+TTS:** `http://mac.internal:8000` — Parakeet TDT 0.6B + Kokoro-82M
- **Kiro Gateway:** `http://mac.internal:8001` — Claude Opus 4.6 proxy

### iCloud CalDAV (Reminders)
- **CalDAV home:** `https://p108-caldav.icloud.com:443/1449763261/calendars/`
- **Auth:** Basic, `op://kubernetes/icloudpd/ICLOUD_USERNAME` + `ICLOUD_PASSWORD`
- **Reminders list:** `2ab8b9d8-4563-4508-81e4-9a0886ff0b3e` — legacy, NOT visible in modern app
- **Family list:** `6FAD7116-62C0-47BB-B644-6A5DB430E3D9`
- **Calendars:** Home, Work, Family, Calendar, Kubeflow Community
- **VTODOs:** Server-side only — modern Reminders uses CloudKit, ignores CalDAV

### Remindctl Bridge (Apple Reminders)
- **URL:** `http://127.0.0.1:9876` (mac.internal localhost only)
- **Access:** `ssh mac.internal "curl -s http://127.0.0.1:9876/..."`
- **Endpoints:**
  - `GET /health`, `GET /list`
  - `POST /add` — `{"list": "Reminders", "title": "...", "due": "...", "notes": "...", "priority": 1}`
  - `POST /complete` — `{"list": "Reminders", "title": "..."}`
- **Lists:** Personal, Reminders, Work
- **LaunchAgent:** `com.goyangi.remindctl-bridge` (GUI domain for TCC)
- **Notes:** SSH can't access Reminders (TCC blocks sshd). Bridge runs in GUI session.

### Google Workspace (gogcli)
- **Status:** ✅ Installed via brew, authed as `andrewchen1520@gmail.com`
- **Binary:** `/opt/homebrew/bin/gog` (v0.12.0)
- **Access:** Node exec ONLY (keychain needs GUI session, SSH can't access)
- **Account:** `andrewchen1520@gmail.com` (default profile, full scopes)
- **Custom OAuth client:** `personal` (Desktop type, fixes redirect_uri_mismatch)
- **Skill:** `skills/google-workspace/SKILL.md`
- **Usage pattern:**
  ```
  exec host=node node="Mac Mini"
  export PATH=/opt/homebrew/bin:$PATH; gog gmail search "is:unread" --json --max 10 --client personal
  ```
- **Note:** `gog auth list` fails over SSH (keychain TCC). Must use node exec.

### Gmail (Direct API)
- **Used by:** `scripts/email-check.py` (cron job)
- **Auth:** OAuth2 refresh token (Desktop client, no mac.internal dependency)
- **Creds:** `.secrets.json` cache + 1Password `gmail-oauth` (GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN)
- **Endpoint:** `https://gmail.googleapis.com/gmail/v1/users/me/messages`
- **Note:** Runs entirely in sandbox. No keychain/SSH/gog needed.
- **Mac paths:** `uv` at `/opt/homebrew/bin/uv`, `kubectl` at `/opt/homebrew/bin/kubectl`
- **Cluster access:** `ssh mac.internal "export PATH=/opt/homebrew/bin:\$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl ..."`
- **mlx-lm:** `~/mlx-server/.venv` (uv, no pip). Git main 0.31.2+gemma4.

### Agent Gateway (agentgateway)
- **URL:** `https://gateway.goyangi.io`
- **LBIPAM:** `192.168.69.130` / `fd5d:a293:f321:69::130`
- **Version:** v1.1.0 (no healthPolicy support yet)
- **LLM Routing:** Unified `/v1/chat/completions` endpoint. Model selected via `model` field in request body. Available models (from `/v1/models`): `claude-opus-4.6` (→ GLM-5 → MiniMax → Gemma fallback), `claude-opus-4.7`, `claude-opus-4.5`, `claude-sonnet-4.6`, `claude-sonnet-4.5`, `claude-sonnet-4`, `claude-haiku`, `gemma`, `deepseek`, `minimax-m2.5`, `minimax-m2.1`, `glm-5`, `qwen3-coder`
- **Model Discovery:** `GET /v1/models` returns available models (CronJob-synced from HTTPRoute config)
- **Audio:** `/v1/audio/transcriptions` (Parakeet STT), `/v1/audio/speech` (Kokoro TTS) — via `mlx-audio` ExternalName → mac.internal:8000
- **MCP:** Removed (CLI tools are more effective)
- **Auth:** API key required (Strict mode). Keys: openclaw, personal, work. From 1Password `agentgateway`.
- **Config:** `kubernetes/apps/network/agentgateway/` in home-ops
- **CRDs:** `AgentgatewayBackend`, `AgentgatewayPolicy` (agentgateway.dev/v1alpha1)
- **Backends:** Opus/Kiro → mac.internal:8001 (kiro-gateway) with GLM-5 → MiniMax → Gemma fallback chain. Haiku → mac.internal:8001. Gemma → mac.internal:8080.
- **Grafana:** Dashboard `agentgateway-llm-cost` in network folder (18 panels: cost, tokens, latency, TTFT)
- **Skill:** `skills/kgateway/SKILL.md`

### Home Assistant
- **URL:** `http://home-assistant.default.svc.cluster.local:8123`
- **Token:** 1Password `home-assistant` (HASS_TOKEN). User: `hawow`
- **Speakers:** `media_player.dining_room_speaker` (Chromecast, works). `media_player.living_room` (broken, avoid)
- **TTS:** Kokoro via mac.internal:8000 → mp3 → HA play_media

### Grafana
- **URL:** `http://grafana-service.o11y.svc.cluster.local:3000`
- **Token:** 1Password `grafana` (GRAFANA_SA_TOKEN), Editor role

### GitHub CLI (gh)
- **Auth:** `solanyn` via PAT from 1Password `git` (GITHUB_TOKEN). 5000/hr.
- **Git commits:** `git config user.name "bot-goyangi[bot]"` + `user.email "194625711+bot-goyangi[bot]@users.noreply.github.com"`

### Work Mono (Forgejo Mirror)
- **URL:** `https://forgejo.goyangi.io/work/mono.git`
- **Notes:** Synced from GitLab. READ ONLY — don't push.

### Forgejo API
- **CLI:** v0.4.0 needs glibc 2.39, container has 2.36 — won't run
- **Workaround:** REST API with `op read "op://kubernetes/forgejo/FORGEJO_TOKEN"`
- **Base:** `http://forgejo-http.default.svc.cluster.local:3000/api/v1/`

### Atuin (Shell History)
- **Key:** `op://kubernetes/atuin/ATUIN_KEY` (base64 format, 32 bytes)
- **Notes:** v18+ requires base64 key, not mnemonic. Injected via nix-darwin.

### Continuwuity (Matrix)
- **URL:** `https://matrix.goyangi.io` / `http://continuwuity.default.svc.cluster.local:6167`
- **User:** `@andrew:goyangi.io`. Password: 1Password `matrix` (MATRIX_BOT_PASSWORD)
- **Registration:** Disabled (token-gated)

### Redlib (Reddit)
- **URL:** `http://reddit.goyangi.io` (internal only). No persistence.

### Baikal (CalDAV/CardDAV) — REMOVED
- Migrated to iCloud CalDAV. Baikal and Rustical both decommissioned.
- See iCloud CalDAV section above and `skills/caldav-calendar/SKILL.md`

### InfluxDB (Health Data)
- **URL:** `http://influxdb.storage.svc.cluster.local:8086`
- **Org:** `home`, **Bucket:** `health`
- **Token:** 1Password `apple-health-ingester` (APPLE_HEALTH_INGESTER_INFLUXDB_TOKEN)
- **Notes:** Apple Health synced every 6h. 7 days retention.

### Work GitLab (Rosetta)
- **API:** `https://gitlab.rosetta.ericssondevops.com/api/v4`
- **Auth:** mTLS + PAT
- **Certs:** `op read "op://kubernetes/gitlab-mirror/GITLAB_MIRROR_CLIENT_CERT"` + `GITLAB_MIRROR_CLIENT_KEY` → `/tmp/devops/`
- **Token:** 1Password `gitlab-mirror` (GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN). User: `andrew.b.chen`
- **Curl pattern:**
  ```bash
  mkdir -p /tmp/devops
  op read "op://kubernetes/gitlab-mirror/GITLAB_MIRROR_CLIENT_CERT" > /tmp/devops/client.pem
  op read "op://kubernetes/gitlab-mirror/GITLAB_MIRROR_CLIENT_KEY" > /tmp/devops/client-key.pem
  chmod 600 /tmp/devops/client-key.pem
  TOKEN=$(op read 'op://kubernetes/gitlab-mirror/GITLAB_MIRROR_PERSONAL_ACCESS_TOKEN')
  curl -s --cert /tmp/devops/client.pem --key /tmp/devops/client-key.pem -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.rosetta.ericssondevops.com/api/v4/..."
  ```
- **Key projects:** `sd-moai-nbnms/ml-cloud/mono`, `sd-moai-syd/api-gateway` (SPG), `sd-moai-nbnms/automation/asrt`, `MOAICAC/bss/eps/cu-anza/nbn/eps`, `sd-moai-syd/nmtool-dev-automation/portnmtool`, `sd-moai-syd/gke-deployments-autodev/api-gateway-deploy-gke`

### Summarize CLI
- **Path:** `/home/node/.local/bin/summarize`
- **Usage:** `summarize "https://url" --length short --plain`
- **Env:**
  - `NODE_TLS_REJECT_UNAUTHORIZED=0`
  - `OPENAI_BASE_URL=https://gateway.goyangi.io/v1`
  - `OPENAI_API_KEY=<from 1Password agentgateway-apikey>`
  - `PATH="/workspace/.bun/bin:/tmp:$PATH"` + `/tmp/node` → bun symlink
- **Note:** Gateway now requires real API key (Strict auth). `dummy` no longer works.

### home-ops Repo
- **GitHub:** https://github.com/solanyn/home-ops

### Kiro IDE (Work Laptop)
- **DB:** `/Users/ecehdna/Library/Application Support/kiro-cli/data.sqlite3`
- **Access:** ❌ BROKEN — `ssh work.internal` removed (chisel security incident 2026-05-04). No remote path to work laptop
- **Tables:** `conversations_v2` (full chat JSON), `history` (shell commands), `auth_kv`, `state`
- **Digest script:** `scripts/work-kiro-digest.py` — parses over SSH, **currently dead**
- **Cron:** `work-activity-digest` (5pm weekdays) — **likely failing**, needs disabling or re-architecting

### Mermaid
- **Script:** `scripts/mermaid.mjs`
- **Usage:** `echo "graph TD\n  A --> B" | npx tsx scripts/mermaid.mjs` (add `--svg` for SVG)

### calsync (Outlook → iCloud CalDAV)
- **Script:** `~/nix-darwin/scripts/calsync.py` on work mac (managed locally by Andrew, no remote access since chisel removal)
- **LaunchAgent:** `com.local.calsync` (every 15 min, GUI session for op)
- **Log:** `/tmp/calsync.log`
- **Chain:** Outlook/Exchange → macOS Calendar.app (Internet Accounts) → icalpal (JSON) → calsync.py → iCloud CalDAV (work)
- **Secrets:** `op run` with SA token from `~/.op-token`. Env: `CALDAV_URL`, `CALDAV_USER`, `CALDAV_PASSWORD`
- **Filters:** Only syncs `Calendar` calendar (Exchange). Excludes: Birthdays, Subscribed, Reminders types. Excludes titles: peer programming, lunch, nearly home time (time blockers)
- **icalpal output fields (key ones):**
  - `sctime`/`ectime`: formatted with offset (`2026-04-22 09:00:00 +1000`) — **use these for times**
  - `sseconds`/`eseconds`: epoch seconds — fallback
  - `sdate`/`edate`: relative strings (`today`, `tomorrow`, `day after tomorrow`) — **never use for time extraction**, only human display
  - `start_tz`/`end_tz`: IANA timezone name (`Australia/Sydney`) or `GMT`/`_float`
  - `start_date`/`end_date`: macOS CoreData epoch (2001-01-01 based) — don't use
  - `duration`: seconds (0 for CalDAV events that lost duration)
  - `store`: `Exchange` (native) vs iCloud CalDAV
  - `UUID`: native Calendar.app UUID — use for stable UID generation
  - `attendees`: list of strings (not dicts), may contain None
  - `all_day`: 0 or 1

### vdirsyncer + khal (CalDAV)
- **venv:** `/workspace/.venvs/vdirsyncer/`
- **Configs:** `/workspace/.config/vdirsyncer/config`, `/workspace/.config/khal/config`
- **Sync:** `scripts/caldav-sync.sh`
- **Calendars:** Home, Work (via iCloud CalDAV)
- **Auth:** iCloud app-specific password via `op://kubernetes/icloudpd/ICLOUD_PASSWORD`
- **Usage:**
  ```bash
  scripts/caldav-sync.sh  # sync
  export XDG_CONFIG_HOME=/home/node/.openclaw/workspace/.config
  /home/node/.openclaw/workspace/.venvs/vdirsyncer/bin/khal list today 7d  # view
  ```
- **Note:** Config paths must use `/home/node/.openclaw/workspace/` not `/workspace/` (no symlink in main container)
- **⚠️ ALWAYS sync before reading:** Run `scripts/caldav-sync.sh` before any `khal list` query (briefings, heartbeats, any calendar check). Data goes stale fast — caused wrong-day meeting bug 2026-05-12

### Scrib (Meeting Transcription)
- **URL:** `http://scrib.default.svc.cluster.local:8090`
- **Audio service:** `http://scrib-audio.network.svc.cluster.local:8002`
- **API:** `/v1/meetings` (list), `/v1/meetings/{uuid}` (transcript)
- **Response:** `{segments: [{speaker, start, end, text}], template, num_speakers, duration_s, status}`
- **Speakers:** SPEAKER_0..N (unnamed, need Andrew to identify)
- **Templates:** `standup` (only one seen so far)
- **Notes:** Lots of duplicate entries (re-processing?). Pick latest `recorded_at` for a given `name`

### Ontology (Knowledge Graph)
- **Script:** `scripts/ontology.py` — **Graph:** `memory/ontology/graph.jsonl`
- **Seeded:** 12 people + 7 projects + 13 relations
- **Usage:** `python3 scripts/ontology.py list`, `query --type Person`, `related --id p_andrew`

### agent-browser
- **Path:** `/workspace/.bun/bin/agent-browser`
- **Usage:** `agent-browser open <url> && agent-browser snapshot -i`
- **Notes:** Headless only in sandbox.

### Mealie Upload
- **Script v2:** `scripts/mealie-upload-v2.py` (proper schema, GET+PUT)
- **Notes:** PATCH silently drops ingredients/instructions. Must GET then PUT.
