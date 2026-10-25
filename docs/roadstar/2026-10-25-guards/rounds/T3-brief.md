# T3 · 收工检查：还有没合并的、没清的、没验收的，就不算收工

## 目标与做完的样子

目标：`skill/scripts/cleanup.py` 加一个 `--check` 模式。Roadstar 完工报告前跑它：还有没合并的任务分支或工作副本、已合并却没清的工作副本、有执行回复却没有验收记录的活，就逐条列出、退出码 1；都收完了退出码 0。它只查不删。

完成线（全部写成 `skill/scripts/tests/close-check-tests.sh` 里的用例，每条在 `mktemp -d` 新建的临时 git 仓库里跑）：

- C1 用法：`python3 skill/scripts/cleanup.py --check [--project 根] [--plan-dir 场次]… [--base 分支] [--json]`。`--check` 和 `--apply` 同时给 → 退出码 2，报「--check 只查不删，不能和 --apply 一起用」，什么都不动。
- C2 没合并：除主工作区外，每个工作副本的分支没合进 `--base`（默认沿用 cleanup.py 现有的基准分支判断）→ 列「没合并：工作副本 <路径>（分支 <名>，领先 <N> 个提交）」。被 `git worktree lock` 锁住的槽位不算没清，但它的分支没合并照样列。
- C3 没合并的任务提交：本地任何分支上，没合进基准分支、且提交说明带 `Roadstar-Task: <场次>/T<n>` trailer 的提交，按任务汇总列「没合并：T<n>（<场次>）在分支 <名> 上，<N> 个提交」。（这个 trailer 由同场的 guard.py 自动加，本件只读它。）
- C4 没清：已合并、干净、没锁的工作副本 → 列「已合并没清：<路径>」（判断规则和 cleanup.py 现有 dry-run 一致，可直接复用）。
- C5 没验收：每个 `--plan-dir` 下，`rounds/exec-T<n>.md` 存在而 `rounds/check-T<n>.md` 不存在或为空 → 列「没验收：T<n>（<场次>）」。没给 `--plan-dir` 时这一项跳过，并打印一行「没给场次目录，验收记录这项没查」。
- C6 输出：第一行「收工检查：都收完了」或「收工检查：还有 <N> 项没收完」；后面按「没合并 / 已合并没清 / 没验收」分组，每条一行，中文大白话，没有 Python 堆栈。`--json` 输出 `{"clean": bool, "items": [{"kind": "unmerged|unmerged_task|merged_not_cleaned|no_acceptance", "detail": "...", ...}]}`。
- C7 `--check` 模式下不删除、不移动、不改任何文件和 git 状态（测试里对比运行前后 `git worktree list --porcelain`、`git branch -a`、目录列表一致）。
- C8 现有 dry-run 和 `--apply` 的行为不变：现有测试照过（`run.sh` 第 1139 行有一个与本件无关的既有失败，不修）。

达不到不算完成，如实报差多少。

## 背景

主席 10-22 实查：RUVO 有 40 个没合并的分支、16 个工作副本，多停在 10-11 到 10-13，验收记录 0 份。Roadstar 现在完工时跑 `cleanup.py` 只会列出来、不拦。这次要求：没收完就不报「做完了」。SKILL.md §10 由 Claude 主会话改，会写成「跑 `cleanup.py --check`，退出码 1 就不报做完了，在报告第一行列出没收完的」。

同场 T2 刚做完 `guard.py`（提交时自动加 `Roadstar-Task` trailer、合并前查验收记录），trailer 格式见 `skill/scripts/guard.py`，读一下保持一致。验收记录约定见 `skill/references/division-of-labor.md`（`rounds/check-T<n>.md`）。

## 涉及模块

Roadstar 模块地图（`docs/模块地图.md`）的「任务执行与验收」。`--check` 是 cleanup.py 的新接口，同一次交付里更新地图那一节「对外接口」里 cleanup.py 那句和「怎么测」。

## 接口签名与文件范围

- 改 `skill/scripts/cleanup.py`：加 `--check`，见完成线。只用 Python 标准库。
- 新建 `skill/scripts/tests/close-check-tests.sh`：输出 `PASS <编号> <一句>` / `FAIL …`，最后一行 `PASS <总数>` 或 `FAIL <失败数>/<总数>`（退出码 1）。
- 在 `skill/scripts/tests/run.sh` 末尾加一行调用它（紧跟 T2 加的 guard-tests 那一行之后）。
- 改 `docs/模块地图.md`：按「涉及模块」那条。

## 项目常驻边界

无 `docs/roadstar/_common.md`；本仓库 `CLAUDE.md` 的规矩：脚本只用标准库和 bash。

## 不许动什么

`skill/SKILL.md`、`skill/references/`、`skill/scripts/guard.py`、`skill/scripts/install-guard.sh`、`skill/scripts/dex-exec.sh`、`README*`、`CHANGELOG.md`、仓库外任何文件。真实项目一律不碰，测试只用临时仓库。范围外一律不动。

## 执行环境

不联网、不起服务、不开浏览器。workspace-write 沙箱够用；临时仓库建在 `mktemp -d` 下，`git config user.name/user.email` 只设在临时仓库本地。测试 shell 禁历史写入（`unset HISTFILE`）。

## 验收命令与期望输出

在 `/Users/rurutia/Documents/RuruCode/Roadstar` 下：

1. `python3 -m py_compile skill/scripts/cleanup.py` → 退出码 0。
2. `bash skill/scripts/tests/close-check-tests.sh` → 最后一行 `PASS <n>`，n ≥ 8，退出码 0。
3. `/bin/bash skill/scripts/tests/close-check-tests.sh` → 同上。
4. `bash skill/scripts/tests/guard-tests.sh` → 仍然最后一行 `PASS <n>`（T2 的测试不被你弄坏）。
5. `python3 skill/scripts/cleanup.py --project . --check --apply; echo $?` → 报错那一句，然后 `2`。

## 资源上限与止损

预计 30 分钟，上限 60 分钟。每试一次某个检查项，就往 `/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-10-25-guards/rounds/exec-T3.progress` 追加一行「ISO 时间 制表符 检查项编号 制表符 pass 或 fail 制表符 一句证据」。同一检查项连续三次失败、或到上限，就停下交报告。验证方式只用上面的命令。

## 交付物

最后回复只列三样：改了哪些文件；跑了哪些验证命令及输出（最后几行原文）；没做成的和原因。

## 收尾

删掉自己建的临时仓库。

## 不提交

不提交 git，不推送，由 Argo 合并。
