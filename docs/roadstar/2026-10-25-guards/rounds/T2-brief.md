# T2 · 提交和合并时自动卡住：改动出了任务书写的模块、改了入口没改地图、没验收就合并

## 目标与做完的样子

目标：Roadstar 带一个 `guard.py` 和安装脚本 `install-guard.sh`。装进某个项目后，凡是 Roadstar 派活产生的提交，在 git 提交和合并时自动检查三件事，不过就拦下并说清怎么办：

1. 改动的文件必须在任务书「涉及模块」写的那几块里（按项目的 `docs/模块地图.md`「模块一览」表的「目录」一栏判断）。
2. 改了某个模块「入口」列出的文件，同一个提交里必须也改 `docs/模块地图.md`，或者在提交说明里写明不用改的理由。
3. 把带任务号的提交合进来之前，那件活必须有验收记录 `<场次目录>/rounds/check-T<n>.md`（非空）。

另给 Claude Code 一个 PreToolUse 入口，主会话敲 `git merge` 时就先拦一次。

完成线（全部写成 `skill/scripts/tests/guard-tests.sh` 里的用例，每条在 `mktemp -d` 新建的临时 git 仓库里跑）：

- C1 `guard.py mark <场次目录> T<n>` 在当前工作区的 git 目录（`git rev-parse --git-dir`，所以每个 worktree 各有一份）写 `roadstar-task`（JSON：`plan_dir` 相对仓库顶层的路径、`task`、`branch` 当前分支名、`time`）；`guard.py unmark` 删掉它。当前分支和标记里的 `branch` 不同时，标记视为不存在。
- C2 prepare-commit-msg：有有效标记时，给提交说明加一行 trailer `Roadstar-Task: <plan_dir>/T<n>`（用 `git interpret-trailers`，已有同值不重复加）；没有标记什么都不做。
- C3 commit-msg 范围检查：说明里有 `Roadstar-Task` 时，读 `<plan_dir>/rounds/exec-T<n>-request.md` 的「## 涉及模块」一节，按模块名去地图「模块一览」表找「目录」一栏（反引号里的路径，逗号或顿号分隔；以 `/` 结尾或是现有目录的按目录前缀匹配，否则按文件精确匹配；支持 `*` 通配）。暂存区里不在这些路径、也不在固定放行名单（`docs/模块地图.md`、`docs/MODULES.md`、`docs/roadstar/`、`CHANGELOG.md`、`CHANGELOG*`）里的文件 → 退出码 1，逐个列出文件和它实际属于哪个模块（找不到写「地图里没有」），并写两种解决办法：改任务书的涉及模块后重提，或在说明里加 `Roadstar-Scope: <为什么要超出范围>`（加了就放行，并在输出里打印一行「越界已放行：<理由>」）。
- C4 任务书「涉及模块」写「无地图」或项目没有 `docs/模块地图.md` 时：范围检查跳过，打印一行「这个项目没有模块地图，范围检查跳过」，退出码 0。任务书文件找不到时：退出码 1，报出期望的路径。
- C5 commit-msg 地图检查：暂存区改了地图里任何模块「## <模块名>」一节「- 入口：」列出的文件，而暂存区没有 `docs/模块地图.md`，说明里也没有 `Roadstar-Map: <不用改的理由>` → 退出码 1，列出是哪个模块的哪个入口文件。这条检查对没有 `Roadstar-Task` 的提交也生效（只要项目有地图）。
- C6 没有 `Roadstar-Task` 的提交只做 C5，其余放行。
- C7 pre-merge-commit：取 `git log HEAD..MERGE_HEAD` 里所有 `Roadstar-Task` trailer，逐个要求主工作区（`git rev-parse --path-format=absolute --git-common-dir` 的上一级）下的 `<plan_dir>/rounds/check-T<n>.md` 存在且非空；缺的 → 退出码 1，列出缺哪几件、各自该写在哪个路径。没有 trailer 的合并放行。
- C8 `guard.py claude-pretool`：从标准输入读 Claude Code 的 PreToolUse JSON（字段 `tool_name`、`tool_input.command`）。`tool_name` 是 `Bash` 且命令里有 `git merge <分支>`（排除 `--abort`、`--continue`、`--quit`）时：对 `HEAD..<分支>` 做 C7 同样的检查；分支里有 `Roadstar-Task` 提交而命令没带 `--no-ff` 时也拦（git 的快进合并不触发 pre-merge-commit）。拦下就退出码 2、原因写到 stderr（Claude Code 的约定：退出码 2 表示拦下，stderr 会转给模型看）；放行退出码 0、不输出。JSON 解析失败或不是 Bash 一律退出码 0。
- C9 `install-guard.sh <项目根> [--uninstall] [--claude]`：在该仓库的 hooks 目录（`git rev-parse --git-common-dir`/hooks；若设置了 `core.hooksPath` 就不动，打印要手动加的三行）写三个小外壳 `prepare-commit-msg`、`commit-msg`、`pre-merge-commit`，用绝对路径调本仓库的 `guard.py`。已有别人的同名钩子时改名为 `<名字>.local`，我们的外壳先跑它、它不过就不往下跑。重复安装结果不变（幂等）；`--uninstall` 删掉外壳并把 `.local` 改回原名。`--claude` 时把 PreToolUse（matcher `Bash`，command 指向 `guard.py claude-pretool` 的绝对路径）合并进 `<项目根>/.claude/settings.local.json`，保留文件里原有的其他内容，重复执行不重复添加。
- C10 `dex-exec.sh` 带 `--write` 且不是 `--dry-run` 时，派活前在 `--root` 那个工作区里跑 `guard.py mark <plan-dir> <T#>`；`--root` 不是 git 仓库或 mark 失败只打印一行警告，不影响派活。
- C11 所有拦下的提示都是中文大白话，第一行说「拦下了：<一句原因>」，后面列文件和怎么办，没有 Python 堆栈。
- C12 环境变量 `ROADSTAR_GUARD=off` 时三种钩子和 claude-pretool 全部直接放行，并打印一行「已关闭检查（ROADSTAR_GUARD=off）」（claude-pretool 不打印）。

达不到不算完成，如实报差多少。

## 背景

主席 10-22 实查：RUVO 57 份任务书只有 21 份写了涉及模块、验收记录 0 份；Mia 141 份任务书验收记录 4 份。规矩只写在 skill 文字里，没人报警就会漏。所以要把能用程序判断的规矩做成 git 钩子和 Claude Code 钩子。总纲在 `/Users/rurutia/Documents/RuruCode/RuruAgent/docs/工作流重构/README.md`，可以读。地图格式规格在 `skill/references/project-map.md`；任务书格式在 `skill/references/task-brief-template.md`；验收记录约定（`rounds/check-T<n>.md`）在 `skill/references/division-of-labor.md`。Roadstar 派给 Codex 的活约定「不提交，由 Argo 合并」，所以真正触发钩子的是 Argo（Claude 主会话）在那个工作区里提交和合并，标记要能在 Codex 跑完之后还留着，直到分支切走。

Claude 主会话同时在改 `skill/SKILL.md` 和 `skill/references/`，并会另派一件「收工检查」（改 `cleanup.py`）排在你之后，那些你都不碰。

## 涉及模块

Roadstar 模块地图（`docs/模块地图.md`）里的「任务执行与验收」。新增 `guard.py`、`install-guard.sh` 是这一块的新入口和新接口，同一次交付里更新地图那一节（入口、对外接口、怎么测三行）和「模块一览」表那一行的目录栏。

## 接口签名与文件范围

- 新建 `skill/scripts/guard.py`（只用 Python 标准库，`#!/usr/bin/env python3`）：
  - `guard.py mark <plan-dir> T<n>`、`guard.py unmark`
  - `guard.py hook prepare-commit-msg <消息文件> [来源] [sha]`
  - `guard.py hook commit-msg <消息文件>`
  - `guard.py hook pre-merge-commit`
  - `guard.py claude-pretool`（读标准输入）
  - `guard.py check-merge <分支>`（C7/C8 共用的检查，单独可调，退出码 0 / 1）
- 新建 `skill/scripts/install-guard.sh <项目根> [--uninstall] [--claude]`（bash，兼容 macOS 自带 /bin/bash 3.2）。
- 改 `skill/scripts/dex-exec.sh`：只加 C10 那一段，别的不动。
- 新建 `skill/scripts/tests/guard-tests.sh`：输出格式 `PASS <编号> <一句>` / `FAIL …`，最后一行 `PASS <总数>` 或 `FAIL <失败数>/<总数>`（退出码 1）。
- 在 `skill/scripts/tests/run.sh` 末尾加一行调用 `guard-tests.sh`（`run.sh` 第 1139 行有一个既有失败，与你无关，不修、不挪）。
- 改 `docs/模块地图.md`：按「涉及模块」那条更新。

## 项目常驻边界

无 `docs/roadstar/_common.md`；本仓库 `CLAUDE.md` 的两条照守：脚本只用标准库和 bash；`codex exec` 一律显式带 `-s`、`-m`、`-c model_reasoning_effort=`、`--disable fast_mode`（本件不需要调 codex）。

## 不许动什么

`skill/SKILL.md`、`skill/references/`、`skill/scripts/cleanup.py`、`README*`、`CHANGELOG.md`、仓库外任何文件。任何真实项目（Huemo、RUVO、Mia 等）都不装、不碰，测试只用临时仓库。范围外一律不动。

## 执行环境

不联网、不起服务、不开浏览器。workspace-write 沙箱够用：临时 git 仓库全建在 `mktemp -d` 下，测试里 `git config user.name/user.email` 只设在临时仓库本地，不碰全局 git 配置。测试 shell 禁历史写入（`unset HISTFILE`）。

## 验收命令与期望输出

在 `/Users/rurutia/Documents/RuruCode/Roadstar` 下：

1. `python3 -m py_compile skill/scripts/guard.py && bash -n skill/scripts/install-guard.sh && bash -n skill/scripts/dex-exec.sh` → 退出码 0。
2. `bash skill/scripts/tests/guard-tests.sh` → 最后一行 `PASS <n>`，n ≥ 20，退出码 0。
3. `/bin/bash skill/scripts/tests/guard-tests.sh` → 同上。
4. `bash skill/scripts/dex-exec.sh /tmp/x T9 --model m --effort low --brief /dev/null --write --dry-run` → 和改之前一样只打印将要执行的命令，不写任何标记。
5. `echo '{"tool_name":"Read","tool_input":{}}' | python3 skill/scripts/guard.py claude-pretool; echo $?` → 只输出 `0`。

## 资源上限与止损

预计 60 分钟，上限 120 分钟。每试一次某个检查项，就往 `/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 追加一行「ISO 时间 制表符 检查项编号 制表符 pass 或 fail 制表符 一句证据」。同一检查项连续三次失败、或到上限，就停下交报告，写清哪些项过了、卡在哪一项、试过什么。验证方式只用上面的命令。

## 交付物

最后回复只列三样：改了哪些文件；跑了哪些验证命令及输出（最后几行原文）；没做成的和原因。另附一段「我做了哪些设计取舍」，不超过五条（例如路径匹配怎么处理中文顿号分隔、找不到模块名时怎么报）。

## 收尾

删掉自己建的临时仓库。

## 不提交

不提交 git，不推送，由 Argo 合并。
