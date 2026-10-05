# Roadstar · 引路星

Claude Code 主会话当总调度，和 Codex 一起干项目的 skill。三种用法：

- 探讨：你只说构思，两家最强的模型几轮谈到能落地，再问你开不开工。
- 复盘：两家各读一遍现有项目，交叉审出不足清单和先做的三件事。
- 协同：方案已有，实现交 Codex，Claude 主会话验收或另开 Codex 只读会话复核，交完工报告。

不管哪种，开始前先列出能用的模型让你选（总调度用什么、探讨和审稿用什么、执行怎么分），派活前每件活先给推荐型号和理由，你定了才动。

Claude 主会话做调度、任务书和验收，不再派 Claude 子代理消耗 Claude 额度。常规实现、机械批量、只读取证用 `gpt-6.1-sol`，难活用 `gpt-6-astra`；钱、权限、迁移类由 Claude 主会话核验 Codex 的实现，不接受执行会话自验。

## 目录

```
skill/        SKILL.md + references/ + scripts/（额度探针、送审、派活、桩测试）+ agents/openai.yaml（Codex 侧元数据）
docs/         每次升级自己的记录（brief / plan / ledger / rounds），各项目里的实跑记录在它们自己的 docs/roadstar/
install.sh    软链到 ~/.claude/skills、~/.agents/skills、~/.codex/skills，不管理 ~/.claude/agents
CHANGELOG.md  每次改动一条，含验证与未验证项
```

## 安装

```bash
./install.sh      # 然后重开一个 Claude Code 会话
```

前置：本机装好 `codex` 命令行（0.160 以上，`npm i -g @openai/codex@latest`）并用 ChatGPT 账号登录；Claude Code 用 Max 套餐。

## 用

对 Claude 说「开圆桌」「探讨一下怎么落地」「复盘这个项目」「直接调度」，或 `/roadstar`。它会先给你模型清单和额度读数，你选完它才开始。

## 前身

2026-09-24 到 10-04 叫 roundtable，住在 RuruAgent 仓库，0.1.0 → 0.3.1 的账在 RuruAgent/CHANGELOG.md；10-04 改名搬出，从 1.0.0 起在这里记。
