# T3d 执行报告

基线：`roadstar/sim-gaps-t3`，HEAD `894c363`，开工时工作区干净。

- C1：guard.py 只新增两行：prepare 遇到标记分支不匹配时，若 merging(root) 为真直接返回，不再打印分支不符提示。非合并提交及两个合并检查入口均未改。
- C2：原有 36 项及所有断言原样保留，仅追加 4 项真实合并检查：分支名/SHA 两种目标的匹配合并全过程无“提示：”行且标记删除，无关分支标记仅出现一次“不属于这次合并”提示且标记保留。
- C3：已执行指定 grep，三个命中逐处说明见下表；本次应改而未改的项：无。
- C4：guard.py 改前 543 行，改后 545 行，均未超过 800 行；没有修改 run.sh、清单、地图或其他用例。

## 三条验收命令

| 命令 | 输出末行 |
|---|---|
| `bash skill/scripts/tests/marker-branch-tests.sh \| tail -1`（启用 pipefail） | `PASS 40 checks`，管道退出 0 |
| `bash skill/scripts/tests/run.sh; echo rc=$?` | `rc=0`，无 FAIL；前九段 PASS 数与顺序不变，末段 `PASS 40 checks` |
| `git status --porcelain` | `?? RSG3d-report.md`；仅两个允许文件和本报告 |

全量 PASS 顺序：`88 checks → 20 checks → 95 checks → 50 → 13 → 36 checks → 41 checks → 8 checks → 18 checks → 40 checks`。另以逐字节对照确认原有 36 项及运行器完全保留，仅在运行器前新增用例。

## 指定 grep 与逐处核对

命令：`grep -n "提示：\|警告：" skill/scripts/guard.py`。

```text
216:        print(f"提示：任务标记 {value.get('task', '未知任务')}（{value.get('branch', '旧格式，没有分支')}）"
230:            print(f"提示：任务标记 {value.get('task', '未知任务')} 的分支为"
339:        print("警告：这次代码提交没有 Roadstar-Task trailer；需要关联任务时请先运行 guard.py mark <场次目录> T<n>。",
```

| 行 | 一次匹配标记分支的正常 --no-ff 合并中是否输出 | 是否应该 / 无关标记的情形 |
|---|---|---|
| 216，合并标记归属提示 | 不输出，标记分支 SHA 与目标匹配 | 应保持静默；标记不属于合并时，由 pre-merge-commit 输出一次，check-merge 的原提示也保留 |
| 230，prepare 分支不符提示 | 不输出，新增 merging 判断提前返回 | 合并中不应输出；非合并分支不符仍按原逻辑输出一行 |
| 339，代码提交缺 trailer 警告 | 不输出，合并 commit_message 沿用原有提前 return | 合并中不应输出；非合并代码提交的原警告保持 |

已再复查一轮：仅抑制合并准备阶段的冗余输出，不改变 trailer、验收或标记删除逻辑；新增测试选用第三个无关分支标记，能够发现 prepare 与合并归属提示重复打印的问题。

临时测试仓库由原套件 EXIT trap 清理；未产生构建产物、旧版本或备份。未提交、未推送。

完成状态：全部完成
