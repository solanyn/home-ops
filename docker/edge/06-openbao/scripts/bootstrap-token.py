#!/usr/bin/env python3
"""Create a least-privilege OpenBao token for the doco-cd bootstrap job.

The bootstrap container only needs to create/update the KV mount, the ESO
policy, the jwt auth method and the jwt role. It does NOT need a root token,
which would put full control of the secret store on the VPS.

Writes the token to the given path (0600) and never prints it; Andrew copies
it into the `openbao` 1Password item as OPENBAO_BOOTSTRAP_TOKEN.
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

ADDR = "https://bao.goyangi.io"
POLICY = "bootstrap"

# Exactly what bootstrap.py touches, no more. sys/mounts and sys/auth need
# read so the script can tell "already exists" from "must create".
POLICY_HCL = """# doco-cd openbao bootstrap job: create/update the ESO wiring only
path "sys/mounts"                { capabilities = ["read"] }
path "sys/mounts/kv"             { capabilities = ["read", "create", "update"] }
path "sys/auth"                  { capabilities = ["read"] }
path "sys/auth/jwt"              { capabilities = ["read", "create", "update"] }
path "sys/policies/acl/eso-read" { capabilities = ["read", "create", "update"] }
path "kv/config"                 { capabilities = ["read", "create", "update"] }
path "auth/jwt/config"           { capabilities = ["read", "create", "update"] }
path "auth/jwt/role/goyangi-eso" { capabilities = ["read", "create", "update"] }
# The job renews its own token on each run so it never expires between deploys.
path "auth/token/renew-self"     { capabilities = ["update"] }
"""


def root_token() -> str:
    res = subprocess.run(
        ["op", "read", "op://kubernetes/openbao/OPENBAO_ROOT_TOKEN"],
        capture_output=True, text=True,
    )
    if res.returncode != 0 or not res.stdout.strip():
        raise SystemExit(f"ERROR: cannot read root token: {res.stderr.strip()[:160]}")
    return res.stdout.strip()


def req(token: str, method: str, path: str, data: dict | None = None):
    body = json.dumps(data).encode() if data is not None else None
    r = urllib.request.Request(
        f"{ADDR}/v1/{path}", data=body, method=method,
        headers={"X-Vault-Token": token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path}: HTTP {e.code}: "
                         f"{e.read().decode(errors='replace')[:200]}") from None


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: bao-bootstrap-token.py <output-path>")
    out_path = sys.argv[1]

    rt = root_token()
    req(rt, "PUT", f"sys/policies/acl/{POLICY}", {"policy": POLICY_HCL})
    print(f"policy '{POLICY}' written")

    # Periodic, not a fixed TTL: a plain 32-day token would silently expire and
    # break deploys. A periodic token can be renewed indefinitely, and
    # bootstrap.py renews it on every run, so it stays valid as long as deploys
    # happen at least once per period.
    created = req(rt, "POST", "auth/token/create", {
        "policies": [POLICY],
        "display_name": "doco-cd-openbao-bootstrap",
        "no_parent": True,
        "renewable": True,
        "period": "720h",
    })
    token = created["auth"]["client_token"]

    # Prove the token is sufficient before handing it over.
    req(token, "GET", "sys/mounts")
    req(token, "GET", "sys/auth")
    req(token, "GET", "auth/jwt/role/goyangi-eso")
    req(token, "GET", "sys/policies/acl/eso-read")
    req(token, "PUT", "auth/token/renew-self", {})
    print("verified: token can read mounts, auth, role, policy and renew itself")

    # Prove it is NOT a root-equivalent token.
    try:
        req(token, "GET", "sys/policies/acl/root")
        print("WARNING: token can read the root policy (too broad)")
    except SystemExit:
        print("verified: token cannot read the root policy")

    fd = os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.write(fd, (token + "\n").encode())
    os.close(fd)
    print(f"token written to {out_path} (mode 0600, {len(token)} chars)")


if __name__ == "__main__":
    main()
