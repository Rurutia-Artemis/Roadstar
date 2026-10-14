# Roadstar · 更新日志

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
