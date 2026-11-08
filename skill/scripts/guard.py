#!/usr/bin/env python3
"""Roadstar 的提交／合并门槛；只读 Git 状态，不执行待检查的 shell 命令。"""

import datetime
import fnmatch
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


MAP = "docs/模块地图.md"
ALLOW = (MAP, "docs/MODULES.md", "docs/roadstar/", "CHANGELOG.md", "CHANGELOG*")
TASK = re.compile(r"T[0-9]+[a-z]?")


class Block(Exception):
    def __init__(self, reason, *details):
        super().__init__("\n".join(("拦下了：" + reason,) + details))


def git(cwd, *args, data=None, optional=False):
    result = subprocess.run(["git", "-C", str(cwd), *args], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            encoding="utf-8", errors="surrogateescape")
    if result.returncode and not optional:
        raise Block("读不到需要的 Git 状态", "命令：git " + shlex.join(args),
                    "怎么办：确认工作区、分支和 Git 状态正常后重试。")
    return result.stdout if result.returncode == 0 else None


def root_at(cwd):
    return Path(git(cwd, "rev-parse", "--show-toplevel").strip())


def git_dir(root, common=False):
    option = "--git-common-dir" if common else "--git-dir"
    return Path(git(root, "rev-parse", "--path-format=absolute", option).strip())


def section(text, title):
    match = re.search(r"^##[ \t]+" + re.escape(title) + r"[ \t]*\r?$", text, re.M)
    if not match:
        return ""
    return re.split(r"^#{1,2}[ \t]+", text[match.end():], maxsplit=1, flags=re.M)[0]


def paths(text):
    return [p.strip().removeprefix("./") for quoted in re.findall(r"`([^`]+)`", text)
            for p in re.split(r"[,，、]", quoted) if p.strip()]


def map_text(root):
    # 未暂存的地图修改不能改变正在提交的入口检查。
    indexed = git(root, "show", ":" + MAP, optional=True)
    if indexed is not None:
        return indexed
    committed = git(root, "show", "HEAD:" + MAP, optional=True)
    if committed is not None:
        return committed
    path = root / MAP
    return path.read_text(encoding="utf-8") if path.is_file() else None


def _abbreviations(section_text):
    abbreviations = {}
    for line in section_text.splitlines():
        if line.lstrip().startswith("|"):
            break
        for name, path in re.findall(r"`([^`]+)`\s*=\s*`([^`]+)`", line):
            abbreviations[name.strip()] = path.strip().removeprefix("./").rstrip("/")
    return abbreviations


def modules_from(text):
    modules = {}
    columns = None
    overview = section(text, "模块一览")
    abbreviations = _abbreviations(overview)
    for line in overview.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        name_column = next((i for i, c in enumerate(cells) if c in ("模块", "名称", "工具")), None)
        path_column = next((i for i, c in enumerate(cells)
                            if any(word in c for word in ("目录", "路径", "位置", "正本"))), None)
        if name_column is not None and path_column is not None:
            columns = (name_column, path_column)
        elif columns and len(cells) > max(columns):
            name = cells[columns[0]].strip("` *")
            if name and not re.fullmatch(r"[: -]+", name):
                directories = []
                for path in paths(cells[columns[1]]):
                    # 只清洗模块表的路径；入口行继续沿用 paths() 的原有行为。
                    if (re.search(r"\s", path) and "/" not in path and "." not in path
                            or re.match(r"(?:[a-z][a-z0-9+.-]*://|//|(?:[\w-]+\.)+[a-z]{2,}/)", path, re.I)):
                        continue
                    prefix, slash, rest = path.partition("/")
                    if slash and prefix in abbreviations:
                        path = abbreviations[prefix] + "/" + rest
                    directories.append(path)
                modules[name] = directories
    return modules


def matches(root, filename, pattern):
    if pattern.endswith("/") or (root / pattern).is_dir():
        return fnmatch.fnmatchcase(filename, pattern.rstrip("/") + "/*")
    return fnmatch.fnmatchcase(filename, pattern)


def trailers(root, message):
    parsed = git(root, "interpret-trailers", "--parse", data=message)
    values = {}
    for line in parsed.splitlines():
        key, sep, value = line.partition(":")
        if sep:
            values.setdefault(key.strip().lower(), []).append(value.strip())
    return values


def task_parts(value):
    plan, sep, task = value.rpartition("/")
    if not sep or not plan or Path(plan).is_absolute() or not TASK.fullmatch(task):
        raise Block("Roadstar-Task 写法不对", "收到：" + value,
                    "怎么办：写成 Roadstar-Task: <场次相对路径>/T<n>。")
    return plan, task


def mark(root, plan, task):
    if not TASK.fullmatch(task):
        raise Block("任务号写法不对", "怎么办：用 T1、T2 这样的任务号。")
    target = Path(plan).resolve()
    main = git_dir(root, common=True).parent.resolve()
    # 工位（另一个 worktree）派活时场次目录常在主工作区：按主工作区记相对路径，
    # 合并时查验收记录、提交时找任务书都从主工作区解析，工位目录深浅不同也一致。
    base = main if target.is_relative_to(main) and not target.is_relative_to(root.resolve()) else root
    relative = os.path.relpath(target, base)
    if any(c in relative for c in "\r\n"):
        raise Block("场次路径里有换行", "怎么办：改成不带换行的目录名后重试。")
    value = {"plan_dir": relative, "task": task,
             "branch": git(root, "symbolic-ref", "--quiet", "--short", "HEAD").strip(),
             "time": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    destination = git_dir(root) / "roadstar-task"
    temporary = destination.with_name("roadstar-task.tmp-" + str(os.getpid()))
    try:
        temporary.write_text(json.dumps(value, ensure_ascii=False) + "\n", encoding="utf-8")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def prepare(root, filename):
    path = git_dir(root) / "roadstar-task"
    if not path.is_file():
        return
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        branch = git(root, "symbolic-ref", "--quiet", "--short", "HEAD", optional=True)
        if not branch or value.get("branch") != branch.strip():
            return
        trailer = value["plan_dir"] + "/" + value["task"]
        task_parts(trailer)
    except (ValueError, KeyError, TypeError, AttributeError):
        raise Block("任务标记读不懂", "文件：" + str(path),
                    "怎么办：重新运行 guard.py mark <场次目录> T<n>，或用 unmark 清掉标记。")
    git(root, "interpret-trailers", "--in-place", "--if-exists", "addIfDifferent",
        "--if-missing", "add", "--trailer", "Roadstar-Task: " + trailer, filename)


def requested_modules(body, modules, request):
    selected = []
    for line in body.splitlines():
        line = re.sub(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)?", "", line).strip()
        if not line:
            continue
        if line.strip(" `*「」『』。\t") in modules:
            selected.append(line.strip(" `*「」『』。\t"))
            continue
        named = re.findall(r"[「`『]([^」`』]+)[」`』]", line)
        found = [name for name in named if name in modules]
        # 任务书可以用整句介绍模块；单纯的模块列表仍逐项核对，错别字不漏过。
        if found and any(mark in line for mark in ("。", "：", "（", "）")):
            selected.extend(found)
            continue
        for item in re.split(r"[,，、;；]", line):
            clean = item.strip(" `*「」『』。\t")
            if clean in modules:
                selected.append(clean)
                continue
            without_note = re.sub(r"\s*(?:（[^（）]*）|\([^()]*\))$", "", clean).strip(" `*「」『』\t")
            if without_note in modules:
                selected.append(without_note)
                continue
            raise Block("任务书里的模块在地图中找不到", "任务书：" + str(request),
                        "模块：" + clean, "怎么办：按模块一览的名字补齐涉及模块后重提。")
    if not selected:
        raise Block("任务书没写涉及模块", "任务书：" + str(request),
                    "怎么办：补上 ## 涉及模块，列出地图里的模块名后重提。")
    return selected


def merging(root):
    # 合并提交里的改动已在各自的任务提交上查过范围和地图，验收记录由 pre-merge-commit 查。
    if (git_dir(root) / "MERGE_HEAD").is_file():
        return True
    action = os.environ.get("GIT_REFLOG_ACTION", "")
    return action.startswith("merge ") or action.startswith("pull")


def commit_message(root, filename):
    if merging(root):
        return
    message = Path(filename).read_text(encoding="utf-8")
    values = trailers(root, message)
    changed = git(root, "diff", "--cached", "--name-only", "--no-renames", "-z").split("\0")
    changed = [name for name in changed if name]
    text = map_text(root)
    modules = modules_from(text) if text is not None else {}
    failures = []
    notices = []
    for value in dict.fromkeys(values.get("roadstar-task", [])):
        plan, task = task_parts(value)
        request = root / plan / "rounds" / ("exec-" + task + "-request.md")
        if not request.is_file():
            shared = git_dir(root, common=True).parent / plan / "rounds" / request.name
            request = shared if shared.is_file() else request
        if not request.is_file():
            raise Block("找不到这件活的任务书", "期望路径：" + str(request),
                        "怎么办：把任务书放回这个路径，或修正 Roadstar-Task 后重提。")
        body = section(request.read_text(encoding="utf-8"), "涉及模块")
        if text is None or "无地图" in body:
            notices.append("这个项目没有模块地图，范围检查跳过")
            continue
        selected = requested_modules(body, modules, request)
        allowed = [p for name in selected for p in modules[name]] + list(ALLOW)
        outside = [name for name in changed if not any(matches(root, name, p) for p in allowed)]
        reason = next((v for v in values.get("roadstar-scope", []) if v), None)
        if outside and reason:
            notices.append("越界已放行：" + reason)
        elif outside:
            failures.append("任务 " + value + " 超出涉及模块：")
            for name in outside:
                owners = [m for m, patterns in modules.items()
                          if any(matches(root, name, p) for p in patterns)]
                failures.append("- " + name + " → " + ("、".join(owners) or "地图里没有"))
            failures.append("怎么办：改任务书的涉及模块后重提；或在提交说明末尾空一行，再加一行 Roadstar-Scope: <为什么要超出范围>（不空行 git 认不出）。")
    if text is not None and MAP not in changed and not any(values.get("roadstar-map", [])):
        entrances = []
        for module in modules:
            for line in section(text, module).splitlines():
                if re.match(r"^\s*-\s*入口[：:]", line):
                    for pattern in paths(line):
                        entrances.extend((module, name) for name in changed if matches(root, name, pattern))
        if entrances:
            failures.append("改了模块入口，却没一起改地图：")
            failures.extend("- " + m + "：" + name for m, name in dict.fromkeys(entrances))
            failures.append("怎么办：把 docs/模块地图.md 的对应一节一起暂存；或在提交说明末尾空一行，再加一行 Roadstar-Map: <不用改的理由>（不空行 git 认不出）。")
    if failures:
        raise Block("提交还没满足范围或地图要求", *failures, *dict.fromkeys(notices))
    for notice in dict.fromkeys(notices):
        print(notice)


def merge_tasks(root, refs):
    tasks = []
    for ref in refs:
        # 先解析单个 revision，避免参数或 revision-range 混进 git log。
        oid = git(root, "rev-parse", "--verify", "--end-of-options", ref + "^{commit}", optional=True)
        if not oid:
            raise Block("找不到要合并的分支", "分支：" + ref,
                        "怎么办：确认分支名或先取回分支，再运行合并。")
        messages = git(root, "log", "--format=%B%x00", "HEAD.." + oid.strip(), "--")
        for message in messages.split("\0"):
            tasks.extend(trailers(root, message).get("roadstar-task", []))
    return list(dict.fromkeys(tasks))


def check_records(root, tasks):
    main = git_dir(root, common=True).parent
    missing = []
    for value in tasks:
        plan, task = task_parts(value)
        record = main / plan / "rounds" / ("check-" + task + ".md")
        if not record.is_file() or not record.read_bytes().strip():
            missing.append("- " + value + "：" + str(record))
    if missing:
        raise Block("这些任务还没有验收记录，不能合并", *missing,
                    "怎么办：先验收，再在上面的主工作区路径写下非空验收记录，然后重试 git merge --no-ff。")


def pending_merge_refs(root):
    merge_head = git_dir(root) / "MERGE_HEAD"
    if merge_head.is_file():
        return merge_head.read_text().split()
    # Git 在成功自动合并的 pre-merge-commit 阶段尚未写 MERGE_HEAD；
    # 此时它通过 GIT_REFLOG_ACTION 保留合并目标（分支名不允许空白）。
    action = os.environ.get("GIT_REFLOG_ACTION", "")
    if action.startswith("merge "):
        return action.split()[1:]
    if action.startswith("pull"):
        fetch_head = git_dir(root) / "FETCH_HEAD"
        if fetch_head.is_file():
            return [line.split("\t", 1)[0] for line in fetch_head.read_text().splitlines()
                    if "\tnot-for-merge\t" not in line]
    if action:
        raise Block("暂时读不到这次合并的目标", "Git 合并说明：" + action,
                    "怎么办：不要自定义 GIT_REFLOG_ACTION，重新执行 git merge --no-ff <分支>。")
    return []


def merge_commands(command, cwd):
    """识别普通 shell 命令段；只解析，不展开变量、不调用 shell。"""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()<>\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    segments = []
    current = []
    redirect_target = False
    for token in lexer:
        if redirect_target:
            redirect_target = False
            continue
        if token in (">", ">>", "<", "<<", "<<<", ">&", "<&", "&>", "&>>", "<>", ">|"):
            if current and current[-1].isdigit():
                current.pop()
            redirect_target = True
        elif token and all(c in ";&|()\n" for c in token):
            if current:
                segments.append(current)
                current = []
        else:
            current.append(token)
    if current:
        segments.append(current)
    for words in segments:
        while words and (re.match(r"^[A-Za-z_][A-Za-z_0-9]*=", words[0]) or words[0] in ("command", "env", "then", "do", "else", "if", "!")):
            words = words[1:]
        if not words:
            continue
        if words[0] == "cd" and len(words) == 2:
            cwd = (cwd / words[1]).resolve()
            continue
        if Path(words[0]).name != "git":
            continue
        target = cwd
        i = 1
        while i < len(words):
            word = words[i]
            if word in ("-C", "-c", "--git-dir", "--work-tree") and i + 1 < len(words):
                if word == "-C":
                    target = (target / words[i + 1]).resolve()
                elif word == "--work-tree":
                    target = Path(words[i + 1]).resolve()
                i += 2
            elif word.startswith("-C") and len(word) > 2:
                target = (target / word[2:]).resolve()
                i += 1
            elif word.startswith("-"):
                i += 1
            else:
                break
        if i >= len(words) or words[i] != "merge":
            continue
        args = words[i + 1:]
        if any(w in ("--abort", "--continue", "--quit") for w in args):
            continue
        refs = []
        no_ff = False
        i = 0
        while i < len(args):
            word = args[i]
            if word == "--":
                refs.extend(args[i + 1:])
                break
            if word == "--no-ff":
                no_ff = True
            elif word in ("--ff", "--ff-only"):
                no_ff = False
            elif word in ("-m", "--message", "-F", "--file", "-s", "--strategy", "-X", "--strategy-option", "--into-name"):
                i += 1
            elif not word.startswith("-"):
                refs.append(word)
            i += 1
        if refs:
            yield target, refs, no_ff


def claude_pretool():
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
            return
        command = payload.get("tool_input", {}).get("command", "")
        if not isinstance(command, str):
            return
    except (ValueError, TypeError, AttributeError):
        return
    try:
        commands = list(merge_commands(command, Path(payload.get("cwd") or os.getcwd())))
    except ValueError:
        return  # 无法组成 shell 命令，交由 Bash 自己报语法错。
    for cwd, refs, no_ff in commands:
        root = root_at(cwd)
        tasks = merge_tasks(root, refs)
        if tasks and not no_ff:
            raise Block("带任务号的提交必须用 --no-ff 合并", "分支：" + "、".join(refs),
                        "怎么办：在 git merge 中加 --no-ff；快进合并不会触发验收钩子。")
        check_records(root, tasks)


def main(args):
    claude = args == ["claude-pretool"]
    if os.environ.get("ROADSTAR_GUARD") == "off" and (claude or args[:1] == ["hook"]):
        if not claude:
            print("已关闭检查（ROADSTAR_GUARD=off）")
        return 0
    try:
        if claude:
            claude_pretool()
            return 0
        if len(args) == 2 and args[0] == "modules":
            path = Path(args[1]) / MAP
            text = path.read_text(encoding="utf-8") if path.is_file() else ""
            for name, directories in modules_from(text).items():
                print(name + "\t" + ", ".join(directories))
            return 0
        root = root_at(Path.cwd())
        if len(args) == 3 and args[0] == "mark":
            mark(root, args[1], args[2])
        elif args == ["unmark"]:
            (git_dir(root) / "roadstar-task").unlink(missing_ok=True)
        elif 3 <= len(args) <= 5 and args[:2] == ["hook", "prepare-commit-msg"]:
            prepare(root, str(Path(args[2]).resolve()))
        elif len(args) == 3 and args[:2] == ["hook", "commit-msg"]:
            commit_message(root, args[2])
        elif args == ["hook", "pre-merge-commit"]:
            check_records(root, merge_tasks(root, pending_merge_refs(root)))
        elif len(args) == 2 and args[0] == "check-merge":
            check_records(root, merge_tasks(root, [args[1]]))
        else:
            raise Block("命令参数不对", "怎么办：使用 mark <场次目录> T<n>、unmark、hook <钩子名>、claude-pretool、check-merge <分支> 或 modules <仓库根>。")
        return 0
    except Block as exc:
        print(str(exc), file=sys.stderr)
    except (OSError, ValueError, TypeError, UnicodeError) as exc:
        print("拦下了：检查所需的文件读写失败\n原因：" + str(exc) +
              "\n怎么办：确认文件内容、路径和读写权限后重试。", file=sys.stderr)
    return 2 if claude else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
