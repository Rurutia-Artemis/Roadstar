# T2 · dex-exec.sh：写活必带时间上限、空交回给信号、加 --wait
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：空项目模拟跑里 `dex-exec.sh --write` 不带 `--max-minutes` 照派（「时间上限：无」）；Codex 只回一句话时，`exec-T<n>.md` 很短或不存在，退出码仍是 0，被当成交回；等 Codex 要手写循环。类别：补全，只动「任务执行与验收」一个模块。
完成线：
- C1 `--write`（含 `--resume`、`--dry-run`）没有 `--max-minutes` 时，在参数解析后、`dex-exec.sh:230`（`缺 --model` 检查）之前退出 2，提示写明「写活必须带 --max-minutes（常规 120、难活 240、窄回归 60）」。`--status`（第 205 行起，先于这处）、只读派活不受影响。
- C2 `run_job`（第 84–129 行）里 `finalize_report` 之后：分两档（写活的最终回答可以很短，报告在文件里，所以短不等于空）：`exec-T<n>.md`（`$OUT`）不存在或 0 字节，在 `write_meta`（第 36 行起）写 `handback=empty`，屏幕打一行以「警告：」开头的话（带 `$OUT` 和 `$LOG`），并且原退出码为 0 时改用退出码 4（写进 `.exit`，`--status` 能看到），原来就非 0（含 124）的保持原码；大于 0 而小于 200 字节，写 `handback=short`，同样打一行警告（写明字节数），退出码不变。两档之外不写 `handback` 这一行，别的 meta 字节不变。`--status` 和 `--wait` 的输出里要能看到 `handback` 这一行。`show_failure`（第 66 行）对 4 不要说「codex 退出码 4」，改成说交回为空。
- C3 `--wait`：前台执行，结束后打印一行 `exit：<.exit 内容>` 和 `$OUT` 最后 5 行（`$OUT` 不存在就打一行说明），退出码同 `.exit`。与 `--detach`、`--status`、`--dry-run` 同用退出 2。不加 `--wait` 时输出与退出行为和现在一致。
- C4 用例写进新文件 `skill/scripts/tests/exec-handback-tests.sh`（风格同 `entry-tests.sh`，用 `tests/bin/codex` 桩，不真调 Codex，结尾 `PASS <n> checks`），覆盖：缺上限被拒且没有任何产物；带上限放行；回复文件不存在或 0 字节 → 退出 4、meta 有 `handback=empty`、屏幕有警告；回复 1 到 199 字节（桩用 `FAKE_CODEX_REPLY` 设短回复）→ 退出码仍是 0、meta 有 `handback=short`、屏幕有警告；回复足够长 → 退出 0 且 meta 无 `handback`；`FAKE_CODEX_EXIT=3` 仍退出 3；超时仍 124；`--wait` 输出末 5 行与退出码；`--wait --detach` 退出 2；`--detach` 的空交回 `.exit` 为 4。`run.sh` 只在 `bash "$TEST_DIR/entry-tests.sh"`（第 1468 行）下面加一行 `bash "$TEST_DIR/exec-handback-tests.sh"`。
- C5 现有用例的调用被新检查波及的，只改调用（给 `--write` 的 dex-exec 调用补 `--max-minutes N`，把过短的 `FAKE_CODEX_REPLY` 换成不少于 200 字节），断言一字不改；已知有 `brief-tests.sh:432、437、451`、`guard-tests.sh:638` 附近、`run.sh:334`（`only reply`）。每处在报告里列「改前改后」。
- C6 修完用一条 grep 列出同一种写法：`grep -rn "max-minutes" skill/scripts/*.sh skill/references/*.md docs/模块地图.md | grep -v v1.14`，报告里逐处说明要不要跟着改文字（只改 `docs/模块地图.md` 第 123 行「规矩」一句的措辞到与行为一致，并在第 128 行后追加一行说明 `--wait`、`handback=empty`、退出码 4；别处文字不动）。头部用法注释和 `--help`（第 188 行 `sed -n '2,14p'`）同步加上新选项，行号范围随之调整。

## 涉及模块
任务执行与验收

## 不许动什么
只许改 `skill/scripts/dex-exec.sh`、`skill/scripts/tests/exec-handback-tests.sh`（新）、`skill/scripts/tests/run.sh`（只加那一行）、C5 列出的用例调用、`docs/模块地图.md`（只动 C6 说的两处）。不动 `guard.py`、别的脚本、`CHANGELOG.md`（报告里给一句话，调度方并入）、铁律文件、`~/.claude` 下任何东西、各项目钩子；不推送。不放宽任何现有检查；「旧用例不改」的例外只有 C5：旧用例与新检查直接冲突时只改调用参数，拿不准单列交回。

## 执行环境
克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG2/repo`，分支 `roadstar/sim-gaps-t2`，基线 Roadstar 主干 HEAD `a262e16`。离线，用 `tests/bin/codex` 桩，不起服务。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh; echo rc=$?`：`rc=0`。基线（a262e16，11-17）：退出 0，各套件 PASS 88 checks、20 checks、95 checks、50、13、36 checks、41 checks、8 checks、18 checks，无失败用例；新增后应多出 `exec-handback-tests.sh` 一段 PASS，原有各段 PASS 数不变。
- `bash skill/scripts/tests/exec-handback-tests.sh; echo rc=$?`：末行 `PASS <n> checks`，`rc=0`。
- 手验：`bash skill/scripts/dex-exec.sh <场次> T1 --model m --effort high --brief <任务书> --write --dry-run; echo $?` 输出 2；加 `--max-minutes 5` 后输出 0。
- `git diff --stat`：只出现「不许动什么」里允许的文件。

## 资源上限与止损
预计 30 分钟，上限 60 分钟。每试一次检查项往 `rounds/exec-T2.progress` 追加一行「时间 TAB 检查项 TAB pass 或 fail TAB 证据」；同一项连败三次或到上限就停，交报告写卡在哪。只用本节命令验证。

## 交付物
克隆根 `RSG2-report.md`：改了哪些文件；跑了哪些验证及输出；C5 改前改后；C6 grep 输出；给 CHANGELOG 的一句话；没做成的。末行 `完成状态：全部完成` 或 `完成状态：未全部完成`。

## 收尾
只删任务临时目录下以 `RSG2-` 开头的自己建的目录；不提交、不推送，由调度方做。
