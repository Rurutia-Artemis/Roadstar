# 四种策略：只改起步层，别的一个字不变

主席 2026-10-16 定：开场问一次策略，默认「自动分配」，直接回车就是自动；选别的只管本场；想改默认在 `quota.json` 设 `default_strategy`。机器读的那份在 `strategies.json`，`tests/run.sh` 断言它的「自动分配」一列和 SKILL §8 那张表逐行相同，所以策略永远不会悄悄改掉共用的分工表。

派活判断的顺序不变：主席硬话 > 执行环境 > 验收条件 > 难度（定类别） > 策略（定起步层） > 额度方向（定走哪条梯子）。策略只在「定起步层」这一步起作用；碰壁升级链、经验回路、审查人跨家、钱和权限由 Argo 亲验，在四种策略下完全一样。

## 四种策略一句话

| 策略 | 一句话 | 并行线 | 探讨审稿轮数 | 额度不够时 |
|---|---|---|---|---|
| 自动分配（auto，默认） | 按 SKILL §8 那张表派；额度紧就自动降档、换梯子，报一行 | Codex 3 + Claude 1，模拟器 ≤ 2 | 3（大 4） | 降强度 → 换梯子 → 串行 → 挂到重置后 → 问刷卡 → 停 |
| 质量优先（quality） | 每类往梯子上挪到顶；额度不够停下来问，不自动降型号 | 同自动 | 4 | 第 2 步就停下来问：刷卡、等重置、还是降档，主席定 |
| 省着用（thrift） | 往下挪到最低能做的那层；易活不派复核，Argo 读 diff | ≤ 2 条（护 5 小时窗） | 2 | 不问刷卡，直接挂到重置后 |
| 赶时间（rush） | 不挪层，改并行和复核：Codex 3 + Claude 3；中活 Argo 复跑验收代替独立复核；性能活推迟 | Codex 3 + Claude 3，模拟器仍 ≤ 2 | 2 | 不串行，先问刷卡 |

「试新型号」是开关，不是策略（`quota.json` 的 `try_new_models`）：开了之后取证、批量这类简单活按一半比例分给还没进起步表的型号（Luna，以后还有 grok-4.7-build-fast）试用并记战绩，其余不变。

## 各类活在四种策略下的起步型号

格式「Codex 梯子 ｜ Claude 梯子」，走哪条由额度方向定。自动分配这一列就是 SKILL §8 的表，只随新版本更新。

| 类别 | 自动分配 | 质量优先 | 省着用 | 赶时间 |
|---|---|---|---|---|
| 取证 | Haiku 只读（常驻；Claude 紧时 6.1 Sol / medium 只读） | 6.1 Sol / high 只读 ｜ Sonnet 只读（取证漏项的代价在后面；Opus 取证没有额外收益） | Haiku 只读；开关开时 Luna / high 分一半试用 | Haiku 只读，一次发出一次收齐 |
| 批量 | Haiku（常驻；Claude 紧时 6.1 Sol / low 或 medium） | 6.1 Sol / medium ｜ Sonnet | Haiku；开关开时 Luna 试用 | 同自动的那一格 |
| 页面实现 | 6.1 Sol / high ｜ Sonnet，上限 2h | Astra / high ｜ Opus | 6.1 Sol / medium ｜ Sonnet；碰壁先升强度再升型号 | 6.1 Sol / high ｜ Sonnet；Codex 线满 3 条时规格清楚的直接给 Sonnet 并行；不派独立复核 |
| 窄回归 | 6.1 Sol / high ｜ Sonnet，上限 1h | Astra / high ｜ Opus | 6.1 Sol / medium ｜ Sonnet | 6.1 Sol / high ｜ Sonnet，上限 30 分钟 |
| 跨模块 | Astra / high ｜ Opus，上限 4h | Astra / xhigh ｜ Opus | 6.1 Sol / high ｜ Sonnet，拆到每份 1.5 小时内 | Astra / high ｜ Opus，上限 2h，到点直接升级补全 |
| 根因 | Astra / xhigh ｜ Opus，附日志和可复现环境 | 同自动；一轮没收敛就派 Fable 查根因（自动是两轮） | Astra / high ｜ Opus | 同自动的那一格 |
| 性能 | Astra / high ｜ Opus，每小时看指标，上限 4h | Astra / xhigh ｜ Opus | Astra / high ｜ Opus，上限 2h | 不接：纪要里写明推迟 |
| 视觉照做 | Argo 出样张 → 主席点头 → 6.1 Sol / high ｜ Sonnet 照做 | Opus 出 2 到 3 版样张 → 主席点头 → Astra / high ｜ Opus 照做 | Argo 出 1 版样张 → 6.1 Sol / medium ｜ Sonnet 照做 | 同自动的那一格 |
| 复核 | Codex 写的 Sonnet 只读；Claude 写的 6.1 Sol / high 只读 | Codex 写的 Opus 只读；Claude 写的 Astra / high 只读 | 同自动；易活不派复核，Argo 读 diff | 中活改 Argo 复跑验收命令，不派独立线；难活仍跨家复核 |
| 审方案 | Astra / high；规模大或难回滚 xhigh | Astra / xhigh；Pro 终审（中、大）；熔断 +1 | 6.1 Sol / high；熔断 −1（最少 1）；Pro 不参与 | Astra / high 一轮加 Argo 自审；Pro 不参与 |
| 补全 | 升级链高一级：Sol → Astra → Opus 或 Fable；Haiku → Sonnet → Opus → Fable；上限取原一半、最多 1h | 同自动的那一格 | 先升强度，再升型号 | 同自动；上限取原一半、最多 30 分钟 |
| 功能地图 | Argo + Astra / high 各想一遍，Astra 再审合并稿 | Argo + Astra / xhigh 各想一遍，Astra 再审合并稿 | Argo + 6.1 Sol / high 各想一遍，6.1 Sol 再审合并稿 | Argo + Astra / high 各想一遍，审合并稿那一步跳过 |
| 探讨审稿 | Astra / high，3 轮（大 4） | Astra / xhigh，4 轮 | 6.1 Sol / high，2 轮 | Astra / high，2 轮 |

三行在四种策略下固定：同一问题两轮没收敛的第三轮由 Fable 子代理查根因写方案（质量优先改成一轮）；钱、权限、迁移、工作区外的活 Codex 写或 Sonnet 写，Argo 亲自验实际状态；Argo 自己改的整合小修超过 30 行交 6.1 Sol / high 只读复核。

Fable 在四种策略下都只做主会话，派子代理只有两种情况（两轮没收敛查根因、审方案要最强一层），质量优先把「两轮」改成「一轮」。Luna 和 Grok 不在任何策略的默认起步层，只在开关开时接取证和批量，战绩照记。

## 额度不够时怎么降、怎么提醒

按顺序走，每走一步在进度屏报一行，记进调度记录：

1. 同家降一档强度（xhigh → high → medium）。
2. 同类活换到另一条梯子（Codex ↔ Claude）。自动分配和省着用下直接换并报一行；质量优先下停下来问。
3. 并行改串行，排在 5 小时窗滚动之后。赶时间跳过这一步。
4. 不急的挂到周窗重置之后，报重置时刻。
5. 问主席刷不刷重置卡（省着用不问，直接挂起；赶时间在第 3 步就问）。
6. 停。

提醒的写法固定：「<哪家> 到 <几成>，第 <几> 件从 <A> 降到 <B>，预计完工 <原> → <新>；想保质量就 <刷卡 / 等 X 时重置>，说一声我换回来。」

## 记账

`.meta` 多一个 `strategy` 字段（auto / quality / thrift / rush），`dex-exec.sh --strategy` 写入，Claude 子代理的 `.meta` 由 Argo 手写；`dispatch-stats.py` 的经验表按它分组看。回传字段等 schema 2 再加，1.12 不动 schema。主席开场选的策略和中途切换都记进账本「主席指令」。
