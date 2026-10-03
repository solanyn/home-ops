#!/usr/bin/env bash
set -euo pipefail

LOCATION="${1:-Sydney}"
LAT="${2:-}"
LON="${3:-}"

# Geocode if no coordinates provided
if [[ -z "$LAT" || -z "$LON" ]]; then
  GEO=$(curl -sf "https://geocoding-api.open-meteo.com/v1/search?name=$(printf '%s' "$LOCATION" | jq -sRr @uri)&count=1&language=en&format=json")
  LAT=$(echo "$GEO" | jq -r '.results[0].latitude // empty')
  LON=$(echo "$GEO" | jq -r '.results[0].longitude // empty')
  RESOLVED=$(echo "$GEO" | jq -r '.results[0] | "\(.name), \(.admin1 // ""), \(.country // "")"')
  if [[ -z "$LAT" ]]; then
    echo '{"error": "Location not found: '"$LOCATION"'"}'; exit 1
  fi
fi

# Fetch weather
DATA=$(curl -sf "https://api.open-meteo.com/v1/forecast?\
latitude=$LAT&longitude=$LON\
&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,uv_index\
&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,relative_humidity_2m_max,sunrise,sunset\
&hourly=temperature_2m,apparent_temperature,precipitation_probability,precipitation,uv_index,relative_humidity_2m,wind_speed_10m\
&timezone=auto&forecast_days=3&forecast_hours=24")

# WMO code lookup
wmo_desc() {
  case $1 in
    0) echo "Clear sky";;
    1) echo "Mainly clear";;
    2) echo "Partly cloudy";;
    3) echo "Overcast";;
    45|48) echo "Fog";;
    51) echo "Light drizzle";;
    53) echo "Moderate drizzle";;
    55) echo "Dense drizzle";;
    56|57) echo "Freezing drizzle";;
    61) echo "Light rain";;
    63) echo "Moderate rain";;
    65) echo "Heavy rain";;
    66|67) echo "Freezing rain";;
    71) echo "Light snow";;
    73) echo "Moderate snow";;
    75) echo "Heavy snow";;
    77) echo "Snow grains";;
    80) echo "Light rain showers";;
    81) echo "Moderate rain showers";;
    82) echo "Violent rain showers";;
    85) echo "Light snow showers";;
    86) echo "Heavy snow showers";;
    95) echo "Thunderstorm";;
    96|99) echo "Thunderstorm with hail";;
    *) echo "Unknown ($1)";;
  esac
}

uv_risk() {
  local uv=$(printf '%.0f' "$1")
  if (( uv <= 2 )); then echo "low"
  elif (( uv <= 5 )); then echo "moderate"
  elif (( uv <= 7 )); then echo "high"
  elif (( uv <= 10 )); then echo "very high"
  else echo "extreme"; fi
}

comfort() {
  local actual=$(printf '%.0f' "$1") feels=$(printf '%.0f' "$2")
  local diff=$((feels - actual))
  if (( feels <= 10 )); then echo "cold — layer up"
  elif (( feels <= 15 )); then echo "cool — light jacket"
  elif (( feels <= 20 )); then echo "mild — comfortable"
  elif (( feels <= 25 )); then echo "warm — pleasant"
  elif (( feels <= 30 )); then echo "hot — stay hydrated"
  else echo "very hot — limit sun exposure"; fi
}

# Current
CUR_TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m')
CUR_FEELS=$(echo "$DATA" | jq -r '.current.apparent_temperature')
CUR_HUMID=$(echo "$DATA" | jq -r '.current.relative_humidity_2m')
CUR_PRECIP=$(echo "$DATA" | jq -r '.current.precipitation')
CUR_WMO=$(echo "$DATA" | jq -r '.current.weather_code')
CUR_WIND=$(echo "$DATA" | jq -r '.current.wind_speed_10m')
CUR_UV=$(echo "$DATA" | jq -r '.current.uv_index')

echo "=== ${RESOLVED:-$LOCATION} ==="
echo ""
echo "NOW: $(wmo_desc $CUR_WMO)"
echo "  Temp: ${CUR_TEMP}°C (feels like ${CUR_FEELS}°C) — $(comfort $CUR_TEMP $CUR_FEELS)"
echo "  Humidity: ${CUR_HUMID}%  |  Wind: ${CUR_WIND} km/h  |  Rain: ${CUR_PRECIP} mm"
echo "  UV: ${CUR_UV} ($(uv_risk $CUR_UV))"
echo ""

# Daily forecast
DAYS=$(echo "$DATA" | jq -r '.daily.time | length')
for i in $(seq 0 $((DAYS - 1))); do
  DATE=$(echo "$DATA" | jq -r ".daily.time[$i]")
  WMO=$(echo "$DATA" | jq -r ".daily.weather_code[$i]")
  TMAX=$(echo "$DATA" | jq -r ".daily.temperature_2m_max[$i]")
  TMIN=$(echo "$DATA" | jq -r ".daily.temperature_2m_min[$i]")
  FMAX=$(echo "$DATA" | jq -r ".daily.apparent_temperature_max[$i]")
  FMIN=$(echo "$DATA" | jq -r ".daily.apparent_temperature_min[$i]")
  UV=$(echo "$DATA" | jq -r ".daily.uv_index_max[$i]")
  RAIN=$(echo "$DATA" | jq -r ".daily.precipitation_sum[$i]")
  RAIN_PCT=$(echo "$DATA" | jq -r ".daily.precipitation_probability_max[$i]")
  WIND=$(echo "$DATA" | jq -r ".daily.wind_speed_10m_max[$i]")
  HUMID=$(echo "$DATA" | jq -r ".daily.relative_humidity_2m_max[$i]")

  echo "$DATE: $(wmo_desc $WMO)"
  echo "  ${TMIN}–${TMAX}°C (feels ${FMIN}–${FMAX}°C) — $(comfort $TMAX $FMAX)"
  echo "  Rain: ${RAIN} mm (${RAIN_PCT}% chance)  |  UV: ${UV} ($(uv_risk $UV))"
  echo "  Wind: ${WIND} km/h  |  Humidity: ${HUMID}%"
  echo ""
done

# Hourly summary (next 24h, every 3h)
echo "--- Hourly (next 24h) ---"
for i in 0 3 6 9 12 15 18 21; do
  TIME=$(echo "$DATA" | jq -r ".hourly.time[$i]" | cut -dT -f2)
  TEMP=$(echo "$DATA" | jq -r ".hourly.temperature_2m[$i]")
  FEELS=$(echo "$DATA" | jq -r ".hourly.apparent_temperature[$i]")
  RPCT=$(echo "$DATA" | jq -r ".hourly.precipitation_probability[$i]")
  RMM=$(echo "$DATA" | jq -r ".hourly.precipitation[$i]")
  HUV=$(echo "$DATA" | jq -r ".hourly.uv_index[$i]")
  HWIND=$(echo "$DATA" | jq -r ".hourly.wind_speed_10m[$i]")
  echo "  ${TIME}: ${TEMP}°C (feels ${FEELS}°C) | rain ${RPCT}%/${RMM}mm | UV ${HUV} | wind ${HWIND}km/h"
done
