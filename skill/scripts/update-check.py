#!/usr/bin/env python3
"""Check for Roadstar updates, or apply an explicitly requested fast-forward."""

import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[2]
FETCH_TIMEOUT = 8
CACHE_SECONDS = 24 * 60 * 60


def git(*args, timeout=8):
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=timeout).stdout.strip()


def version(text):
    frontmatter = re.match(r"\A---\s*\n(.*?)\n---(?:\s|$)", text, re.S)
    match = re.search(r'^\s*version:\s*[\"\'](\d+\.\d+\.\d+)[\"\']\s*$',
                      frontmatter.group(1), re.M) if frontmatter else None
    return match.group(1) if match else "未知"


def local_version():
    try:
        return version((ROOT / "skill/SKILL.md").read_text(encoding="utf-8"))
    except (OSError, UnicodeError):
        return "未知"


def branch_name():
    for command in (("rev-parse", "--abbrev-ref", "@{upstream}"),
                    ("symbolic-ref", "--short", "refs/remotes/origin/HEAD")):
        try:
            ref = git(*command)
            if "/" in ref:
                return ref.split("/", 1)[1]
        except (OSError, subprocess.SubprocessError):
            pass
    return "main"


def cache_path():
    config = Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser()
    config.mkdir(parents=True, exist_ok=True)
    return config / "update-check.json"


def read_cache():
    try:
        data = json.loads(cache_path().read_text(encoding="utf-8"))
        age = time.time() - data["checked_at"]
        if (math.isfinite(age) and 0 <= age < CACHE_SECONDS
                and type(data["behind"]) is int and data["behind"] >= 0
                and all(isinstance(data[key], str) for key in ("local_version", "remote_version"))):
            return data
    except (OSError, ValueError, TypeError, KeyError):
        pass
    return None


def write_cache(data):
    temporary = None
    try:
        path = cache_path()
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(data, handle, ensure_ascii=False)
            handle.write("\n")
        temporary.replace(path)
    except OSError:
        pass  # An unwritable cache must not turn a successful check into a failure.
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass


def snapshot(branch):
    return {"checked_at": time.time(),
            "behind": int(git("rev-list", "--count", f"HEAD..origin/{branch}")),
            "local_version": local_version(),
            "remote_version": version(git("show", f"origin/{branch}:skill/SKILL.md"))}


def emit(data, args, applied=False):
    if applied:
        message = f"已更新到 {data['local_version']}"
        try:
            heading = next((line for line in (ROOT / "CHANGELOG.md").read_text(
                encoding="utf-8").splitlines() if line.startswith("## ")), "")
        except (OSError, UnicodeError):
            heading = ""
        data = {**data, "changelog": heading}
    elif data["behind"] > 0:
        message = (f"Roadstar 有新版本：本机 {data['local_version']}，最新 {data['remote_version']}"
                   f"（落后 {data['behind']} 个提交）。说「更新 Roadstar」就拉到最新。")
    else:
        message = f"Roadstar 已是最新 {data['local_version']}" if args.verbose else ""
    if args.json:
        print(json.dumps({**data, "message": message}, ensure_ascii=False))
    elif message:
        print(message)
        if applied and data["changelog"]:
            print(data["changelog"])


def refuse(reason, args):
    print(json.dumps({"error": reason}, ensure_ascii=False) if args.json else reason)
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        if Path(git("rev-parse", "--show-toplevel")).resolve() != ROOT:
            return 0
        git("remote", "get-url", "origin")
    except (OSError, subprocess.SubprocessError):
        return 0

    if args.apply:
        try:
            if git("status", "--porcelain", "--untracked-files=no"):
                return refuse("更新被拒绝：工作区有已跟踪文件的未提交改动，请先提交或暂存到 stash。", args)
        except (OSError, subprocess.SubprocessError):
            return refuse("更新被拒绝：无法检查工作区状态。", args)
    elif not args.force:
        cached = read_cache()
        if cached is not None:
            emit(cached, args)
            return 0

    try:
        git("fetch", "--quiet", "origin", timeout=FETCH_TIMEOUT)
        branch = branch_name()
        if args.apply:
            try:
                git("pull", "--ff-only", "origin", branch, timeout=60)
            except (OSError, subprocess.SubprocessError):
                return refuse("更新被拒绝：git pull --ff-only 失败，无法快进或远端不可用；未合并本地提交。", args)
        data = snapshot(branch)
    except (OSError, ValueError, subprocess.SubprocessError):
        if args.apply:
            return refuse("更新失败：无法读取远端，请检查 origin 和网络后重试。", args)
        return 0  # Offline/failed fetches are silent, with no cache write.
    write_cache(data)
    emit(data, args, applied=args.apply)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
