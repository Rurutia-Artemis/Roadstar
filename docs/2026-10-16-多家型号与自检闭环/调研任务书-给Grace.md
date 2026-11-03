# Roadstar 1.12 调研任务书（给 Grace，2026-10-16）

交给：Grace（Grok 侧调研机器人）
交回：放在「Grace × Cloud 交接 / 05-Roadstar 引路星」文件夹里，每个题目一份 Google Doc，按交接约定命名「日期-grace-题号-题目」，例如「2026-10-17-grace-R1-模型价格」；放好后在 01-记忆账本记一条日志。
用途：明天（10-17 或 10-18）Claude 用 Fable 5.1 重写 Roadstar 1.12 时，直接拿这些结果填型号登记表、额度估算和分配策略。

## 背景（一段话）

Roadstar 是一个 Claude Code 技能：Claude 当总调度，把一个项目拆成很多小活，派给不同的模型去做（Claude 的 Haiku、Sonnet、Opus、Fable，OpenAI Codex 的 6.1 Sol、Astra，以后还有 Grok 和国产模型）。1.12 要在开场给用户看一张面板：接了哪几家、每家还剩多少额度、重置卡能解锁多少、这周还能派多少活，再按「自动 / 质量优先 / 省着用 / 赶时间」四种策略分配，并且给每件活预估用时和预计完成时刻。我们缺的是下面这些公开事实。

## 统一要求

- 只写查得到出处的事实。每一条都带来源链接和查证日期；查不到写「未找到」，不要估。
- 区分三类：官方公布、可信第三方（评测榜、权威媒体）、社区说法（论坛、X、Reddit）。社区说法单独放一节，标清楚。
- 价格统一写「每百万 token，输入 / 输出，美元」，有缓存价、长上下文价的也列。
- 时效：只要 2026 年 8 月以后的信息；更早的标出日期。
- 每份结果开头三行写结论，后面再放表格和出处。

## 题目

### R1 各家模型的公开价格和上下文长度

范围：
- Anthropic：Claude Fable 5.1、Opus 5.5、Sonnet 5.5、Haiku 5.5。
- OpenAI：gpt-6.1-sol、gpt-6-astra、gpt-6-luna（在 Codex 里能用的这几个），有没有对应的 API 价。
- xAI：grok-4.7、grok-4.7-build-fast、grok-4.6、grok-4.5。
- 国产：DeepSeek、Moonshot（Kimi）、阿里（Qwen）、智谱（GLM）、MiniMax 各自当前最强和最便宜的型号。

表格列：家、型号、输入价、输出价、缓存价、上下文长度、最大输出、来源链接、查证日期。

### R2 公开评测排名

范围同 R1。要这几类榜：综合（Artificial Analysis 的智能指数、LMArena）、写代码（SWE-bench Verified、Terminal-Bench 或同类）、长任务能力（METR 的时间跨度之类）。
表格列：型号、榜名、分数或名次、榜单日期、链接。没有上榜的写「未上榜」。

### R3 订阅额度规则

1. Claude Max（5x、20x）：5 小时窗和周窗的规则；不同型号（Haiku、Sonnet、Opus、Fable）扣额度的倍数有没有官方说明；Fable「最多用到周额度一半」的出处。
2. ChatGPT Pro / Plus 里 Codex 的额度：5 小时窗、周窗；「重置卡」是什么、怎么得到、一张能恢复多少；credits 是什么单位、怎么计价、和订阅额度什么关系。
3. Grok 订阅（SuperGrok 等）：用量上限；有没有办法查剩余用量（网页、API、CLI）。

每条写清楚是官方文档、帮助中心还是社区实测。

### R4 各家查余额或用量的接口

Anthropic、OpenAI、xAI、DeepSeek、Moonshot、阿里百炼、智谱、MiniMax：有没有 API 能查账户余额、本月用量、速率限制；接口地址和需要什么权限的 key。只要文档链接和一句话说明，不要试调。

### R5 同类产品怎么做「多模型分配」

看这些产品怎么让用户选策略、怎么显示额度、怎么估时间：OpenRouter（含 auto router）、Not Diamond、Martian、LiteLLM 的 router、Cursor 的 Auto 模式、Aider 的 architect 模式、Claude Code 子代理、OpenAI Codex 云任务、GitHub Copilot 的模型选择，以及你知道的其他同类。
每个产品写：有哪些预设策略（例如质量 / 成本 / 速度）、默认是什么、界面上给用户看哪些数字、有没有按任务难度自动选模型、有没有预估时间。最后单独写一节「值得 Roadstar 抄的三个做法」。

### R6 编程类 AI 任务的用时数据

有没有公开数据说明「一个编程智能体做一件 X 类型的活大概要多久」：METR 的研究、各家发布会或技术报告里的数字、可信博客的实测。重点要：小改动、页面实现、修 bug、跨模块重构这几类的时长分布。只要数据和出处。

## 优先级

R1、R3 最急（明天填表要用），然后 R5、R2，R4、R6 有多少写多少。

## 交回时

在同一文件夹放一份「日期-grace-R0-总览」：每个题目一句话结论、完成到什么程度、哪些没查到。
