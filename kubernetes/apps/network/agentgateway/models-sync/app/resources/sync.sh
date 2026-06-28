#!/bin/sh
set -e

fetch_models() {
  local url="$1"
  local auth_header="$2"
  if [ -n "$auth_header" ]; then
    curl -fsSL --max-time 10 -H "Authorization: Bearer $auth_header" "$url"
  else
    curl -fsSL --max-time 10 "$url"
  fi
}

MLX=$(fetch_models "http://mac.internal:8080/v1/models" "")
MINIMAX=$(fetch_models "https://api.minimaxi.chat/v1/models" "$(echo "$MINIMAX_AUTH" | sed 's/^Bearer //')")
DEEPSEEK=$(fetch_models "https://api.deepseek.com/v1/models" "$(echo "$DEEPSEEK_AUTH" | sed 's/^Bearer //')")

MODELS=$(jq -s '{object:"list", data: [.[].data[] | {id:.id, object:"model", owned_by:(.owned_by // "agentgateway"), created:(.created // 0)}] | unique_by(.id)}' <<<"$MLX"$'\n'"$MINIMAX"$'\n'"$DEEPSEEK")

kubectl create configmap agentgateway-models \
  --from-literal=models.json="$MODELS" \
  --dry-run=client -o yaml | kubectl apply -f -