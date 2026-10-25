#!/usr/bin/env python3
"""Tier-1 cleanup after a run: merged, clean worktrees and stale rounds/ intermediates.

Default is dry-run: it prints what would go and how much space that frees.
``--apply`` deletes; ``--check`` only reports unfinished work (exit 0/1).
Rules that never bend:
  * a worktree with uncommitted changes (including untracked files), a locked
    worktree, a branch not merged into the base, or a branch with unpushed
    commits on its upstream is listed and left alone;
  * in rounds/ only intermediates older than --days go (stdout logs, shot
    directories, patches, images, recordings, xcresult); .meta, task briefs,
    reports, acceptance notes, progress files, snapshots and review JSON stay.
Standard library only.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


INTERMEDIATE_SUFFIXES = (".log", ".patch", ".diff.orig", ".png", ".jpg", ".jpeg", ".gif", ".mov", ".mp4", ".webm", ".xcresult", ".zip")
INTERMEDIATE_DIRS = ("-shots", "shots", ".xcresult", "DerivedData", ".codex-build")
KEEP_PATTERNS = (re.compile(r"^exec-T\d+[a-z]?(-request(-r\d+)?)?\.md$"), re.compile(r"^exec-T\d+[a-z]?\.(meta|progress|exit|pid)$"),
                 re.compile(r"^check-T\d+[a-z]?\.md$"), re.compile(r"^r\d+-.*\.(md|json|diff)$"), re.compile(r"^pro-.*\.md$"),
                 re.compile(r"^gaps-.*\.md$"), re.compile(r"^\.exec-T\d+[a-z]?\.lock$"))


def git(args, cwd, check=False):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result


def du(path):
    total = 0
    for root, dirs, files in os.walk(path, onerror=lambda e: None):
        for name in files:
            try:
                total += os.lstat(os.path.join(root, name)).st_size
            except OSError:
                pass
    return total


def human(size):
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.1f} {unit}" if unit != "B" else f"{int(size)} B"
        size /= 1024
    return f"{size:.1f} GB"


def base_ref(project):
    for candidate in ("origin/HEAD", "origin/main", "main", "master"):
        if git(["rev-parse", "--verify", "--quiet", candidate], project).returncode == 0:
            return candidate
    return "HEAD"


def list_worktrees(project, runner=git, nul=False):
    result = runner(["worktree", "list", "--porcelain", *(["-z"] if nul else [])], project)
    if result.returncode != 0:
        return []
    items, current = [], {}
    for line in (result.stdout.split("\0") if nul else result.stdout.splitlines()) + [""]:
        if not line.strip():
            if current:
                items.append(current)
            current = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            current["path"] = value
        elif key == "branch":
            current["branch"] = value.replace("refs/heads/", "")
        elif key == "locked":
            current["locked"] = value or "locked"
        elif key in ("bare", "detached", "prunable"):
            current[key] = True
    return items


def judge_worktree(item, project, base, main_path, runner=git, measure_size=True):
    path = item.get("path")
    reasons = []
    if not path or Path(path).resolve() == Path(main_path).resolve():
        return None
    if item.get("bare"):
        return None
    if item.get("locked"):
        reasons.append("已锁定（槽位）")
    if item.get("detached") or not item.get("branch"):
        reasons.append("没有分支（detached）")
    if not Path(path).is_dir():
        reasons.append("目录不存在（可用 git worktree prune）")
        return {"path": path, "branch": item.get("branch"), "action": "skip", "reasons": reasons, "bytes": 0}
    status = runner(["status", "--porcelain", "--untracked-files=all"], path)
    if status.returncode != 0:
        reasons.append("读不到状态")
    elif status.stdout.strip():
        reasons.append("有未提交改动或未跟踪文件")
    branch = item.get("branch")
    if branch:
        merged = runner(["merge-base", "--is-ancestor", branch, base], project)
        if merged.returncode != 0:
            reasons.append(f"分支没合进 {base}")
        upstream = runner(["rev-parse", "--abbrev-ref", "--symbolic-full-name", f"{branch}@{{upstream}}"], project)
        if upstream.returncode == 0 and upstream.stdout.strip():
            ahead = runner(["rev-list", "--count", f"{upstream.stdout.strip()}..{branch}"], project)
            if ahead.returncode == 0 and ahead.stdout.strip() not in ("", "0"):
                reasons.append(f"有 {ahead.stdout.strip()} 个未推送提交")
    size = du(path) if measure_size else 0
    return {"path": path, "branch": branch, "action": "skip" if reasons else "remove", "reasons": reasons, "bytes": size}


def rounds_candidates(plan_dirs, days, now):
    cutoff = now - days * 86400
    found = []
    for plan_dir in plan_dirs:
        rounds = Path(plan_dir) / "rounds"
        if not rounds.is_dir():
            continue
        for entry in sorted(rounds.iterdir()):
            name = entry.name
            if any(pattern.match(name) for pattern in KEEP_PATTERNS):
                continue
            is_dir = entry.is_dir() and not entry.is_symlink()
            intermediate = (is_dir and any(name.endswith(mark) or name == mark for mark in INTERMEDIATE_DIRS)) or \
                           (not is_dir and name.lower().endswith(INTERMEDIATE_SUFFIXES))
            if not intermediate:
                continue
            try:
                mtime = entry.stat().st_mtime
            except OSError:
                continue
            if mtime > cutoff:
                continue
            found.append({"path": str(entry), "kind": "dir" if is_dir else "file",
                          "age_days": int((now - mtime) // 86400), "bytes": du(entry) if is_dir else entry.stat().st_size})
    return found


def remove_worktree(project, item):
    git(["worktree", "remove", "--force", item["path"]], project, check=True)
    if item.get("branch"):
        git(["branch", "-D", item["branch"]], project)


def check_git(args, cwd, check=True):
    """Read-only Git: even status must not refresh an index on disk."""
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True,
                            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "读不到 Git 状态")
    return result


def close_check(project, base, plan_dirs, as_json):
    resolved = check_git(["rev-parse", "--verify", "--end-of-options", base + "^{commit}"],
                         project, check=False)
    if resolved.returncode:
        raise RuntimeError(f"找不到基准分支：{base}")
    base_oid = resolved.stdout.strip()
    worktrees = list_worktrees(project, runner=check_git, nul=True)
    main_path = worktrees[0]["path"] if worktrees else str(project)
    unmerged, tasks, uncleared, acceptance = [], [], [], []
    for item in worktrees:
        path, branch = item.get("path"), item.get("branch")
        if not path or Path(path).resolve() == Path(main_path).resolve() or item.get("bare"):
            continue
        if branch:
            ref = "refs/heads/" + branch
            count = int(check_git(["rev-list", "--count", base_oid + ".." + ref, "--"], project).stdout)
            if count:
                unmerged.append({"kind": "unmerged", "path": path, "branch": branch, "commits": count,
                                 "detail": f"没合并：工作副本 {path}（分支 {branch}，领先 {count} 个提交）"})
                continue
        # Keep dry-run's dirty / locked / detached / unpushed exclusions.
        judged = judge_worktree(item, project, base_oid, main_path,
                                runner=lambda a, c: check_git(a, c, check=False), measure_size=False)
        if judged and judged["action"] == "remove":
            uncleared.append({"kind": "merged_not_cleaned", "path": path, "branch": branch,
                              "detail": f"已合并没清：{path}"})
    branches = check_git(["for-each-ref", "--format=%(refname)", "refs/heads/"], project)
    for ref in branches.stdout.splitlines():
        branch = ref.removeprefix("refs/heads/")
        # Git parses trailers exactly as guard.py does; body lookalikes do not count.
        records = check_git(["log", "--format=%H%x00%(trailers:key=Roadstar-Task,valueonly)%x00",
                             base_oid + ".." + ref, "--"], project).stdout.split("\0")
        counts = {}
        for i in range(0, len(records) - 1, 2):
            values = set()
            for value in records[i + 1].splitlines():
                plan, sep, task = value.strip().rpartition("/")
                if sep and plan and not Path(plan).is_absolute() and re.fullmatch(r"T[0-9]+[a-z]?", task):
                    values.add((plan, task))
            for key in values:
                counts[key] = counts.get(key, 0) + 1
        for (plan, task), count in sorted(counts.items()):
            tasks.append({"kind": "unmerged_task", "plan_dir": plan, "task": task,
                          "branch": branch, "commits": count,
                          "detail": f"没合并：{task}（{plan}）在分支 {branch} 上，{count} 个提交"})
    for plan in dict.fromkeys(p.expanduser().resolve() for p in plan_dirs):
        try:
            label = str(plan.relative_to(project))
        except ValueError:
            label = str(plan)
        rounds = plan / "rounds"
        if not rounds.is_dir():
            continue
        for reply in sorted(rounds.iterdir()):
            match = re.fullmatch(r"exec-(T[0-9]+[a-z]?)\.md", reply.name)
            if not match or not reply.is_file():
                continue
            task = match[1]
            record = rounds / f"check-{task}.md"
            if not record.is_file() or not record.read_bytes().strip():
                acceptance.append({"kind": "no_acceptance", "plan_dir": label, "task": task,
                                   "detail": f"没验收：{task}（{label}）"})
    items = unmerged + tasks + uncleared + acceptance
    report = {"clean": not items, "items": items}
    if as_json:
        print(json.dumps(report, ensure_ascii=False))
        if not plan_dirs:
            print("没给场次目录，验收记录这项没查", file=sys.stderr)
    else:
        print(f"收工检查：还有 {len(items)} 项没收完" if items else "收工检查：都收完了")
        for item in items:
            print(item["detail"])
        if not plan_dirs:
            print("没给场次目录，验收记录这项没查")
    return 1 if items else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="场内垃圾清理第一档：已合并且干净的 worktree、rounds/ 里超期的中间产物；默认只列不删")
    parser.add_argument("--project", type=Path, default=Path.cwd(), help="项目根（主工作区）")
    parser.add_argument("--plan-dir", type=Path, action="append", default=[], help="场次目录，可多个；不给时清理扫 <项目>/docs/roadstar/*，--check 跳过验收记录")
    parser.add_argument("--days", type=int, default=7, help="rounds/ 中间产物保留天数")
    parser.add_argument("--base", help="判「已合并」的基准分支，默认 origin/HEAD、origin/main、main、master 里第一个存在的")
    parser.add_argument("--apply", action="store_true", help="真删；不给就是 dry-run")
    parser.add_argument("--check", action="store_true", help="收工检查：只查不删，没收完退出 1")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.check and args.apply:
        print("--check 只查不删，不能和 --apply 一起用", file=sys.stderr)
        return 2
    if args.check:
        try:
            project = args.project.expanduser().resolve()
            if check_git(["rev-parse", "--show-toplevel"], project, check=False).returncode:
                raise RuntimeError(f"不是 git 仓库：{project}")
            return close_check(project, args.base or base_ref(project), args.plan_dir, args.json)
        except (OSError, RuntimeError, ValueError) as error:
            print(f"收工检查没查完：{error}", file=sys.stderr)
            return 2
    project = args.project.expanduser().resolve()
    if git(["rev-parse", "--show-toplevel"], project).returncode != 0:
        print(f"不是 git 仓库：{project}", file=sys.stderr)
        return 2
    main_path = git(["rev-parse", "--show-toplevel"], project).stdout.strip()
    base = args.base or base_ref(project)
    now = time.time()
    worktrees = [judged for item in list_worktrees(project) if (judged := judge_worktree(item, project, base, main_path))]
    plan_dirs = [p.expanduser().resolve() for p in args.plan_dir] or sorted(p for p in (project / "docs" / "roadstar").glob("*") if p.is_dir())
    intermediates = rounds_candidates(plan_dirs, args.days, now)
    removable = [w for w in worktrees if w["action"] == "remove"]
    kept = [w for w in worktrees if w["action"] == "skip"]
    total = sum(w["bytes"] for w in removable) + sum(i["bytes"] for i in intermediates)
    report = {"mode": "apply" if args.apply else "dry-run", "project": str(project), "base": base, "days": args.days,
              "worktrees_remove": removable, "worktrees_keep": kept, "intermediates": intermediates,
              "bytes": total, "bytes_text": human(total), "errors": []}
    if args.apply:
        for item in removable:
            try:
                remove_worktree(project, item)
                item["done"] = True
            except (RuntimeError, OSError) as error:
                report["errors"].append(f"{item['path']}：{error}")
        for item in intermediates:
            try:
                if item["kind"] == "dir":
                    shutil.rmtree(item["path"])
                else:
                    os.unlink(item["path"])
                item["done"] = True
            except OSError as error:
                report["errors"].append(f"{item['path']}：{error}")
    if args.json:
        print(json.dumps(report, ensure_ascii=False))
    else:
        verb = "删了" if args.apply else "会删"
        print(f"清理（{'已执行' if args.apply else '只列不删，加 --apply 才删'}）：{verb} {len(removable)} 个 worktree、{len(intermediates)} 个中间产物，释放约 {report['bytes_text']}；基准 {base}")
        for item in removable:
            print(f"  {verb} worktree {item['path']}（分支 {item['branch']}，{human(item['bytes'])}）" + ("" if item.get("done", not args.apply) else " 失败"))
        for item in intermediates:
            print(f"  {verb} {item['path']}（{item['age_days']} 天前，{human(item['bytes'])}）")
        for item in kept:
            print(f"  不动 {item['path']}：{'；'.join(item['reasons'])}")
        for error in report["errors"]:
            print(f"  失败 {error}")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
