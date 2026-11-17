# T3 执行报告

## 改动范围

工作区：`/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG3/repo`。分支 `roadstar/sim-gaps-t3`，起点 `a262e16`；开工时工作树干净。已读取设计页和模块地图，按 T3 任务书执行，未提交、未推送。

| 文件 | 本次改动 |
|---|---|
| `skill/scripts/guard.py` | 共用任务标记读取；prepare 对旧格式、分支不符、detached HEAD 提示且放行；两个合并入口对不匹配标记提示；合并 commit-msg 清除匹配标记；普通代码提交缺 trailer 时警告 |
| `skill/scripts/tests/marker-branch-tests.sh` | 新增 36 项检查，临时仓库、独立 Git/配置环境、`call` 调 guard、真实安装钩子及合并，EXIT trap 清理 |
| `skill/scripts/tests/run.sh` | 只在原末行 trailer-path-tests 调用下新增 marker-branch-tests 调用 |
| `docs/模块地图.md` | 只扩充第 117 行 mark 接口括号中的提示、作废、警告说明 |

交付记录另存本文件和 `rounds/exec-T3.progress`。没有改 `CHANGELOG.md`、现有测试、guard_rules、其他脚本或实际项目钩子，没有运行安装全局 skill 的 `install.sh`。

地图原句：`（每个 worktree 独立、绑定当前分支的任务标记）`。

地图新句：`（每个 worktree 独立、绑定当前分支的任务标记；旧格式、分支不符或 detached HEAD 时提示并跳过 trailer，合并目标不符也提示；匹配目标的标记在合并提交时作废；无 Roadstar-Task trailer 的代码提交仅警告）`。

## 实现与覆盖

- C1：mark 保持 `plan_dir / task / branch / time` 原四键。prepare 对得上时静默、重复执行不重复加 trailer；对不上时只输出一行 `提示：`，含任务号、标记分支（旧格式明确写“旧格式，没有分支”）、当前分支及 `guard.py mark <场次目录> T<n>`，退出 0，消息及标记原字节不动。覆盖新分支、旧格式、detached HEAD、旧格式加 detached HEAD、无标记。
- C2：`pre-merge-commit` 和 `check-merge` 统一把 `refs/heads/<标记分支>^{commit}` 与目标解析出的 commit SHA 比较。覆盖分支名、SHA、多个目标、旧格式、已删除分支、坏 JSON、无标记；不匹配只提示，不用标记生成验收任务列表，不改原有验收门槛。两个入口均验证缺验收仍退出 1，补齐后退出 0，标记始终不变。
- C3：自动合并的 commit-msg 阶段删除匹配标记；覆盖真实 `--no-ff` 分支名及 SHA 成功、无标记、旧格式及无关标记保留、pre-merge 拦截及 abort 保留、`--no-commit` 后 abort 保留与再次手动 commit 作废。测试包含实际代码文件，合并不出现缺 trailer 警告。
- C4：保留原有范围、地图、行数及设计检查；通过这些检查后，对无 Roadstar-Task 的暂存代码输出一行 `警告：`，不产生新拦截。覆盖 `guard_rules.CODE` 全部后缀、含空格/引号/换行的文件名、文档、已有 trailer、只在工作树的未暂存代码、混合提交、空暂存区，以及真实无标记/有标记代码提交。
- C5：新套件末行 `PASS 36 checks`，run.sh 只增加约定的一行。旧用例和断言均未改动。
- C6：下方列出指定 grep 的原始输出及每组读取的一致性说明。

已再检查一轮更好方案和漏项：合并比较统一按 SHA，避免分支名与 SHA 两种目标写法分叉；增加坏标记、被删分支、多目标和手动完成合并的覆盖，未扩大生产改动范围。

## 验证命令与实际结果

| 命令 / 阶段 | 实际结果 |
|---|---|
| 改 guard 前 `bash skill/scripts/tests/run.sh; echo rc=$?` | `rc=0`；原有各段 PASS 数与任务书基线一致 |
| 改 guard 前 `bash skill/scripts/tests/marker-branch-tests.sh; echo rc=$?`（当时只有钩子顺序探针） | `PASS 1 checks`，`rc=0` |
| 修改后 `bash skill/scripts/tests/marker-branch-tests.sh; echo rc=$?` | `PASS 36 checks`，`rc=0` |
| 修改后 `bash skill/scripts/tests/guard-tests.sh; echo rc=$?` | `PASS 50`，`rc=0` |
| 修改后 `bash skill/scripts/tests/run.sh; echo rc=$?` | 原九段 PASS 数不变，新增 `PASS 36 checks`；`rc=0` |
| `grep -n "roadstar-task\|\"branch\"" skill/scripts/*.py skill/scripts/*.sh` | 已执行，输出见下 |
| `git diff --stat` | 仅三个已跟踪的允许文件；新增测试未暂存，见下方说明 |

修改后全量实际汇总输出：

```text
PASS 88 checks
PASS 20 checks
PASS 95 checks
PASS 50
PASS 13
PASS 36 checks
PASS 41 checks
PASS 8 checks
PASS 18 checks
PASS 36 checks
rc=0
```

最后一段 36 项为本次新增套件；此前九段与改动前基线及任务书一致，没有失败用例。

首轮完整新增套件在前 35 项通过后，最后一项因新断言要求 stderr 完全为空而失败；实际输出是已有的“这个项目没有模块地图，范围检查跳过”。只修改新测试：从 `p.stderr == ''` 改为精确断言该既有输出，并独立检查标记不变；复跑 36 项全过。没有修改任何旧用例，也没有为此改生产代码。

全量回归曾尝试以自建临时日志包装启动，执行审查拒绝其中的 rm 清理命令，因此那次未运行测试、未创建临时日志目录；改用直接运行验收命令。此启动失败及所有实际测试结果已追加到 `rounds/exec-T3.progress`。

## 钩子顺序实测

先在改动 guard 之前，通过新测试文件创建临时仓库、运行 `install-guard.sh`，使用 `.local` 记录安装器调用 guard 前的现场，再执行真实 `git merge --no-ff --no-edit topic`。测试的 `post-merge` 只记录提交完成后的状态。

| 阶段 | MERGE_HEAD | 改动前标记 | 改动后标记 |
|---|---|---|---|
| pre-merge-commit.local | absent | present | present |
| prepare-commit-msg.local | present | present | present |
| commit-msg.local（guard 之前） | present | present | present |
| post-merge | present | present | absent |

四步的 `GIT_REFLOG_ACTION` 都是 `merge topic`。因此 pre-merge 阶段沿用原有 action 解析目标；prepare 和 commit-msg 阶段已有 MERGE_HEAD。删除放在 commit_message 的合并 return 之前，晚于验收门槛和原 commit-msg.local。真实合并后 HEAD 有两个父提交。缺验收被 pre-merge 拦下时 HEAD 未变、标记原样保留，执行 `git merge --abort` 后仍原样保留。

## C6 grep 原始输出

```text
skill/scripts/cleanup.py:92:        elif key == "branch":
skill/scripts/cleanup.py:93:            current["branch"] = value.replace("refs/heads/", "")
skill/scripts/cleanup.py:110:    if item.get("detached") or not item.get("branch"):
skill/scripts/cleanup.py:114:        return {"path": path, "branch": item.get("branch"), "action": "skip", "reasons": reasons, "bytes": 0}
skill/scripts/cleanup.py:120:    branch = item.get("branch")
skill/scripts/cleanup.py:131:    result = {"path": path, "branch": branch, "action": "skip" if reasons else "remove", "reasons": reasons, "bytes": size}
skill/scripts/cleanup.py:223:    if item.get("branch"):
skill/scripts/cleanup.py:224:        git(["branch", "-D", item["branch"]], project)
skill/scripts/cleanup.py:246:        path, branch = item.get("path"), item.get("branch")
skill/scripts/cleanup.py:253:                unmerged.append({"kind": "unmerged", "path": path, "branch": branch, "commits": count,
skill/scripts/cleanup.py:260:            uncleared.append({"kind": "merged_not_cleaned", "path": path, "branch": branch,
skill/scripts/cleanup.py:279:                          "branch": branch, "commits": count,
skill/scripts/guard.py:175:             "branch": git(root, "symbolic-ref", "--quiet", "--short", "HEAD").strip(),
skill/scripts/guard.py:177:    destination = git_dir(root) / "roadstar-task"
skill/scripts/guard.py:178:    temporary = destination.with_name("roadstar-task.tmp-" + str(os.getpid()))
skill/scripts/guard.py:187:    path = git_dir(root) / "roadstar-task"
skill/scripts/guard.py:208:    branch = value.get("branch")
skill/scripts/guard.py:227:        if not branch or value.get("branch") != branch.strip():
skill/scripts/guard.py:237:        raise Block("任务标记读不懂", "文件：" + str(git_dir(root) / "roadstar-task"),
skill/scripts/guard.py:286:            (git_dir(root) / "roadstar-task").unlink(missing_ok=True)
skill/scripts/guard.py:296:    for value in dict.fromkeys(values.get("roadstar-task", [])):
skill/scripts/guard.py:336:    if not values.get("roadstar-task") and any(Path(name).suffix in guard_rules.CODE for name in changed):
skill/scripts/guard.py:351:            tasks.extend(trailers(root, message).get("roadstar-task", []))
skill/scripts/guard.py:513:            (git_dir(root) / "roadstar-task").unlink(missing_ok=True)
```

一致性结论：

- `guard.py:175,177–178`：原 mark 写入当前分支与同 worktree 的 Git 目录，原四键及原子写入均未改。
- `guard.py:187`：唯一 JSON 标记读取入口 `task_marker()`；prepare、两个合并入口及合并提交作废均从这里读，路径统一为 `git_dir(root)/roadstar-task`，不误用 common Git 目录。
- `guard.py:208,227`：prepare 比较当前分支名，合并比较标记分支 ref 与目标的 SHA；适用阶段不同，但用同一份标记字段。无 branch 的旧格式在两者均视为不匹配。两个合并入口和作废逻辑共用 `merge_marker_matches()`，没有两套合并归属判法。
- `guard.py:237`：仅错误消息中的文件路径，无另一处读取。
- `guard.py:286,513`：前者匹配本次合并才删除，后者是用户明确运行 unmark；路径均与 mark 和读取入口一致。
- `guard.py:296,336,351`：读取 git interpret-trailers 解析后的键，分别用于任务范围检查、缺 trailer 警告、待合并任务收集，不读取标记文件。验收任务列表仍来自提交历史 trailer。
- `cleanup.py` 全部命中：Git worktree porcelain 的 branch 字段和清理结果字段，不读取任务标记，本次未改。

## 差异范围

`git diff --stat` 输出：

```text
 ...250\241\345\235\227\345\234\260\345\233\276.md" |  2 +-
 skill/scripts/guard.py                             | 58 ++++++++++++++++++++--
 skill/scripts/tests/run.sh                         |  1 +
 3 files changed, 55 insertions(+), 6 deletions(-)
```

第一行是 Git 默认路径转义后的 `docs/模块地图.md`。未暂存的新文件不会出现在普通 `git diff --stat`，`git status --short` 另列 `skill/scripts/tests/marker-branch-tests.sh`；除四个允许文件外，仅有要求交付的本报告和进度文件。

## 给 CHANGELOG 的一句话

补全任务标记的分支不符、旧格式及 detached HEAD 提示，合并时核对标记归属并在匹配合并提交时作废，无任务 trailer 的代码提交仅警告；新增 36 项回归，保留原有验收门槛和标记格式。

## 收尾与未完成项

新增测试创建的 `RSG3-marker-tests.*` 临时目录均由 EXIT trap 清理（含首轮失败）；既有测试继续使用原有 trap 清理。未手动删除其他目录，未产生 App、构建产物、旧版本或备份，无需保留回退包。所有钩子安装和 Git 写入均在测试临时仓库；工作区只留源码/文档改动、本报告和进度记录。

未做成的：无。C1–C6 均已完成并按约定命令验证；现有检查及既有测试均保留。

完成状态：全部完成
