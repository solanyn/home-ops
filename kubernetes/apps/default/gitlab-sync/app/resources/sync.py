# /// script
# dependencies = ["httpx"]
# ///
import os
import httpx
import json
import sys

GITLAB_URL = os.environ["GITLAB_URL"]
GITLAB_TOKEN = os.environ["GITLAB_TOKEN"]
GITLAB_PROJECT_ID = os.environ["GITLAB_PROJECT_ID"]
FORGEJO_URL = os.environ["FORGEJO_URL"]
FORGEJO_TOKEN = os.environ["FORGEJO_TOKEN"]
FORGEJO_OWNER = os.environ["FORGEJO_OWNER"]
FORGEJO_REPO = os.environ["FORGEJO_REPO"]


def gitlab_get(client: httpx.Client, path: str, params: dict = None) -> list | dict:
    url = f"{GITLAB_URL}/api/v4{path}"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    results = []
    page = 1
    while True:
        p = {"per_page": 100, "page": page, **(params or {})}
        resp = client.get(url, headers=headers, params=p)
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list):
            if not data:
                break
            results.extend(data)
            page += 1
        else:
            return data
    return results


def forgejo_get(client: httpx.Client, path: str) -> list | dict:
    url = f"{FORGEJO_URL}/api/v1{path}"
    headers = {"Authorization": f"token {FORGEJO_TOKEN}"}
    resp = client.get(url, headers=headers)
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return resp.json()


def forgejo_post(client: httpx.Client, path: str, data: dict) -> dict:
    url = f"{FORGEJO_URL}/api/v1{path}"
    headers = {"Authorization": f"token {FORGEJO_TOKEN}"}
    resp = client.post(url, headers=headers, json=data)
    if resp.status_code == 422:
        print(f"    422 error: {resp.text}")
    resp.raise_for_status()
    return resp.json()


def forgejo_patch(client: httpx.Client, path: str, data: dict) -> dict:
    url = f"{FORGEJO_URL}/api/v1{path}"
    headers = {"Authorization": f"token {FORGEJO_TOKEN}"}
    resp = client.patch(url, headers=headers, json=data)
    resp.raise_for_status()
    return resp.json()


def sync_labels(client: httpx.Client):
    print("Syncing labels...")
    gl_labels = gitlab_get(client, f"/projects/{GITLAB_PROJECT_ID}/labels")
    fg_labels = (
        forgejo_get(client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/labels") or []
    )
    fg_label_names = {l["name"] for l in fg_labels}

    for label in gl_labels:
        if label["name"] not in fg_label_names:
            print(f"  Creating label: {label['name']}")
            forgejo_post(
                client,
                f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/labels",
                {
                    "name": label["name"],
                    "color": label["color"].lstrip("#"),
                    "description": (label.get("description") or "")[:255],
                },
            )


def sync_milestones(client: httpx.Client) -> dict:
    print("Syncing milestones...")
    gl_milestones = gitlab_get(
        client, f"/projects/{GITLAB_PROJECT_ID}/milestones", {"state": "all"}
    )
    fg_milestones = (
        forgejo_get(
            client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/milestones?state=all"
        )
        or []
    )
    fg_milestone_map = {m["title"]: m["id"] for m in fg_milestones}
    gl_to_fg = {}

    for ms in gl_milestones:
        if ms["title"] in fg_milestone_map:
            gl_to_fg[ms["id"]] = fg_milestone_map[ms["title"]]
        else:
            print(f"  Creating milestone: {ms['title']}")
            data = {
                "title": ms["title"],
                "description": ms.get("description", ""),
                "state": "open" if ms["state"] == "active" else "closed",
            }
            if ms.get("due_date"):
                data["due_on"] = ms["due_date"] + "T00:00:00Z"
            created = forgejo_post(
                client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/milestones", data
            )
            gl_to_fg[ms["id"]] = created["id"]

    return gl_to_fg


def sync_issues(client: httpx.Client, milestone_map: dict):
    print("Syncing issues...")
    gl_issues = gitlab_get(
        client, f"/projects/{GITLAB_PROJECT_ID}/issues", {"state": "all"}
    )
    fg_issues = (
        forgejo_get(
            client,
            f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues?state=all&type=issues",
        )
        or []
    )
    fg_issue_map = {}
    for issue in fg_issues:
        if issue.get("body") and "gitlab-id:" in issue["body"]:
            for line in issue["body"].split("\n"):
                if line.startswith("<!-- gitlab-id:"):
                    gl_id = line.split(":")[1].split(" ")[0]
                    fg_issue_map[gl_id] = issue
                    break

    for issue in gl_issues:
        gl_id = str(issue["iid"])
        body = issue.get("description") or ""
        body = f"<!-- gitlab-id:{gl_id} -->\n\n{body}\n\n---\n*Synced from GitLab #{gl_id}*"

        labels = [l for l in issue.get("labels", [])]
        data = {
            "title": issue["title"],
            "body": body,
            "labels": labels,
        }
        if issue.get("milestone") and issue["milestone"]["id"] in milestone_map:
            data["milestone"] = milestone_map[issue["milestone"]["id"]]

        if gl_id in fg_issue_map:
            fg_issue = fg_issue_map[gl_id]
            fg_state = "open" if fg_issue["state"] == "open" else "closed"
            gl_state = "open" if issue["state"] == "opened" else "closed"
            if fg_issue["title"] != issue["title"] or fg_state != gl_state:
                print(f"  Updating issue #{gl_id}: {issue['title']}")
                data["state"] = gl_state
                forgejo_patch(
                    client,
                    f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues/{fg_issue['number']}",
                    data,
                )
        else:
            print(f"  Creating issue #{gl_id}: {issue['title']}")
            created = forgejo_post(
                client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues", data
            )
            if issue["state"] != "opened":
                forgejo_patch(
                    client,
                    f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues/{created['number']}",
                    {"state": "closed"},
                )


def sync_merge_requests(client: httpx.Client, milestone_map: dict):
    print("Syncing merge requests as issues...")
    gl_mrs = gitlab_get(
        client, f"/projects/{GITLAB_PROJECT_ID}/merge_requests", {"state": "all"}
    )
    fg_issues = (
        forgejo_get(
            client,
            f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues?state=all&type=issues",
        )
        or []
    )
    fg_mr_map = {}
    for issue in fg_issues:
        if issue.get("body") and "gitlab-mr:" in issue["body"]:
            for line in issue["body"].split("\n"):
                if line.startswith("<!-- gitlab-mr:"):
                    mr_id = line.split(":")[1].split(" ")[0]
                    fg_mr_map[mr_id] = issue
                    break

    for mr in gl_mrs:
        mr_id = str(mr["iid"])
        body = mr.get("description") or ""
        state_emoji = (
            "🟢"
            if mr["state"] == "merged"
            else ("🔴" if mr["state"] == "closed" else "🟡")
        )
        body = f"<!-- gitlab-mr:{mr_id} -->\n\n**Merge Request** {state_emoji} `{mr['source_branch']}` → `{mr['target_branch']}`\n\n{body}\n\n---\n*Synced from GitLab MR !{mr_id}*"

        labels = [l for l in mr.get("labels", [])] + ["merge-request"]
        data = {
            "title": f"[MR] {mr['title']}",
            "body": body,
            "labels": labels,
        }
        if mr.get("milestone") and mr["milestone"]["id"] in milestone_map:
            data["milestone"] = milestone_map[mr["milestone"]["id"]]

        if mr_id in fg_mr_map:
            fg_issue = fg_mr_map[mr_id]
            fg_state = "open" if fg_issue["state"] == "open" else "closed"
            gl_state = "open" if mr["state"] == "opened" else "closed"
            if fg_issue["title"] != data["title"] or fg_state != gl_state:
                print(f"  Updating MR !{mr_id}: {mr['title']}")
                data["state"] = gl_state
                forgejo_patch(
                    client,
                    f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues/{fg_issue['number']}",
                    data,
                )
        else:
            print(f"  Creating MR !{mr_id}: {mr['title']}")
            created = forgejo_post(
                client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues", data
            )
            if mr["state"] != "opened":
                forgejo_patch(
                    client,
                    f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/issues/{created['number']}",
                    {"state": "closed"},
                )


def sync_releases(client: httpx.Client):
    print("Syncing releases...")
    gl_releases = gitlab_get(client, f"/projects/{GITLAB_PROJECT_ID}/releases")
    fg_releases = (
        forgejo_get(client, f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/releases") or []
    )
    fg_release_tags = {r["tag_name"] for r in fg_releases}

    for release in gl_releases:
        if release["tag_name"] in fg_release_tags:
            continue
        print(f"  Creating release: {release['tag_name']}")
        try:
            forgejo_post(
                client,
                f"/repos/{FORGEJO_OWNER}/{FORGEJO_REPO}/releases",
                {
                    "tag_name": release["tag_name"],
                    "name": release.get("name") or release["tag_name"],
                    "body": release.get("description") or "",
                    "draft": False,
                    "prerelease": False,
                },
            )
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                print(f"    Skipped (tag not found): {release['tag_name']}")
            else:
                raise


def main():
    print(
        f"Syncing GitLab project {GITLAB_PROJECT_ID} to Forgejo {FORGEJO_OWNER}/{FORGEJO_REPO}"
    )
    with httpx.Client(timeout=60, verify=False) as client:
        sync_labels(client)
        milestone_map = sync_milestones(client)
        sync_issues(client, milestone_map)
        sync_merge_requests(client, milestone_map)
        sync_releases(client)
    print("Sync complete!")


if __name__ == "__main__":
    main()
