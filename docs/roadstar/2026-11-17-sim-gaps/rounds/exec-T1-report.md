# RSG1 · T1 执行报告

2026-11-17。在克隆根目录直接执行，分支 `roadstar/sim-gaps-t1`，开始时 HEAD 为 `a262e16`、工作区干净。当前执行会话为 Codex，未通过 dex-exec 或子代理派发；任务书括注的 Sonnet 未在本会话切换。

## 改了什么

- C1：`skill/references/task-brief-template.md` 在指定三节各加一行，涵盖写死数值的断言冲突处理、可判定的停止条件、仅清理自己命名子目录；原有句子保持不变。
- C2：`skill/references/project-map.md:60–68` 新增接入清单，标题到末条共 9 行、7 条清单；`skill/SKILL.md:43` 只加一句指针，全文 54 行。
- C3：`skill/references/division-of-labor.md:213–216` 表尾加 4 行，原第 15 节内容不改。
- C4：`docs/模块地图.md:3` 更新为 2026-11-17、2.0.0，与 `skill/SKILL.md:11` 一致；模块一览及入口只补全路径写法，不增删模块。
- C5：`CHANGELOG.md:3–10` 新增 8 行，写起因、改动、验证范围、未验证项，并注明 T2、T3 的脚本改动另有记录。
- C6：各文件行数统计和接入清单逐条依据列于本报告末尾；进度记录在 `rounds/exec-T1.progress`。

已做一轮交付前复看：确认新增表行连续、模板和第 15 节没有删除或改写原行；接入清单区分脚本已确认行为与未核实的操作约定。

## 第 15 节去重和数字出处

先检索并阅读原第 15 节（165–212 行），未找到四条完整同义要求，因此都新增，没有因同义而跳过的条目。相关但不同的旧条目保留：178 行要求合并主干后跑 e2e；202 行要求多线合并后跑相关测试；212 行解决报告被覆盖，未给读取上限及字节阈值。这些均不能替代本次的提交后回归、批量探路、空回复判定和后台权限参数。

以下两个文件只读，未修改：

- `/Users/rurutia/.claude/projects/-Users-rurutia-Documents-RuruCode/memory/canary-before-fanout.md:11,15`：先派两三份、逐份看内容；15 行明确写每批不超过 4 份、单份阅读量约 3000 行。
- `/Users/rurutia/.claude/projects/-Users-rurutia-Documents-RuruCode/memory/codex-readonly-compaction-empty-ack.md:15`：单份不超过约 3000 行，报告小于 1500 字节或末行不是完成状态则判没做成。

4 份、3000 行、1500 字节均有出处；没有因出处缺失而删除或改成无数字说法的项目。后台参数按任务书新增，未启动真实后台会话验证。

## 验收命令与实际输出

`wc -l skill/SKILL.md`：

```text
      54 skill/SKILL.md
```

`git diff skill/scripts`：无输出。

`git diff skill/references/task-brief-template.md | grep -c '^+[^+]'`：

```text
3
```

`bash skill/scripts/tests/run.sh; echo rc=$?`：完整执行一遍；以下为九套汇总和末行，汇总与任务书提供的 a262e16 基线记录一致。本轮没有另外重跑未修改基线。

```text
PASS 88 checks
PASS 20 checks
PASS 95 checks
PASS 50
PASS 13
PASS 36 checks
PASS 41 checks
PASS 8 checks
PASS 18 checks
rc=0
```

执行任务书给出的 C4 命令：

```sh
grep -o '`[^`]*`' docs/模块地图.md | tr -d '`' | grep -E '^(skill|install|docs)' | sort -u | while read -r p; do ls -d $p >/dev/null 2>&1 || echo MISSING $p; done
```

修改前输出 4 项；修改后输出以下 3 项：

```text
MISSING docs/roadstar/<日期>-<slug>/
MISSING docs/roadstar/_common.md
MISSING docs/界面验收清单.md
```

逐条说明：

- `docs/roadstar/<日期>-<slug>/`：地图第 22 行是被协作项目的场次路径占位符，不能按字面当成当前目录；保留原文。
- `docs/roadstar/_common.md`：地图第 75 行指被协作项目的常驻边界文件，本克隆没有；不在模块一览或入口，不新建、不改写。
- `docs/界面验收清单.md`：地图第 66 行指项目级界面验收材料，本克隆没有；不在模块一览或入口，保留并报告缺失。
- 修改前的 `skill/scripts/tests/bin/{claude,codex,grok}` 是花括号缩写；已改为三个实际存在的完整路径，修改后不再列为 MISSING。

另按任务要求对模块一览和入口逐个用 `ls -d` 核对路径。原来省略目录、在仓库根不存在的 13 个文件名为：`panel.py`、`schedule.py`、`quota-config.py`、`rs_tasks.py`、`estimates.json`、`modes.md`、`division-of-labor.md`、`strategies.md`、`estimates.md`、`ledger-format.md`、`models.md`、`providers.json`、`screens.md`。前四个补 `skill/scripts/`，其余补 `skill/references/`；目标均存在。其余模块一览与入口中的实际文件路径均存在；行内的命令、参数和场次占位符没有当作静态文件改写。

## 未验证和收尾

文字和指定本地检查已完成。未运行真实新项目接入、真实提交后的回归、无人值守后台会话和真实合并；本任务不提交，因此这些只写入约定，不冒充运行验证。未运行 `./install.sh`，任务明确不改 `~/.claude` 及项目钩子；未执行 T2、T3。

未联网、未起服务；依本任务不联网及文件范围边界，未调用远端共享记忆 checkpoint。测试临时产物由测试脚本自带 EXIT 清理处理；没有自建待清的 RSG1- 临时目录，没有删除任务临时目录本身或他人的东西，没有旧版本或备份需要保留。只留下六个文档改动，以及任务书要求的本报告和进度文件；未提交、未推送。

## 各文件改动行数（git diff --stat）

```text
 CHANGELOG.md                                               |  8 ++++++++
 "docs/\346\250\241\345\235\227\345\234\260\345\233\276.md" | 10 +++++-----
 skill/SKILL.md                                             |  1 +
 skill/references/division-of-labor.md                      |  4 ++++
 skill/references/project-map.md                            | 10 ++++++++++
 skill/references/task-brief-template.md                    |  3 +++
 6 files changed, 31 insertions(+), 5 deletions(-)
```

上面 Git 转义的中文路径为 `docs/模块地图.md`，新增 5 行、删除 5 行。其他文件均只新增：CHANGELOG 8 行、SKILL 1 行、踩坑表 4 行、地图模板 10 行、任务书模板 3 行。本报告和进度文件是新交付物，未暂存，不出现在上述已跟踪文件差异中。

## 接入清单逐条依据

| 清单位置 | 内容 | 依据行号或未核实说明 |
|---|---|---|
| `project-map.md:62` | 地图覆盖测试目录 | `skill/scripts/guard.py:17–18,80–108,111–114,266–278`：按所选模块路径匹配暂存文件，放行名单没有测试目录；`entry-check.py:44–68,149–155` 只调用结构检查，不负责模块越界判定。 |
| `project-map.md:63` | CLAUDE 指向地图 | `skill/scripts/entry-check.py:44–63,149–155`；其实际调用的 `/Users/rurutia/Documents/RuruCode/RuruAgent/tools/project-shell/check.py:197–217` 检查地图、钩子及 CLAUDE 是否含“模块地图”。任务书所指 208 行实际在此检查器，当前 entry-check.py 的 208 行为返回语句；检查器不可用时会警告放行，不能宣称始终硬拦。 |
| `project-map.md:64` | 安装 Git 和 Claude 钩子 | `skill/scripts/install-guard.sh:37–47,50–76,77–116`：支持项目根及 --claude，合并 Claude PreToolUse，已有 core.hooksPath 时提示手动接入；本轮只读核实，没安装。 |
| `project-map.md:65` | 常驻边界文件 | 未核实脚本强制检查：对 `skill/scripts/` 检索 `_common.md`、项目常驻边界，没有命中；使用约定来自 `skill/references/task-brief-template.md:30–31` 和 `division-of-labor.md:218–227`。清单明确标“未核实”。 |
| `project-map.md:66` | 主干预检、主干工作区验收记录、no-ff 合并 | `skill/scripts/guard.py:136–164,299–308,312–324,441–447,478–479`：相对当前 HEAD 枚举任务、归一到主工作区场次目录、要求非空记录。脚本不强制分支名必须 main/master，在目标主干运行是调用前提。 |
| `project-map.md:67` | 被拦后退出合并再重试 | `skill/scripts/guard.py:330–346,401–405`、`skill/scripts/tests/guard-tests.sh:496–502`：读取待合并状态，允许 --abort。未核实脚本自动回滚或强制“先 abort”；清单写为人工处理步骤，且限定已进入合并状态。 |
| `project-map.md:68` | 测试命令与 ruru-run 路由 | 未核实。对仓库及 `~/.claude/skills` 使用 `rg -n --hidden --follow 'ruru-run|裸.*pytest|pytest.*拦'` 无匹配；仓库脚本中 pytest 命中是任务书词法识别与降标准扫描，不能支持该路由。没有照抄未经证实的测试命令。 |

完成状态：全部完成
