# T1 · 任务书模板、接入清单、踩坑表和地图：补文字
设计页：/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-11-17-sim-gaps/design.md

## 目标与做完的样子
背景：空项目模拟跑（`/Users/rurutia/Documents/RuruCode/AI任务/roadstar-sim-1117.md`）和使用盘点（`/Users/rurutia/Documents/RuruCode/AI任务/roadstar-review-1117.md`）里，几条教训只在私人记忆里，刚接入的项目没有清单。只改文字，不改脚本。类别：补全（Sonnet 做，不走 dex-exec，写在这里备查）。
完成线（每条能判对错，达不到写差多少）：
- C1 `skill/references/task-brief-template.md` 恰好新增 3 行，分别加在「## 不许动什么」（第 33 行起，放 a）、「## 资源上限与止损」（第 42 行起，放 b）、「## 收尾」（第 48 行起，放 c）三节里：(a) 改了被用例写死的数（个数、清单、版本号）时，先 grep 出钉着它的用例并列进「验收命令与期望输出」，「旧用例不改」要同时写冲突时怎么办（按任务要求改那条断言，只改相关断言，报告里列改前改后）；(b) 停止条件写成能判对错的具体情形，不用「任何」「所有」这类全称；(c) 执行方和子代理收尾只删任务临时目录下以自己名字命名的子目录，不删目录本身和别人的东西。
- C2 `skill/references/project-map.md` 末尾加一节「刚接入的项目：接入清单」，不超过 12 行，每条先到脚本里核实再写，核实不了的写「未核实」：地图里要有管测试目录的模块（`entry-check.py` 与 `guard.py` 对越界的判法先读）；项目 `CLAUDE.md` 指向地图（`entry-check.py` 约 154、208 行的拒派条件）；`scripts/install-guard.sh <项目根> --claude`；`docs/roadstar/_common.md`；`guard.py check-merge <分支>` 在主干上跑、验收记录放主干的场次目录；合并被钩子拦后先 `git merge --abort`；测试命令走哪条（模拟跑记的是 ws-guard 拦裸 pytest、改用 `ruru-run`，先在 `~/.claude/skills`、仓库里 grep 核实，找不到依据就写「未核实」）。`skill/SKILL.md` 只在「## 文件」一节末尾加 1 句指向这一节；`wc -l skill/SKILL.md` 不超过 55。
- C3 `skill/references/division-of-labor.md` 第 15 节（第 165 行起，表到「## 16」前）表尾加 4 行，每行一格现象一格做法：替执行方提交后再跑一遍相关回归（有用例读 `git HEAD` 的源码当基线，提交前全过提交后才挂）；批量派活先派两三份、逐份看内容再放量，每批不超 4 份；Codex 只读活写读取上限（一份读入不超约 3000 行），交回先看字节数和末行，小于 1500 字节或末行没有「完成状态」就当没做成；后台开的会话带 `--permission-mode auto`。先 grep 第 15 节，已有同义行的那条不加，在报告里写已有的行号。这四条里的数字（4 份、3000 行、1500 字节）先到 `/Users/rurutia/.claude/projects/-Users-rurutia-Documents-RuruCode/memory/` 下的 `canary-before-fanout.md`、`codex-readonly-compaction-empty-ack.md` 里核出处（只读），核不到出处的数字不写，改成不带数字的说法，并在报告里列出来。
- C4 `docs/模块地图.md` 第 3 行版本改成与 `skill/SKILL.md` 的 `version` 一致（现为 2.0.0），日期改 2026-11-17；「模块一览」与各「入口」里的反引号路径逐个核对实际文件，不存在的在报告里列出并只改路径写法（不增删模块）。
- C5 `CHANGELOG.md` 顶部（第 2 行后）加一条 2026-11-17，格式同上一条（起因、改了什么、没验证什么），不超过 8 行，写明 T2、T3 的脚本改动另有记录。
- C6 报告末尾列：每个文件改了几行（`git diff --stat`）；接入清单每一条的依据行号或「未核实」。

## 涉及模块
流程与调度契约

## 不许动什么
除上面 C1–C5 的六个文件（task-brief-template.md、project-map.md、SKILL.md、division-of-labor.md、模块地图.md、CHANGELOG.md）外，不动别的文件；不动 `skill/scripts/`、铁律文件、`~/.claude` 下任何东西、各项目的钩子；不推送。第 15 节和模板里原有的行一字不改。模板里现有各句原样保留，只在节内加行。

## 执行环境
克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RSG1/repo`，分支 `roadstar/sim-gaps-t1`，基线 Roadstar 主干 HEAD `a262e16`。不联网，只读核实脚本，不起服务。

## 验收命令与期望输出
- `wc -l skill/SKILL.md`：不超过 55。
- `git diff --stat`：只出现上面六个文件；`git diff skill/scripts` 为空。
- `git diff skill/references/task-brief-template.md | grep -c '^+[^+]'`：3。
- `bash skill/scripts/tests/run.sh; echo rc=$?`：末行 `rc=0`。基线（主干 a262e16，11-17 跑）：退出 0，各套件 `PASS 88 checks`、`PASS 20 checks`、`PASS 95 checks`、`PASS 50`、`PASS 13`、`PASS 36 checks`、`PASS 41 checks`、`PASS 8 checks`、`PASS 18 checks`，没有失败的用例；改文字后应一样。
- C4 路径核对：`grep -o '`[^`]*`' docs/模块地图.md | tr -d '`' | grep -E '^(skill|install|docs)' | sort -u | while read -r p; do ls -d $p >/dev/null 2>&1 || echo MISSING $p; done`，MISSING 行逐条在报告里说明。

## 资源上限与止损
预计 25 分钟，上限 50 分钟。每试一次检查项往 `rounds/exec-T1.progress` 追加一行「时间 TAB 检查项 TAB pass 或 fail TAB 证据」；同一项连败三次或到上限就停，交报告写清卡在哪。只用本节命令验证，不自己发明验法。

## 交付物
报告写到克隆根 `RSG1-report.md`：改了哪些文件、跑了哪些命令及输出、没做成的和原因；末行 `完成状态：全部完成` 或 `完成状态：未全部完成`。

## 收尾
只删自己建的临时目录（任务临时目录下以 `RSG1-` 开头的子目录）；不提交、不推送，由调度方做。
