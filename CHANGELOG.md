# Roadstar · 更新日志

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
