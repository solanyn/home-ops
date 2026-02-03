# Modal LLM Apps

SGLang-based LLM serving with GPU memory snapshots for fast cold starts.

## Deploy

```bash
uv run modal deploy ministral_8b.py
uv run modal deploy devstral_small_2_24b.py
uv run modal deploy gpt_oss_120b.py
```

## Endpoints

After deployment, endpoints are available at:
- `https://solanyn--llm-ministral-8b-sglang-serve.modal.run`
- `https://solanyn--llm-devstral-small-2-24b-sglang-serve.modal.run`
- `https://solanyn--llm-gpt-oss-120b-sglang-serve.modal.run`

All endpoints require Bearer token auth via the `llm-api-key` Modal secret.

## Models

| App | Model | GPU | Features |
|-----|-------|-----|----------|
| ministral-8b | mistralai/Ministral-8B-Instruct-2410 | L4 | Fast fallback |
| devstral-small-2-24b | mistralai/Devstral-Small-2-24B-Instruct-2512 | L40S | Agentic coding |
| gpt-oss-120b | openai/gpt-oss-120b | A100-80GB | EAGLE3 speculative decoding |

## GPU Snapshots

First cold start creates the snapshot (~2-5 min). Subsequent cold starts restore from snapshot (~10x faster).

To prewarm (create snapshots):
```bash
curl https://solanyn--llm-ministral-8b-sglang-serve.modal.run/health
```
