---
name: opencode
description: Interact with OpenCode dev environment on mac.internal. Use for sending coding tasks, managing sessions, checking project status, or delegating work to OpenCode's AI agent. Triggers on opencode, coding session, dev task, send to opencode, opencode session.
---

# OpenCode Skill

Control OpenCode (charmbracelet AI coding agent) running on Andrew's Mac Mini via REST API.

**Status:** Active. Andrew uses OpenCode 1.3.10 via homebrew.

## Connection

- **URL:** `http://mac.internal:4096`
- **Auth:** None required from cluster
- **SDK wrapper:** `scripts/opencode-sdk.mjs`

## SDK Wrapper (preferred)

```bash
# List all projects (get projectID hashes)
node scripts/opencode-sdk.mjs list-projects

# List all sessions (global, not project-filtered)
node scripts/opencode-sdk.mjs list-sessions

# Create a new session
node scripts/opencode-sdk.mjs create-session <projectId> [title]

# Get session details
node scripts/opencode-sdk.mjs get-session <sessionId>

# Get messages from a session
node scripts/opencode-sdk.mjs get-messages <sessionId>

# Send a prompt
node scripts/opencode-sdk.mjs prompt <sessionId> <message>
```

## Raw API Endpoints

All endpoints are at `http://mac.internal:4096` — no `/api` prefix.

### Projects

```bash
# List projects (returns array with id hashes and worktree paths)
curl -s http://mac.internal:4096/project | jq .
```

### Sessions

```bash
# List all sessions (always global, ignores projectID)
curl -s http://mac.internal:4096/session | jq .

# Get session details
curl -s http://mac.internal:4096/session/<sessionId> | jq .

# Create session
curl -s -X POST http://mac.internal:4096/session \
  -H 'Content-Type: application/json' \
  -d '{"projectID":"<hash>","title":"my task"}'

# Get messages in session
curl -s http://mac.internal:4096/session/<sessionId>/message | jq .
```

### Sending Messages

```bash
# Send a prompt to a session
curl -s -X POST "http://mac.internal:4096/session/<sessionId>/message" \
  -H 'Content-Type: application/json' \
  -d '{"parts":[{"type":"text","text":"your prompt here"}]}'

# Project-scoped message (append ?projectID=<hash>)
curl -s -X POST "http://mac.internal:4096/session/<sessionId>/message?projectID=<hash>" \
  -H 'Content-Type: application/json' \
  -d '{"parts":[{"type":"text","text":"your prompt here"}]}'
```

### SSE Event Stream

```bash
# Stream all events (new messages, session updates, etc.)
curl -s -N http://mac.internal:4096/event
```

## Fire-and-Forget Pattern

OpenCode prompts can take a long time. Use fire-and-forget:

```bash
# 1. Send the message (timeout after 5s, don't wait for completion)
curl -s --max-time 5 -X POST "http://mac.internal:4096/session/<sid>/message?projectID=<pid>" \
  -H 'Content-Type: application/json' \
  -d '{"parts":[{"type":"text","text":"implement feature X"}]}' || true

# 2. Poll for results later
sleep 30
curl -s http://mac.internal:4096/session/<sid>/message | jq '.[-1]'
```

### Polling for Completion

Check the last message in the session. When the assistant's response appears with tool results or a final answer, the task is done:

```bash
# Get last message
curl -s http://mac.internal:4096/session/<sid>/message | jq '.[-1].role'
# "assistant" = done, "user" = still your last prompt (still working)

# Get last assistant message content
curl -s http://mac.internal:4096/session/<sid>/message | jq '[.[] | select(.role=="assistant")] | last'
```

## Project-Scoped Sessions

OpenCode is project-aware. Each project has a hash ID.

1. Get project ID: `curl -s http://mac.internal:4096/project | jq '.[] | {id, path: .path}'`
2. Use `?projectID=<hash>` on the `/session/{id}/message` endpoint
3. The `/session` list endpoint does NOT filter by project — always returns all sessions

## Preferred Sessions (from TOOLS.md)

Check TOOLS.md for current preferred session IDs. Reuse existing sessions instead of creating new ones. Key sessions:

- **home-ops** and **mono** project sessions exist
- **yield** sessions for mono project work
- Always check with Andrew before sending messages to active sessions

## Gotchas and Limitations

- **No `/api` prefix** — endpoints are at root (`/session`, not `/api/session`)
- **Default SDK port 54321 doesn't work** — always use `mac.internal:4096`
- **Base64 path prefix in URLs** (e.g. `/L1VzZXJz.../session/...`) is frontend-only, returns HTML not JSON
- **Session list is global** — `?projectID` on `/session` does nothing
- **Sessions die on long commands** — kubectl, long builds etc. can kill the session. Not suitable for interactive cluster debugging
- **One session per task** — don't bounce between sessions, causes confusion
- **Ask Andrew first** — before sending prompts to existing sessions, confirm it's okay
- **Fire-and-forget** — `curl --max-time 5` to send, then poll. Don't wait synchronously

## Detailed Notes

See `memory/opencode-notes.md` for additional API quirks, jq patterns, and historical context.
