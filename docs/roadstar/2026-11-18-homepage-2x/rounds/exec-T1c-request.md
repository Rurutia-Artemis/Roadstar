# T1c · 主页配图：英文、日文图上的字按核对后的译文更新并重新生成
设计页：docs/roadstar/2026-11-18-homepage-2x/design.md

## 目标与做完的样子
英文、日文译文经换家核对后改了一批，其中十几处是画在图上的字。`rounds/image-strings.md` 的英文列、日文列已是定稿；现在图里还是旧字。把生成脚本里的英文、日文字符串改成和 `image-strings.md` 一致，重新生成，版式规则不变。
完成线（每条能失败）：
- C1 改之前先列差异：逐行对照 `image-strings.md` 的英文列、日文列和生成脚本里现有的字符串，列出所有不一致（哪张图、哪一格、脚本里的旧字、表里的新字）。改完再对一遍，不一致为 0。字逐字照抄表里的，不自己改写、不增删标点和空格；表里没有的图上字（比如改版对照图的「开工前」「探讨」两行）保持现状，在报告里列出来。
- C2 中文五张 `assets/readme/*.zh-CN.svg` 重新生成后与已提交的逐字节相同。
- C3 `python3 assets/readme/source/check_assets.py --all` 退出 0（字不出框、对比度、离边留白、三份 README 的引用都在这一条里）。新字比旧字长、放不下时，按脚本已有的办法处理：先在本格内折行；折行后放不下，同一组的卡一起加宽或加高、画布相应调整，同组卡保持等宽等高；字号不许小于检查脚本允许的下限，不许删字、改字。同一张图的三语版式结构保持一致（卡数、排列、对齐方式相同）。按这些办法仍放不下的，停下交回是哪一条、超出多少，不自己改字。
- C4 英文、日文各五张图里，没改字的图重新生成后逐字节不变；改了字的图，报告列出改前改后的 viewBox 宽高。
- C5 回归：三个 `gen_*.py` 各跑两遍，15 个文件 `shasum -a 256` 两遍一致；`bash skill/scripts/tests/run.sh` 退出 0，九套 PASS 数依次 90、20、95、36、42、8、18、40、23；`wc -l assets/readme/source/*.py` 每个不超过 400。
- C6 变异并还原：把刚改好的一条英文字符串在脚本里故意加长到放不下（比如重复三遍），重新生成后 `check_assets.py` 退出非 0；还原、重新生成后退出 0，且 15 个文件散列与变异前一致。报告附命令和退出码。

## 涉及模块
README 配图

## 接口签名与文件范围
可改：`assets/readme/source/gen_hero.py`、`gen_changes_workflow.py`、`gen_gates_lineup.py`、`common.py`（只在放不下、需要调版式时），以及重新生成的 `assets/readme/*.svg`、`assets/readme/*.ja.svg`。`CHANGELOG.md` 最上面那条补一句「英文、日文图上的字按译文核对结果更新」。命令行和输出格式都不变。

## 不许动什么
`README*.md`、`skill/` 下任何文件、`install.sh`、`rounds/image-strings.md`、`assets/readme/source/check_assets.py`（检查标准不许为了让图通过而放宽）、中文图、配色和字体。不许 `git stash`、`git checkout --`、`reset`、`clean`。不联网、不起服务、不提交、不推送。
旧用例冲突处理：桩测试不该受影响；有任何一套 PASS 数变了就停下，交回套件名和完整输出，不改测试。

## 执行环境
克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSH1/repo`，分支 `docs/homepage-2x`，HEAD 以 `git log -1` 为准（上一轮的图、脚本、三份 README 和译文修改都已由 Argo 提交）。工作区里这些都属预期、不算停：`docs/roadstar/` 下任何已修改或未跟踪的文件（账本、任务书、验收记录、运行记录由 Argo 和验收员随时追加）；克隆根未跟踪的 `RSH1-report.md`（没有就新建）。`docs/roadstar/` 和这个报告文件之外还有未提交改动才停。命令从仓库根用 `python3` 跑。本机 `qlmanage` 在沙箱里转不了图，不用试，看图由 Argo 做。临时文件放自己 `mktemp -d` 的系统临时目录，收尾用字面路径删。

## 验收命令与期望输出
1. `python3 assets/readme/source/check_assets.py --all; echo $?` → `PASS 15 SVGs; three READMEs; no unreferenced SVGs`，0。
2. `git diff --exit-code -- 'assets/readme/*.zh-CN.svg'; echo $?` → 0。
3. `shasum -a 256 assets/readme/*.svg` 两遍一致；`git diff --stat -- assets/readme` 里只有改了字的英文、日文图。
4. C6 的变异命令与退出码。
5. `bash skill/scripts/tests/run.sh` → 退出 0，九套 PASS 数同上。
6. `wc -l assets/readme/source/*.py` → 每个不超过 400。

## 资源上限与止损
预计 20 分钟，上限 40 分钟（桩测试约 2 分钟一遍）。单条命令超时 180 秒，不并发。同一检查项连败三次就停。每试一次检查项往 `docs/roadstar/2026-11-18-homepage-2x/rounds/exec-T1c.progress` 追加一行「ISO 时间 制表符 检查项 制表符 pass 或 fail 制表符 一句证据」。

## 交付物
克隆根 `RSH1-report.md` 写一节「T1c」：C1 的差异对照表（改前）和改后复核结果；C2 到 C6 各一行；改了字的图改前改后的 viewBox 宽高；表里没有、保持现状的图上字清单。文件最后一行写 `完成状态：全部完成` 或 `完成状态：未全部完成`。

## 不提交
不提交 git，不推送，由 Argo 合并。
