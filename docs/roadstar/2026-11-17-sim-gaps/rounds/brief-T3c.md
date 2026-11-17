# T3c · 标记那份的收尾：只把 run.sh 末尾那一段子套件调用改成读清单
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：T3b 你按止损条款停下是对的，那条止损是调度方写宽了。这次说清楚：只动 `skill/scripts/tests/run.sh` 末尾连续的那一段（现第 1466–1472 行，七行 `bash "$TEST_DIR/…-tests.sh"`）。第 29 行的 `bash "$TEST_DIR/brief-tests.sh"`、第 347、1359 行的 `source … --legacy`、第 1462、1463 行的 `source` 都留在原处，一个字不改，不进清单。
完成线：
- C1 第 1466–1472 行这七行改成读清单文件 `skill/scripts/tests/suites.list`：一行一个文件名，`#` 开头的行和空行跳过，按清单顺序逐个 `bash "$TEST_DIR/<名字>"`。清单内容就是这七个文件名，顺序和现在一样（`guard-tests.sh`、`close-check-tests.sh`、`entry-tests.sh`、`guard-rules-tests.sh`、`baseline-tests.sh`、`trailer-path-tests.sh`、`marker-branch-tests.sh`）。这段循环仍在第 1465 行 `printf 'PASS %d checks\n' "$COUNT"` 之后。
- C2 行为和现在一样严：任何一个子套件失败，`run.sh` 的退出码照旧非 0（先看现在这七行失败时是怎么让 `run.sh` 失败的，循环里保持同一种机制）；清单里列着却不存在的文件，报出文件名并退出非 0；清单文件本身不存在同样退出非 0。
- C3 `run.sh` 改完 `wc -l` 不超过 1471，不靠删空白行或把无关的行并在一起来凑。
- C4 `docs/模块地图.md` 第 32 行入口栏加上 `skill/scripts/tests/suites.list`（`marker-branch-tests.sh` 已经在工作区里加好了，别重复加）；「怎么测」那一节（第 122–128 行附近）补半句：末尾这一段的新套件登记进 `suites.list`，不往 `run.sh` 里加行。
- C5 `guard.py` 和 `marker-branch-tests.sh` 是 T3 做完的，不改。

## 涉及模块
任务执行与验收

## 不许动什么
只许改 `skill/scripts/tests/run.sh` 第 1466–1472 行这一段、新建 `skill/scripts/tests/suites.list`、`docs/模块地图.md` 上面说的两处。`run.sh` 的其他行、别的脚本和用例、`CHANGELOG.md`、铁律文件、`~/.claude` 下任何东西都不动；不推送。不放宽任何现有检查：不加 `Roadstar-Length`、`Roadstar-Scope` 这类放行行，不改 `.roadstar/guard.json`。

## 执行环境
克隆 /Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG3/repo，分支 roadstar/sim-gaps-t3，接着现在的工作区做（T3 的改动已经暂存，别丢、别重置）。提交由调度方做。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh; echo rc=$?`：rc=0，没有 FAIL，各段 PASS 数和 T3 交回时一样（原九段加 `PASS 36 checks`），各段出现的先后顺序也和改之前一样。
- `wc -l skill/scripts/tests/run.sh`：不超过 1471。
- 临时把 `suites.list` 里一个名字改成不存在的文件再跑 `run.sh`：退出非 0 且输出里有那个文件名；验完改回，再跑一次确认 rc=0。
- `git diff a262e16 -- skill/scripts/tests/run.sh`：只有末尾这一段有改动。
- `git status --porcelain`：只有 T3 原有的四个文件加 `suites.list`（和你的报告）。

## 资源上限与止损
预计 15 分钟，上限 30 分钟。同一条验收命令连修三次不过就停，交回写清卡在哪。只有一种情况停下交回：改成循环后，这七个套件里有哪个的 PASS 数或通过与否和改之前不一样，而你查不出原因。

## 交付物
- 报告写到克隆根 RSG3c-report.md：C1 到 C5 各一行，五条验收命令的输出末行，`run.sh` 改前改后的行数。
- 报告末行写 `完成状态：全部完成` 或 `完成状态：未全部完成`。
