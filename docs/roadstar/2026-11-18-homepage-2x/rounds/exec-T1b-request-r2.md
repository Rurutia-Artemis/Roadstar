# T1b · 主页配图返修：改版对照图贴底、英雄图小卡副句对齐、检查脚本补一项
设计页：docs/roadstar/2026-11-18-homepage-2x/design.md

## 目标与做完的样子
上一轮（T1，工作区未提交）15 张图 Argo 逐张转成 PNG 看过，整体可用，查到两处版式问题，都是检查脚本现在查不出来的，所以先给检查脚本补一项、看它把问题报出来，再修图。
完成线（每条能失败）：
- C1 `assets/readme/source/check_assets.py` 新增一项「离边留白」：除铺满画布的底卡外，任何图形和文字的外框离画布上、下、左、右四边都不小于 24（viewBox 单位；文字外框照脚本已有的估宽办法算，高按字号算）。加完先不改图跑一遍：`changes` 三版必须因这一项失败（现在最后一行离底边只有个位数）。报告贴这次失败的输出原文。
- C2 `changes` 三版：画布加高，让最后一行到底卡下边的留白等于第一行（1.14、2.0 两个表头）到底卡上边的留白；行高、字号、各行内容不变。
- C3 `hero` 三版：右边三张小卡的副句，有的版本折成两行（英文版「New session, / other vendor」），现在两行整体上移，和旁边单行副句不在一条线上。改成：副句第一行的基线三张卡统一，第二行往下排，行距取字号的 1.35 倍；放不下就三张卡一起加高、画布和底条相应下移，三张卡始终等高。三版都按这个规则生成，中文、日文版副句是单行的，改后位置不变或三卡同步变化。
- C4 新增一次变异并还原：把任一张图的画布高改小 30，`check_assets.py` 退出非 0；还原后退出 0。报告附命令和退出码。
- C5 回归：三个 `gen_*.py` 各跑两遍，15 个文件 `shasum -a 256` 两遍一致；`check_assets.py` 和 `check_assets.py --all` 都退出 0；`bash skill/scripts/tests/run.sh` 退出 0，九套 PASS 数依次 90、20、95、36、42、8、18、40、23；`wc -l assets/readme/source/*.py` 每个不超过 400。

## 涉及模块
README 配图

## 接口签名与文件范围
可改：`assets/readme/source/check_assets.py`、`common.py`、`gen_hero.py`、`gen_changes_workflow.py`，以及重新生成的 `assets/readme/*.svg`。`check_assets.py` 的命令行不变（`[--all]`，退出 0 过、非 0 不过，每个失败项一行：文件名加原因）。`docs/模块地图.md` 里「README 配图」那行如果列了检查项，同步补「离边留白」；`CHANGELOG.md` 上一轮那条里补一句。

## 不许动什么
`README*.md`、`skill/` 下任何文件、`install.sh`、`rounds/image-strings.md`、图上的任何文字内容和配色、`workflow`、`gates`、`lineup` 三组的版式（它们重新生成后必须逐字节不变，除非新检查项在它们身上也报了问题，那就停下把报错原文交回，不自己改）。不许 `git stash`、`git checkout --`、`reset`、`clean`。不联网、不起服务、不提交、不推送。
旧用例冲突处理：桩测试不该受影响；有任何一套 PASS 数变了就停下，交回套件名和完整输出，不改测试。

## 执行环境
克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSH1/repo`，分支 `docs/homepage-2x`，上一轮的图、脚本和三份 README 已由 Argo 提交（`c1a6189`、`3398670`，其后可能还有只动场次文档的提交，HEAD 以 `git log -1` 为准）。工作区里这些都属预期、不算停：未跟踪的 `RSH1-report.md`（含上一次停工说明，接着往后追加）；本场次目录 `docs/roadstar/2026-11-18-homepage-2x/` 下任何已修改或未跟踪的文件（账本、任务书、运行记录由 Argo 随时追加）。只有这两处之外还有未提交改动才停。命令从仓库根用 `python3` 跑。本机 `qlmanage` 在沙箱里转不了图，不用试，看图由 Argo 做。临时文件放自己 `mktemp -d` 的系统临时目录，收尾用字面路径删。

## 验收命令与期望输出
1. 改图前：`python3 assets/readme/source/check_assets.py; echo $?` → 非 0，输出里有 `changes` 三个文件名和离边留白的原因。
2. 改图后：`python3 assets/readme/source/check_assets.py --all; echo $?` → `PASS 15 SVGs; three READMEs; no unreferenced SVGs`，0。
3. `shasum -a 256 assets/readme/*.svg` 两遍一致；`git diff --exit-code -- assets/readme/workflow*.svg assets/readme/gates*.svg assets/readme/lineup*.svg; echo $?` → 0（这九个文件与已提交的逐字节相同）。
4. C4 的变异命令与退出码。
5. `bash skill/scripts/tests/run.sh` → 退出 0，九套 PASS 数同上。
6. `wc -l assets/readme/source/*.py` → 每个不超过 400。

## 资源上限与止损
预计 25 分钟，上限 50 分钟（桩测试约 2 分钟一遍）。单条命令超时 180 秒，不并发。同一检查项连败三次就停。每试一次检查项往 `docs/roadstar/2026-11-18-homepage-2x/rounds/exec-T1b.progress` 追加一行「ISO 时间 制表符 检查项 制表符 pass 或 fail 制表符 一句证据」。

## 交付物
在克隆根 `RSH1-report.md` 末尾追加一节「T1b」：C1 到 C5 各一行；改图前那次失败输出原文；`changes`、`hero` 六个文件改前改后的 viewBox 高；九个不该变的文件改前改后散列是否一致。把文件最后一行改成 `完成状态：全部完成` 或 `完成状态：未全部完成`。

## 不提交
不提交 git，不推送，由 Argo 合并。
