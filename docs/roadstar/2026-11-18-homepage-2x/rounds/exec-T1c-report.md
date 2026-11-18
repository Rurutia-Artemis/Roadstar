# RSH1 执行报告

## T1c

开工分支：`docs/homepage-2x`；基线：`6b8529f`。

### C1 · 改前逐行对照
三语表 45 行，英、日两列共 90 格；脚本和原 SVG 对应文字一致，发现 17 处与定稿不同。

| 图 | 位置 | 语言 | 脚本旧字 | 定稿新字 |
|---|---|---|---|---|
| hero | 主句 3（intro） | en | Another vendor's model reviews, | Another vendor's model hunts for errors, |
| hero | 主句 3（intro） | ja | 別社のモデルが再点検し、 | 別社のモデルが誤りを探し、 |
| hero | 主句 4（intro） | ja | ルールはスクリプトが止める。 | ルール違反はスクリプトが止める。 |
| hero | 底部（footer） | en | Brief incomplete: no dispatch · Unverified: no merge | Brief missing a field: no dispatch · Unverified: no merge |
| hero | 底部（footer） | ja | 欠けた指示書は渡せない · 未検収は取り込めない | 指示書に項目抜け：割り当て不可 · 未検収：マージ不可 |
| hero | 节点 3 名 / 副（card-T2） | ja | Claude サブエージェント / Codex が不得手な作業 | Claude サブエージェント / Codex にできない作業 |
| changes | 右条（after-1） | en | Scripts block 3 points | Scripts block at 3 points |
| changes | 右标（after-0） | ja | 最初から動く | 既定で動く |
| changes | 左标（before-0） | en | Runs on request | Runs only when named |
| changes | 左标（before-0） | ja | 呼ばれたら動く | 明示呼び出し時のみ |
| workflow | 泳道（owner-3） | ja | Codex か サブエージェント | Codex かサブエージェント |
| gates | 说明（result-0） | ja | 指示書に欠けがあれば渡せない | 指示書に項目抜け：割り当て不可 |
| gates | 说明（result-1） | en | No verification record, no merge | No verification record, no merge to main |
| gates | 说明（result-1） | ja | 検収記録がなければ main に入れない | 検収記録なし：メインにマージ不可 |
| gates | 说明（result-2） | ja | 未完了があれば完了とは言えない | 残作業があれば完了にならない |
| lineup | Haiku（claude-2） | ja | 調査・一括処理 | 事実確認・一括処理 |
| lineup | Opus（claude-3） | ja | 失敗時のみ昇格 | ミス時だけ Opus へ |

**C1 改后复核：通过。** 45 行 × 英、日两列共 90 格，定稿、生成脚本与 SVG 对应文字均一致，差异 0。英文 hero 主句 3 和 gates 合并时说明在原格折行；日文 workflow 的负责方沿用两行显示，生成脚本和 SVG 描述按定稿保留「か」后的无空格写法。

- **C2 通过。** 5 张中文图重新生成后与 HEAD 字节相同，`git diff --exit-code -- 'assets/readme/*.zh-CN.svg'` 退出 0。
- **C3 通过。** `python3 assets/readme/source/check_assets.py --all` 退出 0：`PASS 15 SVGs; three READMEs; no unreferenced SVGs`。
- **C4 通过。** 无改字的英文 `workflow.svg`、`lineup.svg` 逐字节不变；8 张改字图的尺寸见下。逐图核对所有卡片数量、几何与对齐方式保持原样。
- **C5 通过。** 三个生成器各跑两遍，15 张图的两份 `shasum -a 256 assets/readme/*.svg` 清单 `cmp` 退出 0；`bash skill/scripts/tests/run.sh` 退出 0，九行 `PASS N checks` 依次为 90、20、95、36、42、8、18、40、23。另有两条不同格式的摘要：`guard-tests.sh` 为 `PASS 51`、`close-check-tests.sh` 为 `PASS 14`，与 HEAD 的 CHANGELOG 基线记录一致。 `wc -l assets/readme/source/*.py`：检查器 273、共用模块 61、对照／流程生成器 135、拦截／分工生成器 108、hero 生成器 111，均未超 400。
- **C6 通过。** 加长一条已改英文后检查退出 1；还原并重生成后退出 0，15 项散列再比较退出 0。命令及输出见下。

### C4 · 改字图的 viewBox（宽 × 高）

| 文件 | 改前 | 改后 |
|---|---:|---:|
| changes.ja.svg | 1200 × 512 | 1200 × 512 |
| changes.svg | 1200 × 512 | 1200 × 512 |
| gates.ja.svg | 1200 × 331 | 1200 × 331 |
| gates.svg | 1200 × 331 | 1200 × 331 |
| hero.ja.svg | 1200 × 463 | 1200 × 463 |
| hero.svg | 1200 × 472 | 1200 × 472 |
| lineup.ja.svg | 1200 × 461 | 1200 × 461 |
| workflow.ja.svg | 1200 × 330 | 1200 × 330 |

### 表未收录、保持原样的图上字

| 图 | 位置 | 中文 | English | 日本語 |
|---|---|---|---|---|
| hero | intro | CLAUDE CODE SKILL · v2.0.0 | CLAUDE CODE SKILL · v2.0.0 | CLAUDE CODE SKILL · v2.0.0 |
| hero | card-T1-badge | T1 | T1 | T1 |
| hero | card-T2-badge | T2 | T2 | T2 |
| hero | card-verify-badge | ✓ | ✓ | ✓ |
| changes | before | 1.14 | 1.14 | 1.14 |
| changes | after | 2.0 | 2.0 | 2.0 |
| changes | label-3 | 开工前 | Before work | 着手前 |
| changes | before-3 | 开场面板和策略一问 | Dashboard and strategy prompt | 開始パネルと戦略の確認 |
| changes | after-3 | 一页设计 | One-page design | 1 ページ設計 |
| changes | label-4 | 探讨 | Discussion | 検討 |
| changes | before-4 | 默认三轮 | Three rounds by default | 通常は3ラウンド |
| changes | after-4 | 两家各出一轮 | One round from each vendor | 両社が1ラウンドずつ |
| workflow | number-0 | 0 | 0 | 0 |
| workflow | number-1 | 1 | 1 | 1 |
| workflow | number-2 | 2 | 2 | 2 |
| workflow | number-3 | 3 | 3 | 3 |
| workflow | number-4 | 4 | 4 | 4 |
| workflow | number-5 | 5 | 5 | 5 |
| workflow | number-6 | 6 | 6 | 6 |
| workflow | gate-2 | brief-check.py | brief-check.py | brief-check.py |
| workflow | gate-4 | guard.py | guard.py | guard.py |
| workflow | gate-5 | cleanup.py --check | cleanup.py --check | cleanup.py --check |
| gates | script-0 | brief-check.py | brief-check.py | brief-check.py |
| gates | script-1 | guard.py | guard.py | guard.py |
| gates | script-2 | cleanup.py --check | cleanup.py --check | cleanup.py --check |
| lineup | claude-0 | Fable | Fable | Fable |
| lineup | claude-1 | Sonnet | Sonnet | Sonnet |
| lineup | claude-2 | Haiku | Haiku | Haiku |
| lineup | claude-3 | Opus | Opus | Opus |
| lineup | sol | Sol | Sol | Sol |
| lineup | astra | Astra | Astra | Astra |

### C6 · 变异、还原与退出码

以下命令从仓库根执行，`$tmpdir` 是本任务的 `mktemp -d` 目录：

```bash
export PYTHONDONTWRITEBYTECODE=1
src=assets/readme/source/gen_changes_workflow.py
shasum -a 256 assets/readme/*.svg > "$tmpdir/pre-mutation.sha256"
cp -p "$src" "$tmpdir/gen_changes_workflow.py"
python3 - "$src" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
target = "Runs only when named"
assert source.count(target) == 1
path.write_text(source.replace(target, " ".join([target] * 3)), encoding="utf-8")
PY
python3 "$src"                                 # 0
python3 assets/readme/source/check_assets.py --all  # 1
cp -p "$tmpdir/gen_changes_workflow.py" "$src"
python3 "$src"                                 # 0
python3 assets/readme/source/check_assets.py --all  # 0
shasum -a 256 assets/readme/*.svg > "$tmpdir/post-mutation.sha256"
cmp "$tmpdir/pre-mutation.sha256" "$tmpdir/post-mutation.sha256"  # 0
```

变异输出：

```text
assets/readme/changes.svg: 'Runs only when named Runs only when named Runs only when named': overflows 'before-0' or has less than 12 units of side padding
```

还原后输出：`PASS 15 SVGs; three READMEs; no unreferenced SVGs`。

交付范围：3 个生成器、8 张英日 SVG 和 CHANGELOG 顶部一条更新；`git diff --check` 退出 0。重新检查了折行、脚本与 SVG 的对应关系及未改图片，无需调字号、卡片或画布。未作图面验收，按任务书留给 Argo；按离线要求未写共享记忆。本次临时目录已清理，未提交、未推送。

完成状态：全部完成
