# T2b · dex-exec 交回检查的收尾：旧桩适配，新套件登记进清单
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：T2 的 C1 到 C4、C6 做完了，全量 `run.sh` 还挂 3 条（`guard-tests.sh` 的三条 C10）。原因是 `guard-tests.sh` 第 630 行附近那个嵌入的本地 codex 桩不处理 `-o`，不写最终回答文件，按新规矩成了空交回、退出 4。真的 codex 一定会写这个文件，所以该改的是桩。另外主干已经改成用清单文件登记子套件（`skill/scripts/tests/suites.list`），`run.sh` 是不许再变长的长文件。调度方已经把你的克隆接到最新主干上：T2 的改动有一笔进行中的提交，`run.sh` 里你原来加的那一行登记已撤掉，`exec-handback-tests.sh` 还没提交。
完成线：
- C1 只改 `guard-tests.sh` 里这个嵌入桩的桩体：让它像真的 codex 一样处理 `-o <路径>`，往那个路径写一段不少于 200 字节的固定回答（正常的句子，不用空白或重复字符凑字节）；它原来做的事（检查标记、写 `called`）一样不少。三条 C10 用例的断言一个字不改。
- C2 `exec-handback-tests.sh` 登记进 `skill/scripts/tests/suites.list`（加在末尾），`run.sh` 一行不加；`docs/模块地图.md` 第 32 行入口栏加上 `skill/scripts/tests/exec-handback-tests.sh`。
- C3 `run.sh` 里 `only reply` 那条用例保持原样（短回答只警告、退出码不变，这条正好留着覆盖这种情形）。
- C4 `dex-exec.sh` 里不许为测试路径或这个桩加任何豁免；T2 已做完的行为不改。
- C5 修完用一条 grep 列出同一种写法：`grep -rn "bin/codex" skill/scripts/tests/*.sh | grep -v "tests/bin/codex"`，报告里逐个说明别的嵌入桩写不写 `-o` 的文件、要不要跟着改（同改法且不超过 5 处的一起改，更多的只列出来）。

## 涉及模块
任务执行与验收
流程与调度契约

## 不许动什么
`skill/scripts/tests/brief-tests.sh` 归「流程与调度契约」，T2 改过它三处调用参数，所以上面列了这个模块；这次不再动它。
只许改 `skill/scripts/tests/guard-tests.sh` 里嵌入桩的桩体（和 C5 查出来同一种写法的桩体）、`skill/scripts/tests/suites.list`（只加一行）、`docs/模块地图.md` 第 32 行。`run.sh`、`guard.py`、别的脚本、`CHANGELOG.md`、铁律文件、`~/.claude` 下任何东西都不动；不推送。不删断言、不改断言、不加 skip；不加 `Roadstar-Length`、`Roadstar-Scope` 这类放行行。

## 执行环境
克隆 /Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG2/repo，分支 roadstar/sim-gaps-t2，接着现在的工作区做。提交由调度方做。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh; echo rc=$?`：rc=0，没有 FAIL；`guard-tests.sh` 那段是 `PASS 50`，有 `exec-handback-tests.sh` 那一段的 PASS 行。
- `wc -l skill/scripts/tests/run.sh`：和主干一样，没有变长。
- `git diff HEAD -- skill/scripts/tests/guard-tests.sh`：只动了桩体，没有断言行。
- `git status --porcelain`：只有 `guard-tests.sh`、`suites.list`、`docs/模块地图.md` 和未提交的 `exec-handback-tests.sh`（加上你的报告）。

## 资源上限与止损
预计 15 分钟，上限 30 分钟。同一条验收命令连修三次不过就停，交回。桩写了回答之后三条 C10 还挂，停下交回写清各自挂在哪句断言。

## 交付物
- 报告写到克隆根 RSG2b-report.md：C1 到 C5 各一行，四条验收命令的输出末行，给更新日志的一句话。
- 报告末行写 `完成状态：全部完成` 或 `完成状态：未全部完成`。
