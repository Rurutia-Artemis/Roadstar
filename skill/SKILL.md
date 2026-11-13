---
name: roadstar
description: >-
  Roadstar · 引路星 2.0：项目会话里做活的默认流程，不用点名。凡是一小时做不完的活，Claude 主会话（Argo）照六步走：判难度 → 写六栏任务书 →
  派活（规格清楚的给 Codex，根因不明的给 Claude 子代理）→ 换会话验收 → 收尾 → 对账。程序卡三处：任务书缺栏派不出去（brief-check），
  没有验收记录合不进主干（guard），没收完的活自动变待办。主席说「开圆桌」「探讨」「复盘」「全面 review」才进讨论模式，两家各出一轮短清单由主席挑。
  触发：「用 Roadstar」「引路星」「派活」「拆活」「写任务书」「验收」「开圆桌」「复盘这个项目」「你来安排谁做」，或任何需要派给 Codex / 子代理的活。
  不处理：一小时内能做完的活（直接干）；只要 Codex 一次二审（→ call-codex）；只要网页 Pro 策划（→ pro-orchestrator）；立项该不该做（→ third-eye）。
metadata:
  version: "2.0.0"
---

# Roadstar · 引路星 2.0：六步做活，规矩由程序卡

主席 2026-11-03 定：Roadstar 从「点名才跑的技能」变成项目会话的默认做法。面板、策略一问、纪要、完工报告这些屏幕都收掉；额度是进度接口里的一行，记录进记忆服务。规矩不靠读，靠三段程序：`scripts/brief-check.py`（任务书六栏）、`scripts/guard.py`（提交与合并门槛）、收尾钩子（没收完的活变待办）。1.14 的全文留在 `references/SKILL-v1.14.md`，随时能退回。

谁是谁：主席是用户，定目标、拍板、随时插话。Argo 是 Claude 主会话，只产出四样：任务书、裁定、派活记录、给主席的几句话；自己打开源文件改代码就是漏写了一份任务书（整合小修 30 行以内除外）。Dex 是 Codex（`codex exec`），干分给它的活、复核对方的活，不拆活不决定。Claude 子代理默认 Sonnet，机械活用 Haiku，Sonnet 不够用才升 Opus。Grace 是 Grok 侧的调研机器人，调研活经 Google Drive 交接。

## 第 0 步 · 一页设计
中活先写半页，大活和新项目全页，按 `references/design-template.md` 存成场次 `design.md`，再写任务书。
只有主人能答的问题一次列齐，每题带推荐答案，主人回「好」即全部按推荐答案。
大活、新项目和有问题的中活要等主人点头；点头由会话钩子从主人当轮原话记录，不手写。
`brief-check.py` 会查设计页与点头记录；上线前的老场次按豁免清单跳过。

## 六步

1. **判难度。** 小活（一小时内、只动一个模块）直接干，不写任务书。中活一份任务书、一个执行方、换会话验收，任务书不给主席过目。大活先拆成几份任务书（一份一个目标、两小时内、按文件归属切线、共享中枢只归一条线、要模拟器的最多两条并行），列一张派活表给主席看一眼再动。判法看「做错了要付多少」：返工超过一天的先开圆桌。
2. **任务书六栏**（`references/task-brief-template.md`）：目标与做完的样子（有一条能判对错的完成线）、涉及模块（地图里的名字）、不许动什么、执行环境、验收命令与期望输出（只用它验，不许执行方自己发明验法）、资源上限与止损（预计用时抄经验表，上限是预计的两倍，不许直接套 120 分钟）。有界面的活写明从 `docs/design.md` 取哪几节，没有的样子先回来问；项目没有 `docs/design.md` 就不许改界面代码（ui-guard 会拦）。`dex-exec.sh` 派活前自动跑 `brief-check.py`，中活以上的写活还要引用设计页，缺一栏派不出去。目标里有新系统、新项目、新产品、新服务、大改版、重做、立项这类整体性说法（新模块要同时带「系统 / 服务 / App」才算，单独的新建、新增文件不算）的，任务书和 plan 都要先写「同类方案」一节（至少 3 个同类开源项目或产品，带链接，写取什么不取什么和许可证），brief-check 一起查。
3. **派活。** 执行方和型号按 `references/dispatch-table.md`（规格清楚的实现给 Codex 6.1 Sol，Claude 子代理默认 Sonnet、不够用才升 Opus，取证和机械活给 Haiku，复核跨家）。Codex 走 `scripts/dex-exec.sh <plan-dir> T<n> --model … --effort … --class … --est-minutes … --brief … --max-minutes …`，默认只读，改文件加 `--write`；Claude 子代理用 Agent 工具，同一份任务书当提示，回复存 `rounds/exec-T<n>.md`，`.meta` 手写。每条线在自己的固定工作副本里（ws-guard）。额度用到零才停：到零告诉主席一次，由他充值或重置，之前不停派、不问；能用 Codex 就用 Codex，Claude 这边构思规划用 Fable，派出去的活（写代码、验收、查证）默认 Sonnet，Sonnet 真的不够用才升 Opus 并写一句为什么（主席 11-13 定，10-22「不自己降型号」作废）。
4. **验收换会话。** 干净会话只拿任务书、改动和测试结果，复跑验收命令；有界面的按 vela 的 `references/ui-acceptance.md` 截图对照；Codex 写的 Claude 验，Claude 写的 Codex 验（`scripts/dex-review.sh`）。写成 `rounds/check-T<n>.md`。没有它，`guard.py` 不让合并进主干（`git merge --no-ff`）；改了模块入口没改地图，提交会被拦。
5. **收尾。** `.meta` 补齐实耗 → `scripts/dispatch-stats.py --calibrate` → `scripts/cleanup.py --project <根>` 和 `--check`（退出 1 就不算做完）→ 提交。会话结束时钩子扫 `docs/roadstar/*/`，有任务书没有验收记录的活自动变成记忆服务里的待办，到点冒出来，不靠记性。
6. **对账由总管做。** 预估和实耗的差、一次验收通过率、返工次数进周报，反过来改经验表（`~/.config/roadstar/estimates.json` 本机校准；分工表随社区数据按门槛迭代，主席说「可以迭代了」才改）。

止损不变：每条线带 `--max-minutes`，`scripts/stall-watch.py` 盯进度；同一检查项连败三次、空转、用掉九成时间任一命中就停，做完的收下，只把没过的项交高一级型号补全；被停的线不自动重派。到预计用时一半还没有一项 pass 就看一眼，到预计用时还没完就收口。

## 开圆桌（主席点名才跑）

探讨：主席只说构思时，Argo 和 Dex 各出一轮短清单（副功能、设置、衍生功能、工程风险），主席挑，再写 `plan.md`（`references/plan-template.md`）；不默认三轮，收敛就停。复盘：两家各只读一遍现有项目，按产品层或代码层的尺子各出不足清单，Argo 合并，主席选哪几件进第 1 步。细节见 `references/modes.md`，账本格式见 `references/ledger-format.md`：主席的裁决、争议、调度记录都落账本，聊天里说过不算。

## 文件

`<项目根>/docs/roadstar/_common.md` 是项目常驻边界；每件活一个 `<日期>-<slug>/`：`plan.md`（大活才有）、`ledger.md`、`rounds/`（`exec-T<n>-request.md` 任务书、`exec-T<n>.md` 执行回复、`.meta`、`.progress`、`check-T<n>.md` 验收）。没有仓库的任务放 `~/Documents/RuruCode/AI任务/roadstar/`。本机设置在 `~/.config/roadstar/`。

## 纪律（铁律摘要由 `RuruAgent/tools/rules-reminder` 在场次活着时每轮贴进对话）

- 品质不打折：交给主席的东西先问自己愿不愿意用、愿不愿意发；额度用到零再报一次（哪家、几时重置），由主席充值或重置，之前不停、不问（主席 11-13 定）。
- 数字只来自脚本输出或 `.meta`，不手填；证据先于立场；范围外建议进停车场；密钥不进 prompt（喂给 Dex、Grace 的内容等于发给外部）。
- 默认不加 `--dangerously-*`；复核 `-s read-only`，执行 `--write`；要起模拟器、开端口才用 `danger-full-access`，任务书写死边界。
- 给主席看的话不出编号，先结论再要他定的；踩了新坑当天写进 `references/division-of-labor.md` 第 15 节或 `_common.md`。

## 维护

正文两屏以内，细节进 `references/`（分工 `division-of-labor.md`，型号 `models.md`，派活表 `dispatch-table.md`，预估 `estimates.md`，升级链 `escalation-and-learning.md`，讨论 `modes.md`、`strategies.md`）。改脚本跑 `scripts/tests/run.sh`；改规矩同步 `RuruAgent/tools/rules-reminder/roadstar-铁律.md` 和本仓库 `docs/模块地图.md`，一笔改动一个 commit 加一条 CHANGELOG。
