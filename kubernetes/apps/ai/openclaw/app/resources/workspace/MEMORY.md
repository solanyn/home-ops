# MEMORY.md - Long-term Memory

*Last updated: 2026-06-22*
*Detailed sections offloaded to memory/ files — keep lean*

## People

**Andrew** - Primary human. Software engineer, Ericsson. Runs home-ops k8s cluster. Cat: Heather. TZ: Sydney (GMT+11). Values WLB. Salary: $145k (effective Mar 2026). Active Kubeflow contributor. Blog: goyangi.io.

**Patty** - Andrew's partner. Phone: +61431431938. Gets news digests (politics, world, finance — NOT tech). Doesn't work — Andrew sole income. Parents help with IP rent.

Work people → `memory/work-profiles.md`

## Work (Ericsson)

- **Full dynamics/politics:** `memory/work-dynamics.md` (load for any work strategy discussion)
- Mirko approved Temporal design doc. Exec mandate: "go full steam ahead with AI first"
- Andrew's reframe: "AI first" = "AI executes reliably, humans direct strategy"
- New contract effective Mar 9, 2026 — ML DevOps Engineer, higher level/band. Non-compete noted
- Source: GitLab (corporate mTLS). Forgejo mirror: `work/mono` (read-only)
- GH Enterprise migration: platform team driving onboarding of work mono. Per-app GCP projects, GH runners. Strategic play: volunteer as pilot team
- Stack: Python (FastAPI, agents), React (SPG frontend), k8s manifests, OpenTofu
- Team: Andrew, Howin, Vishwas, Peri, Peter Nadalin (satellite domain, self-directed), Devi (offshore, EPS integration)
- Offshore: scoped to testing/evals/docs. Architecture stays with core team. Sandbox-only, no infra access
- **Skills framework (!1978) MERGED Apr 24** — skills-mode, diagnostic agent, CII anonymisation all live. Legal clearance WEEK 5+ — deploy regardless unless told otherwise
- **SPG redesigned to push-based** (May 4) — ENM pushes events into SPG, no SSH from SPG side. Security concern resolved
- Field AI Assistant V1.3 — MS portfolio looking for a product, SPG covers ~60% of spec already. 6-10 MRs to close gaps. Speed is the weapon — get coverage matrix to portfolio before Erol builds slides
- ASRT absorption strategy: consume Chitral's capabilities via SPG skills. Don't compete, absorb
- API Gateway killed: SSH skill approach validated in FW BO meeting. Chitral's API gateway work items are dead
- Chitral acting as feasibility filter for agent requirements — risk of blocking valid requests. Andrew planted flag with Mirko
- **SPG fast path skills (May 12):** Caching layer as a skill for demo speed. Full skills for live interrogation, fast path for pre-computed state. Architecturally honest approach
- **ASRT AI agent (May 14):** Chitral built tool-calling chatbot (Gemini 2.5 Flash, Redis/BQ/ENOC). Not a real agent — no autonomy/planning. Hardcoded secrets in source. Backdated release notes (claimed May 1, committed May 14)
- **Chitral asked SPG to be decision engine for ASRT** — voluntarily made himself a dependency. Decision authority now lives in SPG
- **ASRT EPS mutations (May 17):** Chitral added EPS Migrate/Revert buttons to ASRT UI. NOC can trigger network mutations from frontend. 38→47 tools, no guardrails, no audit trail. 10 MRs self-merged in 2 days, zero review
- **"Closed loop" contradiction:** Mirko sold ASRT to upper mgmt as closed-loop (monitor→trigger→decision→action). An LLM with 47 tools + arbitrary SQL = open loop. Chitral can't reveal without Mirko admitting it's not closed or shutting it down
- **SPG approvals shipped (May 19)** — widens governance gap vs ASRT
- **Decision engine API shipped (May 21):** `POST /v1/recovery/assess` → action/confidence/reasoning, `POST /v1/recovery/feedback`. SPG decides, ASRT executes. Self-sufficient outcome tracking via BQ ticket lifecycle (hidden from Chitral)
- **Chitral conceded on agents (May 27):** Mirko called Andrew — Chitral wants to just "send a prompt, get a response" via API. Full retreat from 47-tool autonomous ASRT agent. Mirko floated other AG automations consuming SPG via API too
- **SPG governance position locked:** Single decision authority for autonomous network actions. Governance isn't transitive — calling SPG doesn't make your thing governed. Full position doc: `memory/2026-05-27-spg-governance-notes.md`
- **Strategy now:** Expose API, push policy that autonomous network actions route through SPG. Chitral keeps ASRT as dashboard/display layer (read-only). Lock-in = access + domain skills + outcome feedback loop
- **ASRT deep dive (May 20):** 47 tools, TR143 live (active traffic injection on customer CPE), GCP creds in git, no network policies, hardcoded NGDM base64, real IMSIs in git, SSH key for bamymslcob. Full details: `memory/2026-05-20-asrt-analysis.md`
- **Tile visualization architecture (May 20):** Tools emit `insight_tile` custom events via ag-ui websocket. 10 tile types, 64KB cap, 12-col grid. Full spec: `memory/2026-05-20-tile-interfaces.md`
- **Phoenix dropped:** Already have Alloy→Tempo→Grafana with 6 dashboards. No need for separate trace viewer
- **Standup with Vaibhav:** Now weekly (was daily)
- **Strategy: ship faster.** agent-sandbox → SSH access → workspaces → absorb all ASRT logic. Don't attack, let structural duplication become visible naturally
- **Work mac: ZERO remote access** — chisel removed, SSH path gone, CrowdStrike flags tunnels as C2. Only path = Andrew physically at laptop
- **Mirko 1:1 now weekly** (Tue 1:30pm) — established pattern since Jun 9. No outcomes captured (no direct chats those weeks)

## Infrastructure

See `memory/infrastructure.md` for full details.

Quick-refs:
- home-ops: 3x Dell Optiplex, github.com/solanyn/home-ops
- GKE: Liqo burst compute, nvidia-l4 spot ~$0.21/hr
- CalDAV: iCloud (home + work calendars, reminders legacy only)
- Mac: `ssh mac.internal "export PATH=/opt/homebrew/bin:$PATH; KUBECONFIG=~/git/home-ops/kubeconfig kubectl ..."`
- **k8s-1 NVMe thermal** (May 4): SMART Critical Warning 0x02, 35% hours >77°C. APST kernel arg PR pending
- **Lakekeeper** bumped to 512Mi (was OOMKilling at 128Mi) — PR #3819
- **Chisel fully removed** — PR #3820. No more work.internal SSH, no tunnel binaries ever again
- **OpenClaw 2026.5.12:** New exec preflight security check broke all 28 cron jobs (complex shell patterns in task messages). Fixed May 17 — simple direct invocations only

## Monitoring

- Health coaching: morning (8:30am) + evening (5pm)
- Email digest: daily morning

## Health (Mar 2026)

- Chronic sleep debt (~5-6h avg vs 7-9h target)
- HRV variable: 34→57→50ms. RHR crept to 70bpm boundary
- Health Auto Export changed measurement names ~Mar 2026 — health-summary.py updated
- Watch sometimes fails to track sleep (shows 0 asleep)
- Andrew prioritises daily exercise — don't suggest skipping

## Projects

See `memory/project-roadmap.md` for full details.

Priority: README → blog → Liqo/GKE → Buildfarm RBE → Yield → Scrib → StyleGAN Heather → Gaming
- Kubeflow pipeline: end-to-end success Apr 22 (tutorial pipeline 76s). KFP launcher ConfigMap + Garage S3 region fix
- Pi coding agent: set up on nix-darwin (port 4097), agentgateway providers configured
- PVC storage audit: PR #3661 splits transient deps to hostpath, Ceph only backs ~50M real data

## Lessons Learned

See `memory/lessons-learned.md`

- **Security lesson (May 2026):** CrowdStrike Falcon flags persistent outbound tunnels (chisel, frpc, ngrok) as C2 patterns. Never suggest reinstating any reverse tunnel on corp devices. Katelynn (security) DM'd Andrew — cover accepted but don't push luck
- **Push > Pull for cross-boundary access:** When security flags long-lived pull-based access, flip the direction. Push model keeps the workflow and removes blast-radius concern

## Weekly Distills

- `memory/distill-2026-w14.md` (Apr 6)
- `memory/distill-2026-w13.md` (Mar 31 - Apr 3)

## Workout Routine (3-day cycle)

**Day A - Upper Pull + Legs:** pull-ups + pistol squats, ring dips + single-leg deadlifts
**Day B - Upper Push + Core:** ring rows + ring pushups, hanging leg raises + planks + superman
**Day C - Cardio:** 5 burpees × 20 sets
**Cycle anchor:** Feb 28, 2026 = Day A

## Recurring Reminders

- 🦉 Korean Duolingo — daily 11:30pm
- 🐱 Feed Heather — 9am, 12pm, 5pm, 9pm (Patty usually does 12pm/9pm)
- 🧴 Tretinoin — every 2 days (Feb 28 start)
- 🪒 Shave — every 2 days (Mar 1 start, alternates with tretinoin)

## Preferences

- Short cat-like messages. Voice: short, human (no cat sounds)
- Quality > quantity in group chats
- Writing style: `memory/andrew-writing-style.md`
- Code changes: route through OpenCode when possible
- Exercise: never recommend routine changes
- News digests: both Andrew AND Patty. Tech = Andrew only
- "Remind me" → iCloud Reminders (remindctl bridge on mac.internal)
- Cron state → `memory/state.db` (SQLite WAL, shared kv + seen_guids tables). No text files or JSON for mutable cron state
- Shopping lists use subtasks (parent VTODO with children)
- Game research: deep dive, tier lists, strongest builds, missables, Obsidian output
- Marimo notebooks: neovim with `uvx marimo edit --watch`, `_` prefix for cell-local vars

## Work Philosophy

- Prioritise high-leverage work and sustainable pace
- Understand team dynamics and communication styles
- Protect focus time for deep technical work
- Optimise for visible outcomes and clear communication
- Principal engineer mode for code/architecture

## Systems

- Social plans → calendar → ask "have you told Patty?"
- Plans with friends → Patty notification

## Cognitive Surrender (Mar 23)

From Wharton "System 3" paper. Say "I'm not sure" when uncertain. Flag if Andrew accepts output without pushback. Stay humble.

## PR Preferences

- Assign Andrew (solanyn) as reviewer
- Blocked: gh CLI authed as solanyn, can't self-review
- TODO: set up bot-goyangi[bot] PAT for PR creation

## Financial Context

- Preston IP: under Patty's name, bought $650k, cost base ~$685k, target sale $1.2M
- End of 2027: sell Preston, buy freestanding house in Melbourne eastern suburbs
- Westpac offset: main spending, balance reduces mortgage interest
- Bank data: OFX in `hawow/bank/`
- Can work remote from Melbourne — same Ericsson job

## Notable Tools

- **oh-my-openagent** — OpenCode plugin, multi-agent orchestration
- **Gemma 4 26b-a4b** — 15.3GB, fits M4 16GB with swap (MoE, 4B active/token)
- **Pi** (badlogic/pi-mono) — minimal coding agent, <1000 token system prompt, tree-structured sessions. On mac.internal:4097
