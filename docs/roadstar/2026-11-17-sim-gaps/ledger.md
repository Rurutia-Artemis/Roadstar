# 2026-11-17-sim-gaps 账本
- 11-17 立场次：起因是主人 11-17 18:57 让盘点 Roadstar 使用情况并在空项目里模拟一遍。两份材料：`/Users/rurutia/Documents/RuruCode/AI任务/roadstar-review-1117.md`（使用盘点与缺口）、`/Users/rurutia/Documents/RuruCode/AI任务/roadstar-sim-1117.md`（空项目模拟跑：14 种故意做错漏 2、部分拦住 3、误拦 1，另有 7 处新项目卡点）。
- 范围：T1 文字（任务书模板三行、新项目接入清单、踩坑表四条、地图版本、更新日志，Sonnet 做、Codex 只读验）；T2 `dex-exec.sh`（`--write` 必带上限、空交回信号、`--wait`）；T3 `guard.py`（任务标记按分支、合并后作废、缺 trailer 警告）；T2、T3 Codex 做、Sonnet 验。
- 不做：会让检查变松的四项（留桩标识符、「重做」否定句、tests 目录越界、`cleanup.py --check` 范围）等主人说；快进合并绕过检查（`merge.ff`）会影响 `git pull`，不做。
- 草稿状态：任务书由「大脑」审过再派，未派出。
- 11-17 19:14 调度（会话「大脑」）：三份任务书由 Sonnet 起草、我核过完成线。改了 T2 一处：空交回分两档，回答文件不存在或 0 字节才改退出码 4，小于 200 字节只记 handback=short 加警告、退出码不变（写活的最终回答本来就可以很短，报告在文件里，一刀切会把正常交回当成空的）。T1 给 Sonnet（文字），T2、T3 给 Codex（gpt-6.1-sol/high），各自一个克隆。
- 11-17 19:15 T1 也给 Codex：本仓库 CLAUDE.md 写明实现交 Codex、不派 Claude 子代理（起草时按 Sonnet 写的，执行方改了，任务书内容没变，只补了一句数字要核出处）。三份的验收都由 Sonnet 做。
- 11-17 19:23 T1 交回（Codex，rounds/exec-T1-report.md）：模板 +3 行、接入清单 +10 行、第 15 节 +4 行、SKILL.md +1 行、地图 5 行、更新日志 8 行；4 份、3000 行、1500 字节三个数都核到出处；接入清单里常驻边界文件那条标了未核实。提交 1761f68。派 Sonnet 验收。
