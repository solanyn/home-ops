---
name: caldav-calendar
description: Sync and query CalDAV calendars (Rustical) using vdirsyncer + khal. Use for scheduling, reminders, appointments, todos, calendar queries, or checking upcoming events. Triggers on calendar, schedule, events, meetings, reminders, or tasks.
---

# CalDAV Calendar (vdirsyncer + khal)

Local calendar access via synced .ics files. No network requests needed for reads.

## Sync First

Always sync before querying or after making changes:
```bash
/workspace/scripts/caldav-sync.sh
```

## View Events

```bash
export KHAL_CONFIG=/workspace/.config/khal/config
KHAL=/workspace/.venvs/vdirsyncer/bin/khal

$KHAL list today                    # Today
$KHAL list today 7d                 # Next 7 days
$KHAL list tomorrow                 # Tomorrow
$KHAL list 2026-04-15 2026-04-20   # Date range
$KHAL list -a work today            # Work calendar only
$KHAL list -a personal today        # Personal calendar only
```

## Search

```bash
$KHAL search "meeting"
$KHAL search "dentist" --format "{start-date} {title}"
```

## Create Events

```bash
$KHAL new 2026-04-15 10:00 11:00 "Meeting title"
$KHAL new 2026-04-15 "All day event"
$KHAL new tomorrow 14:00 15:30 "Call" -a work
$KHAL new 2026-04-15 10:00 11:00 "With notes" :: Description goes here
```

After creating, sync to push:
```bash
/workspace/scripts/caldav-sync.sh
```

## Output Formats (for scripting)

```bash
$KHAL list --format "{start-date} {start-time}-{end-time} {title}" today 7d
$KHAL list --format "{uid} | {title} | {calendar}" today
```

Placeholders: `{title}`, `{description}`, `{start}`, `{end}`, `{start-date}`, `{start-time}`, `{end-date}`, `{end-time}`, `{location}`, `{calendar}`, `{uid}`

## Calendars

| Name | ID | Path |
|------|-----|------|
| personal | d090c8b0-d3a8-4134-8fed-a2fe9c784d49 | Personal events, todos, recurring tasks |
| work | 53e37955-69e7-4ce1-b85f-e0cdfdad785d | Outlook-synced work calendar |

## Filter Out

- "Peer programming" and "LUNCH" entries are calendar blockers, not real meetings
- "Nearly home time" is a reminder, not a meeting

## Config Locations

- vdirsyncer: `/workspace/.config/vdirsyncer/config`
- khal: `/workspace/.config/khal/config`
- venv: `/workspace/.venvs/vdirsyncer/`
- local ics: `/workspace/.local/share/vdirsyncer/calendars/`

## Rustical (upstream server)

- URL: `https://caldav.goyangi.io`
- Auth: app token from `op://kubernetes/rustical/RUSTICAL_APP_TOKEN`
- Principal: `andrew`
