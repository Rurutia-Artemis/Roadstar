# T1 · 收窄五处误拦（留桩、否定句、tests 越界、模块计数、收工检查范围）
设计页：docs/roadstar/2026-11-18-fewer-false-blocks/design.md

## 目标与做完的样子
把 Roadstar 自动检查里五处「不该拦却拦了」收窄，真该拦的照旧拦。主人 11-18 09:41 回「改误拦」，同意改。完成线：

- C1 留桩检查不再命中标识符、测试名、`mktemp` 模板里的 todo / XXX；真留桩照拦。测法：新用例 F1，`guard_rules.lowering_hits` 逐条断言（见下「改动 1」）。
- C2 目标句里的否定说法不再触发「同类方案」；肯定句仍触发。测法：新用例 F2，经 `brief-check.py` 的退出码断言。
- C3 提交范围检查：没有任何模块认领的测试文件不算越界；别的模块认领的和非测试的未收录文件仍拦。测法：新用例 F3a。任务书「涉及模块」里的 tests 不计入「模块表至少两行」的模块数。测法：新用例 F3b。
- C4 `cleanup.py --check --plan-dir` 不计指向别的场次的未合并任务；不带 `--plan-dir` 行为不变。测法：新用例 F4。
- C5 全量回归 `bash skill/scripts/tests/run.sh` 退出 0，各套件末行 PASS 数不低于开工基线（见「验收命令」），新用例使数字增加。
- C6 每个改动的变异检验：把对应源文件改回开工 HEAD 版本，新用例必须失败；恢复后重新通过。
- C7 文档同步：SKILL.md、task-brief-template.md、模块地图、CHANGELOG 按「文件范围」更新。

达不到的项如实报差多少，不降低用例断言。

## 背景
来源：`/Users/rurutia/Documents/RuruCode/AI任务/roadstar-review-1117.md` 缺口 3、4，`roadstar-sim-1117.md` 第二段第 10、2、3 项和「不该拦却拦了」清单，记忆卡 mc-2edd7188bd（合并检查两处误报，与改动 1 重复，已并入；它的 11-18 实例是 `mktemp "$archive_bin/.$script.XXXXXX"` 被报「留桩或半成品」）。以下现状均已在开工 HEAD `1ad849f`（main）的合成小仓库里复现过，复现记录在 `docs/roadstar/2026-11-18-fewer-false-blocks/ledger.md`。

### 改动 1 留桩检查（`skill/scripts/guard_rules.py`）
- 现状：第 23 行 `STUB = re.compile(r'TODO|FIXME|XXX|NotImplementedError|fatalError\(|unimplemented!|todo!\(|not implemented', re.I)`，忽略大小写的子串匹配；第 159 行 `if Path(after).suffix in CODE and STUB.search(line)` 对每条新增行用它。复现：`def count_done(todo_list):`、`def test_todo_done():`、`mktemp "$archive_bin/.$script.XXXXXX"` 都命中「留桩或半成品」。
- 规则（写死）：第 23 行整行换成
  `STUB = re.compile(r'(?<![\w.-])(?:TODO|FIXME|XXX)(?!\w)|(?:#|//|/\*|<!--)[ \t]*(?i:todo|fixme|xxx)(?!\w)|NotImplementedError|fatalError\(|unimplemented!|todo!\(|(?i:not implemented)')`
  含义：大写 TODO / FIXME / XXX 作为独立词（前不是字母数字下划线点横线，后不是字母数字下划线）；小写或混写的 todo / fixme / xxx 只在 `#`、`//`、`/*`、`<!--` 之后（可隔空白）作为独立词才算；其余五个词组照旧，`not implemented` 仍忽略大小写。第 159 行不改。
- 新用例 F1（`skill/scripts/tests/guard-rules-tests.sh`，`@test('F1', …)`）：每条样例各提交一个代码文件，用 `rules.lowering_hits` 断言。
  不该命中：`def count_done(todo_list):`（calc.py）、`def test_todo_done():`（tests/test_x.py）、`f=$(mktemp "$archive_bin/.$script.XXXXXX")`（mk.sh）、`mktemp /tmp/x.XXX`（mk2.sh）、`x = TODO_LIST`、`# todo_list = []`。
  必须仍命中：`# TODO: 没做完`、`raise NotImplementedError`、`# XXX 待补`、`// todo: later`、`/* fixme */`、`XXX`（单独一行）、`FIXME`、`todo!()`、`Not Implemented`。
- 这批样例里的 TODO / XXX / NotImplementedError 写在测试文件的新增行上，合并时会命中本仓库自己的「留桩或半成品」检查；预期如此，不要为避开而改写样例，在报告里列出命中的文件，验收记录「降标准五查」由 Argo 点名。

### 改动 2 「重做」类整体性说法的否定句（`skill/scripts/design_page.py`）
- 现状：第 10 行 `PRIOR_ART_TRIGGER = re.compile(r'新系统|新项目|新产品|新服务|大改版|重做|立项')`，第 11 行 `NEW_MODULE = re.compile(r'新模块')`，第 66–75 行 `prior_art_trigger(goal)` 用 `.search` 取第一个匹配，不看前文。复现：目标写「这次不重做 text 模块，只改乘法。」，`brief-check.py` 报「目标里有「重做」，缺「同类方案」一节」，退出 2。
- 规则（写死）：在 design_page.py 增加 `NEGATION = re.compile(r'(?:不要|不再|不会|不用|不是|不|没有|没|无需|无|别|勿|并非|非)\s*$')`；`prior_art_trigger` 对 `PRIOR_ART_TRIGGER` 和 `NEW_MODULE` 改用 `finditer`，某个匹配的紧前文（`goal[:m.start()]`）以 `NEGATION` 结尾就跳过这个匹配，继续看后面的匹配；全部被跳过则按原逻辑当没有触发词。紧前文以逗号、句号、顿号、换行等结尾（例如「不改接口，重做记忆服务」）不算否定。`brief-check.py` 里 plan 目标节和设计页「为什么做」「做完的样子」都走 `prior_art_problems`，一处改动覆盖。返回值形状不变（触发词字符串或 None，`新模块」+「系统` 那种拼接也照旧）。
- 新用例 F2（`skill/scripts/tests/brief-tests.sh`，沿用 `prior_brief` 的写法，退出码经 `brief-check.py`）：
  放行（无「同类方案」节，退出 0）：「这次不重做 text 模块，只改乘法。」「不要立项，只补一个检查。」「没有新系统，只改已有函数。」「不是重做，只改乘法。」
  仍拦（退出 2，报「缺「同类方案」一节」）：「重做记忆服务。」「不改接口，重做记忆服务。」「新系统：本机记忆服务。」
  旧用例「新模块」「新建 quota.py」「大改版」各条断言不改。

### 改动 3 tests 目录越界与模块计数（`skill/scripts/guard.py`、`skill/scripts/brief-check.py`）
- 现状：`guard.py` 第 309–311 行 `allowed = [...] + list(ALLOW)`，`outside = [name for name in changed if not any(matches(root, name, p) for p in allowed)]`，没有任何模块认领的 `tests/test_calc.py` 被报「→ 地图里没有」，提交退出 1。`brief-check.py` 第 80–81 行 `count = len([m for m in re.split(r'[,，、\n]', modules) if m.strip()])`，任务书「涉及模块」写 calc 和 tests 两行，设计页没有两行模块表时报「设计页「模块表」至少要两行数据」，退出 2。两者都已复现。
- 规则（写死）：
  - guard.py：在算 `outside` 时，一个改动路径同时满足「`guard_rules.test_file(name)` 为真」和「`modules` 里没有任何模块的任何路径模式匹配它」就不算越界（按 `matches(root, name, p)` 对全部模块判断）。别的模块认领的测试文件、不是测试文件的未收录路径照旧越界。`guard_rules` 的导入沿用文件里已有的 `import guard_rules` 写法（函数内导入）。不改 `ALLOW`。
  - brief-check.py：算 `count` 时不计名字（去掉首尾空白、反引号、`「」`后，忽略大小写）等于 `tests`、`test`、`测试` 之一的项。设计页「模块表」规则本身不改。
- 新用例 F3a（`skill/scripts/tests/guard-tests.sh`，用文件里现有的 MAP：甲模块 `src/a/`、乙模块 `src/b/`；任务选甲模块）：提交 `tests/test_calc.py` 放行（退出 0）；提交 `src/b/test_b.py`（乙模块认领的测试文件）仍拦，输出含 `src/b/test_b.py → 乙模块`；提交 `unknown.txt` 仍拦，输出含 `unknown.txt → 地图里没有`。F3a 总共新增不超过 25 行（guard-tests.sh 现 767 行，不许超过 800）。
- 新用例 F3b（`skill/scripts/tests/brief-tests.sh`）：任务书涉及模块「甲」「tests」两行、`--write --class 跨模块`、设计页没有模块表，退出 0；涉及模块「甲」「乙」两行、同样条件，仍退出 2 并含「模块表」（现有 C2 用例已覆盖，F3b 复用同一夹具再断言一次即可，不必改 C2）。

### 改动 4 收工检查范围（`skill/scripts/cleanup.py`）
- 现状：`close_check`（第 236 行）把所有本地分支上带 `Roadstar-Task` trailer 的未合并任务都记成 `unmerged_task`（第 278 行），所有未合并的分支工作副本记成 `unmerged`（第 253 行），不看给的 `--plan-dir`；第 298–310 行 `items = unmerged + tasks + uncleared + acceptance`，`return 1 if items else 0`。复现：`--plan-dir docs/roadstar/mine` 自己的任务都验收了，另一分支带 `Roadstar-Task: docs/roadstar/old/T9` 就退出 1，输出「没合并：T9（docs/roadstar/old）在分支 other 上，1 个提交」。
- 规则（写死）：仅当 `plan_dirs` 非空时，在第 298 行之前按下面三步把条目分成「本场次」和「别场次」：
  1. `unmerged_task` 条目的 `plan_dir`（trailer 里的场次路径，相对路径按 `project` 解析，`resolve()`）等于某个给定场次目录（也是 `resolve()` 后）才算本场次；否则归别场次。
  2. 同一个分支如果有任一 `unmerged_task` 算本场次，这个分支上的所有 `unmerged_task` 条目都留在本场次（一个分支混了两个场次的任务时，按本场次处理）。
  3. `unmerged`（未合并的分支工作副本）条目：它的分支至少带一个 `Roadstar-Task` 且其任务全部指向别场次，才归别场次；分支不带任何 trailer 的、`uncleared`（已合并没清）、`no_acceptance` 一律留在本场次，不改。
  别场次条目不进 `items`、不影响退出码，在输出里单独成段：文本模式在正常条目之后打印一行 `别的场次的（不计入）：` 再每条一行原有 `detail`；JSON 模式在 `clean`、`items` 之外只在别场次非空时多一个键 `"others"`，值是条目列表。别场次非空但本场次全空时，首行仍是 `收工检查：都收完了`，退出 0。`plan_dirs` 为空时行为与输出一字不变（`"others"` 键不出现）。`--check` 仍只查不删。
- 新用例 F4（`skill/scripts/tests/close-check-tests.sh`，沿用 `lane`/`commit`/`report` 夹具，`plan = "docs/roadstar/测试场次"`）：
  (a) 一个分支带 `Roadstar-Task: docs/roadstar/别的场次/T9`、`--check --plan-dir plan`，本场次 `exec-T1.md` 配有效 `check-T1.md`，退出 0，输出含 `别的场次的（不计入）：`，JSON 的 `others` 有 1 条；
  (b) 同样的分支不带 `--plan-dir`，退出 1（行为不变）；
  (c) 分支带 `Roadstar-Task: <plan>/T2`，带 `--plan-dir plan`，退出 1；
  (d) 本场次 `exec-T3.md` 没有 `check-T3.md`，带 `--plan-dir plan`，即使别场次条目存在也退出 1 且列出「没验收：T3」；
  (e) 一个分支同时带别场次 T9 和本场次 T2 的提交，带 `--plan-dir plan`，T9 也计入，退出 1。

## 涉及模块
流程与调度契约
任务执行与验收

## 接口签名与文件范围
改源文件（行数均未超 800，不许让已超 800 的文件变长；没有已超 800 的）：
- `skill/scripts/guard_rules.py`（298 行）：第 23 行 STUB。
- `skill/scripts/design_page.py`（214 行）：新增 `NEGATION`，改 `prior_art_trigger`。
- `skill/scripts/brief-check.py`（163 行）：第 80–81 行的模块计数。
- `skill/scripts/guard.py`（545 行）：第 309–311 行的 `outside`。
- `skill/scripts/cleanup.py`（392 行）：`close_check` 的第 298–310 行，以及 `--plan-dir`、`--check` 的 help 文字（第 316、320 行）。
改测试（只追加新用例，现有用例除下面「不许动什么」列的情形外不改）：
- `skill/scripts/tests/guard-rules-tests.sh`（638 行）加 F1。
- `skill/scripts/tests/brief-tests.sh`（459 行）加 F2、F3b。
- `skill/scripts/tests/guard-tests.sh`（767 行）加 F3a，增量不超过 25 行。
- `skill/scripts/tests/close-check-tests.sh`（306 行）加 F4。
不新建文件，所以地图不需要登记新入口。
改文档（同一提交）：
- `skill/SKILL.md`（54 行）第 2 步那句触发词说明末尾加「前面带不 / 没 / 无 / 别 / 非的否定说法不算」；第 5 步把 `--check` 改成 `--check --plan-dir <本场次目录>`，并在其后加一句「带 `--plan-dir` 时别的场次留下的任务只列出，不计入退出码」。
- `skill/references/task-brief-template.md` 第 22 行（同类方案触发条件那一行）同样加「前面带不 / 没 / 无 / 别 / 非的否定说法不算」。
- `docs/模块地图.md`：「任务执行与验收」一节里 `guard_rules.py` 的留桩规则、`guard.py` 的范围检查（无模块认领的测试文件不算越界）、`cleanup.py --check` 带场次目录的语义；「流程与调度契约」一节里同类方案规则（否定句不触发）和涉及模块计数（tests 不计）。各在对应条目里加一两句，不新增条目；更新日期改 2026-11-18。
- `CHANGELOG.md`：顶部加 `## 2026-11-18 · 少拦错：五处误拦收窄（不升版本）`，写起因（11-17 盘点和模拟、11-18 合并撞上的 mktemp 实例）、改了什么、验证（本任务验收命令的数字）、没验证项。
不在范围、由 Argo 决定要不要同步：`/Users/rurutia/Documents/RuruCode/RuruAgent/tools/rules-reminder/roadstar-铁律.md` 第 11 行。

## 项目常驻边界
无 `docs/roadstar/_common.md`，边界全在下面和本仓库 `CLAUDE.md`：脚本只用标准库和 bash；改了模块入口、接口、测试命令或规矩，同一提交更新 `docs/模块地图.md` 那一节；每笔改动一条 CHANGELOG（含验证与未验证项）；测试里的临时目录一律 `mktemp`，用完删，不在用户设置里留东西。

## 不许动什么
- 范围外一律不动：`dex-exec.sh`、`entry-check.py`、`guard.py` 里除第 309–311 行外的逻辑（标记、trailer、合并检查）、`skiplog.py`、开关与放行口子（`Roadstar-Scope`、`Roadstar-Map`、`Roadstar-Length`、全部 `ROADSTAR_*`）、`.roadstar/guard.json` 语义。
- 不要运行 `./install.sh`：它会把 skill 软链改指向本克隆。
- 不碰克隆之外的东西：主目录 `/Users/rurutia/Documents/RuruCode/Roadstar`、`Roadstar-slots`、RuruAgent 仓库一概不动。
- 旧用例不改，冲突这样处理：这次改动必然改变结果的旧用例，只改那一条断言（按任务要求改，只改相关断言），在报告里逐条列出文件、用例名、改前改后；别的旧用例失败一律停下交回，写清哪条、看到什么，不自行改断言。已核对的可能受影响点：`guard-rules-tests.sh` 第 482–497 行 C3-vocabulary 用单独一行的 `TODO`、`XXX`、`FIXME`、`Not Implemented`、`todo!(` 等样例，新规则下仍命中，预计不用改；`guard-tests.sh` 第 194、300 行断言「→ 地图里没有」的路径是 `github.com/.../file.txt`、`unknown.txt`、`root.txt.more`、`src/ab/file.py`，都不是测试文件，预计不用改；`close-check-tests.sh` C6（第 203 行起）带 `--plan-dir`、分支 trailer 指向本场次，预计不用改。
- 改任何数量、清单、版本号前先 grep 钉着它的用例并列进报告；这次没有这类改动，唯一的数字是各套件 PASS 数，见验收命令。

## 执行环境
- 不联网，不起服务，不开浏览器，不用模拟器；Codex 沙箱能做完开发和验收。
- 克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/repo`，分支 `roadstar/fewer-false-blocks`，开工 HEAD `1ad849faa8bef235ce99ba473399e801303f1ad9`（主干 main，派出前 Argo 再核一遍 `git -C <克隆> rev-parse HEAD` 与 `git status --short` 为空）。
- 变异检验备份只放 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/mut/`；不要用裸 pytest，测试只用下面写的 `bash` 命令；shell 禁历史写入（`HISTFILE=/dev/null`）。
- 本项目有 commit-msg、pre-merge-commit 检查，但不提交所以不会触发。

## 验收命令与期望输出
开工基线（主干 `1ad849f` 在合成克隆里实跑过，11-18）：`bash skill/scripts/tests/run.sh` 退出 0；输出里各套件末行 PASS 数依次为 88（brief-tests）、20（review-tests）、95（run.sh 本体）、50（guard-tests）、13（close-check-tests）、36（entry-tests）、41（guard-rules-tests）、8（baseline-tests）、18（trailer-path-tests）、40（marker-branch-tests）、23（exec-handback-tests），合计 432。
1. `cd <克隆> && git rev-parse HEAD` 期望开工时 `1ad849f…`（分支上开始改之前）。
2. `bash skill/scripts/tests/guard-rules-tests.sh` 退出 0，末行 PASS 数 ≥ 42（基线 41 + F1）。
3. `bash skill/scripts/tests/guard-tests.sh` 退出 0，末行 `PASS 51` 或更多（基线 50 + F3a）。
4. `bash skill/scripts/tests/close-check-tests.sh` 退出 0，末行 `PASS 14` 或更多（基线 13 + F4）。
5. `bash skill/scripts/tests/brief-tests.sh` 退出 0，末行 PASS 数 ≥ 90（基线 88 + F2、F3b 各至少一条）。
6. `bash skill/scripts/tests/run.sh` 退出 0，各套件末行 PASS 数不低于基线对应数，合计 ≥ 436。
7. 变异检验，逐个做（先 `cp <文件> /Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/mut/<文件名>.fixed`，再 `git show 1ad849f:skill/scripts/<文件> > skill/scripts/<文件>`，跑对应套件，再把 `.fixed` 拷回去并确认 `git diff --stat` 回到变异前）：
   - guard_rules.py 改回 → `guard-rules-tests.sh` 退出非 0，输出落在 F1。
   - design_page.py 改回 → `brief-tests.sh` 退出非 0，输出落在 F2。
   - brief-check.py 改回 → `brief-tests.sh` 退出非 0，输出落在 F3b。
   - guard.py 改回 → `guard-tests.sh` 退出非 0，输出落在 F3a。
   - cleanup.py 改回 → `close-check-tests.sh` 退出非 0，输出落在 F4。
   每条把命令和失败输出末几行写进报告；恢复后重跑对应套件退出 0。
8. 合成复现脚本回扣（手工，不进仓库）：在 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/` 下自己 `mktemp -d` 的子目录里，复现「改动 1–4 现状」各一次，期望都不再拦；再复现「仍须拦」各一例，期望仍拦。输出贴进报告。
9. `wc -l` 本次改动的每个源文件和测试文件，期望都 ≤ 800，guard-tests.sh ≤ 800。
10. `git diff --stat` 只含「接口签名与文件范围」列的文件。

## 资源上限与止损
预计 45 分钟，上限 90 分钟（查 `~/.claude/skills/roadstar/references/estimates.md`：窄回归默认 15 分钟，五处修复分属四个源文件各带用例和变异检验，按三倍取 45；上限为预计的两倍，不超过跨模块类型上限 90）。派发时 `--est-minutes 45` 和 `--max-minutes 90`。
- 单条命令超时 10 分钟；不并发跑套件；不开浏览器。
- 验证只用「验收命令」里写的命令，不自己发明；每试一次某个检查项，往 `docs/roadstar/2026-11-18-fewer-false-blocks/rounds/exec-T1.progress` 追加一行「ISO 时间 制表符 检查项编号 制表符 pass 或 fail 制表符 一句证据」（这是对「不许动什么」里场次目录的唯一例外）。
- 同一检查项连续三次失败，或到上限，停下交报告，写清哪些过了、卡在哪一项、试过什么。
- 停止条件（已 grep 现状）：只有下面这些情形停下交回。(1) 开工前 `git rev-parse HEAD` 不是 `1ad849f` 或 `git status --short` 非空；(2) 开工基线 `bash skill/scripts/tests/run.sh` 就非 0；(3) 改完后不在「不许动什么」预估名单里的旧用例失败，且不是这次规则必然改变的结果；(4) 要改的某个文件已在 800 行以上，或改完超过 800 行（现 guard-tests.sh 767 行，F3a 上限 25 行）；(5) 需要改文件范围之外的文件才能过。`guard-rules-tests.sh` C3-vocabulary、`guard-tests.sh` 第 194、300 行断言、`close-check-tests.sh` C6 这几条是现状里已有的相关用例，不动、不算停止条件。

## 交付物
最后回复写进 `docs/roadstar/2026-11-18-fewer-false-blocks/rounds/exec-T1.md`，只列三样：改了哪些文件；跑了哪些验证命令及输出（含各套件 PASS 数、四条变异检验的失败输出、手工复现输出、改过的旧用例改前改后）；没做成的和原因。另在报告里列出新用例样例命中本仓库「留桩或半成品」检查的文件。

## 收尾
自己建的临时目录（`/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/mut/` 和复现用的 `mktemp -d` 子目录）只删这些自己名字的子目录，不删 `RFB1` 本身、不删 `repo`。不起服务、不开浏览器，无模拟器。

## 不提交
不提交 git，不推送，由 Argo 合并。
