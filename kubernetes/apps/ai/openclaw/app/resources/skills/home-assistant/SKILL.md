---
name: home-assistant
description: Query and interact with Home Assistant via REST API. Use for checking entity states (lights, sensors, climate, switches), viewing history/logbook, listing automations, and calling services. Triggers on "lights", "temperature", "home assistant", "smart home", "automation", "turn on", "turn off", "home status".
---

# Home Assistant Skill

## Connection

- **URL:** `http://home-assistant.default.svc.cluster.local:8123`
- **Token:** `op read "op://kubernetes/home-assistant/add more/HASS_TOKEN"`
- **User:** `hawow`

## Auth Setup

Every request needs the Bearer token header:

```bash
HA_URL="http://home-assistant.default.svc.cluster.local:8123"
HA_TOKEN=$(op read "op://kubernetes/home-assistant/add more/HASS_TOKEN")
HA_AUTH="Authorization: Bearer $HA_TOKEN"
```

## API Reference

### Check API is running

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/"
```

### List all entity states

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/states" | python3 -c "
import sys,json
states=json.load(sys.stdin)
domains={}
for s in states:
    d=s['entity_id'].split('.')[0]
    domains[d]=domains.get(d,0)+1
for d in sorted(domains, key=domains.get, reverse=True):
    print(f'{d}: {domains[d]}')
print(f'Total: {len(states)}')
"
```

### Get specific entity state

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/states/light.mushroom"
curl -s -H "$HA_AUTH" "$HA_URL/api/states/sensor.air_circulator_temperature"
```

### Filter entities by domain

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/states" | python3 -c "
import sys,json
for s in json.load(sys.stdin):
    if s['entity_id'].startswith('light.'):
        print(f'{s[\"entity_id\"]}: {s[\"state\"]} ({s[\"attributes\"].get(\"friendly_name\",\"\")})')
"
```

Replace `light.` with any domain: `sensor.`, `switch.`, `automation.`, `binary_sensor.`, `climate.`, `fan.`, `media_player.`, etc.

### History (past states)

```bash
# Last 24h for a specific entity
curl -s -H "$HA_AUTH" "$HA_URL/api/history/period?filter_entity_id=sensor.air_circulator_temperature&minimal_response"

# Specific time range
curl -s -H "$HA_AUTH" "$HA_URL/api/history/period/2026-04-06T00:00:00+00:00?end_time=2026-04-07T00:00:00+00:00&filter_entity_id=light.mushroom&minimal_response"
```

Returns array of arrays. Each inner array is one entity's state changes over the period.

### Logbook

```bash
# Recent logbook entries
curl -s -H "$HA_AUTH" "$HA_URL/api/logbook" | python3 -c "
import sys,json
for e in json.load(sys.stdin)[:20]:
    print(f'{e.get(\"when\",\"?\")[:19]} | {e.get(\"name\",\"?\")} — {e.get(\"message\",\"\")}')
"

# Logbook for specific entity
curl -s -H "$HA_AUTH" "$HA_URL/api/logbook?entity=light.mushroom"

# Logbook for time range
curl -s -H "$HA_AUTH" "$HA_URL/api/logbook/2026-04-06T00:00:00+00:00?end_time=2026-04-07T00:00:00+00:00"
```

### List automations

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/states" | python3 -c "
import sys,json
for s in json.load(sys.stdin):
    if s['entity_id'].startswith('automation.'):
        a=s['attributes']
        print(f'{s[\"entity_id\"]}: {s[\"state\"]}')
        print(f'  Name: {a.get(\"friendly_name\",\"\")}')
        print(f'  Last triggered: {a.get(\"last_triggered\",\"never\")}')
"
```

### Call services

```bash
# Turn off a light
curl -s -X POST -H "$HA_AUTH" -H "Content-Type: application/json" \
  -d '{"entity_id":"light.mushroom"}' \
  "$HA_URL/api/services/light/turn_off"

# Turn on a light with brightness
curl -s -X POST -H "$HA_AUTH" -H "Content-Type: application/json" \
  -d '{"entity_id":"light.mushroom","brightness":128}' \
  "$HA_URL/api/services/light/turn_on"

# Toggle a switch
curl -s -X POST -H "$HA_AUTH" -H "Content-Type: application/json" \
  -d '{"entity_id":"switch.example"}' \
  "$HA_URL/api/services/switch/toggle"

# Trigger an automation
curl -s -X POST -H "$HA_AUTH" -H "Content-Type: application/json" \
  -d '{"entity_id":"automation.bedroom_lights_on_at_5pm"}' \
  "$HA_URL/api/services/automation/trigger"
```

Service call format: `POST /api/services/{domain}/{service}` with JSON body containing `entity_id` and optional parameters.

### List available services

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/services" | python3 -c "
import sys,json
for s in json.load(sys.stdin):
    svcs=', '.join(list(s['services'].keys())[:8])
    print(f'{s[\"domain\"]}: {svcs}')
"
```

### Get HA config

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/config"
```

### Error log

```bash
curl -s -H "$HA_AUTH" "$HA_URL/api/error_log"
```

## Known Entities (as of 2026-04-07)

### Lights (7)
- `light.hue_white_lamp_1` — IKEA Lamp
- `light.andrews_lamp` — Andrew's Lamp
- `light.pattys_lamp` — Patty's Lamp
- `light.study_lamp` — Study Lamp
- `light.living_room_moon` — Living Room Moon
- `light.mushroom` — Mushroom
- `light.dressing_table_lamp` — Dressing Table Lamp

### Key Sensors
- `sensor.air_circulator_temperature` — Room temperature
- `sensor.slzb_mr2u_core_chip_temp` — Zigbee coordinator core temp
- `sensor.feliway_plug_power` — Feliway plug power draw

### Automations (11)
- Lights on at 5pm (bedroom), 5pm (other)
- Adaptive dimming (bedroom, other)
- Lights off at midnight
- Remote brightness cycling (Andrew, Patty)
- Air purifier auto-off after 20min
- Low battery alert
- Air purifier filter replacement

## Limitations

- **Template rendering is blocked** — `POST /api/template` returns 401 for this user. Cannot use Jinja2 templates.
- **Service calls work** — Despite the user being described as "read-only", service calls (turn_on, turn_off, etc.) return 200. Use with caution — confirm with Andrew before making state changes.
- **Prefer reading over writing** — Default to querying states and suggesting actions rather than executing them, unless explicitly asked.

## Usage Patterns

### Quick home status

```bash
HA_URL="http://home-assistant.default.svc.cluster.local:8123"
HA_TOKEN=$(op read "op://kubernetes/home-assistant/add more/HASS_TOKEN")
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states" | python3 -c "
import sys,json
states=json.load(sys.stdin)
print('=== Lights ===')
for s in states:
    if s['entity_id'].startswith('light.'):
        print(f'  {s[\"attributes\"].get(\"friendly_name\",s[\"entity_id\"])}: {s[\"state\"]}')
print()
print('=== Sensors ===')
for s in states:
    eid=s['entity_id']
    if eid.startswith('sensor.') and any(k in eid for k in ['temp','humid','power','battery']):
        unit=s['attributes'].get('unit_of_measurement','')
        print(f'  {s[\"attributes\"].get(\"friendly_name\",eid)}: {s[\"state\"]}{unit}')
"
```

### Check what changed recently

```bash
HA_URL="http://home-assistant.default.svc.cluster.local:8123"
HA_TOKEN=$(op read "op://kubernetes/home-assistant/add more/HASS_TOKEN")
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/logbook" | python3 -c "
import sys,json
for e in json.load(sys.stdin)[:15]:
    ts=e.get('when','')[:19].replace('T',' ')
    print(f'{ts} | {e.get(\"name\",\"?\")} {e.get(\"message\",\"\")}')
"
```
