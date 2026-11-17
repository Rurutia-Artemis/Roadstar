# T3c 执行报告

- C1：仅将 run.sh 原第 1466–1472 行七条调用换成清单循环；suites.list 按原顺序列出七个文件，末尾为 marker-branch-tests.sh；跳过空行和以 # 开头的行。前 1465 行与 T3 暂存版本逐字节一致。
- C2：子套件仍由单独的 bash 命令执行，继续使用原有 set -e 及 ERR trap；缺套件和缺清单均明确报文件名并退出 1。提取实际末尾循环的临时检查已验证子套件退出 7 时立即退出且不运行后续套件，以及注释、空行、清单顺序、无末尾换行、缺清单行为。
- C3：改前 1472 行，改后 1471 行；只替换指定末尾段落，没有删空白行或合并无关代码。
- C4：仅在地图第 32 行任务执行与验收的入口栏增加 suites.list，第 122 行“怎么测”说明末尾这一段的新套件登记进 suites.list、不往 run.sh 加行；marker-branch-tests.sh 没有重复添加。
- C5：guard.py、marker-branch-tests.sh 未改，相对 T3 暂存版本的 diff 为空；所有原有暂存改动保留，没有重置、提交或推送。

## 五条验收命令

| 命令 | 输出末行 / 结果 |
|---|---|
| `bash skill/scripts/tests/run.sh; echo rc=$?` | 首轮及恢复后最终版本均为 `rc=0`；十段 PASS 数和顺序与 T3 一致，未出现 FAIL |
| `wc -l skill/scripts/tests/run.sh` | `1471 skill/scripts/tests/run.sh` |
| 临时改 suites.list 一个名字再跑，恢复后复跑 | 缺文件运行末行 `rc=1`，明确输出 `找不到子套件：RSG3c-missing-suite.sh`；原始清单字节已恢复，恢复后全量末行 `rc=0` |
| `git diff a262e16 -- skill/scripts/tests/run.sh` | `+done < "$TEST_DIR/suites.list"`；仅末尾一个差异块 |
| `git status --porcelain` | 末行 `?? skill/scripts/tests/suites.list`；仅原四文件、suites.list 和本报告 |

首轮正常运行及恢复后最终版本的 PASS 顺序完全一致：

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

首轮正常运行后，针对性检查发现 Bash 对 while 重定向失败不会可靠触发 errexit；补上显式清单存在性检查，最终为 1471 行。该检查及其他针对性检查已通过；最终版本恢复后全量也已通过。

已再复查一轮：清单的七个名字和顺序完全恢复；run.sh 前 1465 行、guard.py、marker-branch-tests.sh 均与开工时 T3 暂存内容逐字节一致。原有前置接入不进入清单，失败路径未增加放行条件。

最终状态范围：

```text
MM "docs/\346\250\241\345\235\227\345\234\260\345\233\276.md"
M  skill/scripts/guard.py
A  skill/scripts/tests/marker-branch-tests.sh
MM skill/scripts/tests/run.sh
?? RSG3c-report.md
?? skill/scripts/tests/suites.list
```

针对性检查临时目录使用 RSG3c-loop- 前缀，均在 finally 中清理；全量回归沿用原测试 trap 清理。未产生构建产物、旧版本或备份。

完成状态：全部完成
