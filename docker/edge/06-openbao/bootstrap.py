#!/usr/bin/env python3
"""Configure OpenBao for External Secrets Operator (idempotent, re-runnable).

Creates the KV v2 mount, the read-only ESO policy, and a JWT auth role that
lets ESO authenticate with a projected service-account token.

Why JWT and not Kubernetes auth: OpenBao runs on the VPS and cannot reach the
cluster API server, so it cannot perform a TokenReview. Instead it validates
ESO's token locally against a static copy of this cluster's service-account
signing keys (JWKS), which are baked in here. There is therefore no bootstrap
secret in the cluster, no callback from OpenBao to the API server, and no
long-lived credential to rotate.

Because those keys are static, THIS IS THE THING TO RE-RUN IF ESO AUTH BREAKS
after a cluster service-account signing key rotation:

    kubectl get --raw /openid/v1/jwks > jwks.json
    ./bootstrap.py --jwks jwks.json

The mount, policy and role are only created if absent, and JWKS keys are
merged rather than replaced, so re-running is always safe. --check verifies
without changing anything and exits non-zero on drift.

Secrets: the token comes from 1Password via `op read` (--token-ref) and is never
printed. Only public JWKS material is written to OpenBao.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

DEFAULT_ADDR = "https://bao.goyangi.io"
DEFAULT_OP_TOKEN = "op://kubernetes/openbao/OPENBAO_ROOT_TOKEN"

KV_MOUNT = "kv"
ESO_SUBJECT = "system:serviceaccount:external-secrets:external-secrets"
ESO_AUDIENCE = "openbao"
ESO_POLICY = "eso-read"
ESO_ROLE = "goyangi-eso"
ESO_TTL = "1h"

# Read everything, write only under generated/ (where PushSecret writes).
ESO_POLICY_HCL = f"""# External Secrets Operator: read the KV mount, write only under generated/
path "{KV_MOUNT}/data/*"     {{ capabilities = ["read", "list"] }}
path "{KV_MOUNT}/metadata/*" {{ capabilities = ["read", "list"] }}
path "{KV_MOUNT}/data/generated/*"     {{ capabilities = ["create", "update", "read", "delete", "list"] }}
path "{KV_MOUNT}/metadata/generated/*" {{ capabilities = ["create", "update", "read", "delete", "list"] }}
"""


class BaoError(RuntimeError):
    pass


class Bao:
    def __init__(self, addr: str, token: str) -> None:
        self.addr, self.token = addr.rstrip("/"), token

    def _req(self, method: str, path: str, data: dict | None = None):
        body = json.dumps(data).encode() if data is not None else None
        req = urllib.request.Request(
            f"{self.addr}/v1/{path}",
            data=body,
            method=method,
            headers={"X-Vault-Token": self.token, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise BaoError(f"{method} {path}: HTTP {e.code}: "
                           f"{e.read().decode(errors='replace')[:200]}") from None
        except urllib.error.URLError as e:
            raise BaoError(f"{method} {path}: {e.reason}") from None
        return json.loads(raw) if raw else {}

    def read(self, path: str):
        return self._req("GET", path)

    def write(self, path: str, data: dict):
        return self._req("PUT", path, data)

    def has_mount(self, name: str) -> bool:
        mounts = (self.read("sys/mounts") or {}).get("data", {})
        return f"{name}/" in mounts

    def has_auth(self, name: str) -> bool:
        auths = (self.read("sys/auth") or {}).get("data", {})
        return f"{name}/" in auths


def read_token(ref: str | None = None) -> str:
    """Resolve the OpenBao token from 1Password, never echoing it.

    Workstation use only: this script is run by hand from the trusted host, so
    the token comes straight from `op`. When no interactive 1Password session
    exists (e.g. over ssh), fall back to the service-account token file that the
    other edge scripts use (`OP_TOKEN_FILE`, default `~/.op-token`).
    """
    if not ref:
        raise SystemExit("ERROR: --token-ref is required")
    env = dict(os.environ)
    if not env.get("OP_SERVICE_ACCOUNT_TOKEN"):
        token_file = pathlib.Path(env.get("OP_TOKEN_FILE", "~/.op-token")).expanduser()
        if token_file.is_file():
            env["OP_SERVICE_ACCOUNT_TOKEN"] = token_file.read_text().strip()
    res = subprocess.run(["op", "read", ref], capture_output=True, text=True, env=env)
    if res.returncode != 0 or not res.stdout.strip():
        raise SystemExit(f"ERROR: cannot read {ref}: {res.stderr.strip()[:160]}")
    return res.stdout.strip()


def jwks_to_pems(jwks: dict) -> list[str]:
    """Convert RFC 7517 RSA keys to PEM SubjectPublicKeyInfo.

    OpenBao takes PEM validation keys, while the cluster publishes a JWKS, so
    the RSA modulus/exponent are re-encoded as DER SPKI here. stdlib only.
    """
    def b64u(value: str) -> bytes:
        return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))

    def tlv(tag: int, value: bytes) -> bytes:
        n = len(value)
        if n < 128:
            length = bytes([n])
        else:
            lb = n.to_bytes((n.bit_length() + 7) // 8, "big")
            length = bytes([0x80 | len(lb)]) + lb
        return bytes([tag]) + length + value

    def integer(raw: bytes) -> bytes:
        raw = raw.lstrip(b"\x00") or b"\x00"
        return tlv(0x02, b"\x00" + raw if raw[0] & 0x80 else raw)

    pems = []
    for key in jwks.get("keys", []):
        if key.get("kty") != "RSA":
            print(f"    skipping non-RSA key {key.get('kid')}")
            continue
        rsa = tlv(0x30, integer(b64u(key["n"])) + integer(b64u(key["e"])))
        # OID 1.2.840.113549.1.1.1 (rsaEncryption) + NULL parameters
        algid = tlv(0x30, bytes.fromhex("06092a864886f70d010101") + b"\x05\x00")
        spki = tlv(0x30, algid + tlv(0x03, b"\x00" + rsa))
        encoded = base64.b64encode(spki).decode()
        lines = "\n".join(encoded[i:i + 64] for i in range(0, len(encoded), 64))
        pems.append(f"-----BEGIN PUBLIC KEY-----\n{lines}\n-----END PUBLIC KEY-----\n")
    if not pems:
        raise SystemExit("ERROR: no RSA keys found in the supplied JWKS")
    return pems


def check(bao: Bao, pems: list[str], replace: bool = False) -> bool:
    """Return True when everything is already in the desired state."""
    ok = True
    if not bao.has_mount(KV_MOUNT):
        print(f"  drift: kv mount '{KV_MOUNT}' missing")
        ok = False
    if not bao.has_auth("jwt"):
        print("  drift: jwt auth method missing")
        ok = False

    role = (bao.read(f"auth/jwt/role/{ESO_ROLE}") or {}).get("data", {})
    if not role:
        print(f"  drift: jwt role '{ESO_ROLE}' missing")
        ok = False
    else:
        if role.get("bound_subject") != ESO_SUBJECT:
            print(f"  drift: bound_subject={role.get('bound_subject')!r}")
            ok = False
        if role.get("bound_audiences") != [ESO_AUDIENCE]:
            print(f"  drift: bound_audiences={role.get('bound_audiences')!r}")
            ok = False
        if role.get("token_policies") != [ESO_POLICY]:
            print(f"  drift: token_policies={role.get('token_policies')!r}")
            ok = False

    cfg = (bao.read("auth/jwt/config") or {}).get("data", {})
    configured = cfg.get("jwt_validation_pubkeys") or []
    if not configured:
        print("  drift: no jwt validation keys configured")
        ok = False
    else:
        have = {k.strip() for k in configured}
        want = {k.strip() for k in pems}
        if replace and have != want:
            print("  drift: jwt validation keys differ from the supplied JWKS")
            ok = False
        elif not replace and not want.issubset(have):
            print("  drift: supplied JWKS keys are not all trusted yet")
            ok = False
    return ok


def apply(bao: Bao, pems: list[str], replace: bool = False) -> None:
    if not bao.has_mount(KV_MOUNT):
        bao.write(f"sys/mounts/{KV_MOUNT}", {"type": "kv", "options": {"version": "2"}})
        print(f"created kv v{mount_version(bao)} mount '{KV_MOUNT}'")
    else:
        print(f"kv mount '{KV_MOUNT}' present")

    bao.write(f"{KV_MOUNT}/config", {"max_versions": 10})
    print(f"kv '{KV_MOUNT}' max_versions=10")

    bao.write(f"sys/policies/acl/{ESO_POLICY}", {"policy": ESO_POLICY_HCL})
    print(f"policy '{ESO_POLICY}' written")

    if not bao.has_auth("jwt"):
        bao.write("sys/auth/jwt", {"type": "jwt"})
        print("jwt auth method enabled")
    else:
        print("jwt auth method present")

    # Merged, not replaced: a stale committed JWKS must never be able to
    # remove the key ESO is currently authenticating with. Use --replace for
    # a deliberate rotation after confirming the new keys work.
    cfg = (bao.read("auth/jwt/config") or {}).get("data", {})
    existing = cfg.get("jwt_validation_pubkeys") or []
    if replace:
        merged = pems
    else:
        seen = {k.strip() for k in existing}
        merged = list(existing) + [p for p in pems if p.strip() not in seen]
    bao.write("auth/jwt/config", {
        "jwt_validation_pubkeys": merged,
        "jwt_supported_algs": ["RS256"],
    })
    added = len(merged) - len(existing)
    print(f"jwt validation keys: {len(merged)} total"
          f" ({'replaced' if replace else f'{max(added, 0)} added, 0 removed'})")

    bao.write(f"auth/jwt/role/{ESO_ROLE}", {
        "role_type": "jwt",
        "bound_audiences": [ESO_AUDIENCE],
        "bound_subject": ESO_SUBJECT,
        "user_claim": "sub",
        "token_policies": [ESO_POLICY],
        "token_ttl": ESO_TTL,
    })
    print(f"jwt role '{ESO_ROLE}' written "
          f"(sub={ESO_SUBJECT}, aud={ESO_AUDIENCE}, ttl={ESO_TTL})")


def mount_version(bao: Bao) -> int:
    mounts = (bao.read("sys/mounts") or {}).get("data", {})
    return int((mounts.get(f"{KV_MOUNT}/", {}).get("options") or {}).get("version", 2))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--addr", default=DEFAULT_ADDR, help=f"OpenBao address (default {DEFAULT_ADDR})")
    ap.add_argument("--jwks", help="cluster service-account JWKS JSON file; omit to run "
                                   "`kubectl get --raw /openid/v1/jwks` directly")
    ap.add_argument("--token-ref", default=DEFAULT_OP_TOKEN,
                    help="1Password reference for a token with policy-write access")
    ap.add_argument("--replace", action="store_true",
                    help="replace trusted JWKS keys instead of merging (deliberate rotation)")
    ap.add_argument("--check", action="store_true",
                    help="only report drift; exit 1 if anything is missing")
    args = ap.parse_args()

    # Read the cluster's signing keys fresh by default, like jfroy/etincelle:
    # a committed copy silently goes stale when the signing key rotates.
    if args.jwks:
        with open(args.jwks) as fh:
            jwks = json.load(fh)
    else:
        try:
            raw = subprocess.run(["kubectl", "get", "--raw", "/openid/v1/jwks"],
                                 capture_output=True, text=True, check=True).stdout
        except (FileNotFoundError, subprocess.CalledProcessError) as exc:
            raise SystemExit(f"ERROR: cannot read the cluster JWKS via kubectl "
                             f"({exc}); pass --jwks with a saved file instead") from None
        jwks = json.loads(raw)
    pems = jwks_to_pems(jwks)

    token = read_token(args.token_ref)
    bao = Bao(args.addr, token)

    # /sys/health is unauthenticated; it tells us whether the instance is usable.
    health = json.loads(
        urllib.request.urlopen(f"{args.addr}/v1/sys/health", timeout=15).read().decode() or "{}"
    )
    if health.get("sealed") or not health.get("initialized"):
        raise SystemExit(f"ERROR: OpenBao not ready (sealed={health.get('sealed')}, "
                         f"initialized={health.get('initialized')})")

    print(f"OpenBao {args.addr}: initialized, unsealed")
    if args.check:
        if check(bao, pems, replace=args.replace):
            print("in sync")
            return
        raise SystemExit(1)

    apply(bao, pems, replace=args.replace)
    print("verifying...")
    if not check(bao, pems, replace=args.replace):
        raise SystemExit("ERROR: state does not match after apply")
    print("done: in sync")


if __name__ == "__main__":
    try:
        main()
    except BaoError as exc:
        raise SystemExit(f"ERROR: {exc}") from None
