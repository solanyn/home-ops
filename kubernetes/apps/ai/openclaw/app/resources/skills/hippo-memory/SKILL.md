---
name: hippo-memory
description: Biologically-inspired persistent memory for AI agents. Use for remembering lessons, recalling context, consolidating memories, and managing memory health. Triggers on "remember this", "remember that", "remind me later", "note this for later", "lets put off planning it", "what do I know about", "memory status", "consolidate", "deferred plan", "backlog", or when starting/ending sessions.
---

# Hippo Memory

Decay by default, retrieval strengthening, sleep consolidation. Zero external API calls, SQLite-backed.

## Session Start (auto via plugin)

The hippo-memory OpenClaw plugin auto-injects relevant context. For manual recall:

```bash
hippo recall "topic description" --budget 3000
```

## Remember

```bash
hippo remember "Mealie PATCH doesn't work for ingredients - use GET then PUT"
hippo remember "vdirsyncer strips a slash from op:// refs - use cat from file instead" --error
hippo remember "Andrew prefers self-hosted open source" --pin
```

Flags:
- `--error` — errors decay slower (stick longer)
- `--pin` — never decays
- No flag — standard 7-day half-life

## Recall

```bash
hippo recall "calendar setup"           # Semantic search
hippo recall "mealie api" --budget 2000  # With token budget
```

## Outcome (after task completion)

```bash
hippo outcome --good   # Recalled memories were helpful
hippo outcome --bad    # Recalled memories were irrelevant
```

This feeds back into retrieval scoring — good outcomes strengthen those memories.

## Sleep (consolidation)

```bash
hippo sleep
```

Compresses episodes into patterns. Run after heavy sessions (10+ new memories) or periodically. The plugin does this automatically when `autoSleep: true`.

## Git Learning

```bash
hippo learn --git                                    # Current repo
hippo learn --git --repos "~/repo1,~/repo2" --days 7 # Multi-repo
```

Extracts lessons from fix/revert/bug commits.

## Status

```bash
hippo status          # Memory health, counts, decay stats
hippo context --auto  # What would be injected right now
```

## Storage

- Local: `.hippo/` in workspace root
- Global: `~/.hippo/` (shared across projects)
- Format: SQLite

## Plugin Config (openclaw.json)

```json
{
  "hippo-memory": {
    "enabled": true,
    "config": {
      "budget": 2000,
      "autoContext": true,
      "autoLearn": true,
      "autoSleep": true,
      "framing": "observe"
    }
  }
}
```

## When to Use Explicitly

- After discovering a gotcha: `hippo remember "..." --error`
- When user says "remember this": `hippo remember "..." --pin`
- After completing a task: `hippo outcome --good/--bad`
- Weekly maintenance: `hippo learn --git && hippo sleep`

## Deferred Plans — "remember this for when I ask again"

When the user defers a task ("let's put off planning it", "remind me about this later", "remember this note somewhere for when I ask again"), the right primitive is `hippo remember --pin` — pinning prevents decay, which is the whole point of a deferred plan.

Structure deferred items as a self-sufficient breadcrumb so a future session can pick them up cold:

```bash
# Good — future-self can act on this
hippo remember "DEFERRED (home-ops): weekly notable-commits cron over home-operations org + starred list — drop onedr0p/home-ops, use solanyn/home-ops. Blocked: GitHub token, schedule, tier, delivery." --pin

# Bad — no context on what's blocked or what triggered it
hippo remember "weekly commits cron"
```

Include four elements whenever possible:
1. **Scope tag** (project / system name in parens) — so similar items cluster
2. **One-line description** of what was being planned
3. **What's blocked or missing** (so you know what to ask for on resume)
4. **Anything that changed during the discussion** (e.g. "use repo X not Y" — easy to lose)

Alternative: the Hermes `memory` tool also accepts deferred items as plain memory entries (target=`memory`). Use that when the item is small enough to fit in the standard MEMORY block (currently capped at `memory_char_limit` in `~/.hermes/config.yaml` — commonly 20,000 chars after recent bumps). Hippo is better for long backlogs because it doesn't compete for the always-injected budget.

## Coexistence with the `memory` Tool

This env runs both:
- **`memory` tool** — small, deterministic, always-injected at the top of every turn as a MEMORY block. Best for stable facts about the user, environment, and deferred plans that should always be visible.
- **`hippo remember`** — larger, semantic, decay-based. Best for gotchas, session-specific lessons, and anything you'd want to look up rather than have always-on.

Rule of thumb:
- **If the future agent should *always* know it** (user prefers X, env quirk Z, deferred plan Y), use `memory`. Even for deferred plans — the always-injected block means the agent sees them before any tool call, which is exactly when they should be visible. The MEMORY budget (currently 20,000 chars by default) supports roughly 50+ short entries before you need to consolidate.
- **If the future agent should know it *when it's relevant to the task*** (a specific API gotcha, a quirk of tool X), use `hippo remember` (with `--pin` for stuff that shouldn't decay).
- **Combine** when the deferred plan has long-form detail that won't fit the MEMORY budget: short breadcrumb in `memory` ("DEFERRED: weekly commits cron — see hippo id X for detail") + full plan in `hippo remember --pin`.

**Pitfall — pre-designing deferred work.** When the user says "let's put off planning it" or "remember this for when I ask again", save the *intent and blockers*, not a full design. It's tempting to enumerate tiers, compare options, design cron templates etc. — don't. The user explicitly deferred the design work; doing it now produces work that may need to be redone when they resume (context changed, requirements shifted). A good deferred entry is: scope tag + one-line description + what's blocked/missing + any "use X not Y" corrections from the conversation. If the user has already done some of the design in the conversation, capture the *decisions made* (e.g. "drop onedr0p/home-ops, use solanyn/home-ops") not the *options considered* — the latter is the work the user asked to defer.

**Pitfall — mid-discussion corrections must survive into the deferred entry.** When the user says "actually use X not Y" or "we're going with this repo, not that one" partway through a conversation that ends in a DEFERRED, those corrections are easy to lose. Re-read the deferred entry before saving and confirm it reflects the *final* state of the conversation, not the early state. Common case: an early "drop onedr0p/home-ops" in the deferred gets accidentally re-captured as the default position, even after the user later says "actually keep onedr0p's list as the source of truth." Always reconcile before the final memory write.

**Pitfall — "DEFERRED" prefix matters.** Without it, a future agent reads the entry as a current state ("Andrew wants a weekly cron") instead of an intent-to-act-later. The prefix is a signal that the item is not active work, it's a breadcrumb for resume. Pair it with explicit blockers ("Blocked: GitHub token, schedule, tier") so the next session knows what to ask for.
