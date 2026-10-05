# CLAUDE.md — Roadstar · 引路星

这是一个 Claude Code / Codex 共用的 skill 仓库：正文在 `skill/`，升级记录在 `docs/`；Claude 主会话负责调度、任务书与验收，实现交 Codex，不派 Claude 子代理。改 skill 的规矩沿用 RuruAgent 的那几条：description 是触发契约；正文要瘦，细节进 `skill/references/`；输出形状问题写正面配方；改表达先出新旧对照给用户比；每笔改动一个 commit 加一条 CHANGELOG（含验证与未验证项）；改完跑 `skill/scripts/tests/run.sh`（桩测试）和 `./install.sh`。

脚本只用标准库和 bash；`codex exec` 一律显式带 `-s`、`-m`、`-c model_reasoning_effort=`、`--disable fast_mode`（本机 Codex 配置默认全盘读写、不询问）。额度探针 `skill/scripts/quota-status.py` 不花额度，可随时跑。

## Obsidian 共享项目记忆

本工作区是「Roadstar」，归属共享项目「Roadstar」。涉及继续项目、历史决定或用户偏好时，先读 `/Volumes/RuruData/ObsidianVaults/RuruOS/MEMORY.md`，再读 `/Volumes/RuruData/ObsidianVaults/RuruOS/10-Projects/Roadstar/项目主页.md`、当前记忆与最近会话记录。桌面端有 project-memory / ruru_memory 工具时，可调用 memory_context 定位同一份文件。

用户已授权此共享记忆接入。收尾记录必须写明实际工作区 `/Users/rurutia/Documents/RuruCode/Roadstar` 和验证证据。只读任务不落盘，长期偏好仅按用户明确要求更新。外置盘离线时报告缺口，不回写旧本地库。前身 roundtable（RuruAgent 仓库，2026-09-24 至 10-04）的会话记录在 `10-Projects/RuruAgent/会话记录/`。

## 项目地图（用户明确要求 · 2026-10-05）

动手前先读 `docs/模块地图.md`：模块一览、每块的入口文件、对外接口、怎么只测那一块、改它的规矩，以及「出了问题先看哪」。改了某个模块的入口、接口、测试命令或规矩，在同一个提交里更新地图那一节。
