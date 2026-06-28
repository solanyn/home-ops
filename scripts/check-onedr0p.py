#!/usr/bin/env python3
"""Compare structure of onedr0p/home-ops against this repo and report actionable differences."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_DIR = REPO_ROOT / "memory"
CACHE_FILE = MEMORY_DIR / "onedr0p-tree-cache.json"
STATE_FILE = MEMORY_DIR / "onedr0p-last-sha.txt"
CACHE_TTL = 86400

UPSTREAM_REPO = "onedr0p/home-ops"
UPSTREAM_APPS_PREFIX = "kubernetes/apps/"
LOCAL_APPS_DIR = REPO_ROOT / "kubernetes" / "apps"

SHARED_APPS = {
    "cert-manager",
    "external-secrets",
    "cilium",
    "flux",
    "kube-prometheus-stack",
    "home-assistant",
    "volsync",
    "spegel",
    "external-dns",
    "1password",
    "rook-ceph",
    "grafana",
    "talos",
    "coredns",
    "gateway-api",
    "openebs",
    "victoria-metrics",
}

IGNORED_APPS = {
    "sonarr",
    "radarr",
    "prowlarr",
    "lidarr",
    "readarr",
    "bazarr",
    "overseerr",
    "plex",
    "tautulli",
    "sabnzbd",
    "qbittorrent",
    "jellyfin",
    "jellyseerr",
    "recyclarr",
    "unpackerr",
    "autobrr",
    "cross-seed",
    "flaresolverr",
    "maintainerr",
    "notifiarr",
    "wizarr",
}


def gh_token():
    result = subprocess.run(
        ["gh", "auth", "token"], capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def gh_api(endpoint):
    result = subprocess.run(
        ["gh", "api", endpoint, "--paginate"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def fetch_upstream_sha():
    data = gh_api(f"repos/{UPSTREAM_REPO}/commits/main")
    return data["sha"]


def fetch_upstream_tree(sha):
    data = gh_api(f"repos/{UPSTREAM_REPO}/git/trees/{sha}?recursive=1")
    return data["tree"]


def load_cache():
    if CACHE_FILE.exists():
        cache = json.loads(CACHE_FILE.read_text())
        if time.time() - cache.get("timestamp", 0) < CACHE_TTL:
            return cache
    return None


def save_cache(sha, tree):
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(
        json.dumps({"timestamp": time.time(), "sha": sha, "tree": tree})
    )


def load_last_sha():
    if STATE_FILE.exists():
        return STATE_FILE.read_text().strip()
    return None


def save_last_sha(sha):
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(sha)


def get_upstream_tree():
    cache = load_cache()
    if cache:
        return cache["sha"], cache["tree"]
    sha = fetch_upstream_sha()
    tree = fetch_upstream_tree(sha)
    save_cache(sha, tree)
    return sha, tree


def extract_apps(tree):
    apps = {}
    for item in tree:
        path = item["path"]
        if not path.startswith(UPSTREAM_APPS_PREFIX):
            continue
        rel = path[len(UPSTREAM_APPS_PREFIX):]
        parts = rel.split("/")
        if len(parts) >= 2:
            namespace = parts[0]
            app_name = parts[1]
            key = f"{namespace}/{app_name}"
            if key not in apps:
                apps[key] = []
            apps[key].append(rel)
    return apps


def get_local_apps():
    apps = {}
    if not LOCAL_APPS_DIR.exists():
        return apps
    for ns_dir in sorted(LOCAL_APPS_DIR.iterdir()):
        if not ns_dir.is_dir():
            continue
        namespace = ns_dir.name
        for app_dir in sorted(ns_dir.iterdir()):
            if not app_dir.is_dir():
                continue
            key = f"{namespace}/{app_dir.name}"
            files = []
            for f in app_dir.rglob("*"):
                if f.is_file():
                    files.append(str(f.relative_to(LOCAL_APPS_DIR)))
            apps[key] = files
    return apps


def get_upstream_file_content(path):
    try:
        result = subprocess.run(
            ["gh", "api", f"repos/{UPSTREAM_REPO}/contents/{path}",
             "--jq", ".content"],
            capture_output=True, text=True, check=True,
        )
        import base64
        return base64.b64decode(result.stdout.strip()).decode("utf-8", errors="replace")
    except (subprocess.CalledProcessError, Exception):
        return None


def extract_chart_info(files, prefix=""):
    charts = {}
    for f in files:
        path = f if not prefix else f"{prefix}/{f}"
        if "helmrelease" in f.lower() and f.endswith(".yaml"):
            charts[path] = True
    return charts


def compare_file_structure(upstream_files, local_files, app_name):
    differences = []
    upstream_basenames = {os.path.basename(f) for f in upstream_files}
    local_basenames = {os.path.basename(f) for f in local_files}

    upstream_has_httproute = "httproute.yaml" in upstream_basenames
    local_has_httproute = "httproute.yaml" in local_basenames

    if upstream_has_httproute and not local_has_httproute:
        differences.append(f"  upstream has httproute.yaml (we use helmrelease values)")
    elif not upstream_has_httproute and local_has_httproute:
        differences.append(f"  upstream moved httproute into helmrelease values (we still have separate file)")

    upstream_has_oci = "ocirepository.yaml" in upstream_basenames
    local_has_oci = "ocirepository.yaml" in local_basenames
    upstream_has_helmrepo = "helmrepository.yaml" in upstream_basenames
    local_has_helmrepo = "helmrepository.yaml" in local_basenames

    if upstream_has_oci and not local_has_oci and local_has_helmrepo:
        differences.append(f"  upstream uses OCIRepository (we use HelmRepository)")
    elif upstream_has_helmrepo and not local_has_helmrepo and local_has_oci:
        differences.append(f"  upstream uses HelmRepository (we use OCIRepository)")

    upstream_only = upstream_basenames - local_basenames - {"httproute.yaml", "helmrepository.yaml", "ocirepository.yaml"}
    if upstream_only:
        interesting = {f for f in upstream_only if not f.startswith(".")}
        if interesting:
            differences.append(f"  upstream has extra files: {', '.join(sorted(interesting))}")

    return differences


def compare_helmrelease_versions(upstream_files, local_app_path, app_key):
    differences = []
    local_hr = local_app_path / "app" / "helmrelease.yaml"
    if not local_hr.exists():
        return differences

    local_content = local_hr.read_text()

    upstream_hr_path = None
    for f in upstream_files:
        if "helmrelease.yaml" in f and "/app/" in f:
            upstream_hr_path = f"{UPSTREAM_APPS_PREFIX}{f}"
            break

    if not upstream_hr_path:
        return differences

    upstream_content = get_upstream_file_content(upstream_hr_path)
    if not upstream_content:
        return differences

    import re

    def extract_chart_version(content):
        tag_match = re.search(r"tag:\s*[\"']?(\d+\.\d+\.\d+)", content)
        version_match = re.search(r"version:\s*[\"']?(\d+\.\d+\.\d+)", content)
        return tag_match.group(1) if tag_match else (version_match.group(1) if version_match else None)

    def parse_semver(v):
        parts = v.split(".")
        return tuple(int(p) for p in parts[:3])

    upstream_ver = extract_chart_version(upstream_content)
    local_ver = extract_chart_version(local_content)

    if upstream_ver and local_ver:
        try:
            u = parse_semver(upstream_ver)
            l = parse_semver(local_ver)
            if u[0] > l[0]:
                differences.append(
                    f"  major version jump: we have {local_ver}, upstream has {upstream_ver}"
                )
        except (ValueError, IndexError):
            pass

    def extract_chart_name(content):
        match = re.search(r"chart:\s*(\S+)", content)
        oci_match = re.search(r"url:\s*oci://([^\s]+)", content)
        return oci_match.group(1) if oci_match else (match.group(1) if match else None)

    upstream_chart = extract_chart_name(upstream_content)
    local_chart = extract_chart_name(local_content)
    if upstream_chart and local_chart and upstream_chart != local_chart:
        differences.append(f"  chart swap: we use {local_chart}, upstream uses {upstream_chart}")

    return differences


def find_new_apps(upstream_apps, local_apps):
    new_apps = []
    for key in sorted(upstream_apps.keys()):
        app_name = key.split("/")[-1]
        if app_name in IGNORED_APPS:
            continue
        if key not in local_apps:
            local_app_names = {k.split("/")[-1] for k in local_apps}
            if app_name not in local_app_names:
                new_apps.append(key)
    return new_apps


def find_structural_differences(upstream_apps, local_apps):
    differences = {}
    for key in sorted(upstream_apps.keys()):
        app_name = key.split("/")[-1]
        if app_name not in SHARED_APPS:
            continue

        local_key = None
        for lk in local_apps:
            if lk.split("/")[-1] == app_name:
                local_key = lk
                break

        if not local_key:
            continue

        diffs = compare_file_structure(
            upstream_apps[key], local_apps[local_key], app_name
        )

        ns, name = local_key.split("/", 1)
        local_app_path = LOCAL_APPS_DIR / ns / name
        version_diffs = compare_helmrelease_versions(
            upstream_apps[key], local_app_path, key
        )
        diffs.extend(version_diffs)

        if diffs:
            differences[app_name] = diffs

    return differences


def check_infrastructure_patterns(tree):
    patterns = []
    upstream_files = [item["path"] for item in tree]

    crd_files = [f for f in upstream_files if "/crds/" in f and f.endswith(".yaml")]
    local_crd_dirs = set()
    for d in LOCAL_APPS_DIR.rglob("crds"):
        if d.is_dir():
            local_crd_dirs.add(d.name)

    upstream_crd_apps = set()
    for f in crd_files:
        parts = f.split("/")
        for i, p in enumerate(parts):
            if p == "crds" and i > 0:
                upstream_crd_apps.add(parts[i - 1])

    upstream_components = set()
    for f in upstream_files:
        if "/components/" in f and f.startswith("kubernetes/"):
            parts = f.split("/")
            for i, p in enumerate(parts):
                if p == "components" and i + 1 < len(parts):
                    upstream_components.add(parts[i + 1])

    local_components = set()
    components_dir = REPO_ROOT / "kubernetes" / "components"
    if components_dir.exists():
        for d in components_dir.iterdir():
            if d.is_dir():
                local_components.add(d.name)

    new_components = upstream_components - local_components
    if new_components:
        patterns.append(f"New components upstream: {', '.join(sorted(new_components))}")

    upstream_justfile = None
    for f in upstream_files:
        if f.endswith("mod.just") and "kubernetes" in f:
            upstream_justfile = f
            break

    return patterns


def main():
    try:
        sha, tree = get_upstream_tree()
    except subprocess.CalledProcessError as e:
        print(f"Error fetching upstream repo: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    last_sha = load_last_sha()
    if last_sha == sha:
        cache = load_cache()
        if cache and time.time() - cache.get("timestamp", 0) < CACHE_TTL:
            print("No upstream changes since last check.")
            sys.exit(0)

    upstream_apps = extract_apps(tree)
    local_apps = get_local_apps()

    found_differences = False
    output_sections = []

    new_apps = find_new_apps(upstream_apps, local_apps)
    if new_apps:
        found_differences = True
        section = ["## New apps upstream (not in our repo)"]
        for app in new_apps[:20]:
            section.append(f"  - {app}")
        if len(new_apps) > 20:
            section.append(f"  ... and {len(new_apps) - 20} more")
        output_sections.append("\n".join(section))

    structural_diffs = find_structural_differences(upstream_apps, local_apps)
    if structural_diffs:
        found_differences = True
        section = ["## Structural differences in shared apps"]
        for app, diffs in sorted(structural_diffs.items()):
            section.append(f"  {app}:")
            section.extend(diffs)
        output_sections.append("\n".join(section))

    infra_patterns = check_infrastructure_patterns(tree)
    if infra_patterns:
        found_differences = True
        section = ["## Infrastructure pattern differences"]
        for p in infra_patterns:
            section.append(f"  - {p}")
        output_sections.append("\n".join(section))

    save_last_sha(sha)

    if found_differences:
        print(f"Upstream SHA: {sha[:12]}")
        print()
        for section in output_sections:
            print(section)
            print()
        sys.exit(2)
    else:
        print(f"No actionable differences found (upstream: {sha[:12]})")
        sys.exit(0)


if __name__ == "__main__":
    main()
