# T1c 验收记录

## 结论
通过

针对 `7ac1db7` 这个最终状态：可以公开。没有必须改的事实或意思错误，没有私人信息命中新增内容、图片文字和图片元数据。

## 验收档位
重档

## 复跑的验收命令与输出
- 三个 `gen_*.py` 各跑两遍，`assets/readme/*.svg` 的合并散列两遍一致，工作区相对提交无变化（与提交一致）。
- `python3 assets/readme/source/check_assets.py --all`：`PASS 15 SVGs; three READMEs; no unreferenced SVGs`，退出 0。
- `bash skill/scripts/tests/run.sh`：退出 0，九套依次 PASS 90、20、95、36、42、8、18、40、23 checks。
- `wc -l assets/readme/source/*.py`：273、61、135、108、137，均不超过 400。
- `git diff --exit-code 0eaf26b 7ac1db7 -- 'assets/readme/*.zh-CN.svg'`：退出 0。
- `git diff 3afe4b6 7ac1db7 -- skill install.sh`：0 行。

## 接手的两份记录（check-T1.md、check-T1b.md）
抽查站得住，原文未改。
- 散列两遍一致且与提交一致：复跑相同（现在是 7ac1db7 的状态，不是它验的 0eaf26b）。
- `--all` 退出 0、桩测试九套 PASS 数：复跑相同。
- 变异：在 `git archive` 出来的副本里做，不动克隆。把 hero 的 card-T1 宽 140 改 90，退出 1，报 `'Writes code': overflows 'card-T1'`；把 `lineup.svg` 画布高 461 改 431，退出 1，报底边留白和底卡出界；还原后退出 0。
- 注意：`check-T1.md` 的结论「不通过」是针对 `0eaf26b` 的，那一处必须改（单家模式一句）已在 `6b8529f` 改掉，见下。
- 两份记录里没有本机绝对路径、人名、别的项目名。

## 逐项完成线
- C1 / 图上字：`rounds/image-strings.md` 英文列、日文列每一条，在对应语种的 SVG 里按去空白后拼接比对，全部找到，对不上 0 条。表外的图上字（改版对照图的「开工前」「探讨」两行、英雄图 `CLAUDE CODE SKILL · v2.0.0`、`T1`、`T2`、`✓`、脚本名）保持现状。
- C2 中文五张逐字节不变：过。
- C3 `--all` 退出 0：过。
- C4 没改字的图逐字节不变：`6b8529f` 到 `7ac1db7` 之间变动的只有英文 changes、gates、hero 和日文 changes、gates、hero、lineup、workflow；英文 workflow、lineup 与五张中文图没变。各图 viewBox 宽高与 `6b8529f` 相同（英文 hero 472，日文 hero 463，其余同前）。过。
- C5 回归：见上，过。
- C6 变异：在副本里把英文英雄图第三句重复三遍，重新生成后 `check_assets.py --all` 退出 1，报 `'Scripts enforce the rules.': overflows 'intro'`；还原脚本重新生成后退出 0，三张英雄图与提交逐字节相同。过。
- 返工 R1：英文第三句以句号结尾，脚本和图一致。过。
- R2：英文英雄图左栏两句副文各占一行，看图确认。过。
- R3：折行行距取字号 1.35 倍的规则在脚本里；现在三版都不折行，没有实际场景可看，只读了代码和执行方的变异记录，没有自己造折行输入。
- R4：`04a6ed8` 到 `7ac1db7` 之间图和脚本只有 `hero.svg`、`gen_hero.py` 变动，另有 `CHANGELOG.md`。过。`check_assets.py`、`common.py` 在 `6b8529f` 之后没改。
- R5：C3、C5、C6 重跑，见上。过。

## 十张图（英文、日文各五张，根标签换成 100% 后转 PNG 逐张看）
- 英文 hero：左栏两句主句、两句副句各占一行，行距均匀，右侧三卡等高，底条字居中，无溢出。
- 日文 hero：版式与英文一致，卡内标题、副句不出框，第二张卡标题字号略小于其他卡，可接受。
- 英文 changes：五行等高对齐，上下留白相等，无溢出。
- 日文 changes：同英文版结构，字不出框。
- 英文 workflow：七块与三条泳道对齐，泳道标签折两行但在框内，上下留白偏紧。
- 日文 workflow：结构同英文，「Codex か／サブエージェント」折两行在框内。
- 英文 gates：三行三格对齐，第二行说明折两行但不出格。
- 日文 gates：三行三格对齐，说明单行，无溢出。
- 英文 lineup：左右两列、箭头两侧留白足，底条与卡片间距偏紧，不压。
- 日文 lineup：结构同英文，字不出框，底条间距同样偏紧。
三语同图版式结构一致（卡数、排列、对齐）。

## 三份 README
- 「单家模式」一句三语都已改成「并明说『本场单家模式，审稿同家』」（中文第 117 行、英文第 123 行、日文第 123 行），不再说写在哪，和第 3 条（2.0 收掉纪要屏）不矛盾。和 `skill/references/dispatch-table.md` 第 34 行比，没有新的冲突；该行仍写「纪要和完工报告写明」，是技能文件里的旧说法，README 没有重复它，场次账本的停车场已记。
- 英文、日文从头到尾读了一遍，对照中文：二级标题各 12、图片引用各 5、代码块各 6、编号条目各 19、列表项各 10、表格行各 6，一致；数字（224、54、18152、4514、0.160、2.0.0、14、2、90%、12 个字段、两小时、一小时）、文件名、命令、版本号一致。三份的代码块内容逐块比对：控制台输出三份相同；目录树块和任务书骨架块里的说明文字在英文、日文里按语种翻译，命令和路径相同。没有漏句、多句、意思相反或强弱明显不对的句子。英文里没有把整件活叫 run 的地方（`run` 只作动词，或指一次真实运行），日文里没有「裏取り」「議事録には」（第 38 行的「議事録」是指 2.0 收掉的纪要屏，与中文对应）。
- 三份 README 里的相对链接和图片路径都指向存在的文件（`--all` 也覆盖了图片引用）。

## 公开前检查
- 新增内容和图片：`git diff 3afe4b6 7ac1db7` 全部新增行、15 个 SVG 的文字、`<title>`、`<desc>`、注释，没有密钥、令牌、邮箱、电话、主机名、内网或 100.x 地址、会话链接。
- 本机绝对路径命中（仓库内会被提交的文件，全部在 `docs/roadstar/2026-11-18-homepage-2x/rounds/`）：`brief-T1.md:46`、`brief-T1b.md:24`、`brief-T1c.md:25`、`exec-T1-request.md:46`、`exec-T1.md:7`、`exec-T1.meta:4`、`exec-T1b-request.md:24`、`exec-T1b-request-r2.md:24`、`exec-T1b.md:3`、`exec-T1b.meta:4`、`exec-T1c-request.md:25`、`exec-T1c-request-r2.md:25`、`exec-T1c.md:7`、`exec-T1c.meta:4`；另有 `exec-T1-report.md`、`exec-T1b-report.md`、`exec-T1c-report*.md` 里提到共享记忆服务所在机器（「M1 服务」，`exec-T1-report.md:136`、`exec-T1b-report.md:136`、`exec-T1c-report-r2.md:28`）。这些路径带用户名和本机项目目录名，账本 16:01 一条已说明同类写法在已公开历史里早就有。
- 真人姓名、别的项目名：新增内容里只有「主人」这个称呼（`design.md:7`、`design.md:41`、`exec-T1-request.md:21`），没有具体姓名。
- `docs/roadstar/**/exec-*-stdout.log` 没被跟踪，`.gitignore` 第 12 行匹配；`git ls-files | grep stdout.log` 有一个结果 `docs/2026-10-04-dispatch-upgrade/rounds/exec-T1-stdout.log`，它在基线 `3afe4b6` 之前就已跟踪，不在 `docs/roadstar/` 下，不是这次新增。
- `check-T1.md`、`check-T1b.md`、本文件：无本机路径、人名、别的项目名。

## 降标准五查
- 下调门槛：无。`check_assets.py` 和 `common.py` 在 T1c 里没改；允许的字号下限、留白、对比度门槛没动。
- 跳过或删测试：无。`skill/` 与 `install.sh` 相对 `3afe4b6` 零改动，桩测试文件没被改、删、跳过，九套 PASS 数同基线。
- 关掉检查：无。
- 留桩或半成品：无。
- 新增例外 / 改检查配置：无。新增行里没有 `noqa`、`type: ignore`、`skip`（命中的只是英文 README 里「skipped test」一句描述）。

## 必须改
无。

## 可以不改
- 场次目录里的执行方运行记录（任务书副本、`exec-*.md`、`.meta`）带本机绝对路径和用户名，会随提交公开；账本说明历史里已有同类写法，是否推送前去掉由调度方定。
- `skill/references/dispatch-table.md` 第 34、36 行仍写「纪要和完工报告」，和 2.0 正文对不上（已在账本停车场）。
- 检查脚本查不出同卡两段字叠在一起、字被图形盖住、只改某一语种的字、`<title>` 的内容。
- 英文、日文工作流图泳道标签折两行时上下留白偏紧；日文英雄图第二张卡标题字号略小；英日 lineup 底条和卡片间距偏紧。
- `docs/2026-10-04-dispatch-upgrade/rounds/exec-T1-stdout.log` 是更早就被跟踪的执行回显，不属于这次。

## 未验证
- 没有在 GitHub 上看实际渲染，也没有看手机宽度。
- 英文、日文措辞好坏没评，只核了事实、结构、数字、术语。
- R3 的折行规则没有自己造折行输入看效果。
- 变异改的是 `git archive` 出来的副本，不是克隆本身；`check-T1b.md` 里「T1b 之前的 changes 三版放回后是否失败」仍没验证。
