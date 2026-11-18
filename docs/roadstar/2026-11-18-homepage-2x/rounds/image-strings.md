# 配图文字三语表

术语统一：任务书 = brief / 指示書；验收 = verify / 検収；验收记录 = verification record / 検収記録；对账 = reconcile / 照合；取证 = evidence gathering / 事実確認；收尾 = wrap up / 仕上げ；会话 = session / セッション。
长度：英文每条 ≤34 字符，日文 ≤18 全角字。hero 末行用「 · 」连接的两段，每段各自不超限。

| 图 | 位置 | 中文 | English | 日本語 |
|---|---|---|---|---|
| hero | 标题 | Roadstar 引路星 | Roadstar | Roadstar |
| hero | 主句 1 | Claude 想方案、拆活、验收， | Claude plans, splits, verifies, | Claude が設計・分割・検収し、 |
| hero | 主句 2 | Codex 写代码。 | Codex writes the code. | Codex がコードを書く。 |
| hero | 主句 3 | 换一家模型回头挑错， | Another vendor's model hunts for errors, | 別社のモデルが誤りを探し、 |
| hero | 主句 4 | 规矩由脚本卡。 | Scripts enforce the rules. | ルール違反はスクリプトが止める。 |
| hero | 节点 1 名 | Claude 主会话 | Claude main session | Claude メインセッション |
| hero | 节点 2 名 / 副 | Codex / 写代码 | Codex / Writes code | Codex / コード実装 |
| hero | 节点 3 名 / 副 | Claude 子代理 / Codex 做不了的 | Claude subagent / What Codex can't do | Claude サブエージェント / Codex にできない作業 |
| hero | 节点 4 名 / 副 | 验收 / 换会话、换一家 | Verify / New session, other vendor | 検収 / 別セッション・別社 |
| hero | 底部 | 任务书缺栏派不出去 · 没验收合不进主干 | Brief missing a field: no dispatch · Unverified: no merge | 指示書に項目抜け：割り当て不可 · 未検収：マージ不可 |
| changes | 左标 | 点名才跑 | Runs only when named | 明示呼び出し時のみ |
| changes | 右标 | 默认就走 | Runs by default | 既定で動く |
| changes | 左条 | 写在正文里 | Rules in the text | 本文に書く |
| changes | 右条 | 脚本拦三处 | Scripts block at 3 points | スクリプトが3か所で止める |
| changes | 左数 | 224 行 | 224 lines | 224 行 |
| changes | 右数 | 54 行 | 54 lines | 54 行 |
| changes | 行名 | 触发 | Trigger | 起動 |
| changes | 行名 | 规矩 | Rules | ルール |
| changes | 行名 | 正文 | Body | 本文 |
| workflow | 步骤 0 | 一页设计 | One-page design | 1 ページ設計 |
| workflow | 步骤 1 | 判难度 | Size the job | 難易度の判定 |
| workflow | 步骤 2 | 六栏任务书 | Six-field brief | 6 項目の指示書 |
| workflow | 步骤 3 | 派活 | Dispatch | 割り当て |
| workflow | 步骤 4 | 换会话验收 | Verify in a new session | 別セッションで検収 |
| workflow | 步骤 5 | 收尾 | Wrap up | 仕上げ |
| workflow | 步骤 6 | 对账 | Reconcile | 照合 |
| workflow | 泳道 | Claude 主会话 | Claude main session | Claude メインセッション |
| workflow | 泳道 | Codex 或子代理 | Codex or subagent | Codex かサブエージェント |
| workflow | 泳道 | 另一家模型 | Other vendor's model | 別社のモデル |
| gates | 栏头 | 派活前 | Before dispatch | 割り当て前 |
| gates | 栏头 | 合并时 | At merge | マージ時 |
| gates | 栏头 | 收尾时 | At wrap-up | 仕上げ時 |
| gates | 说明 | 任务书缺一栏，派不出去 | Brief missing a field: no dispatch | 指示書に項目抜け：割り当て不可 |
| gates | 说明 | 没有验收记录，合不进主干 | No verification record, no merge to main | 検収記録なし：メインにマージ不可 |
| gates | 说明 | 还有没收完的，不算做完 | Loose ends mean not done | 残作業があれば完了にならない |
| lineup | 列头 | Claude 这边 | Claude side | Claude 側 |
| lineup | 列头 | Codex 这边 | Codex side | Codex 側 |
| lineup | 中间 | 换一家验收 | Cross-vendor verify | 別社で検収 |
| lineup | Fable | 任务书、拍板 | Briefs, decisions | 指示書・最終判断 |
| lineup | Sonnet | 验收、补位 | Verify, cover gaps | 検収・代役 |
| lineup | Haiku | 取证、批量 | Evidence, bulk jobs | 事実確認・一括処理 |
| lineup | Opus | 出错才升级 | Escalate only on error | ミス時だけ Opus へ |
| lineup | Sol | 写代码 | Writes code | コード実装 |
| lineup | Astra | 难活、审方案 | Hard tasks, plan review | 難題・設計レビュー |
| lineup | 底部 | 额度用到零才停 | Stop only at zero quota | クォータが 0 になるまで止めない |
