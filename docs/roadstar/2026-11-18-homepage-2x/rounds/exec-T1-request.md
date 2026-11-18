# T1 · 重画 Roadstar 公开主页五张配图（三语共 15 个 SVG）
设计页：docs/roadstar/2026-11-18-homepage-2x/design.md

## 目标与做完的样子
重做公开主页配图：5 张图（hero、changes、workflow、gates、lineup）各出中、英、日三版，由脚本生成，并新增检查脚本。画法沿用旧图（见 `assets/readme/source/` 旧脚本）：米色圆角底卡、深墨字、金色四角星、珊瑚和青绿强调、白色小卡片、深色胶囊条；每张自带底卡，GitHub 浅色深色页面都读得清；不用外链字体、脚本、foreignObject。画布宽 1200（viewBox），字体栈、配色常量沿用旧脚本，不另起。
文件名：中文 `assets/readme/<名>.zh-CN.svg`，英文 `<名>.svg`，日文 `<名>.ja.svg`。图上中文字见下；英文、日文一律照 `docs/roadstar/2026-11-18-homepage-2x/rounds/image-strings.md` 那张三语表逐字用（它和英日主页正文的译法对过），表里没有的（changes 另两行、你自己加的小标）才由你照意思译，并在报告的对照表里标「自译」；都不带型号小版本号。排版提醒：gates 第三格的字最长，三栏不要等宽，给它留宽；workflow 英文块名可以折两行；hero 底条是「·」隔开的两段，放不下就上下两行；lineup 中间箭头两侧留白要够。
1. hero：左小字「CLAUDE CODE SKILL · v<版本号>」（版本号生成时读 `skill/SKILL.md` frontmatter 里缩进在 `metadata:` 下的 `version`，不写死）、大字「Roadstar 引路星」、两行「Claude 想方案、拆活、验收，」「Codex 写代码。」、两行小字「换一家模型回头挑错，」「规矩由脚本卡。」。右：星形节点「Claude 主会话」，虚线分到三张小卡「T1 / Codex / 写代码」「T2 / Claude 子代理 / Codex 做不了的」「✓ / 验收 / 换会话、换一家」；底下深色条「任务书缺栏派不出去 · 没验收合不进主干」。
2. changes：左栏灰「1.14」、右栏亮「2.0」，五行：触发「点名才跑 → 默认就走」；规矩「写在正文里 → 脚本拦三处」；正文「224 行 → 54 行」（最大）；另两行先对照 `skill/references/SKILL-v1.14.md` 核实左边说法再写，候选：开工前「开场面板和策略一问 → 一页设计」、止损「? → 连败三次或用掉九成时间就停」；1.14 原文找不到依据的一行换成有依据的或删掉，报告写各行依据行号（每行都要写，含已知三行）。
3. workflow：从左到右七块「0 一页设计」「1 判难度」「2 六栏任务书」「3 派活」「4 换会话验收」（突出）「5 收尾」「6 对账」；下面一条标谁做：0 到 2「Claude 主会话」、3「Codex 或子代理」、4「另一家模型」、5 到 6「Claude 主会话」；第 2、4、5 块下各有一个小拦截标：`brief-check.py`、`guard.py`、`cleanup.py --check`。
4. gates：三行，每行三格「什么时候 / 哪个脚本 / 结果」：「派活前 / brief-check.py / 任务书缺一栏，派不出去」「合并时 / guard.py / 没有验收记录，合不进主干」「收尾时 / cleanup.py --check / 还有没收完的，不算做完」。
5. lineup：左右两列「Claude 这边」「Codex 这边」，中间双向箭头「换一家验收」。左：「Fable：任务书、拍板」「Sonnet：验收、补位」「Haiku：取证、批量」「Opus：出错才升级」（虚线框）。右：「Sol：写代码」（放大）「Astra：难活、审方案」。底下深色条「额度用到零才停」。
完成线（每条能失败）：
- C1 `python3 assets/readme/source/gen_*.py` 全部跑完得 15 个文件；再跑一遍，`shasum -a 256` 逐字节相同；新脚本每个不超过 400 行（`wc -l`）。
- C2 新增 `assets/readme/source/check_assets.py`，退出 0 才算过。查：15 个文件都在；各自能被 XML 解析且有 viewBox；无 `<script>`、`foreignObject`、`@import`、除 xmlns 外的 `http`；单文件不超过 40 KB；按 GitHub 正文宽 880 像素显示，最小字不小于 11 像素（由 viewBox 宽和字号算）；每段文字按「汉字和假名 1 个字宽、ASCII 0.6 个字宽」估宽，不超出所在卡片或栏，左右各留至少 12；每段文字与底色对比度不低于 4.5（WCAG）；`README.md` 引用的 `assets/readme/*.svg` 都存在；`--all` 查三份 README 并列出没有任何 README 引用的 svg。
- C3 检查脚本自己会失败：至少做四次变异（缩小一张卡让字溢出、一处字色改成接近底色、加一个 `<script>`、删一个文件），每次退出非 0，然后还原，还原后重新退出 0；报告附四次命令与退出码。
- C4 删掉新主页不再用的 `stats*`、`section-*`、`panel*`、`loop*` 的 svg 与只生成它们的旧脚本；`hero`、`workflow`、`lineup` 三组重画覆盖。三份 README 都已改成只引用新图名，`check_assets.py --all` 必须退出 0，且没有未被任何 README 引用的 svg。
- C5 地图和 CHANGELOG 见下，桩测试通过（见验收命令）。
- C6 看效果：用系统自带的 `qlmanage -t -s 1600 -o <临时目录> <svg>` 把 15 个图各转 PNG 看一遍，报告写看了哪些、改了什么。本机没有 `rsvg-convert`，不要驱动 Google Chrome。沙箱里转不了就在报告里写明「没看图，原因」，不算失败，由 Argo 来看。

## 背景
2.0 大改版后主页停在 1.14，主人要求主页、配图、三语介绍全部重做（详见设计页）。中文 `README.md` 正由另一位写手改第二稿，工作区里的未提交改动就是它，别碰；英文、日文稿之后另派。图用在中文稿里，引用名见 README.md 现有 `<img>`。

## 同类方案（只在新系统 / 新项目 / 大改版这类整体性的活写）
本活是主页重做，对同类主页取舍如下：
- https://github.com/obra/superpowers（MIT）：取「开头一段话把流程讲通」；不取「安装占六成、一张图没有」。
- https://github.com/Fission-AI/OpenSpec（MIT）：取「用一段真实终端输出演示流程」；不取口号式价值观。
- https://github.com/github/spec-kit（MIT）：取「要做什么、走哪条、得到什么的三列表和徽章下一行切语言」；不取自造名词堆成的大表。
三家都没有流程图和改版前后对照图，changes 和 workflow 要做得比它们好。

## 涉及模块
README 配图

## 接口签名与文件范围
地图登记（地图里还没有这一块，同一提交在 `docs/模块地图.md`「模块一览」加一行：管什么=主页配图生成与检查；目录=`assets/readme/`、`assets/readme/source/`；入口与测试命令写进该行，并在「怎么跑、怎么测」补一条 `python3 assets/readme/source/check_assets.py --all`。）
新建：`assets/readme/source/` 下生成脚本（每个不超过 400 行，建议 `gen_hero.py`、`gen_changes_workflow.py`、`gen_gates_lineup.py`，共用常量放 `common.py`，也算 400 行限内）；`check_assets.py`，命令 `python3 assets/readme/source/check_assets.py [--all]`，退出 0 过、非 0 不过，每个失败项一行输出文件名与原因；15 个 svg。生成脚本无参数，从仓库根运行，输出到 `assets/readme/`。登记进地图「README 配图」的入口栏。
修改：`docs/模块地图.md`、`CHANGELOG.md`（加一条：验证了什么、没验证什么）。
删除：旧 `stats*`、`section-*`、`panel*`、`loop*` 的 svg 与 `gen_panel_schedule.py`、`gen_sections_stats.py`；`gen_hero_workflow.py`、`gen_lineup_loop.py` 被新脚本取代后删除。动手前 `wc -l` 两个要改的文档，超 800 行的不许变长。

## 项目常驻边界
无 `docs/roadstar/_common.md`，边界全在下面；遵守仓库根 `CLAUDE.md`（脚本只用标准库与 bash，改了模块入口、测试命令同一提交改地图）。

## 不许动什么
`README*.md`、`skill/` 下任何文件、`install.sh`、`docs/roadstar/` 下除 `rounds/exec-T1*` 以外的文件；不新建场次目录以外的文档。旧用例不改；若某桩测试因删旧图失败，只改相关断言并在报告列出改前改后。

## 执行环境
不联网、不起服务；克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSH1/repo`，分支 `docs/homepage-2x`，开工 HEAD `3afe4b6`；工作区已有别人未提交的 `README.md`、`README.en.md`、`README.ja.md` 三份改动和未跟踪的本场次目录 `docs/roadstar/2026-11-18-homepage-2x/`（含 `rounds/image-strings.md`），开工先 `git status --short` 核对，对不上就停并报告。转 PNG 的临时文件放自己 `mktemp -d` 的系统临时目录，收尾用字面路径删。

## 验收命令与期望输出
- `git status --short`，期望：除 `README.md`（及可能出现的 `README.en.md`、`README.ja.md`，均为别人的未提交改动）和本场次目录外，只有本任务范围内文件。
- `python3 assets/readme/source/gen_*.py` 各跑两遍、对比 `shasum -a 256 assets/readme/*.svg`，期望两遍一致。
- `python3 assets/readme/source/check_assets.py`，期望退出 0；带 `--all` 也退出 0，且不列出未被引用的 svg。
- 四次变异各跑 `python3 assets/readme/source/check_assets.py; echo $?`，期望都非 0，还原后为 0。
- `bash skill/scripts/tests/run.sh`，期望退出 0，结尾 PASS 数不低于开工 HEAD 基线：开工 HEAD 实跑退出 0，各套件末行依次 PASS 90、20、95、36、42、8、18、40、23 checks，共 9 套。
- `wc -l assets/readme/source/*.py`，期望每个不超过 400。

## 资源上限与止损
预计 75 分钟，上限 150 分钟；浏览器最多 1 个实例，单条命令超时 120 秒，不并发。验证只用上面的命令。每试一次某个检查项，往 `docs/roadstar/2026-11-18-homepage-2x/rounds/exec-T1.progress` 追加一行「ISO 时间 制表符 检查项编号 制表符 pass 或 fail 制表符 一句证据」；同一检查项连续三次失败或到上限就停，写清哪些过了、卡在哪项、试过什么。停止条件：仅指上述 C1 到 C6 的检查项连败三次；README.md 改动与本场次目录属预期，不算停。

## 交付物
报告写克隆根 `RSH1-report.md`，末行 `完成状态：全部完成` 或 `完成状态：未全部完成`，只列三样：改了哪些文件；跑了哪些验证及输出；没做成的和原因。另含：三语文字对照表（每张图每段字的中、英、日）；「1.14」栏各行在 SKILL-v1.14.md 的原文依据行号；英日 README 仍引用的旧图清单。

## 收尾
删掉自己建的临时目录（PNG 等）；不动别的线的东西，只删临时目录下自己名字的子目录。

## 不提交
不提交 git，不推送，由 Argo 合并。
