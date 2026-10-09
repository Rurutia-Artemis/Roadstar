# Roadstar · 更新日志

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
