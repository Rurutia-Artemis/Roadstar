# 重构任务书：Roadstar 1.12（交给 Fable 5.1，经 API 无头运行）

你是 Claude Fable 5.1，这一场独立负责把 Roadstar 重构成产品级的 1.12。主席（用户）把判断交给你：哪里该改、怎么改、写成什么样，你来定，但下面的「主席已定」不许推翻。你跑在一个独立的 git worktree 里，没有人实时盯着，所以要自己读全材料、自己验证、自己写清楚报告。

## 工作区

- 仓库 worktree：`/Users/rurutia/Documents/RuruCode/Roadstar-wt-1.12`，分支 `roadstar-1.12`，基于 main 当前 HEAD。所有改动只在这里。
- 不许 `git push`，不许开 Issue、发网络请求写东西（`gh issue create`、`telemetry.py send` 真发都不行）；查资料可以读网页。本机提交，按逻辑单元分多个提交，每个提交一条 CHANGELOG。
- 花钱上限由启动脚本设定；接近上限时优先把已完成的部分提交、写报告，不要半途留下坏状态。

## 先读（读全再动手）

1. 仓库规矩：`CLAUDE.md`（description 是触发契约；正文要瘦，细节进 references；输出形状写正面配方；每笔改动一个 commit 加一条 CHANGELOG，写验证与未验证；改完跑 `skill/scripts/tests/run.sh` 和 `./install.sh`；脚本只用标准库和 bash；改了模块的入口、接口、测试命令或规矩，同一提交更新 `docs/模块地图.md`）。
2. 设计：`docs/2026-10-16-多家型号与自检闭环/设计v1.md`（**第 0 节是主席 10-16 的拍板，压过全文**）、同目录 `设计v0.md`。
3. 调研：同目录 `grace调研/`（Grace 交回的 R0–R6，含模型价格、评测、订阅额度规则、查余额接口、同类产品、任务用时）。只用里面标了出处的事实；社区说法只作参考，不进默认表。
4. 校准：先读同目录 `校准第一轮结论.md`（Codex 两型号 6 件全对、每件 1–2 分钟、周窗与 credits 不动、token 2–6 万；结论是标准活要加难度梯度、额度换算改用 token 累计反推），原始数据在 `/Users/rurutia/Documents/RuruCode/AI任务/roadstar-calibration/runs/*/summary.md`。
5. 现有 skill 全部：`skill/SKILL.md`、`skill/references/*`、`skill/scripts/*`、`README*.md`、`docs/社区数据回传.md`、`docs/模块地图.md`、`CHANGELOG.md` 最近 15 条。
6. README 规范：`/Users/rurutia/Documents/RuruCode/RuruAgent/skills/vela/SKILL.md` 的「GitHub README 标准」与 `references/github-readme/layout-and-emphasis.md`；中文 README 叙述段用 `/Users/rurutia/Documents/RuruCode/RuruAgent/skills/daerduo-tv-voice/SKILL.md` 的口吻；英日按 `/Users/rurutia/Documents/RuruCode/cardestiny/cardestiny-data/spec/copy-style/STYLE_GUIDE_EN.md`、`STYLE_GUIDE_JA.md` 的 L1。

## 主席已定（不许推翻）

- 所有用户共用一张分工表；本机记录不单独改本机起步层，只用于回传和周报（10-14）。
- 打分和迭代由 Claude 自己持有；主席每周说一句「可以迭代了」，Claude 按门槛自动改表发版（10-16，见 v0 开头）。1.12 先不做 iterate.py。
- 社区自动回传：同意一次、完工自动发、12 个白名单字段，已上线，不改 schema（1.12 不升 schema）。
- 探讨开头先做功能地图；碰壁就停、只把没过的检查项交高一级补全；Fable 平时只做主会话，两轮没收敛或审方案要最强时才派；Luna 是「还没实测」。
- 设计 v1 第 0 节六条：开场问一次策略（回车 = 自动）；调研类活交 Grace（Google Drive「Grace × Cloud 交接 / 05-Roadstar 引路星」，按 00-约定 命名与记日志）；质量优先额度不够就停下来问；1.12 不接 API、不问 API 预算；额度单位用「件」；用时默认值按实测重定。
- 中文正文不用破折号，不用「不是……而是……」类翻案句；写给不看代码的主席也能看懂。

## 1.12 要做成什么样

主席的原话：用户一调用，先弹出跟用户对接的界面，列出接了哪几家、各剩多少额度（把重置卡算进去，估一个总额度），再展示这个项目怎么分配，用户可以选「自动 / 质量优先 / 省着用 / 赶时间」；新项目先探讨，开场说清楚讨论用高等级模型；讨论完排活，一张非常清楚的表：每一项给哪个模型、为什么、预估用时、预计几点完成，加总时长和完工时刻。要真正做成产品级的 skill。

按设计 v1（第 0 节覆盖后）实现，范围以 v1 第 7 节为准，结合调研和校准数据修正：

1. 开场面板与压缩版（接入与额度、策略一问、本项目分配预览、探讨开场说明），数字全部来自脚本输出。面板第一行直说「接了 N 家」。Grace 在面板里单列为「调研协作方」。
2. `providers.json`（型号登记表：家、接法、价格、上下文、评测、默认角色，价格与评测用调研结果，带来源和日期，查不到为 null）。
3. `quota.json` 配置（Grace、默认策略、试新型号开关；不含 API 预算）。
4. 额度估算（件、可解锁、置信度；系数未校准时显示百分点加「约」）。
5. 四种策略的起步层表（`strategies.md` + `strategies.json`，自动列与 SKILL §8 逐行一致的测试）。
6. 排期脚本（依赖、并行上限、Argo 单线程、额度窗口），排活表七列加总账；`.meta` 加 `est_minutes`、`strategy`；完工报告加预估对账；本机用时校准（只改预估）。
7. 场内垃圾清理第一档（默认 dry-run，脏目录一律不动）。
8. 把 SKILL.md 重写成产品级的「使用步骤」：每一屏的正面配方、什么时候问、沉默等于什么；正文要瘦，细节进 references。旧规则里和 1.12 冲突的就地改掉，不留两套说法。
9. README 三语同步（新功能做成分段与配图，按 vela 标准；版本 1.12.0）、CHANGELOG、模块地图。

不做：API 执行器、打分、iterate.py、Grok CLI 写活、匿名中转、图形界面。

## 验证（全部要有证据写进报告）

- `bash skill/scripts/tests/run.sh` 全过，新脚本都有测试，包括「每个面板数字都能在输入 JSON 里找到」「策略自动列与 §8 一致」「脏 worktree 不删」。
- 用本机真实读数跑一次面板（`quota-status.py --json` 实读）和一次排期（拿一个示例拆分表），把输出原样贴进报告。
- 三份 README 过 vela 的 `audit_readme.py`，新文无破折号。
- `./install.sh` 在 worktree 上不要跑（会把软链指过去）；在报告里写「合并后由主会话跑」。

## 交付

写 `docs/2026-10-16-多家型号与自检闭环/重构报告-1.12.md`：一句话结论；改了什么（按模块）；每项验证的命令和输出摘要；没做成的和原因；还要主席拍板的（最多 3 条，带推荐）；花了多少钱（读启动脚本记录的结果）。最后一个提交就是这份报告。
