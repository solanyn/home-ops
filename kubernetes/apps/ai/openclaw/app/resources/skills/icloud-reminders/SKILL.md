---
name: icloud-reminders
description: Create, list, and manage Apple Reminders via iCloud CalDAV
---

# iCloud Reminders (CalDAV VTODO)

Create, list, and manage Apple Reminders via iCloud CalDAV. Use when asked to add reminders, shopping lists, tasks, or to-dos. Triggers on: reminders, shopping list, to-do, task, pick up, don't forget.

## Access

- **CalDAV endpoint:** `https://p108-caldav.icloud.com:443/1449763261/calendars/`
- **Auth:** Basic auth with iCloud credentials
- **Credentials:** `op://kubernetes/icloudpd/ICLOUD_USERNAME` and `op://kubernetes/icloudpd/ICLOUD_PASSWORD`

## Reminders Lists (VTODO collections)

| List | UUID | Color |
|------|------|-------|
| Reminders ⚠️ | `2ab8b9d8-4563-4508-81e4-9a0886ff0b3e` | Purple |
| Family | `6FAD7116-62C0-47BB-B644-6A5DB430E3D9` | Yellow |

Default list: `Reminders ⚠️` (use unless user specifies otherwise).

## Creating a Reminder

PUT a VTODO to `{list_url}/{uuid}.ics`:

```bash
ICLOUD_USER=$(op read "op://kubernetes/icloudpd/ICLOUD_USERNAME")
ICLOUD_PASS=$(op read "op://kubernetes/icloudpd/ICLOUD_PASSWORD")
LIST_URL="https://p108-caldav.icloud.com:443/1449763261/calendars/2ab8b9d8-4563-4508-81e4-9a0886ff0b3e/"
UUID=$(cat /proc/sys/kernel/random/uuid)

curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  -u "$ICLOUD_USER:$ICLOUD_PASS" \
  -X PUT -H "Content-Type: text/calendar" \
  -d "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Hawow//NONSGML v1.0//EN
BEGIN:VTODO
UID:${UUID}
SUMMARY:Buy milk
STATUS:NEEDS-ACTION
END:VTODO
END:VCALENDAR" \
  "${LIST_URL}${UUID}.ics"
```

Expect: `201` (created) or `204` (updated).

## Optional VTODO Fields

```
DUE:20260409T090000Z          # due date (UTC)
PRIORITY:1                     # 1=high, 5=medium, 9=low (maps to Reminders flagged)
DESCRIPTION:Extra notes here   # notes field
RELATED-TO;RELTYPE=PARENT:parent-uid  # subtask relationship
```

## Listing Reminders

REPORT on the list URL to get all VTODOs:

```bash
curl -s --max-time 10 -u "$ICLOUD_USER:$ICLOUD_PASS" \
  -X REPORT -H "Content-Type: application/xml" -H "Depth: 1" \
  -d '<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>' \
  "$LIST_URL"
```

## Completing a Reminder

PUT the same VTODO with `STATUS:COMPLETED` and `COMPLETED:20260408T120000Z`. Use `If-Match` with the etag from listing.

## Deleting a Reminder

```bash
curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  -u "$ICLOUD_USER:$ICLOUD_PASS" \
  -X DELETE "${LIST_URL}${UUID}.ics"
```

## Batch Operations

Use bash arrays and loop with `sleep 0.3` between requests to avoid rate limiting. Always use `bash << 'SCRIPT'` heredoc since default shell is sh.

## Notes

- iCloud CalDAV supports VTODO with Apple extensions (subtasks, priority/flagged)
- Tags and location-based triggers are NOT available via CalDAV (Apple-internal only)
- Reminders sync bidirectionally — items created here appear on all Apple devices
- The `icloudpd` 1Password item has the credentials (originally for iCloud Photo Downloader)
- Principal ID: `1449763261`
