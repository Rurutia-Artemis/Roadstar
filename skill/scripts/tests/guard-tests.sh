#!/bin/bash
# 所有 Git 写入、配置和派活桩都限制在 mktemp 创建的目录里。
set -euo pipefail
unset HISTFILE
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-guard-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1
python3 - "$SCRIPTS" "$TMP" <<'PY'
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

scripts = Path(sys.argv[1])
base = Path(sys.argv[2])
guard = scripts / "guard.py"
installer = scripts / "install-guard.sh"
progress = Path(os.environ["ROADSTAR_GUARD_PROGRESS"]) if os.environ.get("ROADSTAR_GUARD_PROGRESS") else None  # 不设就不写进度（总管 11-10）
plan = "docs/roadstar/测试场次"
task_value = plan + "/T1"
map_path = "docs/模块地图.md"
env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_") and k != "ROADSTAR_GUARD"}
env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
           GIT_TERMINAL_PROMPT="0", GIT_EDITOR="true", LC_ALL="C")
MAP = """# 测试地图
## 模块一览
| 模块 | 管什么 | 目录 |
|---|---|---|
| 甲模块 | 甲 | `src/a/`、`existing`，`root.txt`、`extra/*.py` |
| 乙模块 | 乙 | `src/b/`, `other.txt` |
## 甲模块
- 入口：`src/a/entry.py`、`root.txt`
## 乙模块
- 入口：`src/b/entry.py`
"""
tests = []

def test(number, description):
    def register(fn):
        tests.append((number, description, fn))
        return fn
    return register

def run(cwd, *args, expected=0, input=None, extra=None):
    e = dict(env)
    e.update(extra or {})
    p = subprocess.run([str(a) for a in args], cwd=cwd, env=e, input=input,
                       text=True, capture_output=True)
    assert p.returncode == expected, (args, "退出码", p.returncode, expected, p.stdout, p.stderr)
    if expected in (1, 2) and str(guard) in [str(a) for a in args]:
        assert p.stderr.startswith("拦下了："), p.stderr
        assert "怎么办：" in p.stderr and "Traceback" not in p.stderr, p.stderr
    return p

def git(root, *args, **kwargs):
    return run(root, "git", *args, **kwargs)

def call(root, *args, **kwargs):
    return run(root, "python3", guard, *args, **kwargs)

def write(root, name, text):
    p = root / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p

def stage(root, name, text="changed\n"):
    write(root, name, text)
    git(root, "add", "--", name)

def fixture():
    # 每条用例独立调用 mktemp -d；一个用例可以另建关联 worktree。
    directory = Path(subprocess.check_output(["mktemp", "-d", str(base / "case.XXXXXX")], text=True).strip())
    root = directory / "项目 repo"
    root.mkdir()
    git(root, "init", "-q", "--template=")
    git(root, "symbolic-ref", "HEAD", "refs/heads/main")
    git(root, "config", "user.name", "Guard Test")
    git(root, "config", "user.email", "guard@example.invalid")
    for name in ("src/a/entry.py", "src/a/body.py", "src/b/entry.py", "src/b/body.py", "root.txt", "other.txt", "existing/keep.txt"):
        write(root, name, "initial\n")
    write(root, map_path, MAP)
    write(root, plan + "/rounds/exec-T1-request.md", "# T1\n\n## 涉及模块\n甲模块\n\n## 不许动什么\n乙模块\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "initial")
    return root

def message(root, task=True, trailers=""):
    return write(root, "message", "change\n\n" + ("Roadstar-Task: " + task_value + "\n" if task else "") + trailers)

def request(root, body):
    write(root, plan + "/rounds/exec-T1-request.md", "## 涉及模块\n" + body + "\n## 后续\n乙模块\n")

def install(root, *flags, expected=0):
    return run(root, "/bin/bash", installer, root, *flags, expected=expected)

def branch(root, name="topic", task=True, number="T1"):
    git(root, "checkout", "-qb", name)
    stage(root, "src/a/body.py", name + "\n")
    msg = "change\n\nRoadstar-Task: " + plan + "/" + number if task else "ordinary"
    git(root, "commit", "-qm", msg)
    git(root, "checkout", "-q", "main")

def record(root, number="T1", text="已验收：命令及结果\n"):
    write(root, plan + "/rounds/check-" + number + ".md", text)

def pretool(root, command, expected=0, **kwargs):
    p = call(root, "claude-pretool", input=json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}, ensure_ascii=False), expected=expected, **kwargs)
    if expected == 0:
        assert p.stdout == p.stderr == "", (p.stdout, p.stderr)
    return p

MIA_MAP = """# Mia 样式地图
`Core`=`wrong/outside`
## 模块一览
`Core`=`app/Workstation/Sources/WorkstationCore`，`Kit`=`app/Workstation/Sources/WorkbenchKit/`、`Term`=`app/Workstation/Sources/MiaTerminal`。
| 模块 | 管什么 | 目录 |
|---|---|---|
| 主机 Web 与鉴权 | HTTP | `agent/src/web/` |
| App 终端工作台 | 终端 | `Core/Views/Terminal/、Core/Models/` |
| App 首页 H3 与额度 | 首页 | `Core/Views/Home/` |
| 共享组件 | 客户端 | `Kit/`、`Term/`、`CoreExtra/`、`Late/` |
`Late`=`wrong/after-table`
## App 终端工作台
- 入口：`Core/Views/Terminal/TerminalStage.swift`
`Term`=`wrong/after-section`
"""

def listed_modules(root, cwd=None):
    p = call(cwd or root, "modules", root)
    assert p.stderr == "", p.stderr
    return {name: directories.split(", ") if directories else []
            for name, directories in (line.split("\t", 1) for line in p.stdout.splitlines())}

def replace_map(root, text):
    stage(root, map_path, text)
    git(root, "commit", "-qm", "fixture map")

@test("C1-table", "模块表：三种名称列、路径列别名与第一列优先；RuruAgent 样式读出 22 个模块")
def table_headers(root):
    rows = ["| 记忆服务（M1） | 共用记忆 | `tools/memory/` |"]
    rows += ["| 工具 %02d | 职责 | `tools/tool-%02d/` |" % (i, i) for i in range(21)]
    for name_column in ("模块", "名称", "工具"):
        for path_column in ("目录", "目录／正本", "目录/正本", "源码路径", "位置", "正本"):
            text = "## 模块一览\n| %s | 管什么 | %s |\n|---|---|---|\n" % (name_column, path_column)
            write(root, map_path, text + "\n".join(rows))
            modules = listed_modules(root)
            assert len(modules) == 22, modules
            assert modules["记忆服务（M1）"] == ["tools/memory/"], modules
    write(root, map_path, "## 模块一览\n| 源码位置 | 工具 | 目录／正本 |\n|---|---|---|\n| `first/` | 甲 | `second/` |\n")
    assert listed_modules(root) == {"甲": ["first/"]}

@test("C2-table", "模块表：表前多组缩写按前缀展开，终端提交放行、Web 越界归属明确")
def table_abbreviations(root):
    replace_map(root, MIA_MAP)
    modules = listed_modules(root)
    assert modules["App 终端工作台"] == [
        "app/Workstation/Sources/WorkstationCore/Views/Terminal/",
        "app/Workstation/Sources/WorkstationCore/Models/"]
    assert modules["共享组件"] == ["app/Workstation/Sources/WorkbenchKit/",
                               "app/Workstation/Sources/MiaTerminal/", "CoreExtra/", "Late/"]
    request(root, "App 终端工作台")
    stage(root, "app/Workstation/Sources/WorkstationCore/Views/Terminal/TerminalStage.swift")
    call(root, "hook", "commit-msg", message(root))
    stage(root, "agent/src/web/x.ts")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "agent/src/web/x.ts → 主机 Web 与鉴权" in p.stderr, p.stderr

@test("C3-table", "模块表：只取反引号路径，丢说明和外部地址，保留文件、空格路径与通配")
def table_path_notes(root):
    text = """## 模块一览
| 模块 | 管什么 | 目录 |
|---|---|---|
| 中文写作、声线与语料 | 写作 | 相关 `skills/`、`Puppis/` |
| 社区回传 | 回传 | `skill/scripts/telemetry.py`、`docs/社区数据回传.md`；数据仓库 github.com/Rurutia-Artemis/roadstar-data、`github.com/Rurutia-Artemis/roadstar-data`、`https://example.org/repo`、`git://example.org/repo`、`example.org/repo`、`说明 文字` |
| 标准路径 | 原有格式 | `./src/a/`、`existing`、`root.txt`、`extra/*.py`、`path with spaces/`、`file with spaces.py` |
"""
    replace_map(root, text)
    modules = listed_modules(root)
    assert modules["中文写作、声线与语料"] == ["skills/", "Puppis/"]
    assert modules["社区回传"] == ["skill/scripts/telemetry.py", "docs/社区数据回传.md"]
    assert modules["标准路径"] == ["src/a/", "existing", "root.txt", "extra/*.py",
                                 "path with spaces/", "file with spaces.py"]
    request(root, "中文写作、声线与语料")
    stage(root, "Puppis/article.md")
    call(root, "hook", "commit-msg", message(root))
    request(root, "社区回传")
    stage(root, "github.com/Rurutia-Artemis/roadstar-data/file.txt")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "github.com/Rurutia-Artemis/roadstar-data/file.txt → 地图里没有" in p.stderr

@test("C4-table", "模块表：中英文括号说明回退；本名带括号先精确匹配；未知模块仍拦")
def table_requested_names(root):
    # 同时有不带括号的近似名称，证明完整本名不会被截短。
    text = MIA_MAP.replace("## App 终端工作台", """| Mia 资料收录 | 近似名 | `other/` |
| Mia 资料收录（原公众号文章收录） | 收录 | `tools/wechat-article-ingest/` |
| English (legacy) | 英文括号本名 | `legacy/` |
## App 终端工作台""")
    replace_map(root, text)
    for body in ("App 首页 H3 与额度（`Core/Views/Home/`）",
                 "App 首页 H3 与额度 (`Core/Views/Home/`)",
                 "- App 首页 H3 与额度（说明）"):
        request(root, body)
        stage(root, "app/Workstation/Sources/WorkstationCore/Views/Home/Home.swift")
        call(root, "hook", "commit-msg", message(root))
    request(root, "App 首页 H3 与额度（说明）、Mia 资料收录（原公众号文章收录）、English (legacy)")
    stage(root, "tools/wechat-article-ingest/new.py")
    stage(root, "legacy/file.py")
    call(root, "hook", "commit-msg", message(root))
    request(root, "App 首页 H3 与额度（说明）、未知模块（说明）")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "模块：未知模块（说明）" in p.stderr

@test("C5-table", "模块表：入口行仍只按原字面路径检查，不展开缩写或把表路径当入口")
def table_entrances_unchanged(root):
    replace_map(root, MIA_MAP)
    stage(root, "app/Workstation/Sources/WorkstationCore/Views/Terminal/TerminalStage.swift")
    call(root, "hook", "commit-msg", message(root, False))
    stage(root, "Core/Views/Terminal/TerminalStage.swift")
    p = call(root, "hook", "commit-msg", message(root, False), expected=1)
    assert "App 终端工作台：Core/Views/Terminal/TerminalStage.swift" in p.stderr

@test("C6-table", "模块表：modules 从非仓库 cwd 读取指定工作树，制表符输出，不改文件或 Git 状态")
def table_command_readonly(root):
    write(root, map_path, MIA_MAP)
    stage(root, "src/a/body.py")
    before_status = git(root, "status", "--porcelain=v1", "-z").stdout
    before_files = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    modules = listed_modules(root, cwd=root.parent)
    assert len(modules) == 4 and "App 终端工作台" in modules, modules
    assert {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()} == before_files
    assert git(root, "status", "--porcelain=v1", "-z").stdout == before_status
    empty = root.parent / "no-map"
    empty.mkdir()
    p = call(root.parent, "modules", empty)
    assert p.stdout == p.stderr == ""

@test("C1", "标记含绝对路径、任务号、分支和时间；unmark 幂等")
def c1(root):
    call(root, "mark", root / plan, "T1")
    data = json.loads((root / ".git/roadstar-task").read_text())
    assert data["plan_dir"] == str((root / plan).resolve()) and data["task"] == "T1" and data["branch"] == "main", data
    datetime.datetime.fromisoformat(data["time"])
    call(root, "unmark")
    call(root, "unmark")
    assert not (root / ".git/roadstar-task").exists()

@test("C1", "切走分支后旧标记无效，worktree 各有标记")
def c1_worktree(root):
    call(root, "mark", root / plan, "T1")
    git(root, "checkout", "-qb", "other")
    msg = message(root, False)
    call(root, "hook", "prepare-commit-msg", msg)
    assert "Roadstar-Task" not in msg.read_text()
    wt = root.parent / "linked"
    git(root, "worktree", "add", "-qb", "linked", wt)
    call(wt, "mark", wt / plan, "T2")
    directory = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir").stdout.strip())
    assert json.loads((directory / "roadstar-task").read_text())["task"] == "T2"
    assert json.loads((root / ".git/roadstar-task").read_text())["task"] == "T1"
    call(wt, "unmark")
    assert (root / ".git/roadstar-task").exists()

@test("C2", "prepare 用 trailer 追加且重复执行不重复添加")
def c2(root):
    call(root, "mark", root / plan, "T1")
    msg = message(root, False)
    for _ in range(2):
        call(root, "hook", "prepare-commit-msg", msg, "message")
    assert msg.read_text().count("Roadstar-Task: " + str((root / plan).resolve() / "T1")) == 1
    assert git(root, "interpret-trailers", "--parse", msg).stdout.strip() == "Roadstar-Task: " + str((root / plan).resolve() / "T1")

@test("C2", "没有标记不改提交说明，保留已有的其他任务 trailer")
def c2_unmarked(root):
    msg = message(root)
    old = msg.read_bytes()
    call(root, "hook", "prepare-commit-msg", msg)
    assert msg.read_bytes() == old
    call(root, "mark", root / plan, "T2")
    call(root, "hook", "prepare-commit-msg", msg)
    assert task_value in msg.read_text() and plan + "/T2" in msg.read_text()

@test("C3", "目录、现有目录、精确文件、通配与中英分隔符匹配")
def c3_paths(root):
    for name in ("src/a/deep/new.py", "existing/new.txt", "root.txt", "extra/new.py"):
        stage(root, name)
    call(root, "hook", "commit-msg", message(root, trailers="Roadstar-Map: 文件路径没变\n"))

@test("C3", "越界逐个显示实际模块和地图未收录文件")
def c3_scope(root):
    for name in ("src/b/body.py", "unknown.txt", "root.txt.more", "src/ab/file.py"):
        stage(root, name)
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "src/b/body.py → 乙模块" in p.stderr
    for name in ("unknown.txt", "root.txt.more", "src/ab/file.py"):
        assert name + " → 地图里没有" in p.stderr
    assert "改任务书的涉及模块后重提" in p.stderr and "Roadstar-Scope:" in p.stderr

@test("C3", "范围豁免必须有理由，放行打印原理由")
def c3_override(root):
    stage(root, "src/b/body.py")
    p = call(root, "hook", "commit-msg", message(root, trailers="Roadstar-Scope: 配套修复乙模块\n"))
    assert p.stdout.strip() == "越界已放行：配套修复乙模块"
    call(root, "hook", "commit-msg", message(root, trailers="Roadstar-Scope: \n"), expected=1)

@test("C3", "固定放行名单全部通过，类似目录不误放行")
def c3_allow(root):
    for name in (map_path, "docs/MODULES.md", "docs/roadstar/new/log.md", "CHANGELOG.md", "CHANGELOG-zh.txt"):
        stage(root, name, MAP if name == map_path else "new\n")
    call(root, "hook", "commit-msg", message(root))
    stage(root, "docs/roadstar-other/hidden.md")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "docs/roadstar-other/hidden.md" in p.stderr

@test("C3", "多个模块与任务 trailer 都检查，未知模块不静默放行")
def c3_modules(root):
    request(root, "- 甲模块\n- 乙模块")
    stage(root, "src/b/body.py")
    call(root, "hook", "commit-msg", message(root))
    request(root, "不存在模块")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "不存在模块" in p.stderr
    request(root, "甲模块")
    msg = message(root, trailers="Roadstar-Task: " + plan + "/T2\nRoadstar-Scope: 配套调整\n")
    p = call(root, "hook", "commit-msg", msg, expected=1)
    assert "exec-T2-request.md" in p.stderr

@test("C3", "删除和跨模块重命名同时检查旧新路径")
def c3_rename(root):
    git(root, "mv", "src/b/body.py", "src/a/moved.py")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "src/b/body.py → 乙模块" in p.stderr

@test("C3", "模块名加说明文字可识别，列表里的未知模块仍拦下")
def c3_prose(root):
    request(root, "项目地图（`docs/模块地图.md`）里的「甲模块」。新增 `new.py`、`new.sh` 是新入口，同一次交付里更新地图那一节。")
    stage(root, "src/a/body.py")
    call(root, "hook", "commit-msg", message(root))
    request(root, "「甲模块」、「未知模块」")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "未知模块" in p.stderr

@test("C4", "无地图声明只跳过范围检查")
def c4_optout(root):
    request(root, "无地图：本次迁入")
    stage(root, "unknown.txt")
    p = call(root, "hook", "commit-msg", message(root))
    assert p.stdout.strip() == "这个项目没有模块地图，范围检查跳过"
    stage(root, "src/a/entry.py")
    call(root, "hook", "commit-msg", message(root), expected=1)

@test("C4", "项目没有地图时范围跳过，仍要求任务书存在")
def c4_no_map(root):
    git(root, "rm", map_path)
    git(root, "commit", "-qm", "remove map")
    stage(root, "unknown.txt")
    p = call(root, "hook", "commit-msg", message(root))
    assert p.stdout.strip() == "这个项目没有模块地图，范围检查跳过"
    (root / plan / "rounds/exec-T1-request.md").unlink()
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert str(root / plan / "rounds/exec-T1-request.md") in p.stderr

@test("C4", "缺任务书或缺涉及模块节给出路径和补救")
def c4_missing(root):
    req = root / plan / "rounds/exec-T1-request.md"
    req.unlink()
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert str(req) in p.stderr
    write(root, plan + "/rounds/exec-T1-request.md", "# 没写模块\n")
    p = call(root, "hook", "commit-msg", message(root), expected=1)
    assert "## 涉及模块" in p.stderr

@test("C5", "无任务提交也拦入口改动，逐项显示模块与入口")
def c5(root):
    stage(root, "src/a/entry.py")
    stage(root, "src/b/entry.py")
    p = call(root, "hook", "commit-msg", message(root, False), expected=1)
    assert "甲模块：src/a/entry.py" in p.stderr and "乙模块：src/b/entry.py" in p.stderr

@test("C5", "地图暂存或 Map 理由各能放行，空理由不能")
def c5_overrides(root):
    stage(root, "src/a/entry.py")
    call(root, "hook", "commit-msg", message(root, False, "Roadstar-Map: 入口签名和路径未变\n"))
    call(root, "hook", "commit-msg", message(root, False, "Roadstar-Map: \n"), expected=1)
    stage(root, map_path, MAP + "\n已核对。\n")
    call(root, "hook", "commit-msg", message(root, False))

@test("C5", "未暂存地图不算更新，也不能隐去旧入口")
def c5_unstaged(root):
    stage(root, "src/a/entry.py")
    write(root, map_path, MAP.replace("- 入口：`src/a/entry.py`、`root.txt`", "- 入口：无"))
    p = call(root, "hook", "commit-msg", message(root, False), expected=1)
    assert "src/a/entry.py" in p.stderr

@test("C6", "无任务提交只查地图，普通文件和无地图项目放行")
def c6(root):
    stage(root, "unknown.txt")
    call(root, "hook", "commit-msg", message(root, False))
    git(root, "rm", map_path)
    git(root, "commit", "-qm", "without map")
    stage(root, "src/a/entry.py")
    call(root, "hook", "commit-msg", message(root, False))

@test("C7", "check-merge 列出多任务缺失和空白验收记录")
def c7_records(root):
    branch(root)
    git(root, "checkout", "-q", "topic")
    stage(root, "src/a/body.py", "second\n")
    git(root, "commit", "-qm", "second\n\nRoadstar-Task: " + plan + "/T2")
    git(root, "checkout", "-q", "main")
    record(root, text=" \n")
    p = call(root, "check-merge", "topic", expected=1)
    assert str(root / plan / "rounds/check-T1.md") in p.stderr
    assert str(root / plan / "rounds/check-T2.md") in p.stderr
    record(root)
    record(root, "T2")
    call(root, "check-merge", "topic")

@test("C7", "真实 pre-merge-commit 拦缺验收，补记录后合并通过")
def c7_hook(root):
    branch(root)
    install(root)
    p = git(root, "merge", "--no-ff", "--no-edit", "topic", expected=1)
    assert "拦下了：" in p.stderr and "check-T1.md" in p.stderr
    git(root, "merge", "--abort")
    record(root)
    git(root, "merge", "--no-ff", "--no-edit", "topic")
    assert len(git(root, "rev-list", "--parents", "-n", "1", "HEAD").stdout.split()) == 3

@test("C7", "合并提交不再查范围和地图：任务提交已带 Roadstar-Map 理由时合并通过")
def c7_merge_commit_skips_map(root):
    install(root)
    git(root, "checkout", "-qb", "topic")
    stage(root, "src/a/entry.py", "entry changed\n")
    git(root, "commit", "-qm", "entry\n\nRoadstar-Task: " + task_value + "\nRoadstar-Map: 只改内部实现")
    git(root, "checkout", "-q", "main")
    record(root)
    git(root, "merge", "--no-ff", "--no-edit", "topic")
    assert len(git(root, "rev-list", "--parents", "-n", "1", "HEAD").stdout.split()) == 3

@test("C9", "guard.py 找不到时外壳提示一句并放行，不挡提交")
def c9_missing_guard(root):
    install(root)
    hook = root / ".git/hooks/commit-msg"
    text = hook.read_text().replace(str(guard), str(root / "不存在/guard.py"))
    hook.write_text(text)
    stage(root, "src/a/entry.py", "entry changed\n")
    p = git(root, "commit", "-qm", "no guard")
    assert "Roadstar 检查没跑" in p.stderr, p.stderr

@test("C7", "worktree 合并只认主工作区验收记录")
def c7_worktree(root):
    branch(root)
    wt = root.parent / "merge-wt"
    git(root, "worktree", "add", "-qb", "merge-lane", wt, "main")
    record(wt)
    p = call(wt, "check-merge", "topic", expected=1)
    assert str((root / plan).resolve() / "rounds/check-T1.md") in p.stderr
    record(root)
    call(wt, "check-merge", "topic")

@test("C7", "MERGE_HEAD 已存在时检查待合并提交，空文件不算验收")
def c7_merge_head(root):
    branch(root)
    git(root, "merge", "--no-ff", "--no-commit", "topic")
    assert (root / ".git/MERGE_HEAD").is_file()
    record(root, text="")
    call(root, "hook", "pre-merge-commit", expected=1)
    record(root)
    call(root, "hook", "pre-merge-commit")

@test("C7", "无 trailer 合并放行，已在 HEAD 的旧任务不重复要求验收")
def c7_plain(root):
    branch(root, task=False)
    install(root)
    git(root, "merge", "--no-ff", "--no-edit", "topic")
    write(root, plan + "/rounds/exec-T9-request.md", "## 涉及模块\n甲模块\n")
    git(root, "commit", "--allow-empty", "-qm", "old\n\nRoadstar-Task: " + plan + "/T9")
    call(root, "check-merge", "topic")

@test("C8", "Claude 拦快进和缺验收，补齐后静默通过")
def c8(root):
    branch(root)
    p = pretool(root, "git merge topic", expected=2)
    assert "--no-ff" in p.stderr
    p = pretool(root, "git merge --no-ff topic", expected=2)
    assert "check-T1.md" in p.stderr
    record(root)
    pretool(root, "git merge --no-ff topic")
    pretool(root, "git merge --no-ff --ff topic", expected=2)

@test("C8", "Claude 忽略 Read、损坏 JSON、非命令文本和退出合并操作")
def c8_ignore(root):
    for data in ("bad json", "[]", '{"tool_name":"Read","tool_input":{}}', '{"tool_name":"Bash","tool_input":null}'):
        p = call(root, "claude-pretool", input=data)
        assert p.stdout == p.stderr == ""
    for command in ("git merge --abort", "git merge --continue", "git merge --quit", "echo 'git merge topic'", "git status"):
        pretool(root, command)

@test("C8", "Claude 支持命令链、-C、引号路径和带参数的 merge 选项")
def c8_shell(root):
    branch(root)
    import shlex
    quoted = shlex.quote(str(root))
    for command in ("pwd && git -C " + quoted + " merge -m 'git merge ignored' --no-ff topic",
                    "cd " + quoted + " && git merge --no-ff topic", "git status\ngit merge --no-ff topic"):
        pretool(root.parent, command, expected=2) if "\n" not in command else pretool(root, command, expected=2)
    record(root)
    pretool(root.parent, "git -C " + quoted + " merge -m 'message' --no-ff topic")

@test("C8", "Claude 无任务分支可快进，多分支逐个检查")
def c8_multi(root):
    branch(root, "plain", False)
    branch(root, "topic")
    pretool(root, "git merge plain")
    pretool(root, "git merge --no-ff plain topic", expected=2)
    record(root)
    pretool(root, "git merge --no-ff plain topic")

@test("C8", "Claude 识别重定向和条件命令，不把日志路径当分支")
def c8_redirect(root):
    branch(root)
    for cmd in ("git merge --no-ff topic > merge.log 2>&1", "if true; then git merge --no-ff topic; fi"):
        p = pretool(root, cmd, expected=2)
        assert "check-T1.md" in p.stderr
    record(root)
    pretool(root, "git merge --no-ff topic > merge.log 2>&1")
    assert not (root / "merge.log").exists()

@test("C9", "安装幂等，原钩子改为 .local，卸载恢复字节与执行权限")
def c9_local(root):
    original = b'#!/bin/bash\nprintf "local:%s\\n" "$*" >> local-ran\n'
    for name in ("prepare-commit-msg", "commit-msg", "pre-merge-commit"):
        path = root / ".git/hooks" / name
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(original)
        path.chmod(0o755)
    install(root)
    snapshot = {p.name: p.read_bytes() for p in (root / ".git/hooks").iterdir()}
    install(root)
    assert snapshot == {p.name: p.read_bytes() for p in (root / ".git/hooks").iterdir()}
    msg = message(root, False)
    run(root, root / ".git/hooks/commit-msg", msg)
    assert "local:" in (root / "local-ran").read_text()
    install(root, "--uninstall")
    install(root, "--uninstall")
    for name in ("prepare-commit-msg", "commit-msg", "pre-merge-commit"):
        p = root / ".git/hooks" / name
        assert p.read_bytes() == original and os.access(p, os.X_OK)
        assert not p.with_name(name + ".local").exists()

@test("C9", "原钩子拒绝时不运行 guard，也保留原退出码和参数")
def c9_block(root):
    local = write(root, ".git/hooks/prepare-commit-msg", '#!/bin/bash\nprintf "%s" "$2" > local-source\nexit 7\n')
    local.chmod(0o755)
    install(root)
    call(root, "mark", root / plan, "T1")
    msg = message(root, False)
    run(root, root / ".git/hooks/prepare-commit-msg", msg, "message", expected=7)
    assert (root / "local-source").read_text() == "message"
    assert "Roadstar-Task" not in msg.read_text()

@test("C9", "core.hooksPath 不动，打印三行手动接入命令")
def c9_custom(root):
    git(root, "config", "core.hooksPath", "custom-hooks")
    write(root, "custom-hooks/commit-msg", "existing\n")
    p = install(root)
    assert len([l for l in p.stdout.splitlines() if l.startswith("python3 ")]) == 3
    assert (root / "custom-hooks/commit-msg").read_text() == "existing\n"
    assert not (root / ".git/hooks/commit-msg").exists()
    install(root, "--uninstall")

@test("C9", "Claude 设置合并保留其他内容，不重复添加，卸载只移除自己")
def c9_claude(root):
    old = {"permissions": {"allow": ["Read"]}, "hooks": {"Stop": [{"hooks": []}], "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "echo keep"}]}]}}
    settings = write(root, ".claude/settings.local.json", json.dumps(old))
    install(root, "--claude")
    once = settings.read_bytes()
    install(root, "--claude")
    assert once == settings.read_bytes()
    data = json.loads(once)
    assert data["permissions"] == old["permissions"] and data["hooks"]["Stop"] == old["hooks"]["Stop"]
    hooks = data["hooks"]["PreToolUse"]
    assert len(hooks) == 2 and hooks[1]["matcher"] == "Bash"
    assert str(guard) in hooks[1]["hooks"][0]["command"]
    install(root, "--uninstall", "--claude")
    assert json.loads(settings.read_text()) == old

@test("C9", "安装到 worktree 使用公共 hooks，真实提交自动加任务号")
def c9_real(root):
    wt = root.parent / "commit-wt"
    git(root, "worktree", "add", "-qb", "commit-lane", wt)
    install(wt)
    assert (root / ".git/hooks/commit-msg").exists()
    call(wt, "mark", wt / plan, "T1")
    stage(wt, "src/a/body.py")
    git(wt, "commit", "-qm", "actual commit")
    assert "Roadstar-Task: " + str((root / plan).resolve() / "T1") in git(wt, "log", "-1", "--format=%B").stdout  # 副本路径统一换成主目录同位置
    stage(wt, "src/b/body.py")
    p = git(wt, "commit", "-qm", "outside", expected=1)
    assert "src/b/body.py → 乙模块" in p.stderr

@test("C9", "备份名冲突或坏设置时不覆盖原文件，不留半套钩子")
def c9_conflict(root):
    path = write(root, ".git/hooks/commit-msg", "original\n")
    backup = write(root, ".git/hooks/commit-msg.local", "backup\n")
    p = install(root, expected=1)
    assert "拦下了：" in p.stderr and "Traceback" not in p.stderr
    assert path.read_text() == "original\n" and backup.read_text() == "backup\n"
    assert not (root / ".git/hooks/prepare-commit-msg").exists()
    backup.unlink()
    write(root, ".claude/settings.local.json", "{bad")
    install(root, "--claude", expected=1)
    assert path.read_text() == "original\n"

def dispatch(root, write_flag=True, dry=False, nonrepo=False, broken=False):
    directory = root.parent / "dispatch"
    directory.mkdir(exist_ok=True)
    shutil.copy2(scripts / "dex-exec.sh", directory / "dex-exec.sh")
    shutil.copy2(guard, directory / "guard.py")
    if broken:
        (directory / "guard.py").write_text("raise SystemExit(1)\n")
    write(directory, "quota-status.py", 'print(\'{"codex":{"tier":"宽"}}\')\n')
    write(directory, "brief-check.py", "raise SystemExit(0)\n")  # 六栏和同类方案校验由 run.sh 测，这里只测任务标记
    write(directory, "entry-check.py", "raise SystemExit(0)\n")  # 接入与存量卡由 entry-tests.sh 测
    codex = write(directory, "bin/codex", '#!/bin/bash\nif [ -n "$FAKE_EXPECT_MARK" ]; then [ -s "$FAKE_EXPECT_MARK" ] || exit 9; fi\nprintf "called\\n" >> "$FAKE_CALLED"\n')
    codex.chmod(0o755)
    target = root
    if nonrepo:
        target = directory / "not-repo"
        target.mkdir()
    args = ["/bin/bash", directory / "dex-exec.sh", root / plan, "T1", "--model", "m", "--effort", "low", "--brief", root / plan / "rounds/exec-T1-request.md", "--root", target]
    if write_flag:
        args.append("--write")
    if dry:
        args.append("--dry-run")
    mark = ""
    if write_flag and not nonrepo and not broken:
        mark = str(Path(git(root, "rev-parse", "--path-format=absolute", "--git-dir").stdout.strip()) / "roadstar-task")
    return run(root, *args, extra={"PATH": str(directory / "bin") + ":" + env["PATH"], "ROADSTAR_CONFIG_DIR": str(directory / "config"), "WS_GUARD_DIR": str(directory / "no-ws-guard"), "FAKE_CALLED": str(directory / "called"), "FAKE_EXPECT_MARK": mark})

@test("C10", "write 实际派活前在 root 留下任务标记，使用离线 codex 桩")
def c10_write(root):
    dispatch(root)
    assert json.loads((root / ".git/roadstar-task").read_text())["task"] == "T1"
    assert (root.parent / "dispatch/called").read_text() == "called\n"

@test("C10", "dry-run 与只读派活不写标记")
def c10_dry(root):
    p = dispatch(root, dry=True)
    assert p.stdout.startswith("命令：") and "警告" not in p.stderr
    assert not (root / ".git/roadstar-task").exists() and not (root.parent / "dispatch/called").exists()
    dispatch(root, write_flag=False)
    assert not (root / ".git/roadstar-task").exists()

@test("C10", "root 指向 worktree 时标记只写该 worktree，派活前已存在")
def c10_worktree(root):
    wt = root.parent / "dispatch-wt"
    git(root, "worktree", "add", "-qb", "dispatch-lane", wt)
    dispatch(wt)
    directory = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir").stdout.strip())
    assert json.loads((directory / "roadstar-task").read_text())["branch"] == "dispatch-lane"
    assert not (root / ".git/roadstar-task").exists()

@test("C10", "非 Git root 只警告一行，仍然派活")
def c10_nonrepo(root):
    p = dispatch(root, nonrepo=True)
    assert p.stderr.count("警告：Roadstar 任务标记失败") == 1 and len(p.stderr.splitlines()) == 1
    assert (root.parent / "dispatch/called").exists()

@test("C10", "mark 失败只警告一行，不影响派活")
def c10_broken(root):
    p = dispatch(root, broken=True)
    assert p.stderr.count("警告：Roadstar 任务标记失败") == 1 and len(p.stderr.splitlines()) == 1
    assert (root.parent / "dispatch/called").exists()

@test("C13", "工位在更深的目录、场次在主工作区：标记按主工作区记，提交找得到任务书，合并认主工作区记录")
def c12_slots(root):
    install(root)
    slot = root.parent / "slots" / "s1"
    slot.parent.mkdir()
    git(root, "worktree", "add", "-qb", "lane/s1-T1", slot)
    call(slot, "mark", root / plan, "T1")
    data = json.loads((Path(git(slot, "rev-parse", "--path-format=absolute", "--git-dir").stdout.strip()) / "roadstar-task").read_text())
    assert data["plan_dir"] == str((root / plan).resolve()), data
    stage(slot, "src/a/body.py", "slot change\n")
    git(slot, "commit", "-qm", "slot commit")
    assert "Roadstar-Task: " + str((root / plan).resolve() / "T1") in git(slot, "log", "-1", "--format=%B").stdout
    integ = root.parent / "slots" / "int"
    git(root, "worktree", "add", "-qb", "integration", integ, "main")
    p = call(integ, "check-merge", "lane/s1-T1", expected=1)
    assert str(root / plan / "rounds/check-T1.md") in p.stderr, p.stderr
    record(root)
    call(integ, "check-merge", "lane/s1-T1")

@test("C11", "坏标记、坏 trailer 和未知分支都给中文补救，无堆栈")
def c11(root):
    write(root, ".git/roadstar-task", "{bad")
    call(root, "hook", "prepare-commit-msg", message(root, False), expected=1)
    call(root, "check-merge", "missing", expected=1)
    call(root, "hook", "commit-msg", message(root, False, "Roadstar-Task: broken\n"), expected=1)

@test("C12", "关闭开关直接放行三种钩子，Claude 静默且不读 stdin")
def c12(root):
    for args in (("hook", "prepare-commit-msg", "missing"), ("hook", "commit-msg", "missing"), ("hook", "pre-merge-commit")):
        p = call(root, *args, extra={"ROADSTAR_GUARD": "off"})
        assert p.stdout.strip() == "已关闭检查（ROADSTAR_GUARD=off）" and p.stderr == ""
    pretool(root, "git merge missing", extra={"ROADSTAR_GUARD": "off"})

failed = 0
count = 0
streak = {}
if progress and progress.exists():
    for line in progress.read_text().splitlines():
        parts = line.split("\t", 3)
        if len(parts) == 4:
            streak[parts[1]] = streak.get(parts[1], 0) + 1 if parts[2] == "fail" else 0
for number, description, fn in tests:
    if streak.get(number, 0) >= 3:
        print("FAIL " + number + " 已连续三次失败，按止损要求停止")
        failed += 1
        count += 1
        break
    root = None
    try:
        root = fixture()
        fn(root)
        status = "pass"
        evidence = description
    except Exception as exc:
        status = "fail"
        evidence = description + "；" + str(exc).replace("\n", " ")
        failed += 1
    finally:
        if root is not None:
            shutil.rmtree(root.parent)
    count += 1
    print(status.upper() + " " + number + " " + evidence, flush=True)
    if progress:
        progress.parent.mkdir(parents=True, exist_ok=True)
        with progress.open("a", encoding="utf-8") as f: f.write(datetime.datetime.now(datetime.timezone.utc).isoformat() + "\t" + number + "\t" + status + "\t" + evidence + "\n")
    streak[number] = streak.get(number, 0) + 1 if status == "fail" else 0
    if streak[number] >= 3:
        break
print("FAIL " + str(failed) + "/" + str(count) if failed else "PASS " + str(count))
sys.exit(1 if failed else 0)
PY
