# T3d · 合并成功时不再多打一行「分支对不上」的提示
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：T3 验收通过。验收时发现一处多余的输出：标记的分支被 `git merge --no-ff` 正常合并时，合并提交的说明准备阶段标记还没删、当前分支是主干，于是照「分支对不上」打了一行「提示：…当前分支为 main」。这次合并本来就是对的，这行提示会让人以为标记出了问题。
完成线：
- C1 `skill/scripts/guard.py`：正在合并时（`merging(root)` 为真），说明准备阶段（`prepare`）不打「分支对不上」的那行提示；非合并提交的行为不变（对不上照旧提示一行）。合并检查（`hook pre-merge-commit`、`check-merge`）里「标记分支不属于这次合并」的提示不变。
- C2 `skill/scripts/tests/marker-branch-tests.sh` 加用例：标记分支被 `git merge --no-ff` 成功合并时，整个合并过程的 stderr 里没有以「提示：」开头的行，合并后标记照旧被删；标记分支不在这次合并里时，「不属于这次合并」那行提示照旧出现，且只出现一次。原有 36 项一项不改。
- C3 修完用一条 grep 列出同一种写法：`grep -n "提示：\|警告：" skill/scripts/guard.py`，报告里逐处写它在一次正常的 `--no-ff` 合并过程中会不会被打出来、该不该；该改而这次没改的只列出来。
- C4 先 `wc -l skill/scripts/guard.py`：超过 800 行的话，改完不许比现在长（报告里写改前改后行数）。

## 涉及模块
任务执行与验收

## 不许动什么
只许改 `skill/scripts/guard.py` 和 `skill/scripts/tests/marker-branch-tests.sh`。`run.sh`、`suites.list`、别的脚本和用例、`docs/模块地图.md`、`CHANGELOG.md`、铁律文件、`~/.claude` 下任何东西都不动；不推送。不放宽任何现有检查，不删断言、不加 skip，不加放行行。

## 执行环境
克隆 /Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG3/repo，分支 roadstar/sim-gaps-t3（HEAD 是 894c363，工作区干净）。提交由调度方做。

## 验收命令与期望输出
- `bash skill/scripts/tests/marker-branch-tests.sh | tail -1`：`PASS <n> checks`，n 大于 36。
- `bash skill/scripts/tests/run.sh; echo rc=$?`：rc=0，没有 FAIL，前九段的 PASS 数不变。
- `git status --porcelain`：只有这两个文件（和你的报告）。

## 资源上限与止损
预计 10 分钟，上限 20 分钟。同一条验收命令连修三次不过就停，交回写清卡在哪。

## 交付物
- 报告写到克隆根 RSG3d-report.md：C1 到 C4 各一行，三条验收命令的输出末行。
- 报告末行写 `完成状态：全部完成` 或 `完成状态：未全部完成`。
