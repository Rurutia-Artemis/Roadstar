# T1 · 合并闸 guard.py 认得各项目模块一览表的写法，范围检查不再被绕过

## 目标与做完的样子
`skill/scripts/guard.py` 的提交检查按任务书「涉及模块」去 `docs/模块地图.md` 的「模块一览」表里找每个模块的目录，算出这次提交允许改哪些文件。现在三个真实项目的地图它都读不全，各场次只好在「涉及模块」里写「无地图」绕过，范围检查实际被跳过。读 `modules_from()`（第 68–81 行）和 `requested_modules()`（第 147–170 行）可以确认的原因：
1. 表头只认 `模块` + `目录` 两列。RuruAgent 地图（`/Users/rurutia/Documents/RuruCode/RuruAgent/docs/模块地图.md` 第 25 行）表头是 `| 模块 | 管什么 | 目录／正本 |`，一个模块都读不出来。
2. 不认缩写。Mia 地图（`/Users/rurutia/Documents/RuruCode/Mia/docs/模块地图.md` 第 28 行）在表上方写了 `` `Core`=`app/Workstation/Sources/WorkstationCore` ``，表里写 `Core/Views/Terminal/`，guard 按字面 `Core/Views/Terminal/*` 去匹配真实路径 `app/Workstation/Sources/WorkstationCore/Views/Terminal/…`，永远匹配不上。
3. 目录格里有说明文字时拆不干净。例如 RuruAgent「中文写作、声线与语料」写的是「相关 `skills/`、`Puppis/`」，Roadstar 自己地图「社区回传」一格里带「；数据仓库 github.com/…」。
4. 任务书「涉及模块」里模块名后面跟括号说明（如「App 首页 H3 与额度（`Core/Views/Home/`）」「Mia 资料收录（原公众号文章收录）」这种本身带括号的名字）时，逐项比对会报「模块在地图中找不到」。

这件活让 guard 认得这些写法；地图里本来就是 `模块` + `目录` 标准写法的项目（Roadstar 自己、RUVO）行为不变。

完成线（每项能失败，达不到不算完成，如实报差多少）：
- C1 表头：名称列认 `模块`、`名称`、`工具` 之一；路径列认表头里含 `目录`、`路径`、`位置`、`正本` 之一的第一列（`目录／正本`、`目录/正本` 都算）。桩测试：RuruAgent 那种表头读出 ≥ 20 个模块，`记忆服务（M1）` 的路径是 `tools/memory/`。
- C2 缩写：「模块一览」节内、表格之前出现的 `` `X`=`路径` `` 写法（同一行可有多组，用中文逗号或顿号分开）登记成缩写，表里路径以 `X/` 开头的展开成 `路径/`。桩测试：Mia 那种写法下，`App 终端工作台` 的路径展开为 `app/Workstation/Sources/WorkstationCore/Views/Terminal/` 与 `app/Workstation/Sources/WorkstationCore/Models/`，改 `app/Workstation/Sources/WorkstationCore/Views/Terminal/TerminalStage.swift` 的提交在声明该模块时放行，改 `agent/src/web/x.ts` 时拦下并报「地图里归 主机 Web 与鉴权」。
- C3 路径格只取反引号里的内容（`paths()` 现在就这么做），反引号外的说明文字丢掉；反引号里不像路径的（含空格且没有 `/` 或 `.` 的、`github.com/…` 这类外部地址）也丢掉。桩测试覆盖「相关 `skills/`、`Puppis/`」和带外部地址的一格。
- C4 任务书模块名：逐项比对前，先试整项原样匹配，再试去掉末尾一对中文或英文括号及其内容后匹配；都不中才报错。桩测试：「App 首页 H3 与额度（`Core/Views/Home/`）」认成 `App 首页 H3 与额度`；名字本身带括号的「Mia 资料收录（原公众号文章收录）」原样匹配。
- C5 不变的：地图缺失、任务书写「无地图」时仍打印「这个项目没有模块地图，范围检查跳过」；入口检查（第 218–228 行，只看各模块节里的「- 入口：」行）逻辑不改；`Roadstar-Scope`、`Roadstar-Map` 两个放行尾注不改。已有 `skill/scripts/tests/guard-tests.sh` 全部用例照过。
- C6 真地图对账：写一个只读的小命令（加在 guard.py 里，`python3 skill/scripts/guard.py modules <仓库根>` 打印「模块名 制表符 展开后的路径列表」），对 Mia、RuruAgent、RUVO、Roadstar 四个仓库各跑一次，报告贴每个仓库读出的模块数和 3 行样例。Mia 期望 ≥ 35 个、RuruAgent ≥ 20 个。
- C7 文档：`skill/references/project-map.md` 里讲模块一览表格式的地方补一句「表头路径列认 目录／路径／位置／正本；表上方可写 `X`=`路径` 缩写」；`docs/模块地图.md`「任务执行与验收」节如有 guard 的测试命令变化同步写上；`CHANGELOG.md` 加一条。

## 背景
- 主会话转述：各场次只能写「无地图模块条目」绕过，例如 `Mia/docs/roadstar/2026-11-05-home-v2/rounds/exec-T7-request.md`、`exec-T10-request.md`、`exec-T12-request.md`。
- guard 由 `install-guard.sh` 装进各项目 git hooks，调用的就是 `~/.claude/skills/roadstar` → `Roadstar/skill` 这一份。所以本件在固定副本里改，不在 Roadstar 主目录改，合并前其他项目照旧用老版本。
- 新命令 `modules` 只读、不写 git 状态；子命令分发在 guard.py 末尾 `main`。

## 涉及模块
任务执行与验收、流程与调度契约（只改 `skill/references/project-map.md` 一句）。

## 接口签名与文件范围
可以改：
- `skill/scripts/guard.py`：`modules_from(text) -> dict[str, list[str]]` 签名不变，内部支持 C1–C3；新增私有 `_abbreviations(section_text) -> dict[str, str]`；`requested_modules(body, modules, request)` 签名不变，内部加 C4；新增子命令 `modules <root>`，输出每行 `模块名\t路径1, 路径2`，退出 0。
- `skill/scripts/tests/guard-tests.sh`：加 C1–C4、C6 的桩用例（桩仓库建在 `$TMP` 下）。
- `skill/references/project-map.md`、`docs/模块地图.md`（只在 C7 需要时）、`CHANGELOG.md`。

## 项目常驻边界
无 `docs/roadstar/_common.md`，边界全在下面：在固定副本 `/Users/rurutia/Documents/RuruCode/Roadstar-slots/s1`（分支 `codex/guard-c1-table-modules`，已从 main f87363f 切好）里改；测试只用 `skill/scripts/tests/` 的桩，不联网、不调真 codex/claude；`HISTFILE=/dev/null`。

## 不许动什么
范围外一律不动。特别是：`dex-exec.sh`、`brief-check.py`、`install-guard.sh`、`SKILL.md` 正文、其他项目仓库（Mia、RuruAgent、RUVO 只读，C6 只读它们的地图）、Roadstar 主目录 `/Users/rurutia/Documents/RuruCode/Roadstar`。

## 执行环境
Codex workspace-write 沙箱，root `/Users/rurutia/Documents/RuruCode/Roadstar-slots/s1`。不联网、不起服务、不开浏览器。全部检查是 Python 和 bash 桩测试，沙箱里能跑完；读其他仓库的地图用绝对路径只读。

## 验收命令与期望输出
在 s1 根目录：
1. `bash skill/scripts/tests/guard-tests.sh` → 退出 0，最后一行报总数，新用例在列。
2. `bash skill/scripts/tests/run.sh` → 退出 0。跑完 `git status --short docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 若显示改动，就 `git checkout -- docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 还原，再跑一次 `git status --short` 确认该文件不在列。
3. `for r in Mia RuruAgent RUVO-wt-feat-r1-integ Roadstar; do python3 skill/scripts/guard.py modules /Users/rurutia/Documents/RuruCode/$r | wc -l; done` → 依次 ≥ 35、≥ 20、≥ 20、≥ 8。
4. `python3 skill/scripts/guard.py modules /Users/rurutia/Documents/RuruCode/Mia | grep -F 'App 终端工作台'` → 路径以 `app/Workstation/Sources/WorkstationCore/` 开头。
5. `git -C /Users/rurutia/Documents/RuruCode/Roadstar-slots/s1 diff --stat main` → 只含「接口签名与文件范围」所列文件。

## 资源上限与止损
类别 窄回归，预计 29 分钟（本机校准表 窄回归 × gpt-6.1-sol × high 63 条样本的 P80 29.4），上限 58 分钟（预计两倍）；派发 `--est-minutes 29 --max-minutes 58 --class 窄回归`。单条命令超时 5 分钟，不开浏览器，并发 1。每试一次检查项，往 `/Users/rurutia/Documents/RuruCode/Roadstar-slots/s1/docs/roadstar/2026-11-07-guard-table/rounds/exec-T1.progress` 追加一行「ISO 时间 制表符 C 编号 制表符 pass 或 fail 制表符 一句证据」（目录不存在先 `mkdir -p`）。同一检查项连续三次失败或到上限就停，交报告写清过了哪些、卡在哪一项、试过什么。只用上面的验收命令验，不自造验法。

## 交付物
最后回复就是报告（dex-exec 存成 `rounds/exec-T1.md`），只列三样：改了哪些文件；跑了哪些验证命令及输出（含 C6 四个仓库的模块数和样例）；没做成的和原因。

## 收尾
测试临时目录由 run.sh 自己清；确认 `exec-T2.progress` 已还原。

## 不提交
不提交 git，不推送，由 Argo 合并。
