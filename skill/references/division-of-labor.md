# 调度：怎么读额度、怎么判活、派给谁、怎么验

主席开场一句话定这次模型怎么用，Argo 按这里的规则把每件活派下去、派完回来审。这里给的是默认判断和初值，跑两三场按调度记录调。

主席在第 0 节选的方向和在推荐表上点的人，压过这里所有默认值；这里的表用来生成推荐和理由。

## 1 各方能做什么

| 参与者 | 结构性优势 | 默认派给它的 |
|---|---|---|
| Argo（Claude Code 主会话） | 主席就在这个会话里，插话零成本；Plan 模式；本仓库全部 skill（vela / apple-hig / 写作三把刀 / 罗盘）；Obsidian 共享记忆读写；内置浏览器与 Claude in Chrome；iOS 模拟器；Artifact | 规划与取舍、起草与改稿、写任务书、调度、最终整合与裁定、需要主席频繁拍板的活 |
| Claude 侧子代理 | `roadstar-builder`（Opus 5.5 / high）、`roadstar-builder-hard`（Opus 5.5 / xhigh）、`roadstar-builder-light`（Sonnet 5.5 / medium）、`roadstar-checker`（Opus 5.5 / high，只读加跑命令）；另有内置 Explore 搜文件 | 按任务书实现：难活给 hard，常规给 builder，机械活和取证给 light；跨家验收给 checker |
| Dex（Codex CLI） | 另一家模型，盲区与 Argo 不重合；独立沙箱与审批策略；`--output-schema` 结构化输出；能换型号跑不同分量的活；主席的 Codex 侧有生图能力与 C2C 桥（连 Pro） | 审稿和难实现用 `gpt-6-astra`，常规实现、机械批量、只读取证和复核用 `gpt-6.1-sol`（强度按活 low / medium / high）；Luna 不派活；生图类任务 |
| Pro（网页 GPT Pro） | 主席实测推理水平与 Claude 相当，GPT 侧最强；慢，走网页，不直接读仓库 | 大方案起草、定稿终审；Codex 空时的跨家审稿兜底 |
| 主席 | 目标、取舍、预算、验收 | 开场定模型用法、争议裁决、开工与定稿的最后一句话 |

型号细节见 `models.md`。

## 2 额度怎么读

一条命令：`scripts/quota-status.py`。它只读、不花额度，两边各出一行读数加档位；`--json` 给机器读。

- Claude 看三项：5 小时窗、周窗、Fable 单列，三项各算一档，取最差的。Fable 最多占周额度一半，主会话是 Fable 时这一项先到顶。
- Codex 看周窗（有 5 小时窗也一起算，取最差）。重置卡数脚本能读到，写在 Codex 那一行。
- 命令行不在或超时，脚本退回最近一份读数并标多久前；读不到的项照实写「读不到」。

## 3 档位与阈值

每一项用「窗口过了几成、用了几成」比。按下面顺序判，命中即停：

| 档位 | 条件 |
|---|---|
| 空 | 用了 95% 以上，且 6 小时内不重置 |
| 紧 | 用了 85% 以上，或用量比时间进度快 15 个点 |
| 宽 | 用量比时间进度慢 15 个点且不到 70%；或 12 小时内重置且不到 80% |
| 正常 | 其余 |

连着两次读数都越线才换档，免得反复改派（脚本的 `--prev` 读上一次的 `--json` 输出做这件事）。两边各留一成底，给 Mia（常驻 Codex 的 Luna）和主席别的会话：派活按 90% 当顶。

## 4 主席的话和读数谁算

主席一句话定方向，读数只决定能不能派、什么时候停。重置卡的意思是「到顶时停下等主席刷卡」，不等于现在就宽。主席的硬话和读数撞上（例如主席说实现全给 Opus，Claude 周窗已经紧），照硬话排，纪要里报一句冲突，让主席知道代价。

## 5 每件活判四点

- 难度。难：要取舍、跨模块不变量、并发、迁移、权限、钱、时区与夏令时、幂等与重发、定时跨日、根因不明、主席说过「重要、不放心」。中：接口和验收写清楚的实现。易：机械批量、格式、照抄模式。
- 验收条件。命令行能验，还是要浏览器、模拟器、本地服务、真机。
- 执行环境。分两种：开发过程本身就要起浏览器、本地服务、模拟器、SwiftUI 构建或联网装依赖的（调样式、改接线、大搬运、要边编边改的），整件留在 Claude 侧；只有验收那一步要这些的，Codex 写、Claude 侧跑验收。要真动 /Applications、LaunchAgent、Obsidian、生产的那一步，只能 Argo 或主席做；脚本本身谁写都行，沙箱里只碰工作区内的临时路径。
- 上下文。任务书写得全就能派；离不开主会话的，先把上下文写进任务书再派。

## 6 优先顺序

多条同时命中按这个顺序取第一条：主席硬话 > 执行环境 > 验收条件 > 难度 > 额度方向。

## 7 派给谁

| 活 | 主席说 Claude 紧、Codex 多 | 主席说你定且两边差不多 | 主席说 Codex 紧、Claude 多 |
|---|---|---|---|
| 规划、取舍、写任务书、最后裁定 | Argo（主会话） | 同左 | 同左 |
| 取证（读代码、查现状） | Codex 6.1 Sol / low 只读 | Sonnet 子代理 | Sonnet 子代理 |
| 审方案 | Astra / high | Astra / high | 6.1 Sol / high；Codex 空时先请网页 Pro，再允许 Opus 另开会话审并注明 |
| 难实现、沙箱能验 | Astra / high | 看哪边更空 | Opus / xhigh |
| 中实现、沙箱能验 | Astra / high，Codex 紧才降 6.1 Sol / medium | 6.1 Sol / medium | Opus / high |
| 易（批量、格式、照抄模式） | 6.1 Sol / low | 6.1 Sol / low 或 Sonnet / medium | Sonnet / medium |
| 只有验收要浏览器、模拟器、本地服务、真机 | Codex 写，Sonnet 子代理跑验收 | Opus / high | Opus / high |
| 开发本身就要开浏览器、编 SwiftUI、起服务、联网 | Opus / high（整件，不拆给 Codex） | 同左 | 同左 |
| 界面视觉、中外文文案、要主席反复看的 | Opus / high（省不了，或 Codex 先写 Opus 改） | 同左 | 同左 |
| 验收 Codex 做的 | Codex 另一型号只读审（Astra 写的 6.1 Sol 审，6.1 Sol 写的 Astra 审）；钱、权限、迁移类仍要 Claude 这边验 | Opus 子代理跑验收 | Opus 子代理跑验收 |
| 验收 Claude 做的 | Codex 6.1 Sol / high 只读审 | 同左 | Codex 空时先网页 Pro，再 Opus 另开会话并注明 |

表是起点，不照表派要在理由栏写一句；max 和 ultra 主席点名才用。表里没有 Luna：主席 2026-10-04 判它太差，不派活。6.1 Sol 要 codex-cli 0.160 以上才调得到（0.158 会 400），派活前看一眼 `codex --version`。

## 8 验收分级与配对

- 易：执行方自测，Argo 读 diff。
- 中、难：换一家跑证据（Codex 做的给 `roadstar-checker`，Claude 做的给 Codex 只读）。
- 钱、权限、迁移类（含写工作区外、动生产）：不接受同家验收。另一家空了就请网页 Pro 审，或等它重置、问主席刷卡，或主席亲自验；纪要里说清选了哪条。
- Codex 空又需要另一家审：先请网页 Pro，再允许 Opus 另开会话审，纪要里注明。
- 改完再验只在改到同一处逻辑时做。

证据写进 plan §11 和 `rounds/check-T<n>.md`：具体命令与输出摘要，不写「通过」两个字了事。

## 9 怎么派

0. 把推荐表给主席，主席定了再派。

派活前复读一次额度，每件活先按 `task-brief-template.md` 写好任务书。

Codex：

```bash
scripts/dex-exec.sh <plan-dir> T3 --model gpt-6.1-sol --effort medium --brief <任务书路径> \
  [--root <项目根>] [--write] [--detach] [--resume <session id>] [--status] [--force]
```

- 默认 `-s read-only`；要改文件加 `--write`（换成 `-s workspace-write`）。`--root` 不给时取 plan-dir 所在的 git 根。
- 长任务加 `--detach`，脚本立即返回；`--status` 查运行中还是已结束、退出码和 meta。
- 返工加 `--resume <session id>` 接着原会话，session id 在 `rounds/exec-T<n>.meta`。
- Codex 档位是「空」时脚本拒派，`--force` 放行，用前要有主席的话。
- 产物都在 `rounds/`：任务书副本 `exec-T<n>-request.md`（再派一次是 `-r2`）、回复 `exec-T<n>.md`、`exec-T<n>-stdout.log`、`exec-T<n>.meta`。

Claude：用 Agent 工具，`subagent_type` 写 `roadstar-builder`、`roadstar-builder-hard`、`roadstar-builder-light`、`roadstar-checker` 之一，prompt 里给任务书路径；并行时加 `isolation: "worktree"`。

主席在 Codex 应用里做的活（生图、要走 Pro、要交互）：主席对 Codex 说「按 <任务书路径> 做 T3」，结果写回 `rounds/exec-T3.md`；主席说「T3 做完了」，Argo 读文件验收。

并行与合并：

1. 每件并行任务各开一个 worktree（Codex 用手动 `git worktree add` 再 `--root` 指过去）。
2. 大搬运类（批量改名、移目录）先单独落地，再开并行。
3. 全部回来后 Argo 按依赖顺序合并，合完跑一次全量验收。

## 10 改派与失败上限

一件活执行两次、改派一次，第三次 Argo 接手或交主席，每次都记进调度记录的失败次数。改派时任务书末尾带上已有 diff、验收输出和 worktree 路径，下一个执行者不重读仓库。改派不越过主席定的方向；要跨到另一边，先问主席一句。

## 11 两边都紧或都空的梯子

按顺序走，走到能继续为止：降一档强度 → 并行改串行 → 不急的挂到重置后 → 问主席刷不刷重置卡 → 停。每一步记进调度记录，停了就在纪要里写重置时刻。

问主席时的说法：「Codex 用到 90% 了，剩两件实现。按你定的方向我先等它周日 10 点重置；要是想现在做，刷一张重置卡告诉我，或者说一声让 Opus 接。」

## 12 常驻指令放哪

本场的记账本「主席指令」区；跨场的（例如「这个项目代码一律 Opus」）记项目 CLAUDE.md。优先级：账本 > 项目 CLAUDE.md > 额度。

## 13 成本怎么记

按每批派活前后的读数差记进账本调度记录，完工报告写一行。stdout 里的 tokens used 不当成本：它不含缓存读取，会低估两到八倍。任务自己会调模型的（例如评测脚本）单列一行预算。

## 14 主会话是什么模型

- Fable：只做判断、任务书、裁定，更要省，因为 Fable 最多占周额度一半。
- Opus：账本记实际型号；难判断加一次 Astra / xhigh 的第二意见。
- Sonnet：建议主席先切模型再开。
