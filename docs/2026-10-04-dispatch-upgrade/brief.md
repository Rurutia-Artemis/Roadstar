# 立项 · roundtable 0.3.0：按模型和额度调度（直接调度）

主席 2026-10-04 拍板的计划：/Users/rurutia/.claude/plans/lively-seeking-eagle.md（本目录 plan.md 只放验收与分工）。

- 目标：圆桌 skill 升到 0.3.0。开场读两边额度并问主席模型用法；每件活按难度、验收条件、执行环境、上下文判断后派给 Codex（Astra / 6.1 Sol / Luna）或 Claude 子代理（Opus / Sonnet），派完回来审；配套脚本、子代理定义、参考文件、仓库同步。
- 非目标：不改 dex-review-prompt.md 审稿契约；不改全局 CLAUDE.md；不动别的 skill（call-codex 只补只读参数和过时写法）。
- 硬约束：主席要求本次实施自己省 Claude 额度：脚本派 Codex gpt-6-astra / ultra 写；中文正文由 Opus 5.5 子代理起草；审稿与回放用 Opus；主会话（Fable 5.1）只写提纲、审、改最后一遍、提交。不提交别人的未提交 hunk。
- 规模：大（跨 skill 正文、参考文件、脚本、全局子代理、仓库同步）。
- 参与配置：直接调度，不开内环（方案已由主席批准）。额度读数 13:40 JST：Claude 5 小时 13%、本周 4%、Fable 6%（宽）；Codex 本周 1%、重置卡 2 张、credits 62500（宽）。主席说法：脚本给 Codex 最强模型 + ultra，agent 派 Opus。Pro 不参与。
