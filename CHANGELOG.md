# Roadstar · 更新日志

## 2026-10-10 · 1.6.0：单家模式，本机没有 Codex 也能跑

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
