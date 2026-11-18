# T1 · 收窄五处误拦

## 改了哪些文件

- 源文件（`skill/scripts/`）：`guard_rules.py` 收窄留桩词边界；`design_page.py` 跳过被否定的同类方案触发词；`brief-check.py` 不计测试项；`guard.py` 放行地图未认领的测试文件；`cleanup.py` 让别场次独占分支的未合并任务与副本单列，并更新参数帮助。
- 测试（`skill/scripts/tests/`）：`guard-rules-tests.sh` 新增 F1；`brief-tests.sh` 新增 F2、F3b；`guard-tests.sh` 新增 F3a；`close-check-tests.sh` 新增 F4。
- 文档：`skill/SKILL.md`、`skill/references/task-brief-template.md`、`docs/模块地图.md`、`CHANGELOG.md`。指定场次路径下另写本报告及 `exec-T1.progress`。

## 跑了哪些验证命令及输出

- 开工 `git rev-parse HEAD`：`1ad849faa8bef235ce99ba473399e801303f1ad9`；`roadstar/fewer-false-blocks`，`git status --short` 为空。
- 四套局部回归均退出 0：`bash skill/scripts/tests/guard-rules-tests.sh` → `PASS 42 checks`；`bash skill/scripts/tests/guard-tests.sh` → `PASS 51`；`bash skill/scripts/tests/close-check-tests.sh` → `PASS 14`；`bash skill/scripts/tests/brief-tests.sh` → `PASS 90 checks`。
- 旧用例断言未改，改前改后对照无。收工套件首次裸跑退出 1（`FAIL 1/14`）：旧 C8 的 `--apply` 试图将合成夹具移进 `~/.Trash`，沙箱返回 `Operation not permitted`；F4 本身通过。用 `run.sh` 本来就设置的 `ROADSTAR_TRASH_DIR` 指向 `mktemp` 下的测试废纸篓后，未改动 HEAD 的源码和原套件退出 0（`PASS 13`），改后退出 0（`PASS 14`）。F4 变异和恢复也沿用同一设置。
- `bash skill/scripts/tests/run.sh`：开工和最终版均退出 0。最终较基线净增 5 项，11 套均未下降。

| 套件 | 开工 PASS | 最终 PASS |
|---|---:|---:|
| brief-tests.sh | 88 | 90 |
| review-tests.sh | 20 | 20 |
| run.sh 本体 | 95 | 95 |
| guard-tests.sh | 50 | 51 |
| close-check-tests.sh | 13 | 14 |
| entry-tests.sh | 36 | 36 |
| guard-rules-tests.sh | 41 | 42 |
| baseline-tests.sh | 8 | 8 |
| trailer-path-tests.sh | 18 | 18 |
| marker-branch-tests.sh | 40 | 40 |
| exec-handback-tests.sh | 23 | 23 |
| **合计** | **432** | **437** |

### 五项变异

每项只回退对应源文件：用 `git show 1ad849f:skill/scripts/<源文件>` 的原始字节覆盖工作树文件，运行对应的测试命令，随后在 `finally` 写回进程内保留的固定版字节。每次都对比恢复字节与变异前的 `git diff --stat`，完全一致，并立即重跑局部套件。

| 回退源文件 | 验证命令 | 回退 | 恢复 |
|---|---|---|---|
| `guard_rules.py` | `bash skill/scripts/tests/guard-rules-tests.sh` | 退出 1，F1 失败 | 退出 0，`PASS 42 checks` |
| `design_page.py` | `bash skill/scripts/tests/brief-tests.sh` | 退出 1，F2 失败 | 退出 0，`PASS 90 checks` |
| `brief-check.py` | `bash skill/scripts/tests/brief-tests.sh` | 退出 1，F3b 失败 | 退出 0，`PASS 90 checks` |
| `guard.py` | `bash skill/scripts/tests/guard-tests.sh` | 退出 1，F3a 失败 | 退出 0，`PASS 51` |
| `cleanup.py` | `bash skill/scripts/tests/close-check-tests.sh` | 退出 1，F4 失败 | 退出 0，`PASS 14` |

失败输出末行（仅将临时目录和克隆绝对路径缩写）：

```text
[F1]
FAIL F1 ('calc.py', 'def count_done(todo_list):', [('留桩或半成品', 'calc.py', 'def count_done(todo_list):')])

[F2]
  按 references/task-brief-template.md 补齐再派；真急可 BRIEF_CHECK=0（会记下）。
expected exit 0, got 2
FAIL F2：这次不重做 text 模块，只改乘法。

[F3b]
  File "<stdin>", line 337, in f3b_module_count
  File "<stdin>", line 40, in expect
AssertionError: (['/opt/homebrew/opt/python@3.14/bin/python3.14', '<repo>/skill/scripts/brief-check.py', '<tmp>/roadstar-tests.90k7Nz/design session/task.md', '--write', '--class', '跨模块', '--est-minutes', '90', '--plan-dir', '<tmp>/roadstar-tests.90k7Nz/design session'], 2, '', '任务书不合格，派不出去：\n  - 设计页「模块表」至少要两行数据（跨模块任务）\n  按 references/task-brief-template.md 补齐再派；真急可 BRIEF_CHECK=0（会记下）。\n')
FAIL: line 472

[F3a]
FAIL F3a 未认领的测试文件可提交，别模块测试和未认领普通文件仍越界；(('git', 'commit', '-qm', 'unowned test'), '退出码', 1, 0, '', '拦下了：提交还没满足范围或地图要求\n任务 <tmp>/roadstar-guard-tests.HTc5kg/case.v6S8Ha/项目 repo/docs/roadstar/测试场次/T1 超出涉及模块：\n- tests/test_calc.py → 地图里没有\n怎么办：改任务书的涉及模块后重提；或在提交说明末尾空一行，再加一行 Roadstar-Scope: <为什么要超出范围>（不空行 git 认不出）。\n')
FAIL 1/51

[F4]
PASS C8 原 dry-run 及 apply 保持清理与保护规则：只清已合并干净副本和过期中间产物
FAIL F4 指定场次时别场次独占分支只列出；混合分支、无任务标记副本和缺验收仍计入；(('python3', PosixPath('<repo>/skill/scripts/cleanup.py'), '--project', PosixPath('<tmp>/roadstar-close-check.pd31xR/项目 repo'), '--check', '--plan-dir', 'docs/roadstar/测试场次'), 1, 0, '收工检查：还有 1 项没收完\n没合并：T9（docs/roadstar/别的场次）在分支 other 上，1 个提交\n', '')
FAIL 1/14

```

### 手工合成复现

用临时 Git 仓库分别执行 `guard_rules.lowering_hits`、`brief-check.py`、带真实钩子的 `git commit`、`cleanup.py --check`。五处的误拦样例与必要拦截都已复现。输出：

```text
F1 archive.sh f=$(mktemp "$archive_bin/.$script.XXXXXX")：[]
F1 pending.py # TODO: 没做完：[('留桩或半成品', 'pending.py', '# TODO: 没做完')]
F2 任务书「这次不重做 text 模块，只改乘法。」：退出 0
F2 旧 plan 目标节：退出 0
F2 plan 回读设计页：退出 0
F2 任务书「不改接口，重做记忆服务。」：退出 2
  - 目标里有「重做」，缺「同类方案」一节：至少 3 个同类开源项目或产品，每个写它怎么做、我们取什么、不取什么、许可证，附链接；查不到写「查过：关键词…，无」
F2 旧 plan 目标节：退出 2
  - 目标里有「重做」，缺「同类方案」一节：至少 3 个同类开源项目或产品，每个写它怎么做、我们取什么、不取什么、许可证，附链接；查不到写「查过：关键词…，无」
F2 plan 回读设计页：退出 2
  - design.md：目标里有「重做」，缺「同类方案」一节：至少 3 个同类开源项目或产品，每个写它怎么做、我们取什么、不取什么、许可证，附链接；查不到写「查过：关键词…，无」
F3a tests/test_calc.py：退出 0
F3a src/b/test_b.py：退出 1
- src/b/test_b.py → 乙
F3a unknown.txt：退出 1
- unknown.txt → 地图里没有
F3b 无模块表，涉及 甲 / tests：退出 0
F3b 无模块表，涉及 甲 / 乙：退出 2
  - 设计页「模块表」至少要两行数据（跨模块任务）
F4 指定当前场次：退出 0
收工检查：都收完了
别的场次的（不计入）：
没合并：T9（docs/roadstar/old）在分支 other 上，1 个提交
F4 不指定场次：退出 1
收工检查：还有 1 项没收完
没合并：T9（docs/roadstar/old）在分支 other 上，1 个提交
没给场次目录，验收记录这项没查
F4 指定场次 JSON：{"clean": true, "items": [], "others": [{"kind": "unmerged_task", "plan_dir": "docs/roadstar/old", "task": "T9", "branch": "other", "commits": 1, "detail": "没合并：T9（docs/roadstar/old）在分支 other 上，1 个提交"}]}
F4 本场次任务未合并：退出 1
收工检查：还有 1 项没收完
没合并：T2（docs/roadstar/mine）在分支 local 上，1 个提交
别的场次的（不计入）：
没合并：T9（docs/roadstar/old）在分支 other 上，1 个提交
F4 本场次缺验收：退出 1
没验收：T3（docs/roadstar/mine）
本仓库五查「留桩或半成品」：skill/scripts/guard_rules.py：STUB = re.compile(r'(?<![\w.-])(?:TODO|FIXME|XXX)(?!\w)|(?:#|//|/\*|<!--)[ \t]*(
本仓库五查「留桩或半成品」：skill/scripts/tests/guard-rules-tests.sh：        '# TODO: 没做完', 'raise NotImplementedError', '# XXX 待补',
```

新用例字面样例命中五查的文件是 `skill/scripts/tests/guard-rules-tests.sh`（F1 的 TODO／XXX／NotImplementedError 等正例）；`skill/scripts/guard_rules.py` 的新正则定义也被同类扫描命中。没有改写样例，请 Argo 在「降标准五查」验收记录中点名这两处。

### 行数与范围

`wc -l`：源和测试文件均不超过 800 行。`guard-tests.sh` 从 767 到 781，净增 14 行，低于 25 行限额。`git diff --stat` 只含允许的 13 个已跟踪文件；报告与进度是指定的单独交付。

```text
     298 skill/scripts/guard_rules.py
     217 skill/scripts/design_page.py
     165 skill/scripts/brief-check.py
     549 skill/scripts/guard.py
     407 skill/scripts/cleanup.py
     665 skill/scripts/tests/guard-rules-tests.sh
     485 skill/scripts/tests/brief-tests.sh
     781 skill/scripts/tests/guard-tests.sh
     351 skill/scripts/tests/close-check-tests.sh
    3918 total

 CHANGELOG.md                             |  8 ++++++
 docs/模块地图.md                         | 10 +++----
 skill/SKILL.md                           |  4 +--
 skill/references/task-brief-template.md  |  2 +-
 skill/scripts/brief-check.py             |  4 ++-
 skill/scripts/cleanup.py                 | 21 ++++++++++++---
 skill/scripts/design_page.py             | 17 +++++++-----
 skill/scripts/guard.py                   |  6 ++++-
 skill/scripts/guard_rules.py             |  2 +-
 skill/scripts/tests/brief-tests.sh       | 26 ++++++++++++++++++
 skill/scripts/tests/close-check-tests.sh | 45 ++++++++++++++++++++++++++++++++
 skill/scripts/tests/guard-rules-tests.sh | 27 +++++++++++++++++++
 skill/scripts/tests/guard-tests.sh       | 14 ++++++++++
 13 files changed, 165 insertions(+), 21 deletions(-)
```

## 没做成的和原因

- 沙箱拒绝在 `RFB1` 下直属创建 `mut/` 和复现目录。固定版没有落盘备份，五次变异均用进程内字节恢复；手工复现改在 `RFB1/repo` 下临时建目录。复现目录、临时废纸篓、基线对照及运行日志已清理，没有留下旧版本副本。
- 没有运行 `./install.sh`、做真实场次合并验收或安装后验证；按任务边界不提交、不推送，也未写回外部记忆服务。场次的设计页和 ledger 不在克隆，实施以交付的任务书为准。
