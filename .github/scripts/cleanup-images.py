#!/usr/bin/env python3

import argparse
from datetime import datetime
import json
import re
import subprocess
from urllib.parse import quote

SIGNATURE = re.compile(r"sha256-([0-9a-f]{64})\.sig")


def plan_cleanup(versions, inspect, protect):
    by_digest = {v["name"]: v for v in versions}
    images, signatures, retained = [], [], {protect}
    for version in versions:
        tags = version["metadata"]["container"]["tags"]
        matches = [SIGNATURE.fullmatch(tag) for tag in tags]
        if tags and all(matches):
            signatures.append((version, {f"sha256:{m[1]}" for m in matches}))
        elif "latest" in tags or any(tag.startswith("sha256-") for tag in tags):
            retained.add(version["name"])
        else:
            images.append(version)
    if protect not in by_digest or not any(
        "latest" in v["metadata"]["container"]["tags"] for v in versions
    ):
        raise ValueError("Current build or latest is missing; refusing cleanup")
    recent = sorted(
        (v for v in images if v["metadata"]["container"]["tags"]),
        key=lambda v: (datetime.fromisoformat(v["created_at"]), v["id"]), reverse=True,
    )
    retained.update(v["name"] for v in recent[:2])
    pending, visited = list(retained), set()
    while pending:
        digest = pending.pop()
        if digest in visited:
            continue
        visited.add(digest)
        manifest = inspect(digest)
        children = {m["digest"] for m in manifest.get("manifests", [])}
        if "subject" in manifest:
            children.add(manifest["subject"]["digest"])
        for version, subjects in signatures:
            if digest in subjects:
                children.add(version["name"])
        retained.update(children)
        pending.extend(children - visited)
    return [v for v in images if v["name"] not in retained] + [
        v for v, _ in signatures if v["name"] not in retained
    ]


def cleanup(owner, package, protect, delete=False):
    endpoint = (f"/users/{quote(owner, safe='')}/packages/container/"
                f"{quote(package, safe='')}/versions")
    api = ["gh", "api", "-H", "Accept: application/vnd.github+json",
           "-H", "X-GitHub-Api-Version: 2022-11-28"]

    def read_json(command):
        return json.loads(subprocess.run(
            command, check=True, capture_output=True, text=True,
        ).stdout)

    pages = read_json([*api, "--paginate", "--slurp",
                       f"{endpoint}?per_page=100&state=active"])
    versions = [version for page in pages for version in page]
    candidates = plan_cleanup(versions, lambda digest: read_json([
        "docker", "manifest", "inspect", f"ghcr.io/{owner.lower()}/{package}@{digest}",
    ]), protect)
    for version in candidates:
        tags = ", ".join(version["metadata"]["container"]["tags"]) or "untagged"
        print(f"{'Deleting' if delete else 'Would delete'} {version['id']}: {tags}", flush=True)
        if delete:
            subprocess.run([*api, "--method", "DELETE",
                            f"{endpoint}/{version['id']}"], check=True)
    print(f"{'Deleted' if delete else 'Found'} {len(candidates)} unused versions.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Keep latest plus two recent Ember builds and remove unused images/signatures."
    )
    parser.add_argument("owner")
    parser.add_argument("package")
    parser.add_argument("--protect", required=True, help="Digest of the build just verified")
    parser.add_argument("--delete", action="store_true", help="Apply cleanup (default: dry run)")
    args = parser.parse_args()
    cleanup(args.owner, args.package, args.protect, args.delete)
