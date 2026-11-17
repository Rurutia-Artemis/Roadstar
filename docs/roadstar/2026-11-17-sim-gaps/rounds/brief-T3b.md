# T3b · 标记那份的收尾：登记新套件不许让 run.sh 变长
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：T3 的改动做完了，提交时被长度检查拦下：`skill/scripts/tests/run.sh` 已经 1471 行，超过 800 行的文件不许再变长，登记新套件多出了一行。按规矩拆文件，不用放行行。
完成线：
- C1 `run.sh` 末尾连续调用子套件的那几行（第 1466–1472 行附近，`bash "$TEST_DIR/…-tests.sh"` 这种写法）改成读清单文件 `skill/scripts/tests/suites.list`：一行一个文件名，`#` 开头的行和空行跳过，按清单顺序逐个 `bash "$TEST_DIR/<名字>"`。原来这几行调用的套件一个不少、顺序不变地写进清单，末尾是 `marker-branch-tests.sh`。
- C2 行为和现在一样严：任何一个子套件失败，`run.sh` 的退出码照旧非 0；清单里列着却不存在的文件，报出文件名并退出非 0；清单文件本身不存在同样退出非 0。
- C3 `run.sh` 改完 `wc -l` 不超过 1471，不靠删空白行或把无关的行并在一起来凑。
- C4 `docs/模块地图.md` 第 32 行入口栏加上 `skill/scripts/tests/suites.list`（`marker-branch-tests.sh` 已经在工作区里加好了，别重复加）；「怎么测」那一节（第 122–128 行附近）补半句：新套件登记进 `suites.list`，不往 `run.sh` 里加行。
- C5 `guard.py` 和 `marker-branch-tests.sh` 是 T3 做完的，不改。

## 涉及模块
任务执行与验收

## 不许动什么
只许改 `skill/scripts/tests/run.sh` 末尾那几行、新建 `skill/scripts/tests/suites.list`、`docs/模块地图.md` 上面说的两处。不动别的脚本和用例、`CHANGELOG.md`、铁律文件、`~/.claude` 下任何东西；不推送。不放宽任何现有检查：不加 `Roadstar-Length`、`Roadstar-Scope` 这类放行行，不改 `.roadstar/guard.json`。

## 执行环境
克隆 /Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG3/repo，分支 roadstar/sim-gaps-t3，接着现在的工作区做（T3 的改动已经暂存，别丢、别重置）。提交由调度方做。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh; echo rc=$?`：rc=0，没有 FAIL，各段 PASS 数和 T3 交回时一样（原九段加 `PASS 36 checks`）。
- `wc -l skill/scripts/tests/run.sh`：不超过 1471。
- 临时把 `suites.list` 里一个名字改成不存在的文件再跑 `run.sh`：退出非 0 且输出里有那个文件名；验完改回，再跑一次确认 rc=0。
- `git status --porcelain`：只有 T3 原有的四个文件加 `suites.list`。

## 资源上限与止损
预计 15 分钟，上限 30 分钟。同一条验收命令连修三次不过就停，交回写清卡在哪。如果末尾那几行之外还有别处在调用子套件、搬进清单会改变执行顺序，停下交回。

## 交付物
- 报告写到克隆根 RSG3b-report.md：C1 到 C5 各一行，四条验收命令的输出末行，`run.sh` 改前改后的行数。
- 报告末行写 `完成状态：全部完成` 或 `完成状态：未全部完成`。
