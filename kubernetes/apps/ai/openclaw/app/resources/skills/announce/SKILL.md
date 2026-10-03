---
name: announce
description: Speak announcements on home speakers via Kokoro TTS + Home Assistant
---

# Announce Skill

Speak announcements on home speakers via Kokoro TTS + Home Assistant.

## When to Use

- Weather reports, reminders, alerts spoken aloud
- Any "announce", "say on speaker", "tell me on the speaker" request
- Proactive announcements (calendar reminders, urgent emails)

## Usage

Single HTTP call — TTS generation, file serving, and Chromecast playback all handled by the Mac overlay:

```bash
curl -s -X POST http://mac.internal:8000/v1/announce \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your message here",
    "speaker": "dining_room",
    "voice": "af_heart"
  }'
```

Response: `{"status": "playing", "speaker": "dining_room", "file": "abc123.mp3"}`

Audio files auto-delete after 60 seconds.

## Parameters

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `text` | string | required | What to say |
| `speaker` | string | `dining_room` | Speaker name |
| `voice` | string | `af_heart` | Kokoro voice |
| `volume` | float | null | Set volume (0.0-1.0) before playing |

## Speakers

| Name | Entity ID | Status |
|------|-----------|--------|
| `dining_room` | `media_player.dining_room_speaker` | Works (Chromecast) |
| `living_room` | `media_player.living_room` | Unreliable (500 errors) |

## Voice Options

- `af_heart` — warm female (default, natural sounding)
- `af_bella` — female, clear
- `am_adam` — male, neutral
- `am_michael` — male, deeper

## Tips

- Keep messages short and conversational — sounds more natural
- Use periods and commas for natural pauses
- Spell out numbers ("thirty three" not "33")
- Default volume is 40%

## Architecture

- `mac.internal:8000` runs mlx-audio overlay (FastAPI + Kokoro TTS + static file mount)
- `/v1/announce` generates TTS → saves to `/tmp/tts/` → calls HA `play_media`
- Chromecast pulls mp3 from `mac.internal:8000/tts/{file}.mp3`
- HA token read from `~/.config/mlx-server/ha_token` on Mac
- Files auto-cleanup after 60s via asyncio
