#!/bin/bash
# 每条用例独立 mktemp -d；Git 写入只发生在临时仓库。
set -euo pipefail
unset HISTFILE
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$SCRIPTS" <<'PY'
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

scripts = Path(sys.argv[1])
cleanup = scripts / "cleanup.py"
# Optional per-run evidence sink; previous runs never affect test results.
progress = os.environ.get("ROADSTAR_CLOSE_CHECK_PROGRESS")
env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
           GIT_TERMINAL_PROMPT="0", GIT_EDITOR="true", GIT_OPTIONAL_LOCKS="0", LC_ALL="C")
plan = "docs/roadstar/测试场次"
tests = []


def test(number, description):
    def register(fn):
        tests.append((number, description, fn))
        return fn
    return register


def run(root, *args, expected=0):
    p = subprocess.run([str(a) for a in args], cwd=root, env=env,
                       capture_output=True, text=True)
    assert p.returncode == expected, (args, p.returncode, expected, p.stdout, p.stderr)
    assert "Traceback" not in p.stderr, p.stderr
    return p


def git(root, *args, **kwargs):
    return run(root, "git", *args, **kwargs)


def call(root, *args, **kwargs):
    return run(root, "python3", cleanup, "--project", root, *args, **kwargs)


def report(root, *args, expected=1):
    return json.loads(call(root, "--check", "--json", *args, expected=expected).stdout)


def write(root, name, text="x\n"):
    p = root / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p


def commit(root, message="change"):
    git(root, "commit", "-q", "--allow-empty", "-m", message)


def lane(root, name, merged=False, locked=False, dirty=False):
    path = root.parent / ("副本 " + name)
    git(root, "worktree", "add", "-qb", name, path)
    commit(path)
    if merged:
        git(root, "merge", "-q", "--no-ff", "-m", "merge " + name, name)
    if locked:
        git(root, "worktree", "lock", path)
    if dirty:
        write(path, "scratch")
    return path


def snapshot(root):
    # 文件内容、mtime、mode（含 .git/index），以及要求的三个列表。
    files = {}
    directories = []
    for path in sorted(root.parent.rglob("*")):
        rel = str(path.relative_to(root.parent))
        if path.is_dir():
            directories.append(rel)
        else:
            stat = path.stat()
            files[rel] = (hashlib.sha256(path.read_bytes()).hexdigest(), stat.st_mtime_ns, stat.st_mode)
    return (git(root, "worktree", "list", "--porcelain").stdout,
            git(root, "branch", "-a").stdout, directories, files)


@test("C1", "check 与 apply 冲突退出 2，原句报错且所有文件和 Git 状态不变")
def conflict(root):
    lane(root, "merged", merged=True)
    write(root, plan + "/rounds/old.log")
    before = snapshot(root)
    p = call(root, "--check", "--apply", expected=2)
    assert p.stderr.strip() == "--check 只查不删，不能和 --apply 一起用" and not p.stdout
    assert snapshot(root) == before


@test("C2", "普通及锁定的未合并副本都列出，领先提交数准确，主工作区排除")
def unmerged(root):
    a = lane(root, "ahead")
    commit(a)
    b = lane(root, "locked", locked=True)
    data = report(root)
    assert [i["kind"] for i in data["items"]] == ["unmerged", "unmerged"], data
    by_branch = {i["branch"]: i for i in data["items"]}
    assert by_branch["ahead"]["detail"] == f"没合并：工作副本 {a}（分支 ahead，领先 2 个提交）", by_branch
    assert by_branch["locked"]["detail"] == f"没合并：工作副本 {b}（分支 locked，领先 1 个提交）", by_branch


@test("C2", "默认基准沿用 origin/HEAD 优先级，显式 base 可以覆盖")
def base(root):
    old = git(root, "rev-parse", "HEAD").stdout.strip()
    git(root, "update-ref", "refs/remotes/origin/trunk", old)
    git(root, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk")
    wt = lane(root, "merged", merged=True)
    assert report(root)["items"][0]["kind"] == "unmerged"
    item = report(root, "--base", "main")["items"][0]
    assert item["kind"] == "merged_not_cleaned" and item["path"] == str(wt), item


@test("C2", "从副本运行仍排除真正主工作区，中文空格与引号路径不误读")
def linked_project(root):
    wt = lane(root, '中文"lane')
    data = report(wt)
    assert len(data["items"]) == 1 and data["items"][0]["path"] == str(wt), data


@test("C3", "无副本的本地分支也扫描，按场次任务分支汇总并排除已合并提交")
def task_branches(root):
    commit(root, "accepted\n\nRoadstar-Task: " + plan + "/T9")
    git(root, "checkout", "-qb", "task-only")
    commit(root, "first\n\nRoadstar-Task: " + plan + "/T1")
    commit(root, "second\n\nroadstar-task: " + plan + "/T1\nRoadstar-Task: " + plan + "/T2a")
    commit(root, "not a trailer\n\nRoadstar-Task: " + plan + "/T99\n\nbody after trailer")
    commit(root, "ordinary")
    git(root, "branch", "shared")
    git(root, "checkout", "-q", "main")
    data = report(root)
    assert all(i["kind"] == "unmerged_task" for i in data["items"])
    assert {(i["branch"], i["task"], i["commits"]) for i in data["items"]} == {
        (b, t, n) for b in ("task-only", "shared") for t, n in (("T1", 2), ("T2a", 1))}
    assert data["items"][0]["detail"] == f"没合并：T1（{plan}）在分支 shared 上，2 个提交"


@test("C3", "主工作区分支上的未合并任务也查，重复 trailer 同一提交只计一次")
def task_main(root):
    git(root, "branch", "baseline")
    commit(root, "task\n\nRoadstar-Task: " + plan + "/T1\nRoadstar-Task: " + plan + "/T1")
    items = report(root, "--base", "baseline")["items"]
    assert len(items) == 1 and items[0]["branch"] == "main" and items[0]["commits"] == 1


@test("C4", "只列 dry-run 允许清的副本，脏、锁定、detached 和未推送的都排除")
def merged(root):
    clean = lane(root, "clean", merged=True)
    lane(root, "dirty", merged=True, dirty=True)
    lane(root, "slot", merged=True, locked=True)
    unpushed = lane(root, "unpushed", merged=True)
    git(root, "update-ref", "refs/remotes/local/unpushed", "main~1")
    git(root, "config", "branch.unpushed.remote", "local")
    git(root, "config", "branch.unpushed.merge", "refs/heads/unpushed")
    git(root, "config", "remote.local.fetch", "+refs/heads/*:refs/remotes/local/*")
    git(root, "worktree", "add", "-q", "--detach", root.parent / "detached", "main")
    dry = json.loads(call(root, "--json").stdout)
    assert [i["path"] for i in dry["worktrees_remove"]] == [str(clean)]
    assert any("未推送" in r for i in dry["worktrees_keep"] if i["path"] == str(unpushed) for r in i["reasons"])
    items = report(root)["items"]
    assert len(items) == 1 and items[0]["detail"] == f"已合并没清：{clean}"


@test("C5", "多个场次逐一检查缺失、空及纯空白验收，忽略任务书和有效验收")
def acceptance(root):
    other = "docs/roadstar/另一场"
    for task in ("T1", "T2", "T3a", "T4"):
        write(root, plan + f"/rounds/exec-{task}.md")
    write(root, plan + "/rounds/check-T2.md", "")
    write(root, plan + "/rounds/check-T3a.md", " \n\t")
    write(root, plan + "/rounds/check-T4.md", "已验收\n")
    write(root, plan + "/rounds/exec-T5-request.md")
    write(root, other + "/rounds/exec-T1.md")
    items = report(root, "--plan-dir", plan, "--plan-dir", other, "--plan-dir", plan)["items"]
    assert [(i["plan_dir"], i["task"]) for i in items] == [(plan, "T1"), (plan, "T2"), (plan, "T3a"), (other, "T1")]
    assert items[0]["detail"] == f"没验收：T1（{plan}）"


@test("C5", "不给场次时跳过自动发现的验收记录，并明确提示；JSON 保持可解析")
def no_plan(root):
    write(root, plan + "/rounds/exec-T1.md")
    p = call(root, "--check")
    assert p.stdout.splitlines() == ["收工检查：都收完了", "没给场次目录，验收记录这项没查"]
    p = call(root, "--check", "--json")
    assert json.loads(p.stdout) == {"clean": True, "items": []}
    assert p.stderr.strip() == "没给场次目录，验收记录这项没查"


@test("C6", "四种条目按组排列，首行计数和 JSON 字段准确，不输出堆栈")
def output(root):
    lane(root, "clean", merged=True)
    wt = lane(root, "ahead")
    commit(wt, "task\n\nRoadstar-Task: " + plan + "/T2")
    write(root, plan + "/rounds/exec-T1.md")
    items = report(root, "--plan-dir", plan)["items"]
    assert [i["kind"] for i in items] == ["unmerged", "unmerged_task", "merged_not_cleaned", "no_acceptance"]
    p = call(root, "--check", "--plan-dir", plan, expected=1)
    assert p.stdout.splitlines() == ["收工检查：还有 4 项没收完"] + [i["detail"] for i in items]
    assert not p.stderr


@test("C6", "都收完退出 0；不存在的基准、非 Git 路径及不存在路径给中文错误退出 2")
def errors(root):
    assert report(root, "--plan-dir", plan, expected=0) == {"clean": True, "items": []}
    assert call(root, "--check", "--plan-dir", plan).stdout.strip() == "收工检查：都收完了"
    assert "找不到基准分支" in call(root, "--check", "--base", "missing", expected=2).stderr
    outside = root.parent / "not-repo"
    outside.mkdir()
    assert "不是 git 仓库" in call(outside, "--check", expected=2).stderr
    assert "收工检查没查完" in call(root, "--project", outside / "missing", "--check", expected=2).stderr


@test("C7", "文本和 JSON 检查前后 worktree、分支、目录及全部文件内容与 mtime 一致")
def readonly(root):
    merged = lane(root, "merged", merged=True)
    lane(root, "locked", locked=True)
    write(root, plan + "/rounds/exec-T1.md")
    write(root, plan + "/rounds/old.log")
    # 让 status 有刷新 index 的机会；只读模式必须禁止刷新。
    os.utime(merged / "tracked", None)
    before = snapshot(root)
    # The caller permits index refresh; cleanup --check must disable it itself.
    env["GIT_OPTIONAL_LOCKS"] = "1"
    try:
        call(root, "--check", "--plan-dir", plan, expected=1)
        call(root, "--check", "--json", "--plan-dir", plan, expected=1)
    finally:
        env["GIT_OPTIONAL_LOCKS"] = "0"
    assert snapshot(root) == before


@test("C8", "原 dry-run 及 apply 保持清理与保护规则：只清已合并干净副本和过期中间产物")
def legacy(root):
    clean = lane(root, "clean", merged=True)
    dirty = lane(root, "dirty", merged=True, dirty=True)
    slot = lane(root, "slot", merged=True, locked=True)
    ahead = lane(root, "ahead")
    rounds = plan + "/rounds/"
    keep = ("exec-T1.meta", "exec-T1-request.md", "exec-T1.md", "check-T1.md", "exec-T1.progress", "r1-plan.md", "r1-dex-review.json")
    old = time.time() - 10 * 86400
    for name in keep + ("exec-T1-stdout.log", "old.patch", "T1-shots/a.png"):
        p = write(root, rounds + name)
        os.utime(p, (old, old))
    os.utime(root / rounds / "T1-shots", (old, old))
    write(root, rounds + "exec-T2-stdout.log")
    before = snapshot(root)
    dry = json.loads(call(root, "--json").stdout)
    assert dry["mode"] == "dry-run" and [i["path"] for i in dry["worktrees_remove"]] == [str(clean)]
    assert {Path(i["path"]).name for i in dry["intermediates"]} == {"exec-T1-stdout.log", "old.patch", "T1-shots"}
    assert "只列不删" in call(root).stdout
    assert snapshot(root) == before
    applied = json.loads(call(root, "--apply", "--json").stdout)
    assert applied["mode"] == "apply" and not applied["errors"]
    assert all(i["done"] for i in applied["worktrees_remove"] + applied["intermediates"])
    assert not clean.exists() and all(p.exists() for p in (dirty, slot, ahead))
    assert "clean" not in git(root, "branch", "--format=%(refname:short)").stdout.splitlines()
    assert all((root / rounds / name).is_file() for name in keep + ("exec-T2-stdout.log",))
    assert not any((root / rounds / name).exists() for name in ("old.patch", "exec-T1-stdout.log", "T1-shots"))
    call(root.parent, expected=2)


@test("F4", "指定场次时别场次独占分支只列出；混合分支、无任务标记副本和缺验收仍计入")
def scoped_check(root):
    other_task = "task\n\nRoadstar-Task: docs/roadstar/别的场次/T9"
    git(root, "checkout", "-qb", "other")
    commit(root, other_task)
    git(root, "checkout", "-q", "main")
    write(root, plan + "/rounds/exec-T1.md")
    write(root, plan + "/rounds/check-T1.md", "验收通过\n")
    args = ("--plan-dir", plan)

    p = call(root, "--check", *args)
    scoped = report(root, *args, expected=0)
    assert scoped["clean"] and scoped["items"] == [], scoped
    assert [(i["kind"], i["task"]) for i in scoped["others"]] == [("unmerged_task", "T9")], scoped
    assert p.stdout.splitlines() == [
        "收工检查：都收完了", "别的场次的（不计入）：", scoped["others"][0]["detail"]
    ], p.stdout
    unscoped = report(root)
    assert unscoped == {"clean": False, "items": scoped["others"]}, unscoped

    write(root, plan + "/rounds/exec-T3.md")
    p = call(root, "--check", *args, expected=1)
    assert "没验收：T3" in p.stdout and "别的场次的（不计入）：" in p.stdout, p.stdout
    write(root, plan + "/rounds/check-T3.md", "验收通过\n")

    local = lane(root, "local")
    commit(local, "task\n\nRoadstar-Task: " + str(root / plan / "../测试场次/T2"))
    scoped = report(root, *args)
    assert [(i["kind"], i.get("task")) for i in scoped["items"]] == [
        ("unmerged", None), ("unmerged_task", "T2")
    ], scoped
    commit(local, other_task)
    scoped = report(root, *args)
    assert {i["task"] for i in scoped["items"] if i["kind"] == "unmerged_task"} == {"T2", "T9"}, scoped
    assert [(i["branch"], i["task"]) for i in scoped["others"]] == [("other", "T9")], scoped

    git(root, "worktree", "add", "-q", root.parent / "other copy", "other")
    lane(root, "unmarked")
    scoped = report(root, *args)
    assert {i["branch"] for i in scoped["items"] if i["kind"] == "unmerged"} == {"local", "unmarked"}, scoped
    assert [(i["kind"], i["branch"]) for i in scoped["others"]] == [
        ("unmerged", "other"), ("unmerged_task", "other")
    ], scoped


failed = count = 0
for number, description, fn in tests:
    directory = None
    try:
        directory = Path(subprocess.check_output(["mktemp", "-d", str(Path(os.environ.get("TMPDIR", "/tmp")) / "roadstar-close-check.XXXXXX")], text=True).strip())
        # Git reports canonical worktree paths (macOS /var -> /private/var).
        root = directory.resolve() / "项目 repo"
        root.mkdir()
        git(root, "init", "-q", "--template=")
        git(root, "symbolic-ref", "HEAD", "refs/heads/main")
        git(root, "config", "user.name", "Close Check Test")
        git(root, "config", "user.email", "close-check@example.invalid")
        write(root, "tracked")
        git(root, "add", ".")
        commit(root, "initial")
        fn(root)
        status, evidence = "pass", description
    except Exception as exc:
        status, evidence = "fail", description + "；" + str(exc).replace("\n", " ")
        failed += 1
    finally:
        if directory is not None:
            shutil.rmtree(directory)
    count += 1
    print(status.upper() + " " + number + " " + evidence, flush=True)
    if progress:
        with Path(progress).open("a", encoding="utf-8") as f:
            f.write(datetime.datetime.now(datetime.timezone.utc).isoformat() + "\t" + number + "\t" + status + "\t" + evidence + "\n")
print("FAIL " + str(failed) + "/" + str(count) if failed else "PASS " + str(count))
sys.exit(1 if failed else 0)
PY
