# Roadstar · 更新日志

## 2026-10-04 · 1.0.0：改名 Roadstar · 引路星，搬到独立仓库，加「开始前选模型」和「派活前先推荐、主席定」

用户 10-04 定名 Roadstar（引路星），要求搬到 RuruCode 下独立文件夹便于迭代；开始前一定要给他选模型的权利（总调度用什么、探讨和审稿用什么、执行怎么分，他大多数情况想自己选）；派活前每件活先推荐交给哪个模型并写明理由，最后由他决定；功能分三种：协同、复盘、探讨，探讨阶段用最强模型，干活才用便宜的。

- 搬迁：`RuruAgent/skills/roundtable` → `Roadstar/skill`，`RuruAgent/global/agents/rt-*` → `Roadstar/agents/roadstar-*`，10-04 升级的记录 → `Roadstar/docs/2026-10-04-dispatch-upgrade`。skill 名 roadstar，各项目记录目录改 `docs/roadstar/<日期>-<slug>/`（旧 `docs/roundtable/` 照旧能读）。软链：`~/.claude/skills/roadstar`、`~/.claude/agents/roadstar-*.md`、`~/.agents/skills/roadstar`、`~/.codex/skills/roadstar`；旧的 roundtable / rt-* 软链已清。
- 正文：（Opus 子代理按提纲改，见 docs/2026-10-04-roadstar-1-0/）第 0 节「选模型」：列出两边能用的模型和额度，AskUserQuestion 一次问三件事，主席答了才开始；纪要第 5 段改成「推荐分工表」（推荐给谁 / 理由 / 备选），问「按推荐来还是改哪几条」，主席定了才派；新建 `references/modes.md` 写三种用法的流程（复盘：两家各自只读取证各出不足清单 → 合并 → Dex 审 → 不足清单 + 先做的三件事）。
- 前身账目：roundtable 0.1.0 → 0.3.1（2026-09-24 至 10-04）在 `RuruAgent/CHANGELOG.md`。
- 验证：（待填）
- 未验证：（待填）
