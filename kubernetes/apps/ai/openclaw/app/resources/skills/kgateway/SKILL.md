---
name: agentgateway
description: >
  Query and use the Agent Gateway (agentgateway) — OpenAI-compatible LLM proxy with
  fallback chains, MCP server routing, and audio endpoints (STT/TTS).
  Use when making LLM API calls, choosing models, configuring routes, using speech services,
  or connecting to MCP servers. Triggers on gateway, agentgateway, LLM route, model selection,
  TTS, STT, transcription, speech, Opus, Haiku, Gemma, MCP.
---

# Agent Gateway (agentgateway)

OpenAI-compatible LLM + MCP proxy at `https://gateway.goyangi.io`. Uses `agentgateway.dev` CRDs on Kubernetes with Envoy data plane.

## LLM Routes

### Direct Model Routes

| Route | Backend | Fallback | Notes |
|-------|---------|----------|-------|
| `/v1/opus` | Claude Opus 4.6 (via kiro-gateway) | Gemma 4 local | Primary quality route |
| `/v1/kiro` | Claude Opus 4.6 (via kiro-gateway) | Gemma 4 local | Alias for opus |
| `/v1/haiku` | Claude Haiku 4.5 (via kiro-gateway) | None | Fast, direct |
| `/v1/gemma-4` | Gemma 4 E4B (MLX local) | None | Fully local, mac.internal:8080 |

### Audio Endpoints

| Route | Service | Notes |
|-------|---------|-------|
| `/v1/audio/transcriptions` | Parakeet TDT 0.6B (STT) | OpenAI Whisper-compatible, mac.internal:8000 |
| `/v1/audio/speech` | Kokoro 82M (TTS) | OpenAI TTS-compatible, mac.internal:8000 |

Audio routes go through ExternalName service `mlx-audio` → `mac.internal:8000`.

## MCP Server Routes

| Route | Backend | Protocol |
|-------|---------|----------|
| `/mcp/github` | `api.githubcopilot.com` | HTTPS + auth |
| `/mcp/context7` | `mcp.context7.com` | HTTPS + auth |
| `/mcp/flux` | `flux-operator-mcp.network.svc.cluster.local:9090` | StreamableHTTP |
| `/mcp/grafana` | `grafana-mcp.observability.svc.cluster.local:8000` | StreamableHTTP |
| `/mcp/notion` | `notion-mcp.network.svc.cluster.local:3000` | StreamableHTTP |

## Usage

### Chat Completion

```bash
curl -s https://gateway.goyangi.io/v1/opus/chat/completions \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4.6",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 1024
  }'
```

### Speech-to-Text

```bash
curl -s https://gateway.goyangi.io/v1/audio/transcriptions \
  -H "Authorization: Bearer <api-key>" \
  -F file=@audio.wav \
  -F model=parakeet
```

### Text-to-Speech

```bash
curl -s https://gateway.goyangi.io/v1/audio/speech \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world", "model": "kokoro", "voice": "af_heart"}' \
  --output speech.mp3
```

## Auth

- **External:** API key required (AgentgatewayPolicy `llm-apikey-auth`, Strict mode). Key from 1Password `agentgateway-apikey`.
- **Internal (cluster):** Same policy applies — need valid API key even from inside cluster.
- Standard `Authorization: Bearer <key>` header.

## Architecture

- **Gateway CRD:** `Gateway/ai` in `network` namespace, class `agentgateway`
- **LBIPAM:** `192.168.69.130` / `fd5d:a293:f321:69::130`
- **DNS:** `gateway.goyangi.io` (external-dns annotation)
- **TLS:** Terminates at gateway using `goyangi-io-tls` cert
- **Backends:** `AgentgatewayBackend` CRDs with provider groups (fallback chains)
- **Policies:** `AgentgatewayPolicy` for API key auth
- **Helm chart:** `agentgateway` via OCIRepository

### Backend Chain (Opus example)

```
claude-opus backend:
  Group 1 (primary): kiro provider → mac.internal:8001 (Claude Opus 4.6)
  Group 2 (fallback): mlx-gemma → mac.internal:8080 (Gemma 4 E4B)
```

## Gemma 4 Quirks

- Reasoning model — uses thinking tokens before output
- Set `max_tokens` ≥ 500 (lower may exhaust budget during thinking)
- Runs on Mac Mini via MLX (`mlx-community/gemma-4-e4b-it-4bit`)
- Slower than cloud but fully private and always available

## Config Location

```
kubernetes/apps/network/agentgateway/
├── app/          # HelmRelease, ExternalSecret, monitoring
├── crds/         # AgentgatewayBackend/Policy CRDs
├── gateway/      # Gateway resource, parameters, admin/ai listeners
├── llm/          # LLM backends, routes, audio, security policy
└── mcp/          # MCP server backends and routes
```

Modify in `home-ops` repo → commit → Flux reconciles.

## Model Selection

| Need | Route | Why |
|------|-------|-----|
| Best quality | `/v1/opus` or `/v1/kiro` | Opus with Gemma fallback |
| Fast | `/v1/haiku` | Haiku 4.5 direct |
| Fully local | `/v1/gemma-4` | No external calls |
| Transcription | `/v1/audio/transcriptions` | Parakeet STT |
| Speech | `/v1/audio/speech` | Kokoro TTS |

Prefer Claude routes — Andrew pays subscription, Claude models are free.
