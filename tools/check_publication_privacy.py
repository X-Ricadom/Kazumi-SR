"""Check published content and fork commits without printing sensitive values."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

BASE = "184f8db535f9b4098ada763fcefea8e602126dc7"
EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}")
HOME = re.compile(r"(?i:[a-z]:[\\/](?:Users|Files|Data)[\\/])|(?<![\w/:])/(?:home|Users)/[^/\s]+/")
PHONE = re.compile(r"(?<![\w])1[3-9]\d{9}(?![\w])")
SECRETS = re.compile(
    r"gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|"
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|"
    r"AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{32,}"
)


def git(*args, data=None):
    result = subprocess.run(["git", *args], input=data, capture_output=True)
    if result.returncode:
        raise RuntimeError("Git command failed; verify the repository and base revision")
    return result.stdout


def private_email(value):
    value = value.lower()
    return not (value.endswith("@users.noreply.github.com") or value == "noreply@github.com")


def audit(base=BASE, staged=False, revision="HEAD"):
    issues = []
    # Exact upstream blob IDs preserve third-party copyright/contact notices.
    # Editing an exempt file invalidates the exemption automatically.
    metadata_path = Path(__file__).with_name("publication_upstream_metadata.json")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8-sig")) if metadata_path.exists() else {}
    records = git("ls-files", "--stage", "-z") if staged else git("ls-tree", "-r", "-z", revision)
    blobs = []
    for record in records.split(b"\0"):
        if not record:
            continue
        info, raw_path = record.split(b"\t", 1)
        fields = info.split()
        oid = fields[1] if staged else fields[2]
        path = raw_path.decode("utf-8")
        if (path.startswith((".cache/", "build/", ".dart_tool/"))
                or path in {"pubspec_overrides.yaml", ".kazumi_build_defines.env"}
                or path.rsplit("/", 1)[-1].startswith(".env")):
            issues.append(f"{path}: local data must not be tracked")
        if fields[0] == b"160000":
            continue
        blobs.append((oid, path))
    output = git("cat-file", "--batch", data=b"\n".join(oid for oid, _ in blobs) + b"\n")
    offset = 0
    for oid, path in blobs:
        end = output.index(b"\n", offset)
        size = int(output[offset:end].rsplit(b" ", 1)[1])
        content = output[end + 1:end + 1 + size]
        offset = end + 1 + size + 1
        if b"\0" in content:
            continue
        text = content.decode("utf-8", errors="replace")
        if SECRETS.search(text):
            issues.append(f"{path}: possible credential")
        if metadata.get(path) == oid.decode():
            continue
        if HOME.search(text):
            issues.append(f"{path}: machine-specific absolute path")
        if any(private_email(value) for value in EMAIL.findall(text)):
            issues.append(f"{path}: personal email in content")
        if PHONE.search(text):
            issues.append(f"{path}: possible personal telephone number")
    if not staged:
        ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", base, revision], capture_output=True)
        scope = f"{base}..{revision}" if ancestry.returncode == 0 else revision
        commits = git("log", scope, "--format=%H%x09%an%x09%ae%x09%cn%x09%ce").decode().splitlines()
        for commit in commits:
            sha, author_name, author, committer_name, committer = commit.split("\t")
            if private_email(author) or private_email(committer):
                issues.append(f"commit {sha[:8]}: author and committer must use GitHub noreply email")
            if any(name.lower() not in {"ricadom", "x-ricadom", "github"}
                   for name in (author_name, committer_name)):
                issues.append(f"commit {sha[:8]}: unexpected personal identity")
        messages = git("log", scope, "--format=%B").decode()
        if HOME.search(messages) or PHONE.search(messages) or any(
                private_email(value) for value in EMAIL.findall(messages)):
            issues.append("fork commit messages: possible personal information")
    return sorted(set(issues)), len(blobs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default=BASE)
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--pre-push", action="store_true")
    args = parser.parse_args()
    try:
        if args.pre_push:
            revisions = {line.split()[1] for line in sys.stdin if line.strip()}
            issues, count = [], 0
            for revision in sorted(revisions):
                if set(revision) == {"0"}:
                    continue
                findings, files = audit(args.base, revision=revision)
                issues.extend(findings)
                count += files
            issues = sorted(set(issues))
        else:
            issues, count = audit(args.base, args.staged)
    except (RuntimeError, ValueError) as error:
        print(f"Privacy check could not complete: {error}", file=sys.stderr)
        return 2
    for issue in issues:
        print(issue)
    print(f"Privacy check: {count} files, {len(issues)} findings")
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
