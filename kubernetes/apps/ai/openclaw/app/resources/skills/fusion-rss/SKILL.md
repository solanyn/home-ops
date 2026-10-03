---
name: fusion-rss
description: Read and manage RSS feeds via Fusion. Use when checking news, tech articles, unread items, searching feeds, generating digests, or marking items read. Triggers on RSS, feeds, news, articles, unread, digest, Fusion.
---

# Fusion RSS Reader

Local RSS aggregator at `http://fusion.default.svc.cluster.local`.

## Authentication

Session cookie, empty password. Token lasts 30 days.

```bash
# Login — extract session token
SESSION=$(curl -s -c - -X POST http://fusion.default.svc.cluster.local/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"password":""}' | grep session | awk '{print $NF}')

# All subsequent calls need:
# -H "Cookie: session=$SESSION"
```

## List Feeds

```bash
curl -s -H "Cookie: session=$SESSION" \
  http://fusion.default.svc.cluster.local/api/feeds | jq .
```

Returns feeds with unread counts. Useful for seeing what's active.

```bash
# Just names and unread counts
curl -s -H "Cookie: session=$SESSION" \
  http://fusion.default.svc.cluster.local/api/feeds \
  | jq '.[] | {title, unread_count}'
```

## Fetch Items

```bash
# Unread items (default limit)
curl -s -H "Cookie: session=$SESSION" \
  "http://fusion.default.svc.cluster.local/api/items?unread=true"

# Limit results
curl -s -H "Cookie: session=$SESSION" \
  "http://fusion.default.svc.cluster.local/api/items?limit=20&unread=true"

# Items from a specific feed
curl -s -H "Cookie: session=$SESSION" \
  "http://fusion.default.svc.cluster.local/api/items?feed_id=3"

# All items (read + unread)
curl -s -H "Cookie: session=$SESSION" \
  "http://fusion.default.svc.cluster.local/api/items?limit=50"
```

## Search

```bash
curl -s -H "Cookie: session=$SESSION" \
  "http://fusion.default.svc.cluster.local/api/search?q=kubernetes" | jq .
```

## Mark Items as Read

```bash
curl -s -X PATCH -H "Cookie: session=$SESSION" \
  -H "Content-Type: application/json" \
  -d '{"ids": [1, 2, 3]}' \
  http://fusion.default.svc.cluster.local/api/items/-/read
```

## Digest Pattern

For generating a news/tech digest:

```bash
BASE=http://fusion.default.svc.cluster.local

# 1. Login
SESSION=$(curl -s -c - -X POST $BASE/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"password":""}' | grep session | awk '{print $NF}')

# 2. Get unread items (last 20)
ITEMS=$(curl -s -H "Cookie: session=$SESSION" \
  "$BASE/api/items?limit=20&unread=true")

# 3. Extract titles and links
echo "$ITEMS" | jq -r '.[] | "- [\(.title)](\(.link))"'

# 4. Mark them read after digesting
IDS=$(echo "$ITEMS" | jq '[.[].id]')
curl -s -X PATCH -H "Cookie: session=$SESSION" \
  -H "Content-Type: application/json" \
  -d "{\"ids\": $IDS}" \
  $BASE/api/items/-/read
```

## Useful jq Patterns

```bash
# Titles only
| jq -r '.[].title'

# Title + feed name + date
| jq -r '.[] | "\(.published_at) [\(.feed_title)] \(.title)"'

# Group by feed
| jq 'group_by(.feed_id) | .[] | {feed: .[0].feed_title, items: [.[].title]}'
```

## Notes

- Many feeds have DNS resolution issues from inside the cluster (i/o timeout on fetch). This affects feed updates, not API reads.
- Password is empty (`FUSION_ALLOW_EMPTY_PASSWORD=true`). If auth fails, check if `FUSION_PASSWORD` env var was set.
- Session tokens expire after 30 days (Max-Age=2592000).
