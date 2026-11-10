# Roadstar · 更新日志

## 2026-11-10 · Roadstar-Task 尾注写绝对路径，旧相对尾注按主目录与各副本解析（不升版本）

起因：大脑线从副本 RuruAgent-slots/s4 提交，尾注 `../../Selene/docs/roadstar/2026-11-10-fable52-review/T26`，合并时按主目录解析落到不存在的路径，验收齐了也被报「没有验收记录」。场次 `docs/roadstar/2026-11-10-trailer-path/`。

- `skill/scripts/guard.py`：mark 写场次目录的绝对路径；副本里的路径统一换成主目录同位置（mark、prepare、commit-msg、merge 共用一个函数）；旧相对尾注先认主目录，主目录拼不出再按各副本根拼，按真实路径去重恰好一个才用，零个或多个拦下并打印试过的路径；绝对路径不存在报「计划目录不存在」；`/T1` 这类根目录场次直接拒。
- `skill/scripts/cleanup.py`：收工检查认绝对尾注。
- 测试：新 `tests/trailer-path-tests.sh` `PASS 18 checks`；guard-tests 五条断言随绝对路径改写、C9 一条期望改为主目录路径，全套 PASS。三遍复查：换会话验收通过；找茬两轮，第一轮两条必须修已修，第二轮无必须修。
- 真实数据：新版对 RuruAgent 主目录干跑 `check-merge brain/t26`，尾注解析到 Selene 下 fable52-review 的 T26，验收记录找得到，下一道降标准检查拦下 rca 文档里一行 `# noqa: E402`，要在 check-T26 的五查里点名。

## 2026-11-10 · plan 模板去掉和设计页重复的节，审稿带上设计页并加降标准一查（不升版本）

起因：总管修正第 3 条，设计页是「为什么做、怎么做、要问主人什么」的唯一一份。

- `references/plan-template.md` 删「1 目标与非目标」「3b 同类方案」「4 方案」「9 开放问题」，开头指向同目录 design.md，其余节号不重排。
- `brief-check.py --plan`：老 plan（有目标节）行为不变；没有目标节时读同目录 design.md 查同类方案，原因前缀「design.md：」。
- `dex-review.sh`：场次有 design.md 时请求多「设计页」一节，第二轮给快照与 diff；没有时请求与以前逐字相同。`dex-review-prompt.md` 与 schema：四项改看设计页，新增必填 `lowering`（降标准五查）。
- 测试：新 `tests/review-tests.sh` `PASS 19 checks`；验收 `check-T4.md`（Argo 复跑：8 份真实老 plan 新旧输出一致，无设计页时审稿请求新旧一致）。

## 2026-11-10 · 跳过记账、基线文件、未提交计数补强（复核 R1–R6，不升版本）

起因：Codex 只读复核 Argo 自己写的 skiplog、baselines、未提交卡三笔小改（`rounds/exec-T5.md`），查出六处：记账失败仍跳过、并发 ratchet 会回升、坏基线被当成首次初始化而放行、未跟踪目录按目录时间整批漏算、符号链接取目标时间、`nan`/`inf` 小时数无痕关掉判断。

- `skiplog.py`：记账成功才跳过，失败照常检查。`baselines.py`：每个名字读改写全程 flock，ratchet 单快照；文件存在但坏了抛 `BaselineError`。`entry-check.py`：坏基线退出 3 并提示；`--untracked-files=all` 逐文件、`lstat`；`ROADSTAR_DIRTY_STALE_HOURS` 只收有限非负数。
- 测试：新 `tests/baseline-tests.sh` `PASS 8 checks`，entry 36 条，全套 PASS；验收 `check-T6.md`（Argo 复跑）。
- 上线：计数改成逐文件后，未提交基线按新口径重记一次（只此一次，之后照旧只降不升）。

## 2026-11-10 · 未提交卡只算 24 小时没动过的文件（不升版本）

起因：上线当天 Argo 自己派 RuruAgent T3 就被未提交卡拒了：记忆那条线正在主目录改 tools/memory，25 个文件里大多是当天刚改的，基线在它中途提交时降到 21，再改就卡死正在跑的线。改成只数「积压」：24 小时内动过的文件当在干的活，不计；删掉的文件读不到时间照算。

- `skill/scripts/entry-check.py` 的 `dirty()` 按文件修改时间过滤，`ROADSTAR_DIRTY_STALE_HOURS` 可改（默认 24）；拒派提示补「只算 24 小时没动过的」。
- `tests/entry-tests.sh`：旧用例设 `ROADSTAR_DIRTY_STALE_HOURS=0` 保持原意，新增一条 24 小时口径（新改 12 个不计，调旧 3 个计 3）；`PASS 30 checks`。
- 验证：RuruAgent 主目录 dry-run 现在放行。Argo 自己写的约 20 行，派 Codex 只读复核。未验证：一个文件 24 小时内反复改、实际积压更久的情况会漏算。

## 2026-11-10 · guard 合并时查降标准、提交时查文件行数、接设计线的两条检查命令（不升版本）

起因：总管 11-10 派活书 P4、P6 与设计线接口。验收不查偷降标准（跳过测试、关检查、留桩）；文件越写越长没人拦。guard.py 由各项目钩子按 Roadstar 主目录绝对路径调用，合并即全部项目生效。场次 `docs/roadstar/2026-11-10-flow-gaps/`，裁定见 ledger.md 第 8、9、20 条。

- 新增 `skill/scripts/guard_rules.py`（298 行）：行数卡（提交时，新代码文件 > 800 行拦；已有文件超过 800 行的只许不变长，按 HEAD 行数比，改名按原路径；vendor、third_party、node_modules、dist、build、Pods、生成文件与 `.roadstar/guard.json` 的 length_exempt 豁免；`Roadstar-Length: 理由` 放行并打印）；降标准卡（合并时扫 HEAD...分支，五类：下调门槛、跳过或删测试、关掉检查、留桩、改检查配置；命中文件要在 `check-T<n>.md` 的「## 降标准五查」里点名；只扫上线后派出的任务，上线时刻存在 `baselines.py` 的 `lowering-scan`）；设计线接口（`.roadstar/guard.json` 里 `design_lint: true` 才跑 `design-lint check --project <根> --staged` 和合并动界面文件时的 `design-audit verify --check <验收记录>`，退出 1 拦，命令没装好不误拦并记一行）。
- `skill/scripts/guard.py` 只加 import 与调用，新增只读子命令 `audit <ref>`（列命中，退出码恒 0）。跳过开关 `ROADSTAR_LENGTH_CHECK=0`、`ROADSTAR_LOWERING_CHECK=0`、`ROADSTAR_DESIGN_GATE=0`，经 skiplog 记账。
- 新增 `skill/references/check-template.md`（验收记录模板，「降标准五查」必填）；`division-of-labor.md` 第 8 节指过去。
- 测试：新 `tests/guard-rules-tests.sh` `PASS 41 checks`，原 guard `PASS 50`；按总管要求 guard-tests 与 guard-rules-tests 只在设了 `ROADSTAR_GUARD_PROGRESS` 时写进度。Opus 换会话验收通过（`check-T3.md`）；回放 RuruAgent 已合并的两条记忆线，若放在今天会被三处 `# noqa: E402` 拦，点名即过。
- 上线：先记上线时刻再合并，之前派出的任务合并时不扫。未验证：五类关键词偏宽（例如注释里的 TODO 也算），先看一周命中再收窄。

## 2026-11-10 · dex-exec 派写活前查项目接入、没验收的存量和主目录未提交；首次派发不再误算返工（不升版本）

起因：总管 11-10 派活书 P2、P5 与修正第 4、5 条。project-shell 的钩子只在 Claude 会话改文件时拦没地图的项目，Codex 经 dex-exec 改文件不经过它，RuruBrain 的活就这样一次都没被拦；没验收的活越积越多（cardestiny mobile 130 多件）；按模板先存成 exec-T<n>-request.md 再派会被另存成 r2、算成返工。场次 `docs/roadstar/2026-11-10-flow-gaps/`，裁定见 ledger.md 第 3–6、17、18 条。

- 新增 `skill/scripts/entry-check.py`（210 行）：`gate <root>` 读 RuruAgent `check.py --json` 的 `structural_gaps`，接入没齐退出 3；`open_tasks` 去掉在跑的（无 .exit 且 24 小时内）后超过 max(基线, 5) 退出 3 并列最久的 10 件；主目录未提交（不含 docs/roadstar/）超过 max(基线, 10) 退出 3。基线用 `baselines.py` 的 `open-tasks`、`uncommitted`，只降不升；`baseline-init` 按登记表记现状，`show` 打印。RuruCode 外、AI任务 下跳过；check.py 缺失、超时、旧版没有字段时警告放行。跳过开关 `ROADSTAR_PROJECT_CHECK=0`、`ROADSTAR_OPEN_CHECK=0`、`ROADSTAR_DIRTY_CHECK=0`，经 skiplog 记账。
- `skill/scripts/dex-exec.sh`：写模式（含 resume）在 ws-guard 之后、dry-run 之前调 `entry-check.py gate`，退出 3 拒派；`choose_request` 在任务书就是 exec-T<n>-request.md 且没有旧 meta 时按第一次派、不另存。`dispatch-stats.py`：历史上 request 与 r2 逐字节相同的按第一次算。
- 测试：新 `tests/entry-tests.sh` `PASS 29 checks`（含从 run.sh 原样搬出的旧测试），run.sh 1624 → 1613；guard-tests.sh 派活夹具补一行 entry-check.py 桩（Argo）；全套 PASS。Opus 换会话验收通过（`check-T1.md`），按建议把 entry-tests 的进度写入改成只在设了 `ROADSTAR_ENTRY_PROGRESS` 时写。
- 上线：`baseline-init` 记下 13 个项目的现状（如 cardestiny mobile 131 件、Selene 8、Mia 10、RuruAgent 6 件与未提交 32 个）。

## 2026-11-10 · 任务书前加一页设计：设计页模板、design_page.py、brief-check 查设计页与钩子记的主人点头（不升版本）

起因：总管 11-10 派活书 P3。任务书之前没有「为什么做、不做什么、什么算失败」的程序检查；plan.md 写没写、主人点没点头没人查。superpowers 的 brainstorming 要求设计获批前不开工，但它没有程序拦截；这里做成 brief-check 的一项。总管修正：只有大活、新项目和「只有主人能答的问题」不为空的中活要主人点头，点头记录只认会话钩子从主人原话里记的（RuruAgent dispatch-gate，另一件活）。场次 `docs/roadstar/2026-11-10-flow-gaps/`，裁定见 ledger.md 第 7、14、15、19 条。

- 新增 `skill/references/design-template.md`：大小、为什么做、做完的样子、这次不做什么、哪种情况技术上跑通也算失败、两三种做法和选的那种、同类方案、模块表（模块｜职责｜依赖谁｜先后顺序）、只有主人能答的问题（每题带推荐答案，主人回「好」即全接受）、小事自己定的清单、主人点头（钩子记，不手写）。取自 obra/superpowers brainstorming 与 addyosmani/agent-skills spec-driven-development Phase 0，均 MIT。
- 新增 `skill/scripts/design_page.py`（可 import，以后的阶段记录也用）：`requires_design`、`find_design_page`、`size_of`、`design_problems`、`needs_approval`、`approvals`；同类方案规则从 brief-check 搬进来共用。
- `skill/scripts/brief-check.py`：新参数 `--class --est-minutes --write --plan-dir`，不给时与旧行为一致；写模式、非取证 / 复核 / 审方案 / 补全、且不是 ≤60 分钟的批量或窄回归时要 `设计页：<路径>`；老场次走 `baselines.py` 的 `design-exempt` 清单（`--init-design-baseline`）；`ROADSTAR_DESIGN_CHECK=0` 只跳设计页并记账，`BRIEF_CHECK=0` 也记进 skip-log。
- `skill/scripts/dex-exec.sh` 只改 brief-check 调用一行，把类别、预计、写模式、场次目录传进去。`SKILL.md` 六步前加「第 0 步 · 一页设计」（净增 6 行），第 2 步补半句；`task-brief-template.md` 加 `设计页：` 一行。
- 测试：新 `tests/brief-tests.sh` `PASS 67 checks`（含从 run.sh 原样搬出的 15 条旧断言），run.sh 1624 → 1548 行，全套 PASS。Opus 换会话验收发现 `str | None` 在系统 Python 3.9 上 import 失败，Argo 补 `from __future__ import annotations` 后复验通过（`check-T2.md`）。
- 上线：写入 73 个老场次豁免；大脑线三个场次最近 12 份任务书按各自参数试跑全部通过。未验证：真实主人回话 → 钩子写记录 → brief-check 放行的整条链路要等 RuruAgent 那边的写入端合并后再跑一次。

## 2026-11-10 · 本机基线与豁免清单的共用小模块（不升版本）

起因：流程补洞的存量上限要「只降不升」的基线，设计页检查要「老场次豁免」清单，降标准五查要「上线时刻」；总管要求这些做成以后阶段记录（stage.py）也能复用的形式，不各写一份。

- 新增 `skill/scripts/baselines.py`（94 行，标准库）：一个名字一份 `~/.config/roadstar/baselines/<名字>.json`，三种用法：豁免清单 `listed/add`（realpath 比较）、只降不升 `ratchet/get`、上线时刻 `since/mark_since`；命令行 `baselines.py show <名字>`。原子写。
- 验证：临时目录里 ratchet 7→9 仍 7、再 6 记 6；同一路径加两次只加一次，/tmp 与 /private/tmp 认作同一条；since 未记为 None、记后为正数。未验证：并发写（两个派活同时 ratchet 同一项目）没加锁，最坏是少降一次，不会升。

## 2026-11-10 · 跳过开关统一记账的小模块（不升版本）

起因：开发流程补洞（场次 `docs/roadstar/2026-11-10-flow-gaps/`）要加五道新检查，每道留一个跳过开关；主人要求跳过也要留痕。三条并行线都要用，先由 Argo 放一份共用的。

- 新增 `skill/scripts/skiplog.py`（42 行，只用标准库）：`skipped(检查名, 开关名, 项目根)` 在开关为 0 时往 `~/.config/roadstar/skip-log.tsv`（`ROADSTAR_CONFIG_DIR` 可改）记一行并在 stderr 说一句，返回 True；bash 用命令行形式，退出 0 表示已跳过。
- 验证：临时目录里开关为 0 时退出 0、记一行六列；不设开关退出 1、不记。未验证：还没有检查接入它（三条线接入时各自带测试）。

## 2026-11-10 · grok-exec 收尾同样不覆盖执行方的报告（不升版本）

起因：上一条修 `dex-exec.sh` 时查到 `grok-exec.sh` 有同一类问题。它在成功时执行 `cp "$LOG" "$OUT"`，执行方自己写的 `exec-T<n>.md` 会被整份 stdout 日志盖掉。协调方交办按同样规则修。

- `skill/scripts/grok-exec.sh`。旧：退出码 0 时把 `exec-T<n>-stdout.log` 整份复制成 `exec-T<n>.md`。新：退出码 0 时，`exec-T<n>.md` 非空且不早于本次请求副本，就把 stdout 日志追加成末尾「## 最终回复」一节；否则照旧复制日志。Grok 用 plain 输出，没有单独的最后回复文件，所以追加的是整份日志。失败和到点停掉时不碰报告，执行方已写的内容原样保留。meta、exit、退出码不变。
- `skill/scripts/tests/bin/grok` 桩加 `FAKE_GROK_REPORT=<路径>`，在输出前先写一份 40 行报告。`skill/scripts/tests/grok-113.sh` 新增 1 条（T5、T6）：执行方写了报告时全文保留，末尾只有一节「## 最终回复」，后面接日志，meta exit=0；没写（含上次留下的旧报告）时报告与日志逐字节相同。
- `docs/模块地图.md` 的 Grok 接口行补了收尾规则；`division-of-labor.md` 第 15 节 11-10 那一行补一句 grok-exec 同样修好。
- 验证：旧脚本跑新 `run.sh` 停在新增断言（grok-113.sh 第 97 行）。`bash skill/scripts/tests/run.sh` 退出 0：主套件 `PASS 115 checks`（上一条 114 加 1），guard `PASS 50`，close-check `PASS 13`；guard-tests 追加到 `exec-T2.progress` 的行已还原。未验证：没用真 grok CLI 跑一单；Grok 现在是 `--sandbox read-only`，实际能不能自己写 `exec-T<n>.md` 取决于任务书和 CLI 沙箱，没实测。

## 2026-11-10 · dex-exec 收尾不再覆盖执行方的报告（不升版本）

起因：今天两条线都踩到，`dex-exec.sh` 把 `codex exec -o` 直接指向 `rounds/exec-T<n>.md`，执行方写好的完整报告在收尾时被 Codex 最后一句短回复覆盖，验收方只能从 `exec-T<n>-stdout.log` 恢复。

- `skill/scripts/dex-exec.sh`。旧：`-o "$OUT"`，Codex 退出时用最后回复整份覆盖 `exec-T<n>.md`。新：`-o` 写到同目录隐藏文件 `.exec-T<n>.md.last-reply`（新派、`--resume`、`--detach` 的 worker 三条路径一致），codex 退出后先并报告再写 meta：`exec-T<n>.md` 非空且不早于本次请求副本，就在末尾追加「## 最终回复」一节；否则用最后回复生成。派活前照旧删掉上一次的报告和残留的回复文件。`.meta`、`.exit`、退出码不变。
- `skill/scripts/tests/bin/codex` 桩加两个开关：`FAKE_CODEX_REPORT=<路径>` 模拟执行方先写 40 行报告（在失败分支之前，便于测中途失败），`FAKE_CODEX_REPLY=<文本>` 作为最后一条回复写进 `-o` 并打到 stdout。
- `skill/scripts/tests/run.sh` 新增 4 条（T50–T53）：执行方写了报告时全文保留且末尾只有一节「## 最终回复」、隐藏文件已删、meta 的 exit 和 tokens 照旧、`-o` 指向隐藏文件；没写时由最后回复生成，上一次留下的旧报告不算；`--detach` 同样保留并追加；codex 中途失败时已写的报告原样保留、不追加、退出码照传。
- `skill/references/division-of-labor.md` 第 15 节表格加一行「11-10 踩坑：收尾覆盖报告」；`docs/模块地图.md`「任务执行与验收」对外接口补报告的收尾规则。RuruAgent `docs/模块地图.md` 只引用 `check_root.py`，没写这块行为，未改。
- 验证：先用假 codex（往 `exec-T1.md` 写 40 行报告、最后回复一句话）跑旧脚本，`exec-T1.md` 只剩 1 行；修后 45 行（40 行报告加最终回复一节），`/bin/bash` 3.2 + `LC_ALL=zh_CN.UTF-8` 下同样结果。旧脚本跑新 `run.sh` 停在 T50 第一条断言。`bash skill/scripts/tests/run.sh` 退出 0：主套件 `PASS 114 checks`（原 110 加 4）、guard `PASS 50`、close-check `PASS 13`；guard-tests 追加到 `docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 的行已还原。未验证：没用真 codex CLI 跑一单；`grok-exec.sh` 成功时 `cp "$LOG" "$OUT"` 也会覆盖执行方自己写的报告，这次没改。

## 2026-11-07 · guard 识别各项目模块表（不升版本）

- `skill/scripts/guard.py`：旧版模块表只认「模块 + 目录」，缩写路径按字面匹配；新版名称列支持「模块／名称／工具」，路径列取首个含「目录／路径／位置／正本」的列，展开「模块一览」表前的 `X`=`路径`；目录格只取反引号路径并过滤说明和外部地址。任务书先匹配完整模块名，再尝试去掉末尾中英文括号说明，保留本名中的括号。
- 新增只读命令 `python3 skill/scripts/guard.py modules <仓库根>`，每行输出 `模块名\t路径1, 路径2`，读工作树地图，不修改 Git 状态。入口行检查、无地图跳过提示及 `Roadstar-Scope`／`Roadstar-Map` 放行规则保持原样。
- `guard-tests.sh` 新增模块表 C1–C6 桩；`project-map.md` 补表头与缩写写法，`docs/模块地图.md` 同步新命令与测试范围。
- 验证：`bash skill/scripts/tests/guard-tests.sh` 退出 0、`PASS 50`（原 44 条及新增 6 条）；`bash skill/scripts/tests/run.sh` 退出 0，主套件 `PASS 110 checks`、guard `PASS 50`、close-check `PASS 13`。只读对账 Mia 37、RuruAgent 23、RUVO 23、Roadstar 8 个模块，Mia 终端路径展开到 `app/Workstation/Sources/WorkstationCore/`；旧 `exec-T2.progress` 已恢复。未验证：真实项目挂钩提交；按任务边界不安装、不提交、不推送。

## 2026-11-07 · 同类方案只在整体性的活触发（不升版本）

起因：上一条上线后实战误拦，任务书目标里写「新建的测试文件」「新建 `quota.py`」也被要求补同类方案。主席交办收窄。

- `skill/scripts/brief-check.py`。旧：目标里出现 新建／新项目／新系统／新模块／大改版／重做 任一个就要同类方案。新：只认整体性说法 新系统／新项目／新产品／新服务／大改版／重做／立项；「新模块」要同一目标里还有「系统」「服务」「App」之一才触发（提示写「新模块」+「服务」）；单独的「新建」「新增」「新模块」不触发。
- 触发条件的写法同步到 `task-brief-template.md`、`plan-template.md` §3b、`SKILL.md` 第 2 步、`dex-review-prompt.md`、`dex-exec.sh` 注释、`docs/模块地图.md`。RuruAgent `roadstar-铁律.md` 原文是「新系统先查同类方案」，和新条件一致，没改。
- 测试（`run.sh`）新增 6 条：「新建的测试文件」「新建 quota.py」「单独的新模块」不拦，「新系统」「大改版」「新模块 + 服务」拦并说触发词；原有两条用「新建记忆系统」当目标的改成「新系统：本机记忆服务」。
- 验证：`bash skill/scripts/tests/run.sh` 退出 0，主文件 110 条 ok、guard-tests 44 条、close-check-tests 13 条全部通过；`brief-check.py --plan` 对 plan 模板退出 0；`./install.sh` 退出 0。跑测试追加到 `exec-T2.progress` 的行已还原。未验证：「重做」仍在词表里，「重做按钮样式」这类小活会被要求写同类方案，遇到再收。

## 2026-11-07 · 新东西先查同类方案，brief-check 卡（不升版本）

起因：大脑和记忆系统一开始没查同类开源方案就自己造，后来才发现 claude-mem、Hindsight 等早有更好的做法（RuruAgent `docs/roadstar/2026-11-07-brain-prior-art.md`）。主席授权直接改。

- `skill/references/plan-template.md`。旧：§3 现状与约束之后直接是 §4 方案，没有要求看别人怎么做过。新：插一节「3b 同类方案」（不重编号，§10 拆分表等引用不变），目标里有 新建／新项目／新系统／新模块／大改版／重做 时必填，其余写「跳过：理由」；至少 3 个同类开源项目或产品，表格六列：项目、它怎么做、我们取什么、不取什么（为什么）、许可证、链接；查不到写「查过：关键词…，无」；许可证不兼容的只借做法不拷代码，取了的在 §4 关键决定里写来源。末尾规矩加第 4 条「§3b 写满了才写 §4」并写明起因。
- `skill/references/task-brief-template.md`。旧：六栏加背景等槽位，没有同类方案。新：「背景」后加「同类方案（只在新建模块 / 新系统时写）」，占位里写清触发条件（目标栏出现上面六个词之一），修 bug、改已有功能、调样式整节删掉；plan 里已有的照抄过来。
- `skill/references/dex-review-prompt.md` 清单加 `prior_art` 一项（plan-template 要求增删槽位时同步改它）。
- `skill/scripts/brief-check.py`。旧：只查任务书六栏。新：「目标」栏（任务书的「目标与做完的样子」，或 plan 的「1 目标与非目标」里除「非目标」以外的行，`<…>` 占位不算）出现上面六个词之一时，缺标题含「同类方案」的一节、或带真实链接的条目（列表项、表格行、### 小标题各算一条）少于 3 条，退出 2 并说缺什么、差几条；「查过：关键词…，无」放行。新参数 `--plan <plan.md>` 只查同类方案不查六栏；没有「目标与做完的样子」而有「数字 目标…」一节时自动按 plan 查。
- `skill/scripts/dex-exec.sh`：任务书过了六栏后，场次目录有 `plan.md` 就再跑一次 `brief-check.py --plan`，不过退出 2 不派。`SKILL.md` 第 2 步加一句，`docs/模块地图.md`「任务执行与验收」入口一行同步。
- 测试（`skill/scripts/tests/run.sh`）：新增 7 条。brief-check 四例按交办：有（新建 + 3 条带链接）放行、缺节拦并说「缺同类方案一节」、2 条带链接加 1 条没链接拦并说「只有 2 条」、普通修 bug 不要求；另加「查过…，无」放行、plan 认得出（「非目标：不做大改版」不触发，plan 模板本身放行，重做却只有 2 条拦）、dex-exec 遇到缺同类方案的 plan.md 退出 2 且不建 rounds。
- 顺手修了 4 处既有测试问题，全是测试写死了旧状态，脚本行为没改。原来 `run.sh` 在第 1166 行就停，后面的检查从 2.0.0 起一直没跑到，这次修通才露出后三处。
  1. quota-estimate 断言 `skill_version` 以 1.13 开头，面板断言首行是「Roadstar 1.13 · 接了」：改成从 `SKILL.md` 读当前版本（现在 2.0.0／2.0），开头再断言版本号是 x.y.z 格式。
  2. quota-estimate 断言 Codex 重置日含「10-19」：桩按真实当前时间 +3 天生成重置时刻，改成从探针 JSON 读期望值换算成 JST 再比。
  3. strategies.json 对表那条去 `SKILL.md` 找「### 8」：2.0.0 把 §8 派活表搬到了 `references/dispatch-table.md`，改读那份。
  4. `guard-tests.sh` C10 三条失败：测试把 `dex-exec.sh` 拷进临时目录时没带 `brief-check.py`（2.0.0 起多出一行警告），又会撞上本机 RuruAgent 的 ws-guard（10-28 起拒绝临时工作副本）。改成在临时目录放一个直接放行的 brief-check 桩、`WS_GUARD_DIR` 指向不存在的目录，C10 只测任务标记。HEAD 干净副本里跑 `guard-tests.sh` 同样是这 3 条失败（3/40），属既有问题。
- 验证：`bash skill/scripts/tests/run.sh` 退出 0，主文件 104 条 ok、guard-tests 44 条、close-check-tests 13 条全部通过（改前停在第 79 条后）。`brief-check.py` 对任务书模板仍退出 2、对 plan 模板 `--plan` 退出 0。`./install.sh` 退出 0，三处软链指向本仓库 `skill/`。guard-tests 每跑一次会往已提交的 `docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 追加几十行，这次跑完已还原，没提交进来。未验证：真实项目里还没有一份新系统 plan 按 §3b 写过、被 dex-exec 拦过；「新建」这个词在普通任务书里也可能出现（如「新建一个测试文件」），会被误要求写同类方案，遇到时可改写目标措辞或 `BRIEF_CHECK=0`，误拦多了再收窄词表。

## 2026-11-07 · 任务书模板：「根因」类活的完成线（不升版本）

吸收 mattpocock/skills 的 `diagnosing-bugs`（https://github.com/mattpocock/skills ，`skills/engineering/diagnosing-bugs/SKILL.md`，MIT，Copyright 2026 Matt Pocock），依据 RuruAgent `docs/roadstar/2026-11-07-github-trending-1104-review.md` 第五节与落地表第 4 条。只借做法，没有拷贝原文。

- `skill/references/task-brief-template.md`「目标与做完的样子」一栏，在原有占位说明后面加 4 行。旧：只有通用说明「完成线拆成编号检查项 C1 … Cn，每项一条能失败的数字或可观测条件」，根因类和别的活写法一样，没说怎么查。新：根因类的活完成线前三项固定，修复从 C4 起。C1 先交一条已经跑过、能在这个 bug 上稳定报错的复现命令（附命令和输出，密钥打码，偶发的写 N 次红几次），交了才开始猜原因，复现不出来就停下交报告；C2 一次列 3–5 个能被证伪的假设，每个写改哪一处 bug 会消失、用什么命令或观察证伪；C3 调试日志统一带 `[DBG-T<n>]` 前缀，收尾 grep 为空，报告写删了哪些文件的几行。
- `brief-check.py` 不改：它现在只查六栏齐不齐，没有按类别分的校验项，也拿不到 `--class`（`dex-exec.sh` 只传任务书路径），按交办条件这次不加「完成线含复现命令」的校验。
- 原技能里丢掉的部分：复现手段十种的清单和「把复现命令压到几秒、去随机」的打磨（Opus、Astra 本来会，写进任务书会把一栏撑长）；第二段「缩到最小复现」和第五段「有合适接缝才先写回归测试」（各项目的完成线会按活自己写回归测试，统一规定反而和 playwright-e2e 的测试规矩重复）；第三段「假设清单先给用户看」（我们的执行方不跟主席对话，清单写进报告由 Argo 看）；人在回路的 `hitl-loop.template.sh`（派出去的线不让主席手动点，界面验收已由 Argo 截图）；读 `GLOSSARY.md` 和 ADR（我们不维护术语表，和全局「不给东西起新名字」冲突）；性能分支「先量基线再二分」（性能类活在派活表里单列，有自己的指标写法）。
- 验证：`bash skill/scripts/tests/run.sh` 过了 79 条（含 brief-check 两例）后停在第 1166 行 quota-estimate 那条断言，它要求 `skill_version` 以 1.13 开头，现在是 2.0.0；在 HEAD 干净副本里跑结果一样（同样 79 条后停在同一处），属 2.0.0 起的既有问题，本次没处理。改后模板仍被 `brief-check.py` 拦下（只有占位，退出 2）。`./install.sh` 退出 0，三处软链指向本仓库 `skill/`。未验证：落地表要求的回放（拿 11-06 微信崩溃那次排查，看按新完成线写的任务书能不能更早要到复现命令）没做，记忆库搜「微信 崩溃 11-06 排查」没有结果；真实根因活还没按新完成线派过一次。

## 2.0.0 · 2026-11-03

主席 11-03 定：Roadstar 从「点名才跑的技能」变成项目会话的默认做法，规矩由程序卡（设计在 RuruAgent `docs/大脑与开发体系方案.md` 第九节）。

- `SKILL.md` 重写成两屏（7.4 千字，原 38 千字）：六步做活流程（判难度 → 六栏任务书 → 派活 → 换会话验收 → 收尾 → 对账），面板、策略一问、纪要、完工报告这些屏幕收掉；探讨和复盘改成主席点名「开圆桌」才跑，两家各出一轮短清单。1.14 全文留 `references/SKILL-v1.14.md`，§8 派活表搬到 `references/dispatch-table.md`，随时能退回。
- 新 `scripts/brief-check.py`：任务书六栏校验（目标与完成线、涉及模块、不许动什么、执行环境、验收命令、资源上限分钟数），`dex-exec.sh` 派活前自动跑，缺一栏退出 2 不派；`BRIEF_CHECK=0` 跳过并记一行；校验器不在脚本旁时只警告。
- 中活任务书不给主席过目（主席定）；没收尾的活由记忆服务的会话结束钩子记成待办（RuruAgent `tools/memory/hooks.py`）；铁律摘要 `RuruAgent/tools/rules-reminder/roadstar-铁律.md` 同步到六步。
- 验证：`skill/scripts/tests/run.sh` 全部通过（测试任务书改成六栏，新增 brief-check 两例）；`./install.sh` 重链。未核实：真实项目里第一次按 2.0 跑一遍（计划拿 Ludi 试点）。

## 1.14.1 · 2026-10-26

- 自动检查修一处路径：工位在主工作区以外、目录层级不同（如 `CardMaxJapan-slots/s1`）而场次目录在主工作区时，任务标记按工位记相对路径，合并时去 `主工作区/../../…` 找验收记录，找错地方，每条线合并都会被拦（Crepo 装上后当场复现）。改为场次在主工作区而不在本工位时按主工作区记相对路径；提交时本工位找不到任务书再去主工作区找。新增 `guard-tests.sh` C13（工位更深、场次在主工作区：标记、提交、合并三步），改前失败、改后 44 条全过。主席 10-26 批准 Crepo 会话直接改。
- `run.sh` 里额度面板那条写死「重置日 10-19」的断言仍随真实日期过期失败，未处理。

## 1.14.0 · 2026-10-25

主席 10-22 定的工作流重构（RuruAgent `docs/工作流重构/README.md`）里归 Roadstar 的三件，按 10-25 批准的改动清单第 14 到 17、20 到 23 条做。

- 自动检查（新 `skill/scripts/guard.py`、`install-guard.sh`，Codex T2 实现）：装进项目后，Roadstar 派活的提交自动带 `Roadstar-Task`；改动出了任务书「涉及模块」在地图里的目录、改了模块入口没改地图，提交时拦下；带任务号的提交没有 `rounds/check-T<n>.md` 不让合并（git 的 pre-merge-commit 加 Claude Code 的 PreToolUse 两层，后者顺带拦快进合并）。确实要越界或地图不用改，提交说明末尾空一行写 `Roadstar-Scope:` / `Roadstar-Map:` 理由。`ROADSTAR_GUARD=off` 整体关闭；`install-guard.sh --uninstall` 卸载并恢复原钩子。`dex-exec.sh --write` 派活时给工作区打任务标记。
- 收工检查（`cleanup.py --check`，Codex T3 起、T3b 改派 Astra 完成）：没合并的任务分支和工作副本、已合并没清的工作副本、有执行回复没有验收记录的活，逐条列出、退出码 1；SKILL §10 要求退出码 1 时不报「做完了」，报告第一行写「还没收完」。
- SKILL：§2 开工前查三样（新产品或大改版要有第三只眼的 `08-决定.md`、模块地图、有界面的再加 `docs/design.md`，缺了先走 third-eye 或 split-and-frame；修 bug 和小功能不查）；§9 有界面的活样式一律从 `docs/design.md` 取，写明自动检查怎么配合；§10 收工检查。
- Argo 验收中自己修的三处（各不到 30 行）：合并提交不再重复查范围和地图（Huemo 副本实测时，任务提交已写过 `Roadstar-Map` 理由，合并又被拦一次）；拦下的提示补「理由前要空一行，不空行 git 认不出」；钩子外壳找不到 `guard.py` 时提示一句并放行（仓库搬走时不至于挡住所有提交）。各补了一条测试。
- Codex 那一层没装：实测 `codex exec` 不会触发没被信任过的 hook（`docs/roadstar/2026-10-25-guards/codex-hook-实测.md`）；Codex 派的活约定不提交，git 那层已经兜住。
- 验证：`tests/guard-tests.sh` 43 条、`tests/close-check-tests.sh` 13 条在 `/bin/bash` 3.2 和 PATH 里的 bash 下都过；Huemo 本地副本里按真实地图跑了八种情况（范围内放行、越界拦、改入口没改地图拦、写了理由放行、没验收不让合并、Claude 敲快进合并拦、补验收后 `--no-ff` 合并成功、普通提交改非入口放行），然后装进了真 Huemo；收工检查对真 Huemo 只读实跑，列出 2 个没合并的工作副本。`run.sh` 第 1139 行的既有失败没处理。没验证：地图里用花括号简写的入口路径（如 `explore/{A,B}.tsx`）不会被识别为入口，属漏报；Mia、RUVO 还没装。

## 1.13.3 · 2026-10-25

- 1.13.1 定了「额度不够不自动降档」，但进度屏、`screens.md` 的提醒写法和两处降级梯子（`strategies.md`「额度不够时怎么排、怎么问」、`division-of-labor.md` 第 11 节）还写着「先降、再说一声我换回来」。统一成先问：自动走的只剩并行改串行、挂到重置后；降强度、换梯子、刷卡都列成选项问主席，主席回话前只派不受影响的活。问的写法固定一句。
- 一起提交 10-23 记忆库搬家改的 `CLAUDE.md` 路径，和 1.13.1 当时没提交的 `strategies.json` / `strategies.md` 自动分配一行。
- 版本号 SKILL.md 与三语 README 徽章从 1.13.0 补到 1.13.3。
- 验证：`grep` 全仓已无「说一声我换回来」；`scripts/tests/run.sh` 仍在第 1139 行失败，在 HEAD 干净副本里跑同样失败（1.13.1 已记，属既有问题），本次没处理。

## 1.13.2 · 2026-10-24

- dex-exec.sh 加 `--network`：只配合 `--write`、只给 `--class 取证` 的调研活，传 `-c sandbox_workspace_write.network_access=true`。起因：主席问「他为什么不能联网？」——Codex 沙箱写模式默认断网，补卡与找卡面图需要上网。验证：dry-run 三种组合（取证+write+network 带参数；复核+network 拒绝；无 write 拒绝），不加 --network 时命令不变。

## 2026-10-22 · 1.13.1：品质不打折，额度不够不自动降档

主席 10-22 定：不能糊弄，不能将就；额度不够要直说，由主席决定用低一档、暂停，还是先做 Codex 擅长的别的活。起因是 Crepo 分享卡一案：主会话在 Claude 周额度 91% 时，把设计稿、样张、分享卡视觉全派给 Codex，自己只核数字和测试，两版纯色底分享卡被主席评「谁会看」。

- SKILL 纪律新增「品质不打折」：Argo 不自己降级（不换低档型号、不改派便宜的一家、主会话不为省额度把要亲自判断的活交出去）；交给主席看的东西先问自己愿不愿意用、愿不愿意发。
- §8：两边都紧时，`strategies.md` 的降级顺序只作为给主席的选项，不自动执行。§9 进度屏：不论哪种策略都不自动降型号，额度不够先停下来问，主席回话前只派不受影响的活。纪律第一条「质量优先下额度不够」改为「额度不够」。
- `strategies.md`、`strategies.json`：自动分配一行由「额度紧就自动降档、换梯子，报一行」改为「额度紧先停下来问，不自动降档」；省着用、赶时间是主席开场主动选的，保留原样。
- 同日补：§8 加「重置卡见底才刷」——派活不等刷卡，余量先用完；撞线中断的线保留进度，主席刷卡后 `--resume <session_id>` 续跑（主席原话「必须得现在额度用完了你再刷呀」）。
- 验证：`scripts/tests/run.sh` 在第 1139 行失败（quota-estimate 的可解锁点数与重置日期断言）；把这次改的三个文件还原成 HEAD 版本后在副本里跑，同一行同样失败，属既有问题、与本次改动无关，未处理。改动的两个文案字段没有任何测试或脚本读取。

## 2026-10-16 · 1.13.0：两处面板修正，Grok 只读线接入

主席 10-16 定：1.12 报告里的三条待拍板都按推荐走，Codex 件数默认系数保留并随本机记录校准，策略开场只问一次，Grok 只读线接入。

- 面板修正：Haiku 停用括号写 Claude 的真实档位（紧、空、读不到）；`panel.py --host-model` 按主会话实际型号写主持说明，没填只写「我主持」。SKILL §0 和屏幕命令同步。两处毛病当时没修，是主会话为赶在额度用完前合并，先推了 1.12；主席指出后本版修正。
- 面板验证：未改动基线 PASS 83；只含面板修正的回归 PASS 85，覆盖 Claude 空、紧、读不到以及主持型号给与不给。
- Grok 只读线：新增 `grok-exec.sh`，沿用 Dex 的任务编号、请求快照、报告、日志、meta、exit、后台 PID、锁、项目登记与限时止损；固定 read-only 与 bypassPermissions，默认 grok-4.7 / high、30 轮，拒绝写活（退出 2），未安装或未登录退出 3，到点退出 124 并记 timed_out=1。token 与 session 无稳定读数留空。
- 流程接入：只有试新型号开关开且已登录才由 Argo 试派取证、复核两类只读活，复核仍须跨家；自动起步表不变，Grok 战绩满 5 条再决定进不进表。分配预览按开关和登录状态显示试用行，providers 角色、策略、SKILL 派活说明、型号说明和模块地图同步；telemetry 已有 model=other 路径，新测试从 Grok 实际 meta 验证，不改 schema 或生产回传代码。
- 发布：版本 1.13.0，三语 README 徽章、Grok 限制说明与生成脚本版本同步，运行头图生成脚本重出三张头图。验证：`bash skill/scripts/tests/run.sh` 最后一行 `PASS 94 checks`（83 旧 + 11 新），覆盖参数、中文全文、正常与失败产物、缺安装／登录、前后台限时、登记去重、试用开关与登录组合、Grok meta 回传为 other；三语 README 过 `audit_readme.py`；`bash -n`、`git diff --check` 通过。未验证：真实 Grok 推理与整场流程未跑。`./install.sh` 已尝试，写发现目录软链被当前沙箱拒绝，三个现有软链已核对都指向本仓库；本地提交同样因 `.git/index.lock` 写权限被拒，未 push。
- 兼容性修正：macOS Bash 3.2 的 `%q` 会拆开中文多字节字符，Grok dry-run 与状态命令改用 Python 标准库 `shlex.join` 转义；中文任务书回归已覆盖。

## 2026-10-16 · 1.12.0：开场面板、四种策略、排活表带预估与完工时刻（Fable 5.1 无头重构，分笔提交）

主席 10-16 定：用户一调用先弹出接入与额度面板（接了几家、各剩多少、重置卡算进去估总额度），问一次策略（回车 = 自动），新项目先探讨并说清讨论用高等级模型，讨论完排活给一张带型号、理由、预估用时、预计完成时刻和总账的表。设计见 `docs/2026-10-16-多家型号与自检闭环/设计v1.md`（第 0 节六条拍板压过全文），调研见同目录 `grace调研/`，校准见 `校准第一轮结论.md`。下面每条对应一个提交。

- 型号登记表 `references/providers.json`：8 家（Claude、Codex、Grok 三家订阅 CLI，DeepSeek、Kimi、Qwen、GLM、MiniMax 五家 API 只登记不接）、16 个型号，每条带接法、价格（R1 官方价，带查证日期和来源，DeepSeek 只有人民币就记人民币）、上下文、评测（R2 的 AA 指数、LMArena、TB4、SWE，查不到为 null）、默认角色、折算到标准件的倍率；`families` 带 API key 环境变量名（只查有无）和每标准件扣几个点的默认系数（Codex 0.3，写明上下界来源；Claude null 只显示百分点）；`partners.grace` 单列调研协作方。校验脚本 `scripts/providers-check.py`（缺字段、未知家、角色或日期不合法退出 2，`--list` 出表）。验证：桩测试新增 1 条（合法样例退出 0、四种坏样例退出 2）。未验证：价格和评测只到 Grace 10-16 的查证日期，没有二次核对链接可达。
- `scripts/quota-config.py`：读写 `~/.config/roadstar/quota.json`（`init` / `show [--json]` / `set 键 值`），只收 `default_strategy`（auto / quality / thrift / rush）、`try_new_models`、`grok_plan`（自报档位，只定上限）、`grace.enabled`、`grace.folder`；没有 API 预算键（主席 10-16 定 1.12 不问）。未知键或坏值退出 2 且不写文件；写入走临时文件改名；文件不存在时 `show` 给默认值并提示「填额度」。验证：桩测试 +1（未知键、坏值、往返、原子写、init 幂等、坏文件回退）。
- 额度探针 `quota-status.py` 加两列，旧字段一个不动：`grok`（跑 `grok models` 判登录和型号表，15 秒超时，不读额度，CLI 没有接口）和 `api_keys`（按 providers.json 的变量名单只查有无，值从不读进报告）。人读输出多两行「Grok：已登录 …（额度读不到）→ ？」「API key：有（…）；1.12 只记有无，派活不用」。桩 `tests/bin/grok` 覆盖已登录、未登录、出错、挂起四种。验证：桩测试 +1（假 key 断言不泄露、超时在打补丁的 0.3 秒内返回、没装 grok 时 `source=none`）；本机实跑 Grok 列出 grok-4.7 等 4 个型号、环境变量里有 ANTHROPIC_API_KEY。
- 四种策略起步层表 `references/strategies.md`（人读）和 `strategies.json`（机器读）：自动分配 = SKILL §8 那张表；质量优先往上挪到顶、额度不够停下来问；省着用往下挪、易活不派复核、并行 ≤ 2；赶时间不挪层、改并行（Codex 3 + Claude 3）和复核方式、性能活推迟。每类四列都有值、没有「同左」。SKILL §8 表加「复核」「审方案」两行（原来在表下段落里），版本号 1.12.0。预估默认值表 `references/estimates.json` 和说明 `estimates.md`：按校准第一轮和本机 233 条记录重定（页面实现 20 分、跨模块 60 分、取证 8 分等，比设计 v1 小一个数量级），强度倍率、型号快慢、Argo 任务书 5 / 验收 8 / 合并 3 分、缓冲 1.3、标准件 3.5 万 token。验证：桩测试 +1，断言 strategies.json 自动列和 SKILL §8 逐行相同（执行、上限、审查三格），strategies.md 含每个类别和策略。
- `scripts/quota-estimate.py`（共用模块 `rs_tasks.py`：拆分表解析、型号与强度归一、默认值读取）：读探针 JSON、providers.json、quota.json 和本机校准表，按「件」算每家还能派多少（可用点 = 90 − 已用；件 = 可用点 ÷ 每标准件扣的点）、重置卡只进「可解锁」、credits 只显示有、读不到的家不进合计、置信度（实时且已校准 高；默认系数 低；读不到 无）；系数未校准时件数带「约」并同时给百分点；`--session 探讨 --rounds N` 算讨论阶段 Codex 要扣几点，`--plan` 算拆分表够不够并指出第几件起会过 90%；输出里每个要上屏的数字都预先格式化（含 JST 重置时刻），面板只抄不算。验证：桩测试 +1（未校准带约、重置卡只在可解锁、Claude 读不到不进合计、本机校准表去掉约并升置信度、quota.json 默认策略与 `--strategy` 覆盖、探讨与拆分表两种够不够）；本机真实读数见重构报告。
- `scripts/panel.py`：渲染三段开场屏。接入与额度面板第一行直说「接了 N 家」加「＋Grace 调研」，每家一行读数（括号里是重置时刻）→ 档位、还能派几件，Grok 单列「？」和自报档位，API key 只写有无，合计行带置信度和百分点，可解锁与回满时刻一行，策略一行（默认的写「回车就按它」，其余三种列出），第一次用提示「填额度」，末行固定「要改说一声，不改我就跑」；全版不超过 14 行、80 列（按东亚宽字算）。本项目分配预览按策略表和额度方向实例化（Claude 紧或读不到时取证、复核退回 Codex 侧并配不同型号；单家模式写同家）。探讨开场说明三行（型号、预计扣几点几件、预计用时）。`--compact` 两行给续接和协同。验证：桩测试 +1，四种策略 × 四种读数的面板都 ≤ 14 行 ≤ 80 列，面板和开场说明里每个数字都能在输入 JSON 里找到（型号名里的数字除外），Claude 读不到、单家模式、压缩版各一条。
- `scripts/schedule.py`：读 plan §10 拆分表（或纪要里的表、或 `--tasks` JSON），每件拆成任务书 → 执行 → 复核 → 验收 → 合并五段，Argo 一条串行线（任务书、验收、合并都排在上面，这常是关键路径），Codex、Claude 线按策略有并行上限，某家周窗「空」时那家的线排在重置时刻之后，依赖拓扑排序、成环退出 2 并点名；用时按 estimates.md 的顺序取（本机 P80 → 本机 P50 × 1.3 → 默认值表），表里写了预估就用表里的；输出七列排活表（事、给谁 · 强度、为什么、预估、预计完成、审查人、依赖）加四行总账（线上工时与 Argo 用时、并行线数、关键路径、预计完工时刻、额度预计），超过 8 件折成「另 N 件同类」，`--json` 给机器。验证：桩测试 +1（依赖先后、六件独立活也至少要 6 × 16 分钟的 Argo 线、省着用并行 2、周窗空时全部线排在重置后并标注、成环报 T1、T2、T3、显式预估覆盖、第 9 件起折叠、本机校准表用 P80 且置信度高）；示例拆分表输出见重构报告。
- 预估对账与本机校准：`dex-exec.sh` 加 `--est-minutes N`、`--strategy auto|quality|thrift|rush`，写进 `.meta` 的 `est_minutes`、`strategy`（后台 worker 同样带上）；`dispatch-stats.py` 表加「预估偏差」列（(实际 − 预估) / 预估，取整到 5%，括号里是有预估的条数，旧记录没有就显示「—」），加 `--calibrate [--out]` 把本机各格（类别 × 型号 × 强度，以及型号 × 强度）样本 ≥ 5 条的 P50 / P80 分钟和 token 中位写进 `<配置目录>/estimates.json`，并按家把 `quota_delta` 和 `tokens_used` 累加，满 3 个点才算出每点 token 数（面板件数据此去掉「约」）。只改本机预估，不改起步层。验证：桩测试 +2。
- `scripts/cleanup.py` 场内垃圾清理第一档：列出本项目已合并进基准分支（origin/HEAD、origin/main、main、master 里第一个存在的）且干净的 worktree，和场次 `rounds/` 里超过 7 天的中间产物（stdout 日志、截图目录、补丁、图片录屏、xcresult）；有未提交改动或未跟踪文件、分支没合进、上游有未推送提交、`git worktree lock` 锁住的槽位一律不动并写明原因；`.meta`、任务书、执行回复、验收记录、进度文件、每轮快照和审稿 JSON 永不删。默认 dry-run 只列清单和预计释放空间，`--apply` 才删，`--json` 给完工报告用。验证：桩测试 +1（造五种 worktree 状态，dry-run 前后文件树哈希相同，apply 只删那一个干净的和三个旧产物，受保护文件全在）；本机对主仓库 dry-run 实跑，正确拒删本 worktree（有未提交改动、分支没合进）。
- 文档：SKILL.md 重写成产品级「使用步骤」：每一屏的形状（开场一条消息 = 面板 + 策略一问 + 分配预览 + 探讨开场说明；纪要带七列排活表；进度屏只写变了的；完工报告加预估对账、额度、清理三段）、什么时候问（只有四处要答）、沉默等于什么（策略回车 = 自动）；description 加面板、策略、排活表和「还能派多少活」「额度面板」「填额度」触发词；§8 表一字未改（只在 4/12 加了复核、审方案两行），策略偏移写明不写回表；谁是谁加 Grace；纪律加「数字不手填」「API key 只记有无」。新 `references/screens.md`：每屏的脚本命令和本机实跑的例子。同步改：`modes.md`（三种用法步骤与开口点）、`division-of-labor.md`（§1 加 Grace、§2 额度怎么读加 Grok / API key / 件数、§6 优先顺序加策略层、§11 降级顺序按策略、§12 加 quota.json、§13 成本加 tokens_used）、`minutes-template.md`（排活表七列加总账、完工报告三段、例子换成脚本形状）、`plan-template.md`（§10 加类别、预估列和填法）、`task-brief-template.md`（预计用时与上限规矩、验证方式只用写明的）、`escalation-and-learning.md`（§5 加 est_minutes、strategy、timed_out；§6 改成主席 10-16 定的 Claude 自己迭代、主席每周一句「可以迭代了」）、`models.md`（加 Grok 侧一节，指向 providers.json）、`docs/社区数据回传.md` §7（谁来改表）、`docs/模块地图.md`（加「额度面板与排期」模块、症状表六行、各模块接口与规矩、验证记录）。验证：新文无破折号、无「不是…而是…」；桩测试 PASS 83。未验证：按新 SKILL 走一整场。
- README 三语：加「开场一张面板，问一次策略，排活给一张表」配图（`assets/readme/panel{,.zh-CN,.ja}.svg`，生成脚本 `assets/readme/source/gen_panel_schedule.py`，数字取自 10-16 本机实跑的面板和示例排期），中文用大耳朵口气加一段讲面板、策略、排活表和「约」的含义，英日按风格指南 L1 各加一段；探针示例换成 1.12 的四行（含 Grok 和 API key）；限制段补「开场面板和排活表刚做、件数系数是默认值、Grok 不派活」；安装验证改 `PASS 83 checks`；徽章和头图版本 1.12.0。顺手把 `division-of-labor.md` 里两处旧破折号改成冒号。验证：三份 README 过 vela `audit_readme.py`；新图三语各在 900px 渲染核对一遍（qlmanage）；新文无破折号。未验证：GitHub 深色模式观感、360px 宽度。
- 第二遍（按《补充交代-第二遍.md》逐条对照）：面板对 Codex Pro 不再显示「5h 读不到」（Pro 没有 5 小时窗，R3）；分配预览三处规则改正：Codex 读到「空」时重置卡不算「现在就宽」，实现走 Claude 梯子、复核同家、刷卡后换回；两边都宽时自动分配下难活优先 Opus（主席 10-12 定、10-14 细化，写进 SKILL §8）；两边都读不到时预览先说「先修登录再派活」；单家模式下 Claude 紧不再把取证退回 Codex。Claude 子代理在面板和排活表里不再带「· 高」这种强度后缀。`providers.json` 加 `spot_check`（10-16 对 Grace 调研 20 条抽查：14 对、2 部分对、0 错、4 条没核成）和 Codex credits 单位说明；SKILL §9、division-of-labor §1 把 Grace 交接的 00-约定（Google Doc、「日期-来源-题目」、01-记忆账本记一行、对主席只回「OK 了」、网盘不放密码）和「交回后抽查一到两成、没核成的标未独立核实」写进去；`estimates.md` 加校准场的用法和局限；division-of-labor §4 写明「空就是空」。测试夹具里假 key 的值改成不像 key 的占位符，全仓 `grep -rI "sk-ant\|ANTHROPIC_API_KEY=\|api_key ="` 为零；panel 测试加 Codex 空、两边都宽两种情形。验证：桩测试 PASS 83；三份 README 审计通过；五种真实情况（只有 Claude、两家都在、Claude 空、Codex 空、什么都读不到）的面板用桩跑出来贴进报告。
- 重构报告 `docs/2026-10-16-多家型号与自检闭环/重构报告-1.12.md`：一句话结论、各模块改动、验证命令与输出（桩测试、本机真实面板与示例排期、README 审计、破折号检索）、没做成的和原因、第二遍改了什么、五种真实情况的面板、要主席拍板的三条（Codex 件数默认系数、策略一问的问法、Grok 1.13 只读线）、花费约 22 美元（以日志 result 行为准）、合并后主会话要做的四步。

## 2026-10-16 · 更正：Luna 改为「还没实测」，不再写主席判它太差

主席 10-16 更正：10-04 写进型号表的「Luna 太差」是听别人说的，主席自己没用过；要公平，等大家用的时候一起反馈，不要写死。

- `models.md` Luna 一行：用途改为「还没实测，可在机械批量、只读取证这类简单活里试用」，注意点写明 10-04 的说法来源和唯一一次冒烟记录，试用时强度可拉到 high 或 max，战绩照记、随社区回传汇总，攒够数据再决定进不进起步表。
- `SKILL.md` 谁是谁、`division-of-labor.md` 第 1 节和第 7 节表下说明同步改写；默认起步层仍不含 Luna（因为没有数据，不是因为判过它差）。
- `docs/` 下 10-04 那几场的历史记录保持原样，记的是当时实际发生的事。
- 验证：`grep -rn -i luna skill/` 只剩更正说明里引用的「太差」一词，已没有把 Luna 定为不派活的规则。未验证：Luna 在真实任务里的表现，等第一批试用和社区数据。

## 2026-10-14 · 测试修复：额度探针测试清理进程时偶发 PermissionError

1.10.0 记下的「第 192 行偶发失败」查清了：失败在额度探针测试最后的清理步骤 `os.killpg`。macOS 在进程组只剩僵尸进程时返回 EPERM 而不是 ESRCH，测试只接了 ProcessLookupError，机器负载高时撞上这个时间差就报错；要验的「子进程已被关掉」断言在清理之前，一直是过的。

- 修改：`tests/run.sh` 清理处同时接 `PermissionError`，只动测试，不动 quota-status.py。
- 验证：修前新版 14 次挂 3 次（同一行），1.7.0 基线 11 次全过（基线没撞上，代码里同样有这个时间差）；修后连跑 12 次 PASS 73，0 次失败。

## 2026-10-14 · 1.11.0：社区自动回传上线，数据仓库 roadstar-data 公开

主席 10-14 定：手动提交没人做，要用户同意一次后全自动回传，安全、透明要讲清楚；作者固定每周迭代一次，直到够准。

- 新建公开仓库 Rurutia-Artemis/roadstar-data：`schema/dispatch-v1.json`（12 个字段，全是固定选项或取整数字）、`validate.yml`（Issue 进来校验，合格打 accepted，不合格打 rejected、评论原因、关闭；正文和标题不进 shell）、`aggregate.yml`（每周日 00:00 JST 汇总，按记录去重、每人每周最多 50 条、5 条且 3 人才给建议，产出不含用户名）、三语 README 与头图、MIT 加数据 CC0。脚本与测试由 Codex（6.1 Sol / high）实现，362 条离线检查通过。
- Roadstar：Codex（6.1 Sol / high）实现 `skill/scripts/telemetry.py`（status / enable / disable / send，dry-run，本机留底，失败下次补传，`ROADSTAR_TELEMETRY=0` 关闭）和 `tests/bin/gh` 桩，测试 60 → 73 条；schema 副本放 `skill/references/dispatch-v1.schema.json`。SKILL §0 加第一次开场问一次与三句开关话术，§9 完工前发送；`docs/社区数据回传.md` 定稿；README 三语加「数据回传」一节；模块地图加「社区回传」。版本 1.11.0。
- 验证：Argo 复跑 Roadstar 桩测试 PASS 73、数据仓库 PASS 362；本机 `telemetry.py status` 显示还没问过、待回传 0 条（旧记录没有 class 和 outcome，不会被发）。线上端到端：临时项目真发一条 → Issue #1 自动 accepted，埋在 meta 里的 notes 秘密值没有出现在正文；手动提交夹带 project 路径的 → #2 rejected、评论只写「含 schema 未允许的额外字段」、自动关闭；手动触发汇总 → 社区表出现该条且不含用户名；随后删除两条测试 Issue（第一次删除遇 GitHub 502，重试成功）并重新汇总，社区表清空。未验证：别人的机器、没装 gh 的补传路径只在桩测试里验过；每周定时汇总的 cron 还没自然触发过。

## 2026-10-14 · 1.10.0：所有人共用一张分工表，项目登记表，开场提醒新版本

主席 10-14 定：所有人用完提建议，作者汇总更新后所有人一起变好，不要出现每个人各自适配、越分越开的分支；别人装的副本要提示更新。

- 规则：起步层只按 SKILL 第 8 节那一张表，表只随新版本更新（社区汇总加主席拍板），本机记录不单独改本机起步层，只用来回传和出周报；escalation-and-learning 第 6 节重写，周报调整门槛加「来自至少 3 个不同的人」；`docs/社区数据回传.md` 草案同步。SKILL §0 开场跑 `update-check.py`，有新版本在开场一行末尾提醒；§1 建场次时 `dispatch-stats.py --register`；没有仓库的任务目录改为 `~/roadstar-tasks/`（作者本机照旧）。版本 1.10.0。
- Codex（6.1 Sol / high）实现：dex-exec.sh 真派活时把项目根登记进 `<配置目录>/projects.txt`（去重、加锁、写失败只警告）；dispatch-stats.py 默认按登记表和 `ROADSTAR_PROJECTS` 扫描、加 `--register`，删掉写死的 `~/Documents/RuruCode`；新增 `update-check.py`（24 小时缓存、fetch 8 秒超时、断网静默、`--apply` 工作区干净才 `git pull --ff-only`）；测试 46 → 60 条。
- README 三语安装段加一句新版本提醒，徽章和头图 1.10.0；模块地图同步。
- 验证：Argo 复跑桩测试 PASS 60 checks；真实仓库 `update-check.py --force --verbose` 输出「Roadstar 已是最新 1.9.0」（提交前）；作者本机登记 5 个项目后 `dispatch-stats.py` 默认扫描结果与改前一致（233 条去重记录）。未验证：别人机器上从 GitHub 克隆后的首次登记与更新提醒；社区回传仍未实现（草案未提交）。另：全量测试连跑四次有一次在第 192 行失败，是额度探针「关闭后子进程 2 秒内退出」那条（quota-status.py 自 1.0.0 未改），其余三次 PASS 60，记为偶发，待查。

## 2026-10-14 · 1.9.0：探讨开头加功能地图，先把要做什么想全，再谈工程

主席 10-14 定：很多人只知道主功能（想做个类似 X 的软件），主功能周围有哪些设置、选项，还能衍生出什么功能，用户自己想不到，要靠两个模型一起讨论补全；这一步讨论完才谈工程怎么安排最稳，没有它整个技能不闭环。

- 新增 `references/feature-map.md`：什么时候做（新产品、带界面的新模块；纯工程改动跳过）；五步（Argo 写骨架含对标产品的功能和设置 → Argo 和 Dex 按十个角度各自独立发散，每条写给谁、达成什么效果、成本 → Argo 合并标出两家共同想到的 → Dex 审合并稿找空角度和过度设计 → Argo 预填「这版必做 / 下版再说 / 不做」交主席只改不同意的）；给 Dex 的发散请求原文；单家模式由和主会话不同型号的 Claude 子代理来想。
- SKILL.md 加 §1.5 功能地图，探讨流程、description（加「我想做个类似 X 的」「帮我规划功能」「还能加什么功能」触发词）同步；modes.md 探讨步骤、plan-template 加 §0 功能地图、dex-review-prompt 清单加 `feature_map`、minutes-template 加「这版要做的功能」；模块地图规矩行同步。版本 1.9.0。
- README 三语正文加「先把功能想全」一段，三种用法图的探讨卡改为先功能后工程，徽章和头图版本 1.9.0。
- 验证：桩测试 PASS 46 checks（脚本未改；审稿 schema 的清单项是自由文本，加一项不影响）；三份 README 过 `audit_readme.py`，三种用法图三语 900px 渲染核对；新文与 README 无破折号。未验证：功能地图没在真实一场探讨里跑过，十个角度的取舍和 Dex 发散请求的产出质量待第一场检验。

## 2026-10-14 · 英日 README 按风格指南 L1 清理

主席 10-14 让清理英日 README 里和 cardestiny STYLE_GUIDE_EN/JA L1 不一致的地方。

- 两份「What it fixes／何が楽になるか」段的五个加粗引导句改成 `###` 小标题；日文去掉三处中黑「・」三项并列（含头图标语和三种用法图的卡片文字），四处「あなた」改成不带人称的说法。
- 验证：`audit_readme.py` 两份通过；日文头图 900px 渲染核对；Codex（6.1 Sol / medium，只读）对照两份指南 L1 复审，回复没有成簇或明显违反的地方。

## 2026-10-14 · 1.8.0：Claude 四层按活常驻，碰壁就停、升级补全，派活经验回路

主席 10-14 定：Claude 这边 Haiku、Sonnet、Opus、Fable 四个型号都要编排进来，Haiku 5.5 便宜又能干，做廉价活；Codex 只有两层不够用。最重要的是迭代：靠真干活的结果让 skill 知道什么活派给什么型号最合适；不浪费额度，一条线做到九成、剩下一成碰壁几次就马上停，用更高级的型号补全；以后只用 Claude 时四个型号也这样混用、这样迭代。Fable 的用法主席选「主会话 + 卡死时出手」。

- SKILL.md：谁是谁、第 0 节开场一行（实现方向之外写取证批量和复核由谁做）、第 2 节取证默认 Haiku、第 8 节改成两家六个型号（常驻活不看 Codex 额度：取证和批量 Haiku、Codex 写的中难活 Sonnet 复核；实现按额度方向；起步层先看经验表；表里加「碰壁后的补全」和「两轮没收敛的第三轮」两行）、第 9 节子代理派法与止损、单家模式审稿改 Fable 子代理（Fable 列紧时 Opus）。版本 1.8.0。
- 新增 `references/escalation-and-learning.md`：升级链（Haiku → Sonnet → Opus → Fable；Sol → Astra → Opus 或 Fable；强度也算一级）、进度文件格式、停的信号（同一检查项连续三次失败、空转、用掉九成时间）、只把没过的检查项交高一级补全、`.meta` 战绩字段、经验回路门槛（样本满 5 次，完成率 ≥ 90% 降起步层，< 60% 或碰壁率 > 30% 升一层，主席点头才改表）、只用 Claude 时的做法。
- models.md 加 Claude 侧 API 价格（Haiku 5.5 $0.10/$0.50、Sonnet 5.5 $2/$10、Opus 5.5 $4/$20、Fable 5.1 $10/$50，claude-api 资料缓存 2026-10-06）；division-of-labor 第 1、7、8、9、10、14、15 节同步；task-brief-template 完成线拆编号检查项、写进度文件。模块地图加「碰壁止损与派活经验」一节。
- Codex（6.1 Sol / high，任务书在会话 scratchpad）实现：`scripts/stall-watch.py`（OK / STALL / WRAP / IDLE / NOPROGRESS，退出码 0/10/12/11/13）、`scripts/dispatch-stats.py`（扫各项目 `docs/roadstar/**/exec-*.meta`，按 session_id 或内容去重，按类别 × 型号 × 强度出完成率、碰壁率、升级率、用时和建议）、`dex-exec.sh --class`；测试加 14 条。
- README 三语：加「两家六个型号」分工图和「碰壁就停、越用越准」循环图，正文加碰壁止损与经验回路两段，单家模式审稿改 Fable，限制段写明这套还没实跑。生成脚本 `assets/readme/source/gen_lineup_loop.py`。
- 验证：Argo 复跑桩测试 PASS 46 checks（原 32 条不变）；`bash -n dex-exec.sh` 通过；`dispatch-stats.py` 实扫 233 条去重后的真实记录（原始 244 条，11 条是 worktree 副本），全部「未分类」、没有 outcome，所以经验表从下一场起才有数；`stall-watch.py` 样例同一项连败三次输出 `STALL C2 fail×3`、退出码 10；Agent 工具 `haiku` 实测是 `claude-haiku-5-5`；三份 README 过 `audit_readme.py`，新图 900px 渲染核对。未验证：四层常驻、碰壁升级、经验回路都没在一整场真实派活里跑过；Max 订阅里各型号扣额度的倍数没有官方数字，要靠 `quota_delta` 攒；Monitor 每 5 分钟跑 stall-watch 的盯线方式没实测。另一会话未提交的 division-of-labor 第 15 节三行没有放进本次提交。

## 2026-10-14 · README 加分段标题条、数字卡、重点色

主席 10-14 问 README 能不能有分段和重点色。实测 GitHub 删掉 `style` 和 `<font color>`，正文不能上色；能用的是 SVG、五色提示框和 `<mark>`。

- 新增 `assets/readme/` 的分段标题条（中文 4 张、英日各 3 张）和数字卡（三语各 1 张），颜色角色：金色讲为什么、青色讲实证、珊瑚色讲限制、墨色讲安装。三份 README 的故事段 `##` 换成标题条，目录和声明保留 `##`；中文正文两处 `<mark>`，安装段加 TIP 和 IMPORTANT 提示框（英日加 TIP）；英日的「真跑过」列表换成数字卡。
- 生成脚本放进 `assets/readme/source/`（只用标准库），改字或改色重跑即可。
- 补记：README.ja.md「…アプリなど」句末补「です。」（ruru-github 预览时发现）。
- 这一套同步写进 vela（RuruAgent `skills/vela/references/github-readme/layout-and-emphasis.md`，SKILL.md README 标准第 8 条）。
- 验证：`audit_readme.py` 三份均通过；GitHub markdown 接口渲染 + headless Chrome 在 900px、380px 两个宽度截图核对，标题条加大到 56 单位后 380px 宽约 16px。未验证：GitHub 深色模式下的观感。

## 2026-10-14 · README 默认改中文，用大耳朵口气重写

主席 10-14：公开仓库的 README 太 AI 味，中文用大耳朵 skill 写，英日按各自常规写法；默认语言改中文，不用英语。

- `README.md` 改为中文大耳朵版（开场用了多久、三个问题逐条兑现、满意点、缺点自限、分人群建议、收尾），内容取自 docs/Roadstar介绍.md，补上额度探针真实输出和规矩实例；安装、给 AI 的五步、目录、声明保持干脆写法。原英文版挪到 `README.en.md`，删 `README.zh-CN.md`，英日两份的语言切换链接跟着改。
- 验证：`audit_readme.py` 三份均通过；大耳朵禁用词（接下来、你只需要、破折号、不是而是）检索为零。未验证：英日两份没按「各语言规范」重写，因为本机没找到单独的英文或日文写作规范，仍是上一版的标准 README 写法。

## 2026-10-14 · README 加给 AI 的安装步骤

主席 10-14：现在朋友都是把仓库地址直接丢给 AI 让它装，README 要让 AI 一次装对。三份 README 的安装段各加五步：克隆到长期目录（安装是软链，删了就失效）、跑 install.sh、验证软链和桩测试、查 Codex 版本与登录（登录要开浏览器，让人自己跑 `codex login`）、提醒重开会话。

- 验证：在临时 HOME 里从 GitHub 克隆、跑 install.sh，三处软链都建好，桩测试 PASS 32 checks；`codex login status` 在本机输出「Logged in using ChatGPT」。未验证：没有真找一个别人的 AI 只拿链接装一遍。

## 2026-10-14 · 上 GitHub：三语 README、配图、MIT 许可与声明，介绍文档压短

主席 10-14 要把项目发给朋友试：介绍文档再简洁、优势写大；仓库上 GitHub，README 按 vela 的 GitHub README 标准（吸收自 beautify-github-readme）配图，中英日三语、默认英语。

- README.md 改成英文默认版，新增 README.zh-CN.md、README.ja.md；顺序是 hero、真跑过的数字与额度探针真实输出、解决的三个问题、三种用法图、安装、目录、声明。shields.io 徽章五枚（Claude Code skill、Codex CLI ≥ 0.160、版本、依赖、许可）。
- 新增 `assets/readme/` 六张纯 SVG（hero 与三种用法各三语），母题是四角引路星连着各条执行线；新增 LICENSE（MIT，与 Reverie 同署名）。
- docs/Roadstar介绍.md 从约 5200 字压到约 2000 字，保留大耳朵口气；版本说法改为现状，数字换成实数：10-04 以来 4 个项目 17 场、Codex 会话 244 次（Sol 130、Astra 114）、division-of-labor 第 15 节 31 条规矩，均从各项目 `docs/roadstar/**/exec-*.meta` 和第 15 节表格数出。
- 验证：`audit_readme.py` 三份 README 均通过；SVG 在 900px 和 360px 用 headless Chrome 渲染核对无溢出；README 经 GitHub markdown 接口渲染后截图核对；英日两版由 Codex（6.1 Sol，只读）对照中文审过。未验证：GitHub 深色模式下的实际观感；单家模式仍未实跑（README 已写明）。

## 2026-10-12 · 1.7.0：设计类活的默认——Huemo 配套、方向主席挑、两遍 review、默认打磨两遍

主人 10-12 定：做 App 或网页时动效、图标、配色全部先从 Huemo（彩动，原 Rurumo）配一套匹配主题的，没有合适的再去别处；设计 review 两遍（每个按钮的细节、按钮与主题的符合度）；元素偏大、动效给足、不满不空；默认打磨两遍再交，他看后决定是否继续；近期助手自选方案和他选的完全不一样，方向一律他定。细则写在 vela（RuruAgent 同日提交），这里只放派活与验收的接口。

- SKILL.md 第 9 节加「设计类的活」一条：开工前 Argo 按 vela 第 4 步从 Huemo 配套，编号写进任务书和项目 `design.md`；方向稿出 2–3 版给主席挑；完成线写两遍 review 与默认两遍打磨，交付物含两张问题清单和打磨记录；Argo 验收核对编号出自 Huemo 目录、记录在不在，少一样不算完成。版本 1.7.0。
- task-brief-template「目标与做完的样子」槽位加设计类三样（Huemo 编号、已选方向稿路径、两遍 review 与打磨记录）。模块地图规矩行同步。介绍文档加一段设计默认。
- 验证：桩测试 32 条全过（脚本未改）；`node lookup.mjs sets` 读到 Huemo 三套（克制 / 弹性 / 华丽）。未验证：还没有一件设计类活按这条派过。另一会话未提交的 division-of-labor 第 15 节两行（换槽位核对分支、外壳改动跑全量）没有放进本次提交，由它自己记。

主席 10-10 定：只订阅 Claude 的人也要能用，核心原理不变；只订阅 GPT 的版本以后单独做再融合。

- SKILL.md 第 0 节：`codex --version` 跑不出来或 `codex login status` 未登录即进单家模式，开场一行有单家写法；探针的 Codex 列在没有 codex 时会退回本地 rollout 记录，不作「有 Codex」的依据。第 1 节审稿人写「Opus 子代理（同家）」、Pro 不参与。第 3 节：不跑 `dex-review.sh`，Argo 自己快照、diff、按同一份审稿契约拼请求，派 Opus 子代理按 `dex-review.schema.json` 出 JSON，`render-review.py --from Opus` 渲染，议题前缀 `O`。第 8 节末加单家模式一段：只剩 Claude 梯子、同家审稿写进纪要、复核仍换型号、钱权限迁移 Argo 亲验。版本 1.6.0。
- modes.md 复盘 Codex 侧改派 Haiku / Sonnet 子代理；division-of-labor 第 1 节 Pro 要 ChatGPT、第 7 节加单家一段；ledger-format 加前缀 `O`；models.md、README、模块地图同步。
- 验证：隐藏 codex 后跑探针，Codex 列显示 `source=rollout` 的旧读数（所以判定只认 `codex --version`）；`render-review.py` 读到 `--from` 参数；桩测试 32 条全过（脚本未改）。未验证：单家模式整场没实跑，Opus 子代理按 schema 出 JSON 的稳定性没测。

## 2026-10-10 · 1.5.0：Claude 子代理按 Haiku → Sonnet → Opus 梯子可派，方向看两边额度

主席 10-10 定：Claude 这边 Haiku、Sonnet 现在都够强，便宜活给 Haiku、常规给 Sonnet、难活给 Opus 更合理；Codex 是几个项目并行时的分流，这个月它送的重置卡多。10-05「不派 Claude 子代理」改为按额度方向启用。

- SKILL.md「谁是谁」加 Claude 子代理一行；第 0 节开场一行写明执行走哪条梯子；第 2 节取证派当前方向最低层；第 8 节改成两条梯子（Codex：6.1 Sol → Astra；Claude：Haiku → Sonnet → Opus，Fable 不当子代理），表的执行列两条并列，方向规则：Codex 宽或正常或有重置卡走 Codex，几个项目并行也走 Codex；Codex 紧或空且 Claude 正常或宽走 Claude 梯子；Claude 周窗紧或空梯子关闭；Codex 宽时派 Claude 梯子理由栏必须写一句。第 9 节加 Claude 子代理派法（Agent 工具 `model`、任务书原文、`.meta` 手写、TaskStop 止损）。版本 1.5.0。
- models.md Claude 侧表改成梯子三层加 Fable，Haiku 版本改到当前 5.5；八二分那段和实测对照表的取证行跟着改。
- division-of-labor：第 1 节加子代理一行与 10-10 决定；第 7 节第三列（Codex 紧、Claude 多）全部换成 Claude 梯子，加「验收 Claude 梯子做的」一行；第 8 节复核优先跨家；第 9 节加 Claude 梯子派法；第 10 节换梯子算换方向；第 14 节加子代理与主会话共用周窗。modes.md 复盘 Claude 侧取证可派 Haiku。README、模块地图同步。
- 验证：桩测试 32 条全过（脚本未改）；额度探针当日实读 Claude 周 84% / Fable 45% / Codex 周 40% 带 2 张重置卡，按新规则这周应走 Codex 梯子。未验证：Claude 梯子没在真实一场里派过；TaskStop 止损没实测；便宜型号扣额度的倍数没有权威数字，第一场派前后读差值补。
- 提交说明：这条的七个文件改动在工作区待主席点头时，被另一会话 09:38 的 `commit -a` 一并带进了提交 743ee55（消息只写了它自己那行），内容完整、没有丢，不改历史。那一行是第 15 节新教训：两条并行线约好一条放占位、另一条写正式版，合并后同名定义并存 iOS 编译失败，合并脚本又只编了 Mac 端，白等一轮；以后任务书写明占位文件路径和「合并时谁删」，合并检查每个平台都编一遍，编不过不进测试。
- 主席 10-10 另问：只订阅 Claude 的人能不能用。现状是两份脚本和审稿都依赖 Codex，没有「没有 Codex」的分支；梯子省额度的思路能借，审方案会变成 Claude 审 Claude。要支持得另开一条：Codex 读不到时审稿改 Opus 子代理并在纪要里标同家、执行走 Claude 梯子、两份脚本跳过。未动手，待主席定。

## 2026-10-09 · 1.4.0 补丁（下午五笔当天漏记，10-10 补）：第 15 节加三条教训、有界面的活接入 vela 界面验收、dex-exec 上限显示修正

- division-of-labor 第 15 节新增三行，都来自 Mia 手机版 T79/T80 与真机复测：任务书里报告和截图写绝对路径、收尾脚本提交前排除产物目录、Argo 合并前看 `git show --stat`（起因是一次把 846 个测试产物提交进分支）；验收夹具照主席真实用法造，先读实际配置、把真实程序输出录成字节流回放、与参考实现逐行比对（起因是终端滑动和中文排版两次都是主席在真机上发现）；取消排队外壳用标记文件控制并 `pgrep -fl` 复核，补测命令照抄跑通过的那条只改 `--only`。
- 有界面的活接入 vela 的 `references/ui-acceptance.md`：SKILL.md 第 9 节加一条，任务书完成线要包含界面自查和截图清单（真实数据、长内容、滚到中间、深浅色、iPad），Argo 验收时亲自逐张看截图、在模拟器里走核心任务，阻塞和应修清零才发版，主席报过的问题进项目 `docs/界面验收清单.md`；division-of-labor 第 8 节加同一条；task-brief-template「目标与做完的样子」槽位加界面自查句和 3–5 件走查任务。
- `dex-exec.sh`：时间上限那行此前把分钟数打印两遍（`${MAX_MINUTES:+…}` 和 `${MAX_MINUTES:-无}` 在有值时都展开），改成先拼好 `CAP_TEXT` 一处，dry-run 和派活两处共用。
- 另一会话 10-10 00:23 又加一行（来自 Mia T90）：任务书让 Codex 用 `yes > /dev/null` 压满 CPU 测性能，它在跑着生产服务的同一台机器上照做，主席当晚终端变卡。以后压测只许在隔离环境做；必须同机做时写死上限（最多占一半核、`nice -n 20`、每次不超过 30 秒），任务书写明这台机器同时跑着主席在用的服务。
- 验证（10-10 补跑）：桩测试 32 条全过；`bash -n` 三个脚本通过；vela 的 `ui-acceptance.md` 存在（83 行）；dry-run 带 `--max-minutes 120` 只打印一次「时间上限：120 分钟」。未验证：界面验收那条还没在真实一场里按清单走过；模块地图在这五笔和 1.3.0 / 1.4.0 时都没同步，10-10 另一笔补。

## 2026-10-09 · 1.4.0：「用 skill」自动判用法，拆活与审查绑成一张表，派发脚本带止损

主席 10-09 拍板四件：开场「选模型」那一问改成报一行默认、不等答复就跑；探讨默认 3 轮（规模大 4，复盘 1）；「全面 review / 全部排查」并进复盘的代码层；Codex 不拆活、不分配、不做决定，只在讨论环节提意见、执行环节干活和复核。

- SKILL.md：新增「先判用法」路由表（续接 > 直接干 > 探讨 > 复盘 > 协同，按顺序取第一条）；第 0 节改为开场一行不等答复，只在额度紧或空、主席要逐件指定、要换总调度时才问；第 1 节熔断改 3 / 4 / 1；第 8 节改名「拆活与分配」，把执行方、时间上限、审查人绑成一张表（页面级 Sol / high 2h、窄回归 Sol / high 1h、跨模块 Astra / high 4h、根因不明 Astra / xhigh 2h、性能 Astra / high 每小时看、设计 Argo 样张、钱权限迁移 Argo 亲验、Argo 自改超 30 行 Sol 复核）；第 9 节派发带 `--max-minutes`；description 加「用 skill」「全面 review」触发词。版本 1.4.0。
- modes.md：加「续接」；复盘分产品层 / 代码层两把尺子，代码层按模块并行派只读线；协同里拆分表报一次就派，主席改哪条停那条重派。
- division-of-labor：第 1 节记 Dex 不拆活不分配；第 8 节加 Argo 自改超 30 行的复核；第 9 节加 `--max-minutes`；第 15 节加边界块临时手写那条；新增第 16 节项目常驻边界文件 `docs/roadstar/_common.md`。plan-template §10 改成拆分表列头（模块 / 完成线 / 上限 / 审查人 / 依赖）；task-brief-template 加「项目常驻边界」槽位；minutes-template 推荐表改拆分表并加「谁审」列。
- `dex-exec.sh --max-minutes N`：到点 TERM、十秒后 KILL，退出码 124，meta 记 `max_minutes` / `timed_out`，`--status` 提示被停止，dry-run 显示上限；后台模式同样生效。
- 验证：桩测试 32 条全过（新增 3 条：到点停掉、后台模式与 status、坏值拒派与 dry-run）；`bash -n` 通过；新 description 在本会话已可见。未验证：路由表和一行开场还没在真实一场里走过。

## 2026-10-08 · 1.3.0：两天实战的十四条教训进第 15 节，止损与能力画像

来源是 Mia 移动版 10-07 / 08 约 20 条 Codex 线、5 个 TestFlight 版本。division-of-labor 第 15 节：一份任务书一个目标、完成线能失败、按文件归属切线、沙箱外真验收的边界块、模拟器最多两条、测试 shell 禁历史、合并后挪 worktree、发版前主会话复跑、设计归 Argo 样张、大活先探讨、额度见底走主席消息通道、止损（时间上限 + 每小时看指标、两轮不收敛第三轮 Argo 查根因）、完成线在能测准的环境里定、编号一律 T<n>。models.md 加实测能力画像与八二分、型号与强度对照表。task-brief-template 加能失败的完成线、执行环境边界、资源上限与止损、收尾。当时没写本日志，此条补记。

## 2026-10-05 · 1.2.0：删除 Claude 子代理，实现统一交 Codex

主席 10-05 定：Claude 主会话只做调度、任务书和验收，实现交 Codex；Claude 子代理会消耗主席的 Claude 额度，不再派。

- 删除 `agents/roadstar-builder.md`、`agents/roadstar-builder-hard.md`、`agents/roadstar-builder-light.md`、`agents/roadstar-checker.md` 及 `~/.claude/agents/` 下四个同名软链接；其他代理目录项不动。`install.sh` 不再安装或清理 Claude 子代理，只管理 skill 软链接。
- 分工：常规实现、机械批量、只读取证用 `gpt-6.1-sol`，难活用 `gpt-6-astra`，按任务显式选强度；Codex 调用保留 `-s`、`-m`、`-c model_reasoning_effort=`、`--disable fast_mode`。第 0 节选模型、推荐表由主席定的规矩保留；浏览器或模拟器核验由 Claude 主会话自己做，或交具备环境的 Codex，不再派 Claude 子代理。
- 验收：Claude 主会话自己跑命令核对 Codex 实现，或另开 Codex 只读会话复核（不续接执行会话）；钱、权限、迁移类配 Claude 主会话跨家核验，不接受执行会话自验或仅同家复核；主会话执行的工作区外操作配独立 Codex 只读核验，缺少验收方时交主席或挂起。
- 同步正文、分工／型号／流程／纪要／方案／账本模板、README、项目约定、模块地图及升级任务书中的旧代理引用。版本 1.2.0。
- 验证：`skill/scripts/tests/run.sh` PASS 29（临时文件放仓库内，设置 Git 查找边界；首轮未设边界时根目录断言失败，调整测试环境后全过）；`bash -n install.sh` 通过；仓库内隔离安装两遍，三个 skill 入口正常且其他代理不变。四个文件及软链接均已删除，源码 grep 仅剩本条记录；直接递归还命中 `.git/index` 的二进制历史文件名，按授权不修改索引；`git diff --check` 通过。
- 未验证：真实模型派工、Claude 主会话验收、浏览器／模拟器流程及重开会话后的发现；按本轮授权不运行真实安装，不改仓库外 skill 软链接，不提交或推送，不写仓库外共享记忆。

## 2026-10-04 · 1.1.0：项目地图——上手、修改、找 bug 都从一页地图出发

主席 10-04 定：以后的项目都要模块化，让 Codex 和各个模型进项目马上知道有什么、改哪里，不用翻长上下文；三件事都要简单：上手、修改、找 bug。

- 新增 `skill/references/project-map.md`：地图放 `docs/模块地图.md`，项目 CLAUDE.md / AGENTS.md 各加一行指过去；固定写法（一句话、怎么跑怎么测、模块一览、「出了问题先看哪」症状表、每个模块：管什么 / 入口 / 对外接口 / 依赖 / 怎么测 / 规矩 / 细节）；每节不超过十行，只写现状，路径命令要能用。
- SKILL.md §2：取证从地图开始，没有或过期先派一件活建 / 补地图（Codex 6.1 Sol / medium 只读起草，Argo 核对后提交）；§9：任务书写明涉及模块，改了入口、接口、测试命令或规矩就同一提交更新地图，验收核对地图与代码一致；纪律加一条。版本 1.1.0。
- `task-brief-template.md` 加必填槽位「涉及模块」；`modes.md` 复盘步骤第 3 步先看地图（后面顺延编号）。
- 验证：`skill/scripts/tests/run.sh` 全过；`./install.sh` 软链正常。
- 未验证：第一张真地图是 Mia（工作站）那场，建图这件活还没跑；地图和代码一致的验收还没有脚本检查，靠验收方人工核对。

## 2026-10-04 · 1.0.0：改名 Roadstar · 引路星，搬到独立仓库，加「开始前选模型」和「派活前先推荐、主席定」

用户 10-04 定名 Roadstar（引路星），要求搬到 RuruCode 下独立文件夹便于迭代；开始前一定要给他选模型的权利（总调度用什么、探讨和审稿用什么、执行怎么分，他大多数情况想自己选）；派活前每件活先推荐交给哪个模型并写明理由，最后由他决定；功能分三种：协同、复盘、探讨，探讨阶段用最强模型，干活才用便宜的。

- 搬迁：`RuruAgent/skills/roundtable` → `Roadstar/skill`，`RuruAgent/global/agents/rt-*` → `Roadstar/agents/roadstar-*`，10-04 升级的记录 → `Roadstar/docs/2026-10-04-dispatch-upgrade`。skill 名 roadstar，各项目记录目录改 `docs/roadstar/<日期>-<slug>/`（旧 `docs/roundtable/` 照旧能读）。软链：`~/.claude/skills/roadstar`、`~/.claude/agents/roadstar-*.md`、`~/.agents/skills/roadstar`、`~/.codex/skills/roadstar`；旧的 roundtable / rt-* 软链已清。
- 正文：（Opus 子代理按提纲改，见 docs/2026-10-04-roadstar-1-0/）第 0 节「选模型」：列出两边能用的模型和额度，AskUserQuestion 一次问三件事，主席答了才开始；纪要第 5 段改成「推荐分工表」（推荐给谁 / 理由 / 备选），问「按推荐来还是改哪几条」，主席定了才派；新建 `references/modes.md` 写三种用法的流程（复盘：两家各自只读取证各出不足清单 → 合并 → Dex 审 → 不足清单 + 先做的三件事）。
- 前身账目：roundtable 0.1.0 → 0.3.1（2026-09-24 至 10-04）在 `RuruAgent/CHANGELOG.md`。
- 验证：`skill/scripts/tests/run.sh` 在新位置 PASS 29（桩里的 clientInfo 跟着改成 roadstar / 1.0，改前挂一条）；`quota-status.py` 真跑读到两边；`./install.sh` 链好四处、清掉旧的 roundtable 与 rt-* 软链；会话重开后 skill 以 roadstar 的名字和新 description 出现，四个 roadstar-* 子代理可用；RuruAgent 那边 `audit-skills.sh` 退出码 0（roadstar 记为场外在册）。
- 未验证：第 0 节选模型那一问和第 5 段推荐表还没在真实一场里走过，下一场开场就是验证；复盘用法的两份不足清单流程没实跑；0.3.0 留下的三项（关 Fast 档省不省、阈值初值、6.1 Sol 当审稿人和实现者的质量）照旧。
