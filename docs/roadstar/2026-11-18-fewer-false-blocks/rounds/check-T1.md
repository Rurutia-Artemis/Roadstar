# T1 验收记录

验的提交：`81a644506386b825a92a399a053e0d607a38801f`（克隆 `/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/repo`，分支 `roadstar/fewer-false-blocks`，基线 `1ad849f`）。验收人：Claude Sonnet 5.5（换会话，不改代码）。

## 结论
通过。五处修复都生效，旧写法回退后新用例都会挂，我自己在合成仓库里实测该放行的放行、该拦的仍拦。没有「必须改」。

## 验收档位
重档（拦所有会话提交与合并的检查规则，放松方向）。

## 复跑的验收命令与输出
在克隆里 `HEAD` 为 81a6445、工作区干净时复跑：
- `guard-rules-tests.sh` 退出 0，`PASS 42 checks`（基线 41）
- `guard-tests.sh` 退出 0，`PASS 51`（基线 50）
- `close-check-tests.sh` 退出 0，`PASS 14`（基线 13）
- `brief-tests.sh` 退出 0，`PASS 90 checks`（基线 88）
- `run.sh` 退出 0，各套件末行：brief 90、review 20、run.sh 本体 95、guard 51、close-check 14、entry 36、guard-rules 42、baseline 8、trailer-path 18、marker-branch 40、exec-handback 23，合计 437（基线 432，任务书要求 ≥ 436）。没有一个套件比基线少。
- `wc -l`：guard-tests.sh 781，guard-rules-tests.sh 665，guard.py 549，其余源文件均远低于 800。
- `git diff --stat 1ad849f 81a6445` 只含任务书列的文件，外加地图一行（见下）。

## 逐项完成线
- C1 留桩：通过。F1 在基线写法下挂；合成实测见下表。
- C2 否定句：通过。F2 在基线 design_page.py 下挂。
- C3 测试越界与模块计数：通过。F3a 在基线 guard.py 下挂（`tests/test_calc.py → 地图里没有`），F3b 在基线 brief-check.py 下挂（报「模块表至少要两行数据」）。
- C4 收工检查：通过。F4 在基线 cleanup.py 下挂。
- C5 全量回归：通过，数字见上。
- C6 变异：五次都做了（手工把源文件改回 `git show 1ad849f:...` 的版本，跑对应套件，再从备份拷回；没用 checkout、stash、reset）。结果：
  - guard_rules.py 改回：guard-rules-tests 退出 1，挂 F1（`def count_done(todo_list):` 被命中）。
  - design_page.py 改回：brief-tests 退出 1，挂 F2（「这次不重做 text 模块，只改乘法。」退出 2）。
  - brief-check.py 改回：brief-tests 退出 1，F2 仍过，挂 F3b（报「设计页「模块表」至少要两行数据」）。
  - guard.py 改回：guard-tests 退出 1，挂 F3a（`tests/test_calc.py → 地图里没有`）。
  - cleanup.py 改回：close-check-tests 退出 1，挂 F4。
  全部做完后克隆里 `git diff --quiet` 为真，`git status --short` 为空，工作区与 81a6445 一致。
- C7 文档同步：通过，见下面「文档核对」。

## 合成仓库实测（`mktemp -d` 的小仓库，新版 81a6445 与基线 1ad849f 对照）

留桩（对每条样例提交一个文件，看 `lowering_hits` 的「留桩或半成品」）：

| 样例 | 预期 | 新版 | 基线 |
|---|---|---|---|
| `def count_done(todo_list):` | 放行 | 放行 | 拦 |
| `def test_todo_done():` | 放行 | 放行 | 拦 |
| `mktemp "$d/.x.XXXXXX"` | 放行 | 放行 | 拦 |
| `# TODO: 没做完` | 拦 | 拦 | 拦 |
| `// fixme 回头补`（.js） | 拦 | 拦 | 拦 |
| `x = 1  # XXX 待补` | 拦 | 拦 | 拦 |
| `raise NotImplementedError` | 拦 | 拦 | 拦 |
| `x = 1 # todo later`、`def f(): # xxx` | 拦 | 拦 | 拦 |
| `- TODO 补文档`（.md） | 拦 | 放行 | 放行 |

和预期不一样的一项是 Markdown：`.md` 不在 `guard_rules.CODE` 里，基线就不查，这次没变，不是退步。

三个「报实际结果」的项：`const u = "https://xxx.example.com"` 新版仍拦（`//` 后面跟着独立的 `xxx` 被当成注释标记）；`x = "TODO"` 新版仍拦（大写独立词）；`p.add_argument("--todo")` 新版放行（基线拦）。

否定句（`design_page.prior_art_trigger`，另用 `brief-check.py --plan` 走一遍退出码）：

| 目标句 | 预期 | 新版 |
|---|---|---|
| 这次不重做 text 模块，只改乘法。 | 放行 | 放行，退出 0（基线报「重做」） |
| 别重做，只改乘法。 | 放行 | 放行，退出 0 |
| 没有新项目，只改函数 / 非重做 | 放行 | 放行 |
| 不改接口，重做记忆服务。 | 拦 | 拦，退出 2 |
| 重做一遍登录页。 | 拦 | 拦，退出 2 |
| 新系统：本机记忆服务 / 新模块：记忆系统 | 拦 | 拦 |
| 不重做登录页，但重做注册页 | 拦 | 拦（后一个触发词照拦） |

报实际结果：「不能不重做」新版放行（紧前文以「不」结尾，被当成否定）。

测试文件越界（真提交，装真钩子，地图是 guard-tests 里的甲乙两模块，任务选甲）：

| 提交的路径 | 预期 | 新版 |
|---|---|---|
| `tests/test_calc.py`、`foo.test.js` | 放行 | 放行（基线拦 `tests/test_calc.py`） |
| `src/a/test_a.py`（甲认领） | 放行 | 放行 |
| `src/b/test_b.py`（乙认领的测试文件） | 拦 | 拦，输出 `src/b/test_b.py → 乙模块` |
| `src/b/sub/c.py`、`other.txt`（乙认领，非测试） | 拦 | 拦，`→ 乙模块` |
| `unknown.txt`、`docs/readme.md` | 拦 | 拦，`→ 地图里没有` |
| `docs/latest/x.txt` | 拦（想当然） | 放行 |

最后一行和直觉不同：`guard_rules.test_file` 用子串 `test/` 判断，`latest/` 含 `test/`，所以这种目录下的未登记文件被当成测试文件放行。这个判断函数是基线原有的，这次只是多了一处引用它，列入「可以不改」。

涉及模块计数（`brief-check.py --write --class 跨模块`，设计页没有模块表）：

| 任务书涉及模块 | 预期 | 新版 |
|---|---|---|
| 甲、tests ／ 甲，测试 ／ 甲 + Tests ／ tests + 测试 | 放行 | 退出 0 |
| 甲、乙 ／ 甲、tests、乙 ／ 甲、test_helper ／ 甲、测试模块 | 要模块表 | 退出 2 |

收工检查（`cleanup.py --check`，临时仓库，一个分支带 `Roadstar-Task: docs/roadstar/old/T9`，本场次 T1 已验收）：

| 场景 | 预期 | 新版 | 基线 |
|---|---|---|---|
| 带 `--plan-dir`（绝对和相对路径） | 只列出，退出 0 | 退出 0，输出首行「收工检查：都收完了」，另起「别的场次的（不计入）：」 | 退出 1 |
| 不带 `--plan-dir` | 和基线一样 | 退出 1，输出与基线一致 | 退出 1 |
| 本场次自己的 T2 分支没合并 | 退出 1 | 退出 1，T2 计入，T9 单列；JSON 有 `others` | 不适用 |
| 同一分支混了别场次 T8 和本场次 T5 | 全部计入 | 退出 1，T5 和 T8 都计入 | 不适用 |
| 本场次 T3 缺验收记录，另有别场次分支 | 退出 1 | 退出 1，列出「没验收：T3」，T9 单列 | 退出 1（T9 也计入） |

## 文档核对
- `skill/SKILL.md`：第 2 步和第 5 步按任务书改，和代码行为一致（`--check --plan-dir <本场次目录>`、别场次只列出）。
- `skill/references/task-brief-template.md`：同类方案那行加了否定说法不算，一致。
- `docs/模块地图.md`：更新日期改 2026-11-18；「任务执行与验收」留桩规则、范围检查、`cleanup --check` 带场次目录的语义，「流程与调度契约」否定句和 tests 不计模块数，都和实测行为一致。「大脑」加的那处登记（行 32 的文件列补 `skill/scripts/tests/close-check-tests.sh`）核对无误：该文件在基线只出现在同一节第 122 行附近的说明里、没进文件列，补上后 `skill/scripts/tests/*.sh` 十三个文件在地图里都能查到，该行属于「任务执行与验收」，和 `cleanup.py` 同一模块，登记得对。
- `CHANGELOG.md`：新增 2026-11-18 一条，写了起因、改动、验证、没验证项，数字（brief 90、guard 51、close-check 14、guard-rules 42、合计 432 到 437）和我复跑的一致。
- 文档里写到的一个差别需知：留桩规则的实际代码里，`NotImplementedError`、`fatalError(`、`unimplemented!`、`todo!(` 现在区分大小写（基线忽略大小写），只有 `not implemented` 仍忽略大小写。地图和 CHANGELOG 没有写这点，见「可以不改」。
- 没改任务书范围以外的文件；测试 diff 里没有被删或改的旧断言行（只有新增行），没有 skip。

## 降标准五查
- 下调门槛：无。没有改覆盖率、阈值、告警上限一类数字，没有改配置文件。
- 跳过或删测试：无。测试 diff 里 0 行删除，新增行里没有 skip 一类字样；四个套件的 PASS 数都比基线多。
- 关掉检查：无。没有关任何检查，也没有加开关或放行口子。
- 留桩或半成品：有两个文件会命中本仓库自己的「留桩或半成品」检查，都是故意的，不是真留桩。我用新规则对 `1ad849f..81a6445` 实跑 `lowering_hits`，命中的恰好是这两个文件：
  - `skill/scripts/tests/guard-rules-tests.sh`：F1 用例里的样例字符串 `'# TODO: 没做完'`、`'raise NotImplementedError'`、`'# XXX 待补'`、`'// todo: later'`、`'/* fixme */'`、`'XXX'`、`'FIXME'`、`'todo!()'`、`'Not Implemented'`。它们是被测规则「必须仍拦」的输入，写进测试数据里，用来证明规则没被放松到放过真留桩；同一用例里的「不该命中」样例（`count_done(todo_list)`、`test_todo_done`、`mktemp ...XXXXXX`、`TODO_LIST`、`# todo_list = []`）是另一半。样例换掉等于去掉对「仍拦」的断言。
  - `skill/scripts/guard_rules.py`：命中的是 `STUB = re.compile(...)` 这一行本身，里面有 `TODO|FIXME|XXX` 这些词，是规则的正则，不是待办。
  其余新增的测试文件（brief-tests.sh、guard-tests.sh、close-check-tests.sh）里没有 TODO、XXX 等样例字符串（我对测试 diff 的新增行逐行搜过，只在 guard-rules-tests.sh 的 F1 里出现）。
  这次留桩检查的匹配规则变窄了，逐条写明：
  - 变窄的部分：大写 `TODO`／`FIXME`／`XXX` 必须是独立词（前面不是字母数字下划线点横线，后面不是字母数字下划线），所以 `todo_list`、`test_todo_done`、`TODO_LIST`、`.XXXXXX` 之类不再命中；小写或混写的 `todo`／`fixme`／`xxx` 只在 `#`、`//`、`/*`、`<!--` 之后才算，所以 `--todo` 参数、小写变量名放行；`NotImplementedError`、`fatalError(`、`unimplemented!`、`todo!(` 由忽略大小写改成区分大小写，只有 `not implemented` 仍忽略大小写。
  - 仍拦的部分：独立的大写 TODO／FIXME／XXX（包括单独一行）、注释符之后的任意大小写 todo／fixme／xxx、`raise NotImplementedError`、`fatalError(`、`unimplemented!`、`todo!(`、`Not Implemented`。
  - 实测证据：见上面留桩表，基线拦而新版放行的是 `count_done(todo_list)`、`test_todo_done`、`mktemp ...XXXXXX`、`--todo`；新版和基线都拦的是 `# TODO`、`// fixme`、`# XXX`、`raise NotImplementedError`、`# todo later`、`# xxx`；`"TODO"` 字符串和 `https://xxx.example.com` 新版仍拦，没有放松。
  - 放松范围的结论：放行的是标识符、测试名、命令行参数、临时文件模板里的字母组合，真留桩的写法没有被放过。唯一放松面是上述四个词组的小写写法（如 `notimplementederror`、`fatalerror(`、`TODO!(` 以外的大小写变体），它们在真实代码里基本不出现。
- 新增例外 / 改检查配置：无。没有改 `.roadstar/guard.json`、`ALLOW`、任何 `ROADSTAR_*` 开关。`guard.py` 的越界判断多了一个条件（无模块认领的测试文件放行），这是任务书写明的、范围检查的收窄，已在上面实测：别模块认领的测试文件和未登记的非测试文件仍拦。

## 必须改
无。

## 可以不改
- `https://xxx.example.com` 这类 URL 里 `//` 后紧跟独立小写 `xxx` 仍被判成留桩。样例概率低，需要时给 `//` 加「前面不是冒号」的限定。
- `guard_rules.test_file` 用子串 `test/` 判断，`docs/latest/x.txt` 这种路径会被当成测试文件而放行，现在多了「未认领也放行」的出口，漏判面比之前大一点。基线原有的判断，需要时改成按路径段匹配。
- 否定词匹配对「不能不重做」这类双重否定会放行。
- 留桩的四个词组改成区分大小写，地图和 CHANGELOG 没写这一点。
- 任务书原以为 Markdown 里的 `- TODO 补文档` 会被拦，实际 `.md` 本来就不在检查的代码后缀里，基线和新版行为相同。

## 未验证
- 没装、没重载 skill（按要求没跑 `./install.sh`），没走真实项目的提交、合并和收工流程。
- 没验 RuruAgent 里 `roadstar-铁律.md` 是否需要同步（任务书说由 Argo 决定）。
- 套件只各跑了一遍；没跑多次看是否有偶发失败。
