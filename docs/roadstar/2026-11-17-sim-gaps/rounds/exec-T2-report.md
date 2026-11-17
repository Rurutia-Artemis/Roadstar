# RSG2 · T2 执行报告

## 结论

C1–C4 与 C6 已实现，新增局测最终 `PASS 23 checks`、退出 0；手验缺上限退出 2、补 `--max-minutes 5` 退出 0。全量回归退出 1，卡在 C5 允许范围不足以修复的 guard 本地桩：它只记 called、不写报告，新契约必须把成功空交回改成 4，旧调用却要求 0。未放宽检查、未改旧断言、未改旧桩。

基线：`a262e166ca170b8e7a2a0895612508e5df41d680`；分支：`roadstar/sim-gaps-t2`。开工前工作区干净。本轮只做「任务执行与验收」。

## 改了哪些文件

| 文件 | 改动 |
|---|---|
| `skill/scripts/dex-exec.sh` | 写活缺上限先于 model 检查拒绝，status 豁免；finalize_report 后按最终文件字节数分 empty/short；empty 只把原 0 改为 4；meta 可选 handback；4 的失败提示；前台 --wait、互斥参数、头部用法及 help 范围 |
| `skill/scripts/tests/exec-handback-tests.sh`（新） | 23 条离线检查，调用公共 tests/bin/codex 桩；临时包装器仅模拟成功后 -o 文件消失/被截空，不改公共桩 |
| `skill/scripts/tests/brief-tests.sh` | 仅三处旧 dex-exec 写活调用补 `--max-minutes 10`，断言不动 |
| `skill/scripts/tests/guard-tests.sh` | 仅 dispatch 写活调用补 `--max-minutes 10`，断言和本地桩不动 |
| `skill/scripts/tests/run.sh` | 只在 entry-tests.sh 调用后加 exec-handback-tests.sh 一行 |
| `docs/模块地图.md` | 只修改原 123 行规矩措辞，原 128 行后加交回与等待说明一行 |

交付文件：根目录 `RSG2-report.md`、`rounds/exec-T2.progress`。未提交、未推送，未运行安装，未改 CHANGELOG、guard.py、铁律、用户钩子或 ~/.claude。

## 验证命令与实际输出

### 1. 未改动基线

`bash skill/scripts/tests/run.sh; echo rc=$?`

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
rc=0
```

### 2. 修改后全量

`bash skill/scripts/tests/run.sh; echo rc=$?`

```text
PASS 88 checks
PASS 20 checks
PASS 95 checks
FAIL C10 write 实际派活前在 root 留下任务标记，使用离线 codex 桩；退出码实际 4，期望 0
FAIL C10 dry-run 与只读派活不写标记；其中只读实际派活退出码 4，期望 0
FAIL C10 root 指向 worktree 时标记只写该 worktree，派活前已存在；退出码实际 4，期望 0
FAIL 3/45
FAIL: line 1466
rc=1
```

三条都命中相同证据：`警告：交回为空；结果：…/exec-T1.md；日志：…/exec-T1-stdout.log`。主套件的原 PASS 95 不变，brief 与 review 段也未变。guard 测试累计到三条失败后自身停止，后续 close-check、entry、新挂接交回、guard-rules、baseline、trailer 套件未由这次全量跑到，不能报告全量通过。新增套件另行独立实跑如下。

### 3. 新增局测

`bash skill/scripts/tests/exec-handback-tests.sh; echo rc=$?`

首次运行：C1 缺上限检查通过，带上限写活因新测试夹具没声明窄任务类别而被已有设计页门槛拒绝，退出 2。修复仅在新测试调用增加 `--class 补全 --est-minutes 1`；生产门槛不变。之后局测通过；收口调整 --wait 摘要放在 run_job 内（保留原 errexit 行为）后，又完整复跑一次，最终输出：

```text
ok 1 - C1 写活含 resume/dry-run 缺上限先于 model 被拒，且无产物
不在 RuruCode 项目里，跳过接入和存量检查
不在 RuruCode 项目里，跳过接入和存量检查
警告：Roadstar 任务标记失败，继续派活（工作区：/var/folders/sl/cgf2dtnn2sbdvrcyltzm9v_40000gn/T/RSG2-handback.Bz3XwX）。
ok 2 - C1 带上限 dry-run 与写活放行
ok 3 - C2 missing 交回退出 4，meta/警告/失败说明齐全
ok 4 - C2 zero 交回退出 4，meta/警告/失败说明齐全
ok 5 - C1/C2 status 无需写活上限且展示 handback 与退出码 4
ok 6 - C2 1 字节交回只警告不改退出码
ok 7 - C2 199 字节交回只警告不改退出码
ok 8 - C2 status 展示 short
ok 9 - C2 200 字节无 handback，重派不残留 short
ok 10 - C2 自写长报告加简短最终回复不误报
ok 11 - C2 非零原码 3 不改成 4
ok 12 - C2 超时仍 124
ok 13 - C3 wait 打印退出码和恰好最后 5 行
ok 14 - C2/C3 wait 展示 short
ok 15 - C3 wait missing 交回退出码与 .exit 一致
ok 16 - C3 wait zero 交回退出码与 .exit 一致
ok 17 - C3 wait 非零退出仍打印摘要
ok 18 - C3 wait 与 --detach 互斥
ok 19 - C3 wait 与 --status 互斥
ok 20 - C3 wait 与 --dry-run 互斥
ok 21 - C2/C3 detach 仍立即返回，空交回最终 .exit 为 4
ok 22 - C3 普通只读无上限调用保持原有结束输出
ok 23 - C6 help 包含 wait 及原有末行选项
PASS 23 checks
rc=0
```

覆盖缺上限（含 resume、dry-run、缺 model 先后与无产物）、带上限真实写活与 dry-run、缺失/零字节退出 4、1/199 字节只警告、200 字节不记 handback、重派不残留、长自写报告加短最终回复、原退出码 3、超时 124、status empty/short、wait 恰好末 5 行及失败摘要、三种互斥、detach empty .exit=4、普通只读无上限输出、help。

### 4. 手验

场次与六栏任务书放在自建 `RSG2-manual/`，引用与本任务同一份设计页；只在命令环境里隔离配置、入口检查根与 ws-guard 路径，无账户设置变动。

```text
bash skill/scripts/dex-exec.sh RSG2-manual T1 --model m --effort high --brief RSG2-manual/brief.md --write --dry-run; echo $?
写活必须带 --max-minutes（常规 120、难活 240、窄回归 60）
2
```

同一调用补 `--max-minutes 5`：

```text
命令：codex exec … -s workspace-write -m m -c model_reasoning_effort=high --disable fast_mode …
时间上限：5 分钟
0
```

### 5. 范围

`git diff --stat`（只统计已跟踪文件；新套件与报告、进度尚未跟踪，不 staging）：

```text
 ...250\241\345\235\227\345\234\260\345\233\276.md" |  3 +-
 skill/scripts/dex-exec.sh                          | 47 ++++++++++++++++++----
 skill/scripts/tests/brief-tests.sh                 |  6 +--
 skill/scripts/tests/guard-tests.sh                 |  2 +-
 skill/scripts/tests/run.sh                         |  1 +
 5 files changed, 46 insertions(+), 13 deletions(-)
```

## C5 每处改前改后

断言一字未改。

| 原位置 | 改前 | 改后 / 处理 |
|---|---|---|
| brief-tests.sh:432 | `… '--write', '--dry-run', '--brief', …` | `… '--write', '--max-minutes', '10', '--dry-run', '--brief', …` |
| brief-tests.sh:437 | `… '--write', '--dry-run', '--brief', …` | `… '--write', '--max-minutes', '10', '--dry-run', '--brief', …` |
| brief-tests.sh:451 | `run_task T9b --write --root "$PLAN"` | `run_task T9b --write --max-minutes 10 --root "$PLAN"` |
| guard-tests.sh:638 | `args.append("--write")` | `args.extend(["--write", "--max-minutes", "10"])` |
| run.sh:334 | `FAKE_CODEX_REPLY='only reply' run_task T51` | 原样保留，单列交回：下一行断言 `$(cat report) == 'only reply'`，把回复改成有实际内容的 ≥200 字节与该断言冲突。新行为下短回复仍退出 0，所以该原测试已随 PASS 95 通过，仅新增 short 警告。没有用大量尾部换行凑 200 字节绕过断言。 |

其他 `FAKE_CODEX_REPLY` 的短最终回复（T50/T52）已有执行方自写的长报告，最终文件超过 200 字节，未受新检查波及，保持原调用。entry-tests.sh 的写活 helper 已有 `--max-minutes 1`，无需修改。

guard 更深一层的冲突位于 :630 的嵌入式本地 codex 桩：它检查标记并写 `called`，却完全不处理 `-o`。补上限只能过 C1，不能满足新 C2。让该桩写报告或记录调用后转交 tests/bin/codex 需要改桩行为，超出本任务允许的“只改调用参数”，故按“拿不准单列交回”保留并报告。不得在 dex-exec 对测试路径或该桩作空交回豁免。

## C6 grep 原样输出

命令：

```sh
grep -rn "max-minutes" skill/scripts/*.sh skill/references/*.md docs/模块地图.md | grep -v v1.14
```

```text
skill/scripts/dex-exec.sh:3:# 用法：dex-exec.sh <plan-dir> <T#> --model M --effort E --brief FILE [--class 类别] [--est-minutes N] [--strategy S] [--root DIR] [--write [--network]] [--max-minutes N] [--resume SESSION_ID] [--detach] [--wait] [--status] [--force] [--dry-run]
skill/scripts/dex-exec.sh:12:#   --max-minutes N  写活必填（含 resume/dry-run，status 除外）；到 N 分钟停掉 codex，退出 124，meta 记 timed_out=1（常规 120、难活 240、窄回归 60）。
skill/scripts/dex-exec.sh:180:    --model|--effort|--brief|--root|--resume|--max-minutes|--class|--est-minutes|--strategy)
skill/scripts/dex-exec.sh:193:        --max-minutes)
skill/scripts/dex-exec.sh:194:          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--max-minutes 要正整数分钟数：$2"
skill/scripts/dex-exec.sh:259:  usage_error '写活必须带 --max-minutes（常规 120、难活 240、窄回归 60）'
skill/scripts/grok-exec.sh:6:#   --max-minutes N 到点 TERM，十秒后 KILL；退出码 124，meta 记 timed_out=1。
skill/scripts/grok-exec.sh:143:    --model|--effort|--brief|--root|--max-turns|--max-minutes|--class|--est-minutes|--strategy)
skill/scripts/grok-exec.sh:158:        --max-minutes)
skill/scripts/grok-exec.sh:159:          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--max-minutes 要正整数分钟数：$2"
skill/references/division-of-labor.md:105:  --max-minutes 120 [--root <项目根>] [--write] [--detach] [--resume <session id>] [--status] [--force]
skill/references/division-of-labor.md:111:- `--max-minutes` 是止损，写拆分表里的上限（常规 120、难活 240、窄回归 60）：到点脚本停掉 codex，退出码 124，meta 记 `timed_out=1`，`--status` 会提示「到时间上限被停止」。停掉的线不自动重派，Argo 先看进度文件和日志诊断（第 15 节），再决定收下、换环境判还是缩窄重派。
skill/references/escalation-and-learning.md:36:停的方法：Codex 线由 dex-exec.sh 的 `--max-minutes` 兜底，碰壁时 Argo 直接 `--stop`；Claude 子代理用 TaskStop。停下的线不自动重派，先走第 4 节。
skill/references/escalation-and-learning.md:59:| `outcome=timed_out` | 到 `--max-minutes` 被停掉的线（meta 有 `timed_out=1`）记这个，和 stalled 分开统计 |
skill/references/modes.md:42:- 代码层：以「有没有 bug、有没有隐患、能不能用」为标准，按项目地图逐模块查。Codex 侧按模块并行派只读线，每模块一条（核心或复杂模块 `gpt-6-astra` / high，简单模块 `gpt-6.1-sol` / high；要模拟器的最多两条；每条 `--max-minutes 120`），任务书要求每条问题带复现步骤或证据位置；Claude 侧 Argo 读结构、跑全量测试、看最近提交。
skill/references/task-brief-template.md:43:<REQUIRED：浏览器实例数、单条命令超时、并发数。预计用时（抄排活表的「预估」）和时间上限（预计的两倍，最多不超过类型默认上限，见 estimates.md；不许直接套 120 分钟），派发时 `--est-minutes` 和 `--max-minutes` 写同样的数；验证方式只用这里写的命令，不自己发明验证手段，视觉验收由 Argo 截图；每试一次某个检查项，就往 `<plan-dir>/rounds/exec-T<n>.progress` 追加一行「ISO 时间 制表符 检查项编号 制表符 pass 或 fail 制表符 一句证据」；同一检查项连续三次失败、或到上限，就停下交报告，写清哪些项过了、卡在哪一项、试过什么，不自行无限尝试（规则见 escalation-and-learning.md）。>
docs/模块地图.md:61:| 「一条线跑了好几个小时不停／到点被停掉了接下来怎么办」 | 任务执行与验收 | 派发时是否带 `--max-minutes`；`--status` 看 meta 的 `max_minutes`／`timed_out`，退出码 124 不自动重派；按 `division-of-labor.md` §15 止损行由 Argo 诊断后三选一 |
docs/模块地图.md:117:- 对外接口：`guard.py mark <场次目录> T<n> | unmark`（每个 worktree 独立、绑定当前分支的任务标记）；`guard.py hook prepare-commit-msg <消息文件> [来源] [sha] | hook commit-msg <消息文件> | hook pre-merge-commit`（任务 trailer、模块范围与入口地图、主工作区非空验收记录）；`guard.py modules <仓库根>`（只读工作树地图，每行 `模块名\t路径1, 路径2`，展开表前缩写，退出 0）；`guard.py check-merge <分支>`（退出 0/1）、`guard.py claude-pretool`（stdin JSON，拦截退出 2、原因到 stderr，带任务号的合并必须 `--no-ff`）；`bash skill/scripts/install-guard.sh <项目根> [--uninstall] [--claude]`（保留 `.local` 钩子，已有 `core.hooksPath` 时仅提示手动接入，合并 Claude 本地设置）；`Roadstar-Scope`／`Roadstar-Map` trailer 可附理由放行对应检查，`ROADSTAR_GUARD=off` 关闭三个钩子与 Claude 检查；`dex-exec.sh --write` 实际派活前自动 mark，失败只警告。`bash skill/scripts/dex-exec.sh <场次目录> <任务号> --model M --effort E --brief FILE --max-minutes N [--class 类别] [--est-minutes N] [--strategy auto|quality|thrift|rush]`；支持 `--write`、`--resume`、`--detach`、`--status`、`--force`、`--dry-run`；到上限脚本 TERM 十秒后 KILL，退出码 124，meta 记 `max_minutes`／`timed_out`。报告 `rounds/exec-T<n>.md`：执行方本次自己写了就保留全文，Codex 最后一条回复追加成末尾「## 最终回复」一节；没写才用最后回复生成（`-o` 先落到隐藏的 `.exec-T<n>.md.last-reply`，收尾并入后删掉）。`--class` 把活的类别写进 meta（取证、批量、页面实现、窄回归、跨模块、根因、性能、视觉照做、复核、审方案、补全），`--est-minutes`、`--strategy` 写 `est_minutes`、`strategy`。`python3 skill/scripts/cleanup.py [--project 根] [--plan-dir 场次]… [--days 7] [--base 分支] [--apply | --check] [--json]`：默认 dry-run 列已合并且干净的 worktree 和超期中间产物；脏、未合并、未推送、锁定的一律不动；`.meta`、任务书、报告、进度文件永不删。`--check` 只读收工检查：列未合并副本（含锁定槽位）、所有本地分支上未合并的 `Roadstar-Task` 任务提交、按原 dry-run 规则可清却未清的副本及指定场次缺失／空白的 `rounds/check-T<n>.md`；不给 `--plan-dir` 跳过验收记录并提示（JSON 模式提示到 stderr）；退出 0 表示都收完、1 表示还有条目、2 表示参数或读取错误，不能与 `--apply` 同用。Claude 子代理没有脚本：Agent 工具 `model` 选 haiku／sonnet／opus（fable 只在两种情况），同一份任务书，结果写同一路径，`.meta` 由主会话手写。
docs/模块地图.md:119:- Grok 接口：`bash skill/scripts/grok-exec.sh <场次目录> T<n> --brief FILE --class 取证|复核 [--model grok-4.7] [--effort high] [--max-turns 30] [--root DIR] [--max-minutes N] [--est-minutes N] [--strategy S] [--detach] [--status] [--dry-run]`；固定 `grok -p <全文> -m M --cwd DIR --sandbox read-only --permission-mode bypassPermissions --max-turns N --reasoning-effort E --output-format plain`。`--write` 退出 2 并提示「写活等后续版本」，未安装或未登录退出 3，到点退出 124、`timed_out=1`；报告、请求快照、日志、meta、exit、后台 pid 与 Dex 同名契约，token 读不到留空；成功收尾时执行方本次写过 `exec-T<n>.md` 就保留全文，把 stdout 日志追加成末尾「## 最终回复」一节，没写才复制日志。仅开关开且已登录时由 Argo 试派，复核保持跨家。
docs/模块地图.md:120:- Grok 测试：`bash skill/scripts/tests/run.sh` 自动加载 `skill/scripts/tests/grok-113.sh`；`PATH="$PWD/skill/scripts/tests/bin:$PATH" bash skill/scripts/grok-exec.sh docs/2026-10-04-dispatch-upgrade T99 --brief docs/2026-10-04-dispatch-upgrade/brief.md --class 取证 --root "$PWD" --max-minutes 30 --dry-run` 可单查命令。桩覆盖参数、只读、登录门槛、产物、限时、后台与项目登记。
docs/模块地图.md:122:- 怎么测：`bash skill/scripts/tests/guard-rules-tests.sh` 覆盖新规则与设计接线，装真钩子跑临时仓库提交／合并（独立配置目录），退出 0、末行 `PASS <n> checks`；`run.sh` 也挂接此套件，原 ws-guard 测试原样迁入该文件的 `--legacy` source 分支。`bash skill/scripts/tests/close-check-tests.sh`（或 `/bin/bash`）：每条用例在 `mktemp -d` 新建临时 Git 仓库，路径规范化后与 Git 输出比较；测试不读取旧进度，可重复运行，`ROADSTAR_CLOSE_CHECK_PROGRESS` 可指定本轮证据追加路径；覆盖收工检查 C1–C8（冲突参数、未合并副本／任务、未清副本、验收记录、输出、文件及 Git 状态不变、原 dry-run／apply）；`bash skill/scripts/tests/guard-tests.sh`（或 `/bin/bash`）覆盖 guard C1–C12、真实提交／合并与 worktree，以及模块表 C1–C6（表头别名、缩写展开与范围、路径说明清洗、括号模块名、入口行为不变、modules 输出及只读）；全量入口 `tests/run.sh` 末尾按 guard-tests、close-check-tests 顺序调用。`bash skill/scripts/dex-exec.sh docs/2026-10-04-dispatch-upgrade T99 --model gpt-6.1-sol --effort high --brief docs/2026-10-04-dispatch-upgrade/brief.md --root "$PWD" --max-minutes 120 --dry-run`，只打印命令、路径和「时间上限：120 分钟」，不查额度、不执行任务、不写产物（10-10 实跑）。
docs/模块地图.md:123:- 规矩：模型／强度／任务书必填，默认只读；写活（含 `--resume`、`--dry-run`）必须带 `--max-minutes`（常规 120、难活 240、窄回归 60），缺失退出 2；`--status` 和只读派活不受此检查影响，被停掉的线不自动重派，Argo 先诊断；额度「空」退出 3，探针失败则警告后继续；重复派发保留请求快照；旧锁不自动清理；执行者不提交；常规实现／取证用 6.1 Sol，难活用 Astra；审查人和执行方型号不同，钱、权限、迁移类由 Claude 主会话核验实际状态，有界面的活 Argo 亲自看截图走任务。
docs/模块地图.md:164:- 2026-10-10 核对：桩测试 PASS 32；`bash -n` 三个脚本通过；`dex-exec.sh` dry-run 带 `--max-minutes 120` 输出上限一次；本机 codex-cli 0.160.0、Claude Code 2.1.295；额度探针实时读到两边。
```

### 逐处是否跟改文字

| 命中位置（修改后行号） | 判断及本次处理 |
|---|---|
| dex-exec.sh:3 | 需要，同步用法中的 --wait，已改；原其他选项仍各自可选，不把原可组合选项改成互斥 |
| dex-exec.sh:12 | 需要，说明写活必填、status 豁免、三种参考上限，已改 |
| dex-exec.sh:180 | 参数解析枚举，已认识 max-minutes，无文字需改；wait 在其独立分支 |
| dex-exec.sh:193 | 既有正整数分支标签，不需改 |
| dex-exec.sh:194 | 既有非法值提示仍正确，不需改 |
| dex-exec.sh:259 | 新增缺上限提示，文字按 C1 原样落地 |
| grok-exec.sh:6 | Grok 到时行为未变，不改 |
| grok-exec.sh:143 | Grok 参数解析未变，不改 |
| grok-exec.sh:158 | Grok 分支标签未变，不改 |
| grok-exec.sh:159 | Grok 正整数提示未变，不改 |
| division-of-labor.md:105 | 示例已显式带上限，仍可执行；若要展示 wait，可由后续文档任务补，按本次边界不动 |
| division-of-labor.md:111 | 限时/124/timed_out/status 的既有描述仍正确；可另补写活强制说明，本次不动 |
| escalation-and-learning.md:36 | 时间兜底仍正确，不动；其中 --stop 并非本次新增能力，不能因这轮 grep 顺手改 |
| escalation-and-learning.md:59 | timed_out 的统计定义仍正确，不动 |
| modes.md:42 | 只读派活带上限是流程建议，与只读参数不强制不矛盾，不动 |
| task-brief-template.md:43 | 任务书资源字段与派发上限要求仍适用，不动 |
| 模块地图.md:61 | 症状排查与 124 说明仍正确，不动 |
| 模块地图.md:117 | 旧接口说明可另补 wait/交回；本轮按 C6 保持原文，由新增第 129 行补齐 |
| 模块地图.md:119 | Grok 契约未变，不动 |
| 模块地图.md:120 | Grok 示例未变，不动 |
| 模块地图.md:122 | 原只读 dry-run 示例带上限仍有效，不动 |
| 模块地图.md:123 | 需要，原“一律”改为写活强制、status/只读豁免，与 C1 行为一致；已改 |
| 模块地图.md:164 | 历史验证记录，不能改写；不动 |

此外，头部注释第 15 行新增 wait，help 从 `sed -n '2,14p'` 改到 `'2,16p'`，覆盖新增说明及原 force/dry-run 末行；地图原第 128 行后新增一行交回与等待契约。地图其余文字未改。

## 给 CHANGELOG 的一句话

`dex-exec 写活强制 --max-minutes，交回按最终报告区分 empty（原成功改退出 4）与 short（仅警告），新增前台 --wait 摘要及离线桩覆盖；全量旧 guard 桩适配待调度方确认。`

## 没做成的与交回

- 全量 `run.sh` 仍退出 1，三条 guard 旧本地桩与空交回新契约冲突；需要调度方授权改该桩生成报告/转交公共桩，然后复跑同一全量命令。原断言不应改。
- C5 指定的 `only reply` 未替换成长回复；建议允许保留这个短回复回归，因为 short 只警告且该测试正用于验证无自写报告时最终回复落盘。若一定换成长回复，需要同时授权改对应严格相等断言，不应通过空白填充凑字节。
- 未运行真实 Codex、服务或安装；本任务规定离线，验证全部使用桩。

已做过交付前第二轮核对：补看了 1/199/200 字节边界、完整报告配短最终回复、旧 handback 重派清除、wait 失败路径以及原 errexit 行为；没有为兼容旧桩放松生产检查。

## 进度与清理

每次实际运行的验收项已追加到 `rounds/exec-T2.progress`。首次局测失败后更换为正确夹具，再通过；全量只运行了一次修改后验证，没有对同一失败无限重试。

本轮生成的手验目录 RSG2-manual、测试临时目录与临时验证日志在交回前清理；关键输出已收入本报告。没有生成 App、构建产物或旧版本备份。

完成状态：未全部完成
