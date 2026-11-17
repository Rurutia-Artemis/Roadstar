本记录覆盖 T2 和 T2b 的全部改动（克隆 RSG2，基线 6c44132，待验 7fb054e）。

# T2b 验收记录

## 结论
通过

## 验收档位
重档（拦所有项目派活的入口脚本）

## 复跑的验收命令与输出
`bash skill/scripts/tests/run.sh; echo rc=$?`：rc=0，无 FAIL，各段 PASS 依次 88、20、95、50、13、36、41、8、18、36、23，与期望一致。
`exec-handback-tests.sh` 已在 `suites.list` 末尾登记，`run.sh` 一行没动。

## 逐项完成线
- 旧用例：`git diff 6c44132 7fb054e -- guard-tests.sh brief-tests.sh` 只有嵌入 codex 桩的桩体（现在处理 `-o`，写入 3 行、超过 200 字节的固定回答，仍检查标记、仍写 `called`）和 3 处调用补 `--max-minutes 10`。没有断言被改、删、跳过，没有删除行以外的放宽。
- 缺上限：自己造输入。`--write` 无上限、加 `--resume x`、加 `--dry-run`、两者都加，四种都退出 2 并输出「写活必须带 --max-minutes（常规 120、难活 240、窄回归 60）」，且没有 rounds 产物。只读派活退出 0；`--write --max-minutes 5` 新旧版都退出 0。
- 空交回（桩包装器造文件不存在、0 字节）：新版退出 4、`.exit` 为 4、meta 有 `handback=empty`、屏幕有「警告：交回为空」；基线同样输入退出 0。`FAKE_CODEX_EXIT=3` 仍退出 3（meta 有 `handback=empty`，码不变）。超时被停仍退出 124。
- 边界：回答文件 199 字节为 `handback=short`、警告、退出 0；200 字节无 `handback`，无警告；1 字节同为 short。
- `--wait`：设计是前台执行（任务书 C3），打印 `handback=`、`exit：<码>`、文件末 5 行；空交回时退出 4 且打印「结果文件不存在」；`--wait --detach` 退出 2。派发指令里「后台派活后带回退出码、任务不存在不挂住」是另一种语义，脚本没有这个功能，也没有挂住的路径（`--wait` 不接受 `--status`、`--detach`）。属任务书与派发描述的差别，不是缺陷。
- 豁免：`dex-exec.sh` 里 grep `STUB|TEST|FAKE|tests/|test|tmp` 只有 `$META.tmp.$$` 和 `$EXIT_FILE.tmp.$$` 两处原子写文件的临时名，没有为测试或桩加的豁免。
- 调用方：`skill/scripts/` 里只有 `dex-exec.sh` 自己和 `grok-exec.sh`（注释）、`brief-check.py`（注释）提到它，`dex-review.sh`、`install-guard.sh` 不调用。文档示例 `SKILL.md:29`、`references/division-of-labor.md:104-105`、`SKILL-v1.14.md:184`、`modes.md:42` 的命令都带 `--max-minutes`；`task-brief-template.md:44` 要求写同样的数。没有不带上限的写活调用。测试里两处 `--write` 调用（`brief-tests.sh` 432、437 行）已补上限。
- 变异（临时拷贝，`exec-handback-tests.sh` 必须挂）：去掉缺上限检查，挂在第 1 项（line 82，期望 2 实得 0）；空交回退出码 4 改回 0，挂在第 3 项（line 97，期望 4 实得 0）；200 门槛改为 1，挂在第 6 项（line 114，短回答不再被标 short）。三个都挂。

## 降标准五查
- 下调门槛：无。验证方式：逐行读 `git diff 6c44132 7fb054e`，另外用独立桩（`tests/bin/codex` 加包装器）在临时目录自己造输入，并用变异证明 `exec-handback-tests.sh` 的门槛会咬人。
- 跳过或删测试：无。`guard-tests.sh`、`brief-tests.sh` 的差异只含桩体和 `--max-minutes 10`，无删除断言。
- 关掉检查：无。
- 留桩或半成品：`guard-tests.sh` 里嵌入的 codex 桩体是测试替身，正常写法；回答文字是普通英文句子，不是用空白凑字节。没有 `# noqa`，没有名字带 todo 的变量或用例。`--skip-git-repo-check` 是 codex 命令行参数，不是跳过测试。
- 新增例外 / 改检查配置：无。`suites.list` 末尾登记 `exec-handback-tests.sh` 是新增套件，不是例外；`run.sh` 未改。

## 未验证
没有调用真的 codex。后台 `--detach` 的真实长跑只靠套件里的桩用例（`C2/C3 detach`）覆盖。
