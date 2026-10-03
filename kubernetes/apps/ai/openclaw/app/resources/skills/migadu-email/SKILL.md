---
name: migadu-email
description: Check and manage email via Migadu IMAP. Use for inbox checks, email digests, reading messages, or email automation. Triggers on email, inbox, messages, or mail queries.
---

# Migadu Email Skill

Access Migadu email via IMAP/SMTP.

## Connection

```bash
IMAP: imap.migadu.com:993 (SSL)
SMTP: smtp.migadu.com:465 (SSL)
User: hawow.shmawow@goyangi.io
Password: op read "op://kubernetes/migadu/IMAP_PASSWORD"
```

## Quick IMAP Check (openssl)

```bash
# List recent messages
(
echo "a1 LOGIN hawow.shmawow@goyangi.io $(op read 'op://kubernetes/migadu/IMAP_PASSWORD')"
echo "a2 SELECT INBOX"
echo "a3 SEARCH UNSEEN"
echo "a4 LOGOUT"
) | openssl s_client -connect imap.migadu.com:993 -quiet 2>/dev/null
```

## Fetch Specific Message

```bash
# Fetch message by UID
echo "a3 FETCH <UID> (BODY[HEADER.FIELDS (FROM SUBJECT DATE)] BODY[TEXT])"
```

## Search Patterns

```imap
SEARCH UNSEEN                      # Unread
SEARCH FROM "example.com"          # From domain
SEARCH SINCE 01-Feb-2026           # Date range
SEARCH SUBJECT "invoice"           # Subject contains
SEARCH OR FROM "a" FROM "b"        # Multiple senders
```

## Folder Operations

```imap
a2 LIST "" "*"                     # List all folders
a2 SELECT "Junk"                   # Select spam folder
a2 STORE <UID> +FLAGS (\Deleted)   # Mark for deletion
a2 EXPUNGE                         # Permanently delete
```

## Scripts

For complex email operations, use `scripts/check-inbox.sh`:

```bash
./scripts/check-inbox.sh [--unread] [--folder INBOX] [--limit 10]
```

## Python stdlib alternative (no extra deps)

When himalaya isn't installed or you want zero-deps Python:

```python
import imaplib
M = imaplib.IMAP4_SSL('imap.migadu.com', 993)
M.login('<EMAIL_ADDRESS>', '<password from op read>')
M.select('INBOX', readonly=True)
typ, data = M.search(None, 'UNSEEN')
uids = data[0].split() if data[0] else []
print(f'unread count: {len(uids)}')
typ, data = M.search(None, 'ALL')
print(f'total messages: {len(data[0].split()) if data[0] else 0}')
M.logout()
```

Useful inside cron scripts where adding himalaya/clients to the runtime would be a packaging change.

## Higher-level client: `himalaya`

For scripted inbox checks, prefer `himalaya` (Homebrew: `brew install himalaya`). IMAP + SMTP + PGP-capable, structured output. Currently **not configured on this pod** — needs `~/.config/himalaya/config.toml`. Avoid recommending himalaya for cron scripts until the config is wired up; the skill scripts handle auth via `op read` inline, which is the working pattern.

When himalaya IS configured, the equivalent of the openssl snippet above is:

```bash
himalaya --account migadu envelope list --folder INBOX --page-size 10
```

## Common Patterns

**Daily digest:** Search UNSEEN, fetch headers, summarize, mark as seen or archive.

**Spam cleanup:** SELECT Junk, SEARCH ALL, STORE +FLAGS \Deleted, EXPUNGE.

**Filter by sender:** SEARCH FROM "cullenjewellery.com" for specific notifications.
