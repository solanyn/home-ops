---
name: fusion-rss-patches
description: Corrections and improvements discovered while using the fusion-rss skill. Captures field name fixes, cookie jar patterns, and focus-feed digest workflow.
tags: [rss, fusion, patches, corrections]
---

# Fusion RSS — Session Corrections

These corrections were discovered during actual use of the `fusion-rss` skill. The source skill is imported from openclaw-imports and cannot be autonomously patched.

## Field Name Fixes

The `fusion-rss` skill jq patterns reference incorrect field names:

1. **Feeds use `name`, not `title`** — The "List Feeds" jq pattern shows `{title, unread_count}` but the actual API returns `name`.
   - Correct: `jq '.[] | {name, unread_count}'`

2. **Items have `feed_id` but not `feed_title`** — The "Useful jq Patterns" section shows `"\(.published_at) [(.feed_title)] \(.title)"` but `feed_title` doesn't exist in the items response.
   - Correct: use `feed_id` and join with feeds list if you need names.

## Cookie Jar Approach (Recommended)

The skill's Digest Pattern manually extracts and passes session tokens. A simpler approach uses curl's cookie jar:

```bash
# Login with cookie jar (simpler, avoids shell quoting)
curl -s -c /tmp/fc -X POST 'http://fusion.default.svc.cluster.local/api/sessions' \
  -H 'Content-Type: application/json' -d '{"password":""}'

# All subsequent calls just use -b
curl -s -b /tmp/fc 'http://fusion.default.svc.cluster.local/api/items?limit=50&unread=true'
```

This is more reliable for multi-call workflows than the manual `-H "Cookie: session=$SESSION"` pattern.

## Focus-Feed Digest Workflow

For filtering to specific feeds (e.g., tech digest):

```bash
BASE=http://fusion.default.svc.cluster.local

# 1. Login
curl -s -c /tmp/fc -X POST $BASE/api/sessions \
  -H 'Content-Type: application/json' -d '{"password":""}'

# 2. List feeds to discover feed_ids
curl -s -b /tmp/fc $BASE/api/feeds | jq '.[] | {id, name, unread_count}'

# 3. Fetch items from specific feeds
curl -s -b /tmp/fc "$BASE/api/items?feed_id=25&limit=10&unread=true" | \
  jq -r '.[] | "\(.pub_date) \(.title)\n  \(.link)"'
```

## Known Feed Issues

- **Latent.Space** (id=30) and **The Gradient** (id=27) consistently return 0 items due to DNS resolution failures from inside the cluster. This affects feed updates, not API reads.
- **Chip Huyen** (id=16, huyenchip.com) last published Jan 2025 — no new content.
- External URL (`https://fusion.goyangi.io`) also works with cookie jar auth if cluster DNS is unavailable. **Use this from cron context** — in-cluster DNS (`fusion.default.svc.cluster.local`) may not resolve from pods outside the cluster network.

## Building a feed_id→name Map for Item Filtering

Items only have `feed_id` (numeric), never feed names. When you need to filter items by feed name (e.g., "get me world news from BBC, Al Jazeera, Guardian-World"), build the map first:

```bash
BASE=https://fusion.goyangi.io

# Login
curl -s -c /tmp/fcw -X POST $BASE/api/sessions \
  -H 'Content-Type: application/json' -d '{"password":""}'

# Build feed_id→name map
curl -s -b /tmp/fcw $BASE/api/feeds | python3 -c "
import sys, json
data = json.load(sys.stdin)
feeds = data.get('data', [])
for f in feeds:
    print(f'Feed {f.get(\"id\")}: {f.get(\"name\", \"unknown\")}')
"

# Then filter items by feed_id
curl -s -b /tmp/fcw "$BASE/api/items?limit=50" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', [])
world_feeds = {68: 'BBC News', 70: 'Al Jazeera', 71: 'Guardian-World', 73: 'France24', 74: 'NYT-World'}
for item in items:
    if item.get('feed_id') in world_feeds:
        print(f'[{world_feeds[item[\"feed_id\"]]}] {item[\"title\"]}')
"
```

**Current known world news feed IDs** (as of Aug 2026 — verify with `/api/feeds` if titles change):
- 68: BBC News
- 70: Al Jazeera
- 71: Guardian-World
- 73: France24
- 74: NYT-World
