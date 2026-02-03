import os
import subprocess
import modal

MINUTES = 60
PORT = 8000
MODEL_NAME = "openai/gpt-oss-120b"
MODEL_REVISION = "main"
MAX_INPUTS = 16

vllm_image = (
    modal.Image.from_registry("nvidia/cuda:12.8.1-devel-ubuntu22.04", add_python="3.12")
    .entrypoint([])
    .uv_pip_install("vllm==0.13.0", "huggingface_hub[hf_transfer]==0.36.0")
    .env({"VLLM_USE_FLASHINFER_MOE_MXFP4_MXFP8": "1"})
)

hf_cache_vol = modal.Volume.from_name("huggingface-cache", create_if_missing=True)
vllm_cache_vol = modal.Volume.from_name("vllm-cache", create_if_missing=True)

app = modal.App("llm-gpt-oss-120b")


@app.function(
    image=vllm_image,
    gpu="A100-80GB",
    scaledown_window=10 * MINUTES,
    timeout=30 * MINUTES,
    volumes={
        "/root/.cache/huggingface": hf_cache_vol,
        "/root/.cache/vllm": vllm_cache_vol,
    },
    secrets=[modal.Secret.from_name("llm-api-key")],
)
@modal.concurrent(max_inputs=MAX_INPUTS)
@modal.web_server(port=PORT, startup_timeout=30 * MINUTES)
def serve():
    cmd = [
        "vllm", "serve", MODEL_NAME,
        "--revision", MODEL_REVISION,
        "--served-model-name", MODEL_NAME, "llm",
        "--host", "0.0.0.0",
        "--port", str(PORT),
        "--tensor-parallel-size", "1",
        "--enforce-eager",
        "--kv-cache-dtype", "fp8",
        "--max-num-batched-tokens", "16384",
        "--max-model-len", "32768",
        "--api-key", os.environ["API_KEY"],
    ]
    print(*cmd)
    subprocess.Popen(cmd)
