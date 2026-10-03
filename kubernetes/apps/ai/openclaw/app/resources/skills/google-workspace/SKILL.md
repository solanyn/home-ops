---
name: google-workspace
description: Access Google Drive, Gmail, Sheets, Docs, Calendar, Tasks via gogcli
---

# Google Workspace CLI (gogcli)

Access Google Drive, Gmail, Sheets, Docs, Calendar, Tasks, and Contacts via `gog` CLI. Use for reading emails, searching Drive, viewing spreadsheets, reading docs. Prefer read-only operations unless explicitly asked to write.

## Installation

Build from source (requires Go):

```bash
git clone https://github.com/steipete/gogcli.git
cd gogcli
make
# binary at ./gog
```

Or on Mac: clone to `~/git/gogcli` and build there.

## Setup (one-time, requires Andrew)

1. Create OAuth2 Desktop app credentials at https://console.cloud.google.com/apis/credentials
2. Enable APIs: Gmail, Drive, Docs, Sheets, Calendar, Tasks, People
3. Download client_secret JSON
4. `gog auth credentials ~/Downloads/client_secret_....json`
5. `gog auth add andrew@gmail.com --services user --readonly` (read-only scopes)

## Usage

All commands support `--json` for parseable output. Use `--readonly` flag where available.

### Gmail
```bash
gog gmail search "from:someone subject:invoice" --json
gog gmail threads list --max 10 --json
gog gmail messages get MESSAGE_ID --json
gog gmail labels list --json
```

### Drive
```bash
gog drive list --json                          # list files
gog drive search "name contains 'report'" --json
gog drive download FILE_ID -o /tmp/file
```

### Sheets
```bash
gog sheets get SPREADSHEET_ID --json
gog sheets read SPREADSHEET_ID "Sheet1!A1:D10" --json
```

### Docs
```bash
gog docs get DOC_ID --json
gog docs export DOC_ID --format markdown
```

### Calendar
```bash
gog calendar events list --json
gog calendar events list --time-min 2026-04-08 --time-max 2026-04-15 --json
```

### Tasks
```bash
gog tasks lists --json
gog tasks list TASKLIST_ID --json
```

## Running from Sandbox

`gog` is a native binary — needs to run on mac.internal via SSH:

```bash
ssh mac.internal "export PATH=\$HOME/git/gogcli:\$PATH; gog gmail search 'is:unread' --json --max 5"
```

## Notes

- Prefer `--readonly` auth scopes — Andrew wants read-only access
- JSON output for all queries (`--json`)
- Multiple accounts supported (`--account` or `GOG_ACCOUNT` env var)
- Keyring stores tokens — no password prompts after initial auth
- Rate limits: Google API quotas apply (Gmail: 250 units/sec, Drive: 1000 queries/100sec)
- `GOG_KEYRING_BACKEND=file` + `GOG_KEYRING_PASSWORD=...` avoids macOS Keychain prompts over SSH
- Command allowlist available for sandboxed runs: `GOG_ALLOWED_COMMANDS=gmail,drive,sheets,docs,calendar,tasks`

## Status

✅ **Installed and authenticated.** Account: `andrewchen1520@gmail.com` (full scopes).

⚠️ **Must use node exec** — keychain access requires GUI session (TCC blocks SSH).

```bash
# From OpenClaw:
exec host=node node="Mac Mini"
export PATH=/opt/homebrew/bin:$PATH; gog gmail search "is:unread" --json --max 10
```
