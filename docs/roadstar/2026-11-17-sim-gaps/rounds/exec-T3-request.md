# T3 · guard.py：任务标记和分支对不上要提示，合并后作废，缺 trailer 的代码提交警告
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：`guard.py mark`（第 167–183 行）已把分支名写进 `.git/roadstar-task`；`prepare`（第 186–202 行）分支对不上时直接 `return`，没有任何提示，所以模拟跑里「在默认分支派活后新开分支」「旧标记留在分支上」都是静默没有 trailer。老格式（没有 `branch` 键）也是静默跳过。合并成功后标记不清。类别：补全，只动「任务执行与验收」一个模块。
完成线：
- C1 标记格式不改（已含 `branch`，不要重复加）。`prepare` 里标记没有 `branch` 键（老格式）、或与当前分支不同、或 HEAD 是 detached 时：仍不加 trailer、不拦、退出 0，并向 stderr 打一行以「提示：」开头的话，写明标记的任务号、标记里的分支（老格式写「旧格式，没有分支」）、当前分支，以及 `guard.py mark <场次目录> T<n>`。对得上的情形输出与现在一致（不多打字）。标记文件不被改动。
- C2 `hook pre-merge-commit`（第 475 行）和 `check-merge <分支>`（第 478 行）：标记存在，但标记的分支没有出现在被合并的目标里（用 `rev-parse` 比较 `refs/heads/<标记分支>` 与被合并的提交，分支名和 sha 两种写法都要对；老格式视为对不上）→ 打一行「提示：…不属于这次合并，不当作任务标记，需要时重新 mark」，不改退出码，也不改现有的验收记录检查。没有标记时无任何新输出。
- C3 合并成功后标记作废：钩子顺序先用 `git merge --no-ff` 在临时仓库里实测（装 `install-guard.sh`），在合并提交一定会完成的那一步（预期是 `commit_message` 第 246 行 `if merging(root): return` 之前）：标记的分支就是被合并的分支时删掉 `.git/roadstar-task`。pre-merge-commit 被拦、`git merge --abort` 之后标记必须还在。标记分支不在被合并目标里时不删。
- C4 `commit_message`（第 245 行起，非合并提交）：提交说明没有 `Roadstar-Task` 且暂存的文件里有后缀在 `guard_rules.CODE`（`guard_rules.py:17`）里的，向 stderr 打一行以「警告：」开头的话，不拦、退出码不变；只改文档、有 trailer、或合并提交都不打。
- C5 用例写进新文件 `skill/scripts/tests/marker-branch-tests.sh`（风格同 `guard-tests.sh`：mktemp 临时仓库、`call` 调 guard.py、结尾 `PASS <n> checks`），覆盖 C1–C4 各自的放行和打提示两面、老格式、detached HEAD、真实 `git merge --no-ff` 成功后标记消失、被拦后 abort 标记仍在。`run.sh` 只在 `bash "$TEST_DIR/trailer-path-tests.sh"`（第 1471 行，末行）下面加一行 `bash "$TEST_DIR/marker-branch-tests.sh"`。
- C6 修完用一条 grep 列出同一种写法：`grep -n "roadstar-task\|\"branch\"" skill/scripts/*.py skill/scripts/*.sh`，报告里说明每处读标记的地方是否一致；`docs/模块地图.md` 第 117 行「对外接口」里 `mark` 一句补上提示、作废、警告三点（只改这一处）。

## 涉及模块
任务执行与验收

## 不许动什么
只许改 `skill/scripts/guard.py`、`skill/scripts/tests/marker-branch-tests.sh`（新）、`skill/scripts/tests/run.sh`（只加那一行）、`docs/模块地图.md`（只动 C6 说的那一处）。不动 `guard_rules.py`、`dex-exec.sh`、别的脚本、`CHANGELOG.md`（报告里给一句话，调度方并入）、铁律文件、`~/.claude` 下任何东西、各项目钩子；不推送。不放宽任何现有检查。现有用例不改；若某条旧用例与 C1 的新提示直接冲突（比如断言 stderr 为空），只改那条的断言到「允许这一行提示」并在报告里列改前改后，拿不准单列交回。

## 执行环境
克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG3/repo`，分支 `roadstar/sim-gaps-t3`，基线 Roadstar 主干 HEAD `a262e16`。离线，临时仓库都放 `mktemp -d`，用例 `trap` 清掉。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh; echo rc=$?`：`rc=0`。基线（a262e16，11-17）：退出 0，各套件 PASS 88 checks、20 checks、95 checks、50、13、36 checks、41 checks、8 checks、18 checks，无失败用例；新增后多出 `marker-branch-tests.sh` 一段，原有各段 PASS 数不变。
- `bash skill/scripts/tests/marker-branch-tests.sh; echo rc=$?`：末行 `PASS <n> checks`，`rc=0`。
- `bash skill/scripts/tests/guard-tests.sh; echo rc=$?`：末行 `PASS 50`（基线同），`rc=0`。
- `git diff --stat`：只出现「不许动什么」里允许的文件。

## 资源上限与止损
预计 35 分钟，上限 70 分钟。每试一次检查项往 `rounds/exec-T3.progress` 追加一行「时间 TAB 检查项 TAB pass 或 fail TAB 证据」；同一项连败三次或到上限就停，交报告写卡在哪。只用本节命令验证。

## 交付物
克隆根 `RSG3-report.md`：改了哪些文件；跑了哪些验证及输出；钩子顺序实测结果；C6 grep 输出；给 CHANGELOG 的一句话；没做成的。末行 `完成状态：全部完成` 或 `完成状态：未全部完成`。

## 收尾
只删任务临时目录下以 `RSG3-` 开头的自己建的目录；不提交、不推送，由调度方做。
