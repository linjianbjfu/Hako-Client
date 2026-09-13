#!/usr/bin/env python3
"""Report Hako Git change layers without fetching or modifying the checkout."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def git(repo, *arguments):
    environment = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    result = subprocess.run(["git", *arguments], cwd=repo, env=environment,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(detail or "Git could not resolve the requested comparison")
    return result.stdout


def commit(repo, ref):
    return git(repo, "rev-parse", "--verify", "--end-of-options", ref + "^{commit}").decode().strip()


def paths(repo, *arguments):
    return sorted(set(os.fsdecode(value) for value in git(repo, *arguments).split(b"\0") if value))


def areas(changed):
    result = set()
    for path in changed:
        if path == "AGENTS.md" or path.startswith(".agents/"):
            result.add("agent-workflows")
        if path.endswith(".md"):
            result.add("documentation")
        if path.endswith(".strings") or "/AppLocalization/" in path:
            result.add("localization")
        if path.startswith("apple/HakoClientKit/"):
            result.add("shared-models")
        if path.startswith("apple/HakoClientUI/"):
            result.add("shared-ui")
        if path.startswith("apple/HakoMacClient/") or path.startswith("apple/HakoClient/Sources/Mac/"):
            result.add("macos-ui-runtime")
        if path.startswith("apple/HakoClient/Extension/"):
            result.add("network-extension")
        if path.startswith("apple/HakoClient/ProxyServer/") or "MacProxyServer" in path or path == "scripts/test_proxy_server.py":
            result.add("proxy-server")
        if path.startswith("apple/HakoClient/Sources/") or path.startswith("apple/HakoClient/Shared/"):
            result.add("app-logic")
        if "/Tests/" in path or Path(path).name.startswith("test_"):
            result.add("tests")
        if path in {"Dependencies.lock.json", "scripts/bootstrap.py", "scripts/configure.py", "apple/HakoClient/project.yml"} or path.endswith("/Package.swift"):
            result.add("build-and-dependencies")
    return sorted(result)


def report(repo, base=None, head="HEAD"):
    root = Path(os.fsdecode(git(repo, "rev-parse", "--show-toplevel").removesuffix(b"\n")))
    resolved_head = commit(root, head)
    resolved_base = commit(root, base) if base else None
    merge_base = git(root, "merge-base", resolved_base, resolved_head).decode().strip() if base else None
    layers = {
        "committed": paths(root, "diff", "--no-renames", "--name-only", "-z", merge_base, resolved_head, "--") if base else [],
        "staged": paths(root, "diff", "--cached", "--no-renames", "--name-only", "-z", "--"),
        "unstaged": paths(root, "diff", "--no-renames", "--name-only", "-z", "--"),
        "untracked": paths(root, "ls-files", "--others", "--exclude-standard", "-z"),
    }
    return {
        "schemaVersion": 1,
        "repository": str(root),
        "scopeKind": "base-and-worktree" if base else "worktree-only",
        "head": resolved_head,
        "base": resolved_base,
        "mergeBase": merge_base,
        "worktreeHead": commit(root, "HEAD"),
        "paths": layers,
        "areas": areas({path for layer in layers.values() for path in layer}),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--base", help="Previously verified comparison ref; never guessed or fetched")
    parser.add_argument("--head", default="HEAD", help="Commit being inspected; requires --base when not HEAD")
    args = parser.parse_args()
    if args.head != "HEAD" and not args.base:
        parser.error("--head requires --base when it is not HEAD")
    try:
        print(json.dumps(report(args.repo, args.base, args.head), indent=2, ensure_ascii=True))
    except (ValueError, OSError) as error:
        print("error: " + str(error), file=sys.stderr)
        raise SystemExit(2)


if __name__ == "__main__":
    main()
