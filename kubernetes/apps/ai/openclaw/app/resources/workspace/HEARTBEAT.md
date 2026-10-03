# Hawow's Heartbeat Tasks

Recurring schedules only. One-shot tasks go in hippo (`hippo remember "..." --tag heartbeat --tag one-shot`).
On each heartbeat, also run: `hippo recall "heartbeat tasks" --budget 500` for pending one-shots.

## Midday Check (1 PM weekdays - 30% chance)
- [ ] Motivation/message if nothing urgent

## Pre-Meeting (15 min before any meeting)
- [ ] Pull relevant notes/docs for context
- [ ] Send brief reminder with key points

## OpenCode Session Monitor (every 10 min during work hours)
- [ ] Poll mac.internal:4096 for active sessions
- [ ] Check for sessions needing input (permissions, questions, errors)
- [ ] If attention needed → message Andrew with session ID and status
- [ ] Track active projects/themes in memory/opencode-tracker.md

## Dashboard Update (every heartbeat during work hours)
- [ ] Read `obsidian-vault/Hawow/Work/Kanban.md` for latest state
- [ ] Regenerate standup cheat sheet if kanban changed
- [ ] Update dashboard (`obsidian-vault/Hawow/dashboard.md`)

---

## Moved to Cron (don't duplicate here)
- Morning briefing (8:30am weekdays) → `morning-briefing`
- Health coaching morning (8:30am) → `morning-briefing`
- Health coaching evening (5pm) → `Evening recovery check`
- Email inbox (9am daily) → `email-inbox-check`
- OzBargain (10am, 6pm) → `ozbargain-morning`, `ozbargain-evening`
- RSS tech digest (2pm) → `rss-tech-digest`
- News digests (8am, 6pm, 7pm) → `au-politics-*`, `au-finance-*`, `tech-news-*`
- End of day preview (5:30pm weekdays) → `end-of-day-preview`
- Weekly memory maintenance (Mon 8am) → `weekly-memory-maintenance`
- Westpac CSV reminder (Mon 9am) → `westpac-csv-reminder`
- Daily memory init (midnight) → `daily-memory-init`
- Motivation (1-3pm weekdays) → `daily-motivation`

---
*Recurring only. Ad-hoc → hippo. One-shots decay naturally after completion.*
