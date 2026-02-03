import os
import subprocess
import time
import modal

MINUTES = 60
PORT = 8000
MODEL_NAME = "mistralai/Devstral-Small-2-24B-Instruct-2512"
TARGET_INPUTS = 32

sglang_image = (
    modal.Image.from_registry("lmsysorg/sglang:v0.5.6.post2-cu129-amd64-runtime")
    .entrypoint([])
    .uv_pip_install("huggingface-hub==0.36.0", "requests")
    .env({
        "HF_HUB_CACHE": "/root/.cache/huggingface",
        "HF_XET_HIGH_PERFORMANCE": "1",
        "TORCHINDUCTOR_COMPILE_THREADS": "1",
    })
)

hf_cache_vol = modal.Volume.from_name("huggingface-cache", create_if_missing=True)
app = modal.App("llm-devstral-small-2-24b")


def wait_ready(process, timeout=5 * MINUTES):
    import requests
    deadline = time.time() + timeout
    while time.time() < deadline:
        if (rc := process.poll()) is not None:
            raise subprocess.CalledProcessError(rc, cmd=process.args)
        try:
            requests.get(f"http://127.0.0.1:{PORT}/health").raise_for_status()
            return
        except (ConnectionError, requests.exceptions.RequestException):
            time.sleep(1)
    raise TimeoutError(f"SGLang server not ready within {timeout}s")


def warmup():
    import requests
    headers = {"Authorization": f"Bearer {os.environ['API_KEY']}"}
    for _ in range(3):
        requests.post(f"http://127.0.0.1:{PORT}/v1/chat/completions", json={
            "model": MODEL_NAME,
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 8,
        }, headers=headers).raise_for_status()


def sleep():
    import requests
    requests.post(f"http://127.0.0.1:{PORT}/release_memory_occupation", json={}).raise_for_status()


def wake_up():
    import requests
    requests.post(f"http://127.0.0.1:{PORT}/resume_memory_occupation", json={}).raise_for_status()


@app.cls(
    image=sglang_image,
    gpu="L40S",
    volumes={"/root/.cache/huggingface": hf_cache_vol},
    scaledown_window=10 * MINUTES,
    timeout=30 * MINUTES,
    secrets=[modal.Secret.from_name("llm-api-key")],
    enable_memory_snapshot=True,
    experimental_options={"enable_gpu_snapshot": True},
)
@modal.concurrent(max_inputs=TARGET_INPUTS)
class SGLang:
    @modal.enter(snap=True)
    def startup(self):
        cmd = [
            "python", "-m", "sglang.launch_server",
            "--model-path", MODEL_NAME,
            "--served-model-name", MODEL_NAME,
            "--host", "0.0.0.0",
            "--port", str(PORT),
            "--cuda-graph-max-bs", str(TARGET_INPUTS * 2),
            "--max-running-requests", str(TARGET_INPUTS),
            "--context-length", "32768",
            "--api-key", os.environ["API_KEY"],
            "--enable-metrics",
            "--enable-memory-saver",
            "--enable-weights-cpu-backup",
        ]
        self.process = subprocess.Popen(cmd)
        wait_ready(self.process)
        warmup()
        sleep()

    @modal.enter(snap=False)
    def restore(self):
        wake_up()

    @modal.web_server(port=PORT, startup_timeout=10 * MINUTES)
    def serve(self):
        pass

    @modal.exit()
    def stop(self):
        self.process.terminate()
