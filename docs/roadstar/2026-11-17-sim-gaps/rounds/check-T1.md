# T1 验收记录

## 结论
通过（有 3 处建议改，均不挡合并；其中接入清单第 7 条「未核实」可以核实，建议补）

## 验收档位
重档（只改文字，但接入清单要逐条对脚本）

## 复跑的验收命令与输出
- `wc -l skill/SKILL.md`：54（≤55）。`git diff a262e16 1761f68` 删除行（`^-[^-]`）0 行；模板新增行 3。
- `bash skill/scripts/tests/run.sh`：rc=0，输出无 FAIL，各段 PASS 合计 369，与基线一致。
- C4 路径核对：3 条 MISSING，见下。未跑 `./install.sh`。

## 逐项完成线
- C1 通过：模板 +3，分别在「不许动什么」「资源上限与止损」「收尾」三节，原行未动，三条内容与任务书一致。
- C2 通过（有保留）：新增一节 9 行（≤12）；SKILL.md 只多 1 行。逐条核脚本：
  - 地图要有管测试目录的模块：对。`guard.py:18` 的 ALLOW 只含地图、CHANGELOG、docs/roadstar/，测试目录不豁免。
  - 「entry-check.py 调用项目检查器」：对，但检查器实际是 RuruAgent/tools/project-shell/check.py（`entry-check.py:44-52`），不在 Roadstar 仓库里；结构缺口含：非 git、无地图、没装钩子、无 CLAUDE.md、CLAUDE.md 不含「模块地图」四个字（`check.py:195-212`）。清单写「写明先读它」，没写必须出现这四个字，新项目写成别的说法仍会被拒派。
  - install-guard：对。脚本按自身位置找 guard.py，在哪个目录运行都行；写「skill/ 目录」多余但无害。已有 `core.hooksPath` 时只打印三行、退出 0，不改钩子（`install-guard.sh:109-112`），写法准确。
  - _common.md「未核实：当前脚本没有存在检查」：可核实。`skill/scripts` 下非测试脚本 grep `_common` 无命中，可直接写「脚本不检查」。
  - check-merge：对。`HEAD..分支` 算待合并提交（`guard.py:306`），验收记录按主干路径解析（`resolve_task` 把副本路径折回主干）。
  - merge --abort：对。`guard.py:404` 对含 --abort 的 merge 命令放行；「未自动回滚」属实。
  - 测试命令「未核实 ruru-run」：可核实，Codex 只搜了仓库和 ~/.claude/skills。`RuruAgent/tools/ws-guard/guard.py:7,29,462` 拦的是没套 `timeout`/`gtimeout`/`ruru-run` 的长测试命令（pytest、swift test、npm test 等），不只是裸 pytest；套 timeout 也能过。
- C3 通过：第 15 节新增 4 行（213 到 216），与原有行关键词交叉检索无重复。出处：4 份、3000 行、1500 字节、「完成状态」都在 canary-before-fanout.md 与 codex-readonly-compaction-empty-ack.md 里；`--permission-mode auto` 出自记忆索引的 spawn-sessions-in-auto-mode 条（未逐字打开该文件，标为索引核对）。
- C4 通过：文头「2026-11-17　适用版本：2.0.0」，与 `SKILL.md` 的 version "2.0.0" 一致；模块名列的 md5 前后相同，无增删。MISSING 三条：`docs/roadstar/<日期>-<slug>/` 是占位写法；`docs/roadstar/_common.md`、`docs/界面验收清单.md` 是被协作项目自己的文件，地图里写的是「项目 xxx」，不是缺文件。
- C5 通过：新增 8 行，含起因、改了什么、没验证什么，写了 T2、T3 脚本改动另有记录。
- C6 未单独核：报告不在克隆里，不影响文字验收。

接入清单对模拟报告 7 处卡点的覆盖：已盖到缺清单、CLAUDE.md、install-guard、_common.md、check-merge 位置、合并中状态；ruru-run 一条因「未核实」没给出能照做的说法。仍会卡：先开分支再派活（标记绑派活时的分支）与 `guard.py mark <场次目录> T<n>` 的用法；任务书「不许动 docs/roadstar」与要求写 .progress 互相冲突；无 trailer 的分支和快进合并不被拦。新项目照这九行做，前两处仍会卡。

## 降标准五查
- 下调门槛：无（只改文字；复核 diff 无删除行，run.sh 的 PASS 数不降）。
- 跳过或删测试：无（`git diff --stat` 只有 6 个 md 文件，`skill/scripts` 无改动）。
- 关掉检查：无。
- 留桩或半成品：无；清单里三处「未核实」是写明的缺口，其中两处现在可核实（见上）。
- 新增例外 / 改检查配置：无。
文档活没有用例文件的几查：不适用：只改文档，用 diff 删除行计数、脚本源码逐行对照、run.sh 复跑代替。

## 未验证
真实新项目照清单接入一遍；CHANGELOG 里指向的 RSG1-report.md 不在克隆里。

## 建议改（可以不改）
1. 清单 ruru-run 条：改写为已核实（ws-guard 要求长测试命令套 timeout、gtimeout 或 ruru-run，证据 RuruAgent/tools/ws-guard/guard.py:462），并去掉 CHANGELOG「ruru-run 路由未找到依据」。
2. 清单 _common.md 条：「未核实」改成「脚本不检查，写不写由人把关」。
3. 清单 CLAUDE.md 条：补一句「文中要出现『模块地图』四个字」。

## 补验 299cbb8
结论：通过。
- 「CLAUDE.md 要出现『模块地图』」对：`project-shell/check.py` 用 `'模块地图' not in 文本` 按字面判。「_common.md 脚本不检查」对：skill/scripts 非测试脚本无 `_common` 命中。
- 「标记记的是派活那一刻的分支」对：`mark` 写入当时的 HEAD 分支（`guard.py:175`），`prepare` 分支不一致就不加 Roadstar-Task（`:193`）。`dex-exec.sh:377-378` 只在带 `--write` 时调 mark；该句可补「写活派发时」，不改也不错。
- 「mark 写进当前目录所在的仓库」对：`root_at(Path.cwd())`，写到该工作区自己的 git-dir 下（`:177`）。dex-exec 在 `cd $ROOT` 里调用。
- 长测试命令要套 timeout、gtimeout 或 ruru-run：对（ws-guard `guard.py:29,462`）；放行口子是命令里写 `# ws-guard:ok <理由>`，清单没提，不影响照做。
- 清单一节 11 行（含标题和空行，条目 9 条，≤12）；SKILL.md 仍 54 行；run.sh rc=0，无 FAIL，PASS 合计 369。
