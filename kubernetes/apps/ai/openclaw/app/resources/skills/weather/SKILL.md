---
name: weather
description: Get current weather and forecasts via Open-Meteo. Use when user asks about weather, temperature, UV, rain, or forecasts for any location. Includes UV index, precipitation mm, humidity, apparent temperature (feels like). No API key needed.
---

# Weather Skill

Comprehensive weather via Open-Meteo free API. No key needed.

## Usage

```bash
# Get weather for a location (default: Sydney)
bash scripts/weather.sh "Sydney"
bash scripts/weather.sh "Sydney Olympic Park"
bash scripts/weather.sh "Melbourne"

# With coordinates (faster, no geocoding)
bash scripts/weather.sh "" -33.85 151.21
```

## Output

Returns JSON with:
- **Current:** temp, feels like, humidity, precipitation, UV index, wind, weather description
- **3-day forecast:** max/min temp, feels like range, UV max, total rain mm, rain probability, max wind, humidity
- **Hourly (next 24h):** temp, feels like, rain probability, precipitation mm, UV, humidity, wind

## WMO Weather Codes

The script translates WMO codes to human-readable descriptions (clear, cloudy, rain, snow, thunderstorm, etc).

## Comfort Guidance

The script includes a comfort assessment:
- **Feels like** vs actual temp (wind chill / heat index)
- **UV risk level** (low/moderate/high/very high/extreme)
- **Rain likelihood** summary

## Notes

- Open-Meteo geocoding for location → coordinates
- Timezone auto-detected from coordinates
- No rate limits for reasonable use
- Data updates every 15 minutes
