# CLAUDE.md — Roadstar · 引路星

这是一个 Claude Code / Codex 共用的 skill 仓库：正文在 `skill/`，升级记录在 `docs/`；Claude 主会话负责调度、任务书与验收，实现交 Codex，不派 Claude 子代理。改 skill 的规矩沿用 RuruAgent 的那几条：description 是触发契约；正文要瘦，细节进 `skill/references/`；输出形状问题写正面配方；改表达先出新旧对照给用户比；每笔改动一个 commit 加一条 CHANGELOG（含验证与未验证项）；改完跑 `skill/scripts/tests/run.sh`（桩测试）和 `./install.sh`。

脚本只用标准库和 bash；`codex exec` 一律显式带 `-s`、`-m`、`-c model_reasoning_effort=`、`--disable fast_mode`（本机 Codex 配置默认全盘读写、不询问）。额度探针 `skill/scripts/quota-status.py` 不花额度，可随时跑。

## 记忆

记忆在 M1 的记忆服务里（`RuruAgent/tools/memory`），会话开场钩子自动带入本项目的记忆、规则和待办；查以前的事用 memory_recall，主人拍板的事当场 memory_remember，收尾用 memory_checkpoint。

## 项目地图

动手前先读 `docs/模块地图.md`：模块一览、每块的入口文件、对外接口、怎么只测那一块、改它的规矩，以及「出了问题先看哪」。改了某个模块的入口、接口、测试命令或规矩，在同一个提交里更新地图那一节。
