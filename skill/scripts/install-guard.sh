#!/bin/bash
# 安装到指定项目；保留原钩子与 Claude 本地设置。兼容 Bash 3.2。
set -euo pipefail
unset HISTFILE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 - "$SCRIPT_DIR/guard.py" "$@" <<'PY'
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

MARKER = "# Roadstar guard wrapper v1"
NAMES = ("prepare-commit-msg", "commit-msg", "pre-merge-commit")

def fail(reason):
    raise ValueError(reason)

def git(root, *args, optional=False):
    p = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    if p.returncode and not optional:
        fail("读不到项目的 Git 目录；请传入一个现有 Git 工作区。")
    return None if p.returncode else p.stdout.strip()

def owned(path):
    return path.is_file() and not path.is_symlink() and path.read_bytes().splitlines()[:2] == [b"#!/bin/bash", MARKER.encode()]

def atomic_write(path, text):
    tmp = path.with_name(path.name + ".roadstar-" + str(os.getpid()))
    try:
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)

def install():
    guard = str(Path(sys.argv[1]).resolve())
    args = sys.argv[2:]
    if not args or any(a not in ("--uninstall", "--claude") for a in args[1:]):
        fail("参数不对；用 install-guard.sh <项目根> [--uninstall] [--claude]。")
    root = Path(git(Path(args[0]).resolve(), "rev-parse", "--show-toplevel"))
    uninstall = "--uninstall" in args
    hooks_path = git(root, "config", "--get", "core.hooksPath", optional=True)
    hooks = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir")) / "hooks"
    command = "python3 " + shlex.quote(guard) + " claude-pretool"
    settings = root / ".claude/settings.local.json"
    content = None
    # 先验证全部输入，避免覆盖到一半才发现旧备份或 JSON 有问题。
    if "--claude" in args:
        content = json.loads(settings.read_text(encoding="utf-8")) if settings.exists() else {}
        if not isinstance(content, dict) or not isinstance(content.get("hooks", {}), dict):
            fail("Claude 设置格式不对；请先修好 " + str(settings))
        entries = content.get("hooks", {}).get("PreToolUse", [])
        if not isinstance(entries, list) or any(not isinstance(e, dict) or not isinstance(e.get("hooks", []), list) for e in entries):
            fail("Claude 的 PreToolUse 不是钩子列表；请先修好 " + str(settings))
        if uninstall:
            kept = []
            for entry in entries:
                remaining = [h for h in entry.get("hooks", []) if not (
                    entry.get("matcher") == "Bash" and isinstance(h, dict)
                    and h.get("type") == "command" and h.get("command") == command)]
                if remaining != entry.get("hooks", []):
                    if remaining:
                        kept.append(dict(entry, hooks=remaining))
                else:
                    kept.append(entry)
            if "PreToolUse" in content.get("hooks", {}):
                content["hooks"]["PreToolUse"] = kept
        else:
            exists = any(e.get("matcher") == "Bash" and any(
                isinstance(h, dict) and h.get("type") == "command" and h.get("command") == command
                for h in e.get("hooks", [])) for e in entries)
            if not exists:
                content.setdefault("hooks", {}).setdefault("PreToolUse", []).append(
                    {"matcher": "Bash", "hooks": [{"type": "command", "command": command}]})
    if hooks_path is None:
        for name in NAMES:
            path = hooks / name
            local = hooks / (name + ".local")
            if not uninstall and os.path.lexists(path) and not owned(path) and os.path.lexists(local):
                fail("已有钩子和 .local 同时存在，不能覆盖：" + str(path) + "；请先整理这两个文件。")
            if os.path.lexists(path) and not path.is_file() and not path.is_symlink():
                fail("钩子位置不是文件：" + str(path) + "；请先检查这个路径。")
        if not uninstall:
            hooks.mkdir(parents=True, exist_ok=True)
        for name in NAMES:
            path = hooks / name
            local = hooks / (name + ".local")
            if uninstall:
                if owned(path):
                    path.unlink()
                    if os.path.lexists(local):
                        local.rename(path)
                continue
            if os.path.lexists(path) and not owned(path):
                path.rename(local)
            wrapper = "\n".join(("#!/bin/bash", MARKER,
                'LOCAL="$(dirname "$0")/' + name + '.local"',
                'if [ -x "$LOCAL" ]; then', '  "$LOCAL" "$@" || exit "$?"', 'fi',
                "GUARD=" + shlex.quote(guard),
                'if [ ! -f "$GUARD" ]; then',
                '  echo "Roadstar 检查没跑：找不到 $GUARD（Roadstar 仓库搬走了？重跑 install-guard.sh 或 --uninstall）。这次放行。" >&2',
                '  exit 0', 'fi',
                'exec python3 "$GUARD" hook ' + name + ' "$@"', ""))
            atomic_write(path, wrapper)
            path.chmod(0o755)
        print("已卸载 Roadstar Git 钩子，原钩子已恢复。" if uninstall else "已安装 Roadstar Git 钩子：" + str(hooks))
    else:
        print("设置了 core.hooksPath，现有钩子不动。请在对应钩子中手动加入以下三行（卸载时移除）：")
        for name in NAMES:
            print("python3 " + shlex.quote(guard) + " hook " + name + ' "$@"  # ' + name)
    if content is not None and (not uninstall or settings.exists()):
        settings.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(settings, json.dumps(content, ensure_ascii=False, indent=2) + "\n")
        print("已更新 Claude PreToolUse：" + str(settings))

try:
    install()
except (OSError, ValueError, TypeError, UnicodeError) as exc:
    print("拦下了：安装或卸载没有完成\n原因：" + str(exc) + "\n怎么办：处理上面的问题后重试；不要覆盖已有的 .local 钩子。", file=sys.stderr)
    sys.exit(1)
PY
