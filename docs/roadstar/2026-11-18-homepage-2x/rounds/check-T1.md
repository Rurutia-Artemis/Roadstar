# T1 验收记录

## 结论
不通过

只有一处必须改：三份主页的「单家模式」一句仍说「纪要里写明」，而同一份主页第 3 条说 2.0 已把纪要屏收掉。其余项都过。

## 验收档位
重档

## 复跑的验收命令与输出
- 三个 `gen_*.py` 各跑两遍，15 个 SVG 的 SHA-256 两遍一致，且与提交里的一致（工作区无变化）。
- `python3 assets/readme/source/check_assets.py`：`PASS 15 SVGs; README.md references`，退出 0。
- `python3 assets/readme/source/check_assets.py --all`：`PASS 15 SVGs; three READMEs; no unreferenced SVGs`，退出 0。
- `bash skill/scripts/tests/run.sh`：退出 0，九套依次 PASS 90、20、95、36、42、8、18、40、23 checks。
- `wc -l assets/readme/source/*.py`：check_assets 273、common 61、gen_changes_workflow 131、gen_gates_lineup 103、gen_hero 106，均不超过 400。

## 逐项完成线
- C1 生成两遍一致、行数不超：过。
- C2 检查脚本：过。变异六次都退出非 0，还原后退出 0（见下）。
- C3 变异：缩小卡片（result-0 宽 578 改 300）报溢出；字色改 #F0F0F0 报对比度 1.14:1；加 `<script>` 报 forbidden element；删 `hero.ja.svg` 报文件不存在并连带报 README.ja.md 缺图；`lineup.svg` 画布高减 30 报离边留白和底卡出界；`workflow.svg` 一处字号改 8 报渲染 5.87px 小于 11px。六次还原后均退出 0。
- C4 旧图与旧脚本已删，三份 README 只引用新图名，`--all` 退出 0：过。
- C5 地图与 CHANGELOG 已登记，桩测试九套 PASS 数同基线，`skill/` 与 `install.sh` 无任何改动：过。
- C6 看图：用副本把根标签改成 `width="100%"` 后经 `qlmanage` 转 PNG，15 张逐张看过（见下）。

### 检查脚本查不出的情形（各试一次）
- 同一张卡里两段文字叠在一起（第二段 y 只差 2）：退出 0，查不出。
- 在文字上面盖一个同尺寸实心矩形（字被盖住）：退出 0，查不出。
- 只改某一语种的字（如中文 gates 把「派活前」改成「派活后」），三语版式和 `image-strings.md` 不一致：退出 0，查不出。
- `<title>`、`<desc>` 的内容不检查（改成本机路径也退出 0）。
- README 引用错语种的图（英文页引用中文图）：默认模式不报，`--all` 只以「某图没人引用」报出。
- 能查出的：README 引用不存在的图（`README.md`、`README.en.md` 各试一次，退出 1）。

### 15 张图
全部没有字溢出卡片、被裁、互相压住。逐张一句：
- hero 中、英、日：版式一致；英文小卡副句两行，首行与旁边单行副句基线一致，三卡等高；日文第二张小卡标题「Claude サブエージェント」字号略小于其他卡标题，可接受。
- changes 中、英、日：五行等高对齐，上下留白相等；第五行「探讨」「开工前」两行的英日文不在 `image-strings.md` 里（自译），含义与 1.14 原文对得上。
- workflow 中、英、日：七块与泳道、三个拦截标对齐；英日泳道标签折两行时上下留白偏紧（约 6 个单位），仍在卡内。
- gates 中、英、日：三行三格对齐，第三格留宽足够。
- lineup 中、英、日：左右两列、双向箭头两侧留白足，底条与卡片间距偏紧但不压。
图上的字与 `rounds/image-strings.md` 逐条对得上，除上面两行自译。

## README 事实核对（中文逐条；英日只核结构与数字）
- 版本 2.0.0：`skill/SKILL.md` 第 10 行 `metadata.version: "2.0.0"`。对。
- 正文 54 行对 224 行，18152 字对 4514 字：`wc -l`、`wc -m` 实测 224/18152（`skill/references/SKILL-v1.14.md`）、54/4514（`skill/SKILL.md`）。对。
- 「2.0 改了什么」七条：1 默认就跑（SKILL.md 第 15 行、description）对；2 三处脚本拦（SKILL.md 第 28、30、31 行；`dex-exec.sh` 第 265–268 行缺栏退出 2）对；3 屏幕收掉（CHANGELOG.md 第 220 行）对；4 一页设计与点头（SKILL.md 第 19–23 行）对；5 五查与换家验收（SKILL.md 第 29–30 行，`skill/references/check-template.md`）对；6 止损与两倍上限、`--calibrate`（SKILL.md 第 28、31、34 行）对；7 少拦错（CHANGELOG.md 11-17、11-18 条：14 种漏 2 种、五处误拦、两处漏拦）对。
- 11 月 3 日重写：CHANGELOG.md 第 216 行 `2.0.0 · 2026-11-03`。对。
- changes 图左栏「1.14」：点名才跑（SKILL-v1.14.md 第 4、11 行「用 skill」）、开场面板和策略一问（第 4、75 行）、默认三轮（第 40 行）、224 行（`wc -l`）均有原文；「写在正文里」对应 1.14 把规矩写在 224 行正文里，无单独一句原文，可接受。
- 「看它拦一次」三段：在副本的一次性演示仓库里真跑。第一段缺「执行环境」栏，`brief-check.py` 输出三行与退出码 2 与 README 逐字一致（任务书只缺这一栏时）。第二段 `git merge --no-ff` 被拦，输出「拦下了：这些任务还没有验收记录，不能合并」「怎么办…」「Not committing merge…」，与 README 一致（README 里路径换成相对路径，另有一行「这个项目没有模块地图，范围检查跳过」被省略）。第三段 `cleanup.py --check` 输出「收工检查：还有 1 项没收完」「没合并：T1…在分支 feat/export 上，1 个提交」，退出 1，与 README 一致。对。英日版三段命令与退出码与中文一致，输出正文保留中文。
- 型号一节：Fable 只做任务书和拍板、Sol 与 Astra 分档、Sonnet 做 Codex 做不了的并验收、Haiku 取证批量，与 `skill/references/dispatch-table.md` 第 8 行起及 SKILL.md 第 29 行一致，对。「Haiku 价格约为 Sonnet 的二十分之一」：`skill/references/models.md` 第 12 行写 Haiku $0.10/$0.50、Sonnet $2/$10，且明写「约 Sonnet 的二十分之一」，对（提示超 10 万 token 时 Haiku 贵到 $0.50/$2.50，约四分之一，README 未提）。Opus 三种情况：dispatch-table.md 第 8 行同段与 SKILL.md 第 29 行一致，对。
- 「单家模式…纪要里写明」：不对。SKILL.md 第 15 行与 CHANGELOG.md 第 220 行写 2.0 把纪要屏收掉；`dispatch-table.md` 第 34 行、`division-of-labor.md` 第 79 行仍保留旧说法「纪要和完工报告写明」，只有圆桌流程（`modes.md` 第 24、55 行）还写纪要。应改成「圆桌的纪要里写明『本场单家模式，审稿同家』」，并把中、英、日三份同步。
- 安装一节：`install.sh` 第 14–20 行软链到 `~/.claude/skills/roadstar`、`~/.agents/skills/roadstar`、`~/.codex/skills/roadstar` 并清旧 roundtable 软链，对。`codex --version` 要 0.160：`models.md` 写 0.158 报 400、0.160 通；本机 `codex login status` 子命令存在。对。`install-guard.sh <项目根> --claude`：`install-guard.sh` 第 40–41 行接受 `--claude`，实跑安装成功。对。
- 数据回传：默认关（`telemetry.py` 第 43–45 行要 config 明确开启），12 个字段（第 22–23 行 `KEYS` 与 `docs/社区数据回传.md` 第 19 行），子命令 `status`/`disable`/`enable`/`send`（第 246–251 行），`ROADSTAR_TELEMETRY=0`（第 44 行），用本机 `gh issue create`（第 216 行）。对。
- 「仓库没带」两样：会话结束转待办的钩子，`skill/scripts` 里无实现，SKILL.md 第 31 行只描述；点头记录工具，`design_page.py` 第 160–163 行到作者环境里的 `approvals.py`，仓库内无。属实。`ROADSTAR_DESIGN_CHECK=0`：`brief-check.py` 第 21、145 行存在，经 `skiplog` 记账，与 README 所说一致。对。
- 英日版：二级标题 12、图片 5、代码块 12、表格行 6、编号条目 19，与中文一致；数字（224、54、18152、4514、0.160、2.0.0、14、2、90%）一致。

## 降标准五查
- 下调门槛：无。
- 跳过或删测试：无。`skill/` 下没有任何改动，桩测试文件没有被改、删、跳过；九套 PASS 数与基线相同。
- 关掉检查：无。
- 留桩或半成品：无。
- 新增例外 / 改检查配置：无。新增行里没有 `noqa`、`type: ignore`、`skip`（命中的只是 README 英文里「skipped test」这句描述）。

## 公开前的最后一眼
15 个 SVG 的文字、`<title>`、`<desc>`、注释和五个新脚本里，没有本机绝对路径、邮箱、真人姓名、别的项目名；唯一的 `http` 是 `xmlns` 与检查脚本里的正则。

## 必须改
1. 三份 README「只订阅一家」一段里的「纪要里写明」改成「圆桌的纪要里写明」，或改成不提纪要的说法，与第 3 条不自相矛盾。

## 可以不改
- 检查脚本查不出文字叠压、被盖住的字、单个语种的字不一致、`<title>`/`<desc>` 内容。
- 工作流图英日泳道标签折两行时上下留白偏紧；日文英雄图第二张小卡标题字号略小。
- 型号一节可以补一句 Haiku 长提示时价格更高。

## 未验证
- 没有在 GitHub 上看实际渲染，也没有看手机宽度。
- 英文、日文译文的措辞没有核，只核了事实、结构、数字。
- `git show` 回放 T1b 之前的 `changes` 三版在新检查下是否失败：本轮到上下文上限，没有跑，只看了 viewBox 高从 480 改成 512、对照图下留白已补。
