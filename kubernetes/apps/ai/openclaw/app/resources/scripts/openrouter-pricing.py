#!/usr/bin/env python3
"""Report new and good-value Qwen models from OpenRouter."""

import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone


BASE_URL = "https://openrouter.ai/api/v1/models"
CACHE_PATH = os.path.expanduser("~/.hermes/cache/openrouter-models.json")
WATCH_PREFIXES = ("qwen/qwen3",)


def fetch_models() -> list[dict]:
    query = urllib.parse.urlencode(
        {
            "q": "qwen3",
            "sort": "newest",
            "limit": 1000,
            "output_modalities": "text",
        }
    )
    request = urllib.request.Request(
        f"{BASE_URL}?{query}",
        headers={"User-Agent": "Hermes/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    return payload["data"]


def price_per_million(value: str | None) -> float:
    return float(value or 0) * 1_000_000


def is_watched(model: dict) -> bool:
    model_id = model.get("id", "")
    return model_id.startswith(WATCH_PREFIXES)


def main() -> None:
    silent = "--silent" in sys.argv
    try:
        models = [model for model in fetch_models() if is_watched(model)]
    except Exception as error:
        print(f"[ERROR] Failed to fetch OpenRouter models: {error}", file=sys.stderr)
        raise SystemExit(1)

    current = {
        model["id"]: {
            "id": model["id"],
            "created": model.get("created", 0),
            "input": price_per_million(model.get("pricing", {}).get("prompt")),
            "output": price_per_million(model.get("pricing", {}).get("completion")),
            "context": model.get("context_length", 0),
            "tools": "tools" in model.get("supported_parameters", []),
        }
        for model in models
    }

    previous = {}
    if os.path.exists(CACHE_PATH):
        try:
            with open(CACHE_PATH, encoding="utf-8") as cache:
                previous = json.load(cache).get("models", {})
        except (OSError, ValueError):
            previous = {}

    new_ids = sorted(set(current) - set(previous))
    picks = sorted(
        current.values(),
        key=lambda model: (model["output"] or float("inf"), model["input"]),
    )[:8]

    os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as cache:
        json.dump(
            {
                "fetched_at": datetime.now(timezone.utc).isoformat(),
                "models": current,
            },
            cache,
            indent=2,
        )

    if not new_ids and silent:
        print("[SILENT]")
        return

    print("OpenRouter Qwen model watch")
    if new_ids:
        print("\nNew since the previous check:")
        for model_id in new_ids:
            print(f"- {model_id}")
    else:
        print("\nNo new Qwen models since the previous check.")

    print("\nLowest output-price candidates ($/MTok):")
    for model in picks:
        tools = "tools" if model["tools"] else "no-tools"
        print(
            f"- {model['id']}: input ${model['input']:.4f}, "
            f"output ${model['output']:.4f}, "
            f"context {model['context']:,}, {tools}"
        )


if __name__ == "__main__":
    main()
