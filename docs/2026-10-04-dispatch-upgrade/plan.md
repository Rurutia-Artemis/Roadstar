# roundtable 0.3.0 · 执行方案（正文见主席批准的计划文件）

状态：执行完成 2026-10-04 14:3x（直接调度）
主席：Rurutia　Argo：Claude（Fable 5.1 / max，只写提纲、审、提交）　Dex：Codex（gpt-6-astra / ultra）　Claude 侧执行者：Opus 5.5 / high　Pro：不参与

## 2 验收标准
见计划文件「怎么验」七条：quota-status.py 真跑出两边读数与档位；dex-review.sh dry-run 不留文件且请求正文不变；dex-exec.sh 桩测试全过并真跑一次 Luna；子代理定义四个名字可见；调度回放六条检查通过且一致率 ≥ 80%；三步礼回归卡三场景自检；audit-skills.sh 退出码 0、install.sh 无报错。

## 10 执行分工表
| T# | 任务 | 难度 | 验收条件 | 执行环境 | 执行方（模型·强度） | 理由 | 验收方式 | 验证方 | 主席改动 |
|---|---|---|---|---|---|---|---|---|---|
| T1 | 脚本：quota-status.py、dex-exec.sh、dex-review.sh 改动、桩测试 | 中 | 命令行 | 沙箱可跑（桩测试不联网） | Codex gpt-6-astra / ultra，workspace-write | 主席点名；接口与验收写清 | tests/run.sh 全过；真机探针由 Argo 跑 | Argo | 主席定 Astra + ultra |
| T2 | 中文正文：SKILL.md 与 references 七个文件 | 中（文字多、规矩多） | 读审 + 回放测试 | 本地写文件 | Opus 5.5 / high 子代理（Workflow，按 Argo 逐节提纲） | 省 Fable 额度；提纲已把内容写满 | Argo 逐文件审，T5 回放 | Argo + T5 | 主席要求派 Opus |
| T3 | 子代理定义 4 个 + install.sh 链接步骤 | 易 | 命令行 | 本地 | Argo | 四个小文件，写提纲比写文件还长 | Haiku `claude -p` 列出四个名字 | Argo | — |
| T4 | 仓库同步：SKILLS.md、Codex专用/AGENTS.md、SUBAGENT_MODELS.md、call-codex | 易 | 读审 | 本地 | Argo | 小改动，涉及别人的未提交 hunk 要分开提 | diff 自查 | Argo | — |
| T5 | 调度回放测试 | 中 | 程序化检查 | 子代理 | Opus 5.5 / high 子代理（Workflow） | 要没上下文的读者 | 六条检查 + 一致率 | Argo | — |
| T6 | CHANGELOG、提交、audit、install、共享记忆 | 易 | 命令行 | 本地 | Argo | 提交规矩只有主会话掌握 | audit 退出码 0 | — | — |

## 11 执行记录
| T# | 执行方 | 结果 | 验证证据 | 未闭合项 |
|---|---|---|---|---|
| T1 | Codex gpt-6-astra / ultra（workspace-write，一次派出，96,895 tokens，约 20 分钟） | 完成：quota-status.py、dex-exec.sh、tests/{run.sh,bin/codex,bin/claude} 新建，dex-review.sh 改 | Argo 验收：tests/run.sh PASS 29；真机探针 1.3 秒读到两边；dex-review 新旧请求正文 diff 为空、dry-run 两次 rounds/ 为空；dex-exec 真跑 Luna/low 8.6 秒回「正常」、meta 含 session_id 与 tokens_used=28271 | Argo 修了一处：resume 不沿用原会话模型（config 默认 gpt-6.1-sol 直接 400），改为 `-c model=` / `sandbox_mode=` 覆盖并在 root 里启动，修后 resume 跑通（44,938 tokens）；桩测试仍 29 条全过 |
| T2 | Opus 5.5 / high 子代理（Workflow，159,436 tokens，约 8 分钟） | 完成：SKILL.md 149 行 + 七个参考文件 | Argo 逐文件读审；改了两处措辞（41KB→8KB 的空跑数、开场句对照）；回放测试见 T5 | 回放第一轮暴露「执行环境」规则没分开发与验收，Argo 改规则文字并补「另一家空时敏感任务走 Pro/主席」；6.1 Sol 本机 CLI 400，表与型号表随之改 |
| T3 | Argo | 完成：global/agents/rt-{builder,builder-hard,builder-light,checker}.md，install.sh 链接步骤 | `./install.sh` 四个已链接；Haiku `claude -p` 新会话列出四个名字 | 没在新会话里真派一个任务看 /tasks 的模型与强度（省额度，frontmatter 按官方字段写） |
| T4 | Argo | 完成：SKILLS.md 两条、Codex专用/AGENTS.md 两处、SUBAGENT_MODELS.md 四处、call-codex SKILL.md 重写 | diff 自查；audit-skills.sh 退出码 0 | — |
| T5 | Opus 5.5 / high 子代理 ×16（Workflow 两轮，715,403 + 320,599 tokens） | 完成：11 份分工表，check.py 310 条 | 第一轮 282 过 13 挂；改规则文字后重跑 5 个情形，309 过 1 挂（挂的是检查脚本把「写工作区外只能 Argo」判成易活不该给 Fable，规则本意如此）；reverie A 两遍一致率 9/9 | 阈值是初值；检查脚本的那条误报没改（留作提醒） |
| T6 | Argo | 完成：CHANGELOG、提交、install、audit、共享记忆 | 见 CHANGELOG 2026-10-04 条与 git log | — |

额度：Claude 5 小时 13%→19%、本周 4%→6%、Fable 6%→8%；Codex 本周 1%→1%（Astra ultra 一单 96,895 tokens 加 Luna 三次没动整数位）。
