#!/usr/bin/env python3
"""Structural checks for the OpenBao edge bootstrap; never prints secrets.

Modes:
  config <path>   assert required stanzas exist in config.hcl
  init <path>     assert the operator-init JSON has 1 recovery key + root token
  status          read `bao status -format=json` on stdin; refuse if initialized
  inspect         read `docker inspect openbao` JSON on stdin; print state
"""
import json
import pathlib
import sys

REQUIRED = {
    "raft storage": 'storage "raft"',
    "static seal": 'seal "static"',
    "seal from env": "env://OPENBAO_STATIC_SEAL_KEY",
    "audit device": 'audit "file" "default"',
    "audit to stdout": 'file_path = "stdout"',
    "forwarded-for trusted": "x_forwarded_for_authorized_addrs",
    "mlock disabled": "disable_mlock = true",
}


def read_json_arg_or_stdin(argv):
    if len(argv) > 2:
        return json.loads(pathlib.Path(argv[2]).read_text())
    text = sys.stdin.read().strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # `docker inspect` interleaves its own error text on some failures;
        # fall back to decoding just the first JSON document.
        obj, _ = json.JSONDecoder().raw_decode(text)
        return obj


def check_config(path):
    cfg = pathlib.Path(path).read_text()
    missing = [name for name, needle in REQUIRED.items() if needle not in cfg]
    if missing:
        print("FAIL: config.hcl missing " + ", ".join(missing), file=sys.stderr)
        return 1
    print("OK: config.hcl has all required stanzas")
    return 0


def check_init(data):
    recovery = data.get("recovery_keys_b64") or []
    unseal = data.get("unseal_keys_b64") or []
    token = data.get("root_token") or ""
    print(
        f"OK: recovery_keys={len(recovery)} unseal_keys={len(unseal)} "
        f"root_token={'present' if token else 'MISSING'}"
    )
    if len(recovery) != 1 or not token:
        print("FAIL: expected exactly 1 recovery key and a root token", file=sys.stderr)
        return 1
    return 0


def check_status(data):
    if data is None:
        print("REFUSING: could not read OpenBao status (container not running?)", file=sys.stderr)
        return 1
    if data.get("initialized"):
        print("REFUSING: OpenBao is already initialized", file=sys.stderr)
        return 1
    print("OK: not initialized yet")
    return 0


def show_inspect(data):
    if isinstance(data, list):
        if not data:
            print("container=absent")
            return 0
        data = data[0]
    state = data.get("State", {})
    health = (state.get("Health") or {}).get("Status", "none")
    print(f"container={state.get('Status', 'unknown')} health={health}")
    return 0


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    try:
        if mode == "config":
            return check_config(argv[2])
        if mode == "init":
            return check_init(read_json_arg_or_stdin(argv))
        if mode == "status":
            return check_status(read_json_arg_or_stdin(argv))
        if mode == "inspect":
            return show_inspect(read_json_arg_or_stdin(argv))
    except (IndexError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {mode}: {exc}", file=sys.stderr)
        return 2
    print("usage: validate.py {config <path>|init <path>|status|inspect}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
