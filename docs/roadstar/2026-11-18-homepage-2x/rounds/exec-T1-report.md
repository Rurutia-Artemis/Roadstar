# RSH1 · T1 公开主页三语配图

## 改了哪些文件

- `assets/readme/`：覆盖 `hero`、`workflow`、`lineup` 各三版，新增 `changes`、`gates` 各三版。三版分别使用 `.zh-CN.svg`、`.svg`、`.ja.svg` 后缀。删除 `stats*`、`section-*`、`panel*`、`loop*` 共 19 张旧图。
- `assets/readme/source/`：新增 `gen_hero.py`、`gen_changes_workflow.py`、`gen_gates_lineup.py`、`common.py`、`check_assets.py`；删除被替换的 `gen_hero_workflow.py`、`gen_lineup_loop.py`、`gen_panel_schedule.py`、`gen_sections_stats.py`。
- `docs/模块地图.md` 新增 README 配图入口和检查命令，`CHANGELOG.md` 增一条验证记录。本场记录为 `docs/roadstar/2026-11-18-homepage-2x/rounds/exec-T1.progress` 和本报告。

## 跑了哪些验证及输出

- 开工 `git status --short`：仅三份 README 的未提交改动和本场次目录；分支 `docs/homepage-2x`，HEAD `3afe4b6`。收尾仍为同一 HEAD；原有三份 README 和本场次文件未改，本轮新增或修改均在任务范围内。
- **C1**：两轮分别用 `python3` 跑三个 `gen_*.py`，两轮各用 `shasum -a 256 assets/readme/*.svg`，`cmp` 退出 0、15 个散列逐一一致。英雄图版本小字由 `skill/SKILL.md` 的 `metadata.version` 生成，当前为 `v2.0.0`。最终 `wc -l assets/readme/source/*.py`：`check_assets.py` 181、`common.py` 61、`gen_changes_workflow.py` 129、`gen_gates_lineup.py` 103、`gen_hero.py` 96。
- **C2**：`python3 assets/readme/source/check_assets.py` 退出 0，输出 `PASS 15 SVGs; README.md references`。初检发现部分版面溢出和青绿徽标对比度 4.30:1；改宽英雄图中间卡和流程泳道、折排英文验收副句、把英雄图底条扩为通栏，青绿底改为旧灰底加青绿描边。第三列最宽，型号图中线两边留白。
- **C3**：同一张 `hero.zh-CN.svg` 分别变异，用原始字节逐次还原，检查输出如下。全部还原后重跑默认命令退出 0。

| 变异 | 命令 | 退出码与输出 |
|---|---|---|
| T2 卡片宽度 238 改 70 | `python3 assets/readme/source/check_assets.py; echo $?` | 1；两段字报告 `overflows 'card-T2'` |
| 左上小字的墨色 `#2B2A3D` 改 `#F6F3ED` | `python3 assets/readme/source/check_assets.py; echo $?` | 1；`contrast 1.01:1 against 'intro' (< 4.5:1)` |
| 加入 `<script>void(0)</script>` | `python3 assets/readme/source/check_assets.py; echo $?` | 1；`forbidden SVG element <script>` |
| 删除中文 hero | `python3 assets/readme/source/check_assets.py; echo $?` | 1；`cannot read SVG`，同时报告 `README.md: missing asset` |

- **C4**：`python3 assets/readme/source/check_assets.py --all` 退出 0，输出 `PASS 15 SVGs; three READMEs; no unreferenced SVGs`。英日 README 仍引用的旧图清单：`README.en.md` 无，`README.ja.md` 无。三份都是他人已有改动，本次未编辑。
- **C5**：`bash skill/scripts/tests/run.sh` 最终退出 0，耗时 117.9 秒。在同版本 Xcode Apple Git 2.54.0、关闭临时 Git 仓库自动维护和隔离 Python 用户包的命令环境中运行；九套依次输出 `PASS 90`、`PASS 20`、`PASS 95`、`PASS 36`、`PASS 42`、`PASS 8`、`PASS 18`、`PASS 40`、`PASS 23` checks，与给定基线逐套一致，共 372 项。前两次触及各自命令时限，分别产出前 4 套和前 8 套的完整结果，没有改测试或断言。
- **C6**：对 hero、changes、workflow、gates、lineup 的中英日共 15 张逐个运行 `qlmanage -t -s 1600 -o <临时目录> <svg>`，每次退出 255、均未生成 PNG；没有目检，也没有根据 PNG 调图。C2 促成的版式调整见上。按任务书的沙箱例外，C6 不判任务失败。

### 「1.14」栏的原文依据

| 行 | `skill/references/SKILL-v1.14.md` 行号与依据 |
|---|---|
| 触发：点名才跑 | 第 4、11、26 行：以主席说「用 skill」或同类点名触发，再进入判法。 |
| 规矩：写在正文里 | 第 178–190、198–211 行：执行、验收、纪律按正文列出。第 184、190、196 行也已有派活、止损和收工脚本；对照概括的是 2.0 将三处门槛明确放进流程，未将 1.14 描述成完全没有脚本。 |
| 正文：224 行 | 第 1–224 行，`wc -l skill/references/SKILL-v1.14.md skill/SKILL.md` 实得 224、54，均按整文件统计。 |
| 开工前：开场面板和策略一问 | 第 75、82–86 行：开场同一条消息放面板、策略一问与分配预览。2.0 的一页设计有规模门槛，见 `skill/SKILL.md` 第 19–23 行。 |
| 探讨：默认三轮 | 第 4、32、40 行：探讨默认三轮，规模大可四轮，收敛可提前停。2.0 的两家各一轮见 `skill/SKILL.md` 第 38 行。 |

复核时排除了止损对照：1.14 第 190 行已有连败三次、空转、九成时间止损，2.0 第 34 行也明说不变。

### 三语文字对照

仅列图上可见文字；折行合并回原句。三步泳道和两步泳道都使用同一条「Claude 主会话」译文；型号名保留原名，不带小版本号。


#### hero

| 位置 | 中文 | English | 日本語 |
|---|---|---|---|
| 小字 | CLAUDE CODE SKILL · v2.0.0 | CLAUDE CODE SKILL · v2.0.0 | CLAUDE CODE SKILL · v2.0.0 |
| 标题 | Roadstar 引路星 | Roadstar | Roadstar |
| 主句 1 | Claude 想方案、拆活、验收， | Claude plans, splits, verifies, | Claude が設計・分割・検収し、 |
| 主句 2 | Codex 写代码。 | Codex writes the code. | Codex がコードを書く。 |
| 主句 3 | 换一家模型回头挑错， | Another vendor's model reviews, | 別社のモデルが再点検し、 |
| 主句 4 | 规矩由脚本卡。 | Scripts enforce the rules. | ルールはスクリプトが止める。 |
| 节点 1 名 | Claude 主会话 | Claude main session | Claude メインセッション |
| 卡片标记 T1 | T1 | T1 | T1 |
| 卡片标记 T2 | T2 | T2 | T2 |
| 卡片标记 ✓ | ✓ | ✓ | ✓ |
| 节点 2 名 / 副 | Codex / 写代码 | Codex / Writes code | Codex / コード実装 |
| 节点 3 名 / 副 | Claude 子代理 / Codex 做不了的 | Claude subagent / What Codex can't do | Claude サブエージェント / Codex が不得手な作業 |
| 节点 4 名 / 副 | 验收 / 换会话、换一家 | Verify / New session, other vendor | 検収 / 別セッション・別社 |
| 底部 | 任务书缺栏派不出去 · 没验收合不进主干 | Brief incomplete: no dispatch · Unverified: no merge | 欠けた指示書は渡せない · 未検収は取り込めない |

#### changes

| 位置 | 中文 | English | 日本語 |
|---|---|---|---|
| 左栏版本 | 1.14 | 1.14 | 1.14 |
| 右栏版本 | 2.0 | 2.0 | 2.0 |
| 左标 | 点名才跑 | Runs on request | 呼ばれたら動く |
| 右标 | 默认就走 | Runs by default | 最初から動く |
| 左条 | 写在正文里 | Rules in the text | 本文に書く |
| 右条 | 脚本拦三处 | Scripts block 3 points | スクリプトが3か所で止める |
| 左数 | 224 行 | 224 lines | 224 行 |
| 右数 | 54 行 | 54 lines | 54 行 |
| 行名 | 触发 | Trigger | 起動 |
| 行名 | 规矩 | Rules | ルール |
| 行名 | 正文 | Body | 本文 |
| 行名（自译） | 开工前 | Before work | 着手前 |
| 1.14 开工前（自译） | 开场面板和策略一问 | Dashboard and strategy prompt | 開始パネルと戦略の確認 |
| 2.0 开工前（复用步骤 0 译文） | 一页设计 | One-page design | 1 ページ設計 |
| 行名（自译） | 探讨 | Discussion | 検討 |
| 1.14 探讨（自译） | 默认三轮 | Three rounds by default | 通常は3ラウンド |
| 2.0 探讨（自译） | 两家各出一轮 | One round from each vendor | 両社が1ラウンドずつ |

#### workflow

| 位置 | 中文 | English | 日本語 |
|---|---|---|---|
| 步骤编号 | 0、1、2、3、4、5、6 | 0, 1, 2, 3, 4, 5, 6 | 0、1、2、3、4、5、6 |
| 步骤 0 | 一页设计 | One-page design | 1 ページ設計 |
| 步骤 1 | 判难度 | Size the job | 難易度の判定 |
| 步骤 2 | 六栏任务书 | Six-field brief | 6 項目の指示書 |
| 步骤 3 | 派活 | Dispatch | 割り当て |
| 步骤 4 | 换会话验收 | Verify in a new session | 別セッションで検収 |
| 步骤 5 | 收尾 | Wrap up | 仕上げ |
| 步骤 6 | 对账 | Reconcile | 照合 |
| 泳道 | Claude 主会话 | Claude main session | Claude メインセッション |
| 泳道 | Codex 或子代理 | Codex or subagent | Codex かサブエージェント |
| 泳道 | 另一家模型 | Other vendor's model | 別社のモデル |
| 步骤 2 拦截标 | `brief-check.py` | `brief-check.py` | `brief-check.py` |
| 步骤 4 拦截标 | `guard.py` | `guard.py` | `guard.py` |
| 步骤 5 拦截标 | `cleanup.py --check` | `cleanup.py --check` | `cleanup.py --check` |

#### gates

| 位置 | 中文 | English | 日本語 |
|---|---|---|---|
| 栏头 | 派活前 | Before dispatch | 割り当て前 |
| 栏头 | 合并时 | At merge | マージ時 |
| 栏头 | 收尾时 | At wrap-up | 仕上げ時 |
| 说明 | 任务书缺一栏，派不出去 | Brief missing a field: no dispatch | 指示書に欠けがあれば渡せない |
| 说明 | 没有验收记录，合不进主干 | No verification record, no merge | 検収記録がなければ main に入れない |
| 说明 | 还有没收完的，不算做完 | Loose ends mean not done | 未完了があれば完了とは言えない |
| 派活前脚本 | `brief-check.py` | `brief-check.py` | `brief-check.py` |
| 合并时脚本 | `guard.py` | `guard.py` | `guard.py` |
| 收尾时脚本 | `cleanup.py --check` | `cleanup.py --check` | `cleanup.py --check` |

#### lineup

| 位置 | 中文 | English | 日本語 |
|---|---|---|---|
| 列头 | Claude 这边 | Claude side | Claude 側 |
| 列头 | Codex 这边 | Codex side | Codex 側 |
| 中间 | 换一家验收 | Cross-vendor verify | 別社で検収 |
| Fable | 任务书、拍板 | Briefs, decisions | 指示書・最終判断 |
| Sonnet | 验收、补位 | Verify, cover gaps | 検収・代役 |
| Haiku | 取证、批量 | Evidence, bulk jobs | 調査・一括処理 |
| Opus | 出错才升级 | Escalate only on error | 失敗時のみ昇格 |
| Sol | 写代码 | Writes code | コード実装 |
| Astra | 难活、审方案 | Hard tasks, plan review | 難題・設計レビュー |
| 底部 | 额度用到零才停 | Stop only at zero quota | クォータが 0 になるまで止めない |

## 没做成的和原因

- 没看图：Quick Look 在沙箱内报 `sandbox_extension_issue_file ... Operation not permitted` 及 `sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean`。留给 Argo 看 15 张 PNG，并核对 GitHub 深浅背景及手机宽度。
- 没写入共享记忆：记忆入口指向 M1 服务，本轮要求不联网。
- 已清掉本任务生成的临时目录（Quick Look 输出目录、散列和测试临时目录），无待保留的旧构建。未提交、未推送。

完成状态：全部完成
