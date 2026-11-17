# RSG2b · T2b 执行报告

C1：已完成。仅适配 guard-tests.sh 的嵌入桩体，解析 `-o <路径>` 并写入 359 字节固定正常句子；原标记检查与 called 记录保留，所有原断言不动，guard 段 `PASS 50`。
C2：已完成。suites.list 末尾仅追加 `exec-handback-tests.sh`；模块地图第 32 行登记该文件，run.sh 未改、仍为 1471 行，与 HEAD 相同。
C3：已完成。only reply 的调用和断言均保持原样，随主套件 `PASS 95 checks` 通过。
C4：已完成。本轮 dex-exec.sh 与进场快照字节一致，未加测试路径或桩豁免；brief-tests.sh、run.sh 也与进场快照字节一致。
C5：已完成。指定 grep 找到三组桩，只有 guard 桩缺输出文件处理并已修复，其余两组无需修改，逐处说明见下。

## 四条验收命令

1. `bash skill/scripts/tests/run.sh; echo rc=$?`：首次运行通过，输出最后两行：

```text
PASS 23 checks
rc=0
```

全部套件汇总（无 FAIL 行）：

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
PASS 23 checks
```

2. `wc -l skill/scripts/tests/run.sh`：

```text
    1471 skill/scripts/tests/run.sh
```

`git show HEAD:skill/scripts/tests/run.sh | wc -l` 也是 1471；run.sh 与进场快照完全一致，未加行。

3. `git diff HEAD -- skill/scripts/tests/guard-tests.sh`：输出最后一行是 `     mark = ""`。未修改任何断言；本轮相对进场快照只改桩体。但 HEAD 比较还包含进场时已有的 T2 `args.append("--write")` → `args.extend(["--write", "--max-minutes", "10"])`，因此不能把这条命令的结果声称为“相对 HEAD 仅桩体”。该既有调用未在 T2b 改动。

4. `git status --porcelain`：输出最后一行是 `?? skill/scripts/tests/exec-handback-tests.sh`。完整实际输出：

```text
 M "docs/\346\250\241\345\235\227\345\234\260\345\233\276.md"
 M skill/scripts/dex-exec.sh
 M skill/scripts/tests/brief-tests.sh
 M skill/scripts/tests/guard-tests.sh
 M skill/scripts/tests/suites.list
?? RSG2-report.md
?? RSG2b-report.md
?? rounds/
?? skill/scripts/tests/exec-handback-tests.sh
```

## 进场状态与未满足的审计条件

进场 HEAD 为 `6c44132`，分支 `roadstar/sim-gaps-t2`；T2 的 dex-exec.sh、brief-tests.sh、guard-tests.sh 参数、地图规矩/交回说明仍有未提交差异，RSG2-report.md、rounds/ 也已存在。因此任务书预期的“status 只有本轮三处文件、未提交新套件与报告”在当前环境不成立。

本轮已完成 C1–C5 的代码和测试工作；两条 Git 范围审计还受既有 T2 未落提交影响。未删除既有报告/进度、未回退 T2 改动、未 staging、未提交、未推送；提交留给调度方。调度方收录 T2 既有差异后，可重新核对 HEAD diff 与 status。

## C5 同类写法检查

```sh
grep -rn "bin/codex" skill/scripts/tests/*.sh | grep -v "tests/bin/codex"
```

```text
skill/scripts/tests/exec-handback-tests.sh:17:export STUB_CODEX="$TEST_DIR/bin/codex"
skill/scripts/tests/exec-handback-tests.sh:40:cat > "$TMP/bin/codex" <<'WRAPPER'
skill/scripts/tests/exec-handback-tests.sh:58:chmod +x "$TMP/bin/codex"
skill/scripts/tests/guard-tests.sh:630:    codex = write(directory, "bin/codex", r'''#!/bin/bash
skill/scripts/tests/review-tests.sh:17:export REVIEW_CODEX_STUB="$TEST_DIR/bin/codex"
skill/scripts/tests/review-tests.sh:18:cat > "$TMP/bin/codex" <<'STUB'
skill/scripts/tests/review-tests.sh:35:chmod +x "$TMP/bin/codex"
```

| 命中位置 | 是否写 -o 文件、是否跟改 |
|---|---|
| exec-handback-tests.sh:17 | 指向公共 tests/bin/codex，公共桩会写 -o 文件；不是另一份缺输出的桩，不改。 |
| exec-handback-tests.sh:40 | 包装器先调用公共桩；missing/zero 模式故意删除或截空输出，正用于覆盖空交回，不改。 |
| exec-handback-tests.sh:58 | 上述包装器的 chmod，非独立桩，不改。 |
| guard-tests.sh:630 | 原桩不写；本轮已解析 -o 并写 359 字节回答。标记检查和 called 记录保留。 |
| review-tests.sh:17 | 指向公共 tests/bin/codex，已有输出能力，不改。 |
| review-tests.sh:18 | 包装器先调用公共桩；schema 模式再读取 -o 文件、补 checklist 并写回，已有文件处理，不改。 |
| review-tests.sh:35 | 上述包装器的 chmod，非独立桩，不改。 |

需同改的桩只有 guard 这一处；未改其他桩体。

## 给更新日志的一句话

适配 guard 离线 Codex 桩的 -o 最终回答输出，并通过 suites.list 与模块地图登记交回测试；全量回归退出 0，guard PASS 50、交回测试 PASS 23，保留 only reply 短回复回归。

已做过交付前第二轮核对：固定回答字节数、带空格输出路径、原标记/调用记录、只读及 dry-run、原断言、新套件清单顺序均已检查。临时快照和全量测试日志交付前清理，关键结果留在本报告；没有创建版本备份或构建产物。

完成状态：未全部完成
