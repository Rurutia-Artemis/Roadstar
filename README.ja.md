<p align="center">
  <img src="./assets/readme/hero.ja.svg" width="100%" alt="Roadstar 引路星：Claude が計画・分担・検証、Codex がコードを書く。両方のサブスクを無駄なく使い、計画は必ずもう一社のモデルがレビューする。">
</p>

<p align="center"><a href="./README.md">English</a> · <a href="./README.zh-CN.md">中文</a> · <b>日本語</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-skill-E07A5F?style=flat-square" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/Codex_CLI-%E2%89%A5%200.160-3E9C9E?style=flat-square" alt="Codex CLI 0.160 以上">
  <img src="https://img.shields.io/badge/version-1.7.0-F2B544?style=flat-square" alt="バージョン 1.7.0">
  <img src="https://img.shields.io/badge/deps-bash%20%2B%20python%20stdlib-8A8798?style=flat-square" alt="bash と Python 標準ライブラリのみ">
  <img src="https://img.shields.io/badge/license-MIT-2B2A3D?style=flat-square" alt="MIT ライセンス">
</p>

Roadstar は、Claude Code のメインセッションを Codex の指揮役にする skill です。Claude が計画を書き、作業を 2 時間以内で終わる単位に切り分け、タスクごとにモデルを選び、実装を Codex に渡します。実装結果は担当したモデルとは別のモデルで検証し、合格したものだけをあなたに届けます。Claude と ChatGPT の両方を契約している人なら、二つのサブスクがどちらもきちんと働くようになります。

## 実際に使った記録

作者は 2026-10-04 から自分の 4 つのプロジェクト（アプリ 2 本、Web サイト 1 つ、デザインツール 1 つ）で使っています。

- **17 回の実行**：アイデアの段階からリリースまで
- **244 回の Codex セッション**：`gpt-6.1-sol` が 130 回、`gpt-6-astra` が 114 回
- **31 のルール**：どれも実際の失敗のその日に書き足したものです。7 時間半で週間利用枠の 30% を消費したタスク、スクリーンショット 846 枚をコミットしてしまったマージ、全テストに合格したのにスマートフォンに入れると画面がまったくタップに反応しなかったアプリなど

毎回、最初に設定とその時点の利用枠の状況を 1 行で報告します。両サービスの状況は 1 秒強で取得でき、利用枠は消費しません。

```console
$ python3 skill/scripts/quota-status.py
Claude：5 小时 4%（18:49 重置）｜本周 82%（10-18 12:59 重置）｜Fable 2%（上限是周额度一半） → 紧
Codex：本周 24%（10-20 14:57 重置）｜重置卡 1 张｜credits … → 正常
```

Claude の利用枠は「逼迫」（紧）、Codex は「通常」（正常）なので、今週の実装は Codex に回します。出力は中国語です。

## 何が楽になるか

**サブスクが二つあるのに、働いていたのは片方だけ。** 整理と指揮が得意な Claude には計画・分担・レビューを任せ、実装は Codex が担当します。Codex の利用枠に余裕がなくなったら、作業内容に応じて Claude 側のモデルを使い分けます。機械的な一括作業は Haiku、仕様が明確な作業は Sonnet、難しい問題は Opus です。

**計画は一回では詰め切れない。** Claude と Codex は見落とすところが違います。計画検討モードでは両社の最上位モデルが同じ計画をレビューし、指摘には必ずファイル・行番号・コマンド出力のどれかを添えます。Claude は一件ずつ採用するか、理由を書いて退けるか、あなたの判断に回します。通常は 3 ラウンドで、双方から新しい指摘が出なくなれば早めに終わります。

**作業の割り振りと確認がとにかく疲れる。** 各タスクには、達成できたかどうかを明確に判定できる完了条件、モデルと推論強度、スクリプトが強制する時間上限、そしてレビュー担当が付きます。レビューには、実装を担当したモデルとは必ず別のモデルを使います。マージ後は Claude 自身がメインブランチで全テストを流し直し、実装側の「全部通りました」は参考扱いです。

<p align="center">
  <img src="./assets/readme/workflow.ja.svg" width="100%" alt="三つの使い方、入口は一つ。計画検討：アイデアだけある段階で、Claude が起案し Codex が審査して、3 ラウンドで計画と分担表を作る。レビュー：既存のプロジェクトを両者がそれぞれ読んで相互にレビューし、課題一覧と最初に取り組む 3 件をまとめる。実行：計画に沿ってタスクを分割・割り当てし、成果を検証して、根拠つきの完了レポートで終える。">
</p>

1 時間以内で終わる小さな作業はこの流れを使わず、その場で片付けます。段取りは一言でいつでも変えられます。たとえば「今月は GPT を多めに」と言えば、その実行のあいだずっとそれに従います。

## インストール

```bash
git clone https://github.com/Rurutia-Artemis/Roadstar.git
cd Roadstar && ./install.sh
```

`install.sh` は `skill/` を `~/.claude/skills`、`~/.agents/skills`、`~/.codex/skills` にシンボリックリンクします。任意のプロジェクトで Claude Code のセッションを開き直し、`/roadstar` と入力するか「用 skill」と言えば始まります。

必要なもの：

- Claude Code（作者は Max プランで開発・運用）
- [Codex CLI](https://github.com/openai/codex) 0.160 以上、ChatGPT アカウントでログイン済み：`npm i -g @openai/codex@latest`
- macOS、bash、Python 3（スクリプトは標準ライブラリのみ）

Codex がなくても Claude だけのモードで動きます。計画のレビューは Opus のサブエージェントが担当し（記録には同じ会社のモデル同士と明記）、実装は作業内容に応じて Haiku・Sonnet・Opus が担当します。このモードは実装済みですが、実際のプロジェクトで最初から最後まで通したことはまだありません。

## 構成

```
skill/        SKILL.md、references/、scripts/（利用枠の取得、レビュー依頼、タスク割り当て、スタブテスト）
docs/         この skill 自身のアップグレード記録。他プロジェクトでの実行記録は各プロジェクトの docs/roadstar/ に
install.sh    skill を Claude Code と Codex にリンク
CHANGELOG.md  変更ごとに一件、検証済みと未検証を明記
```

## 免責事項

- 個人のプロジェクトです。Anthropic および OpenAI とは関係がなく、承認も受けていません。Claude、Claude Code、Codex、ChatGPT は各社の商標です。
- あなた自身のサブスクで動き、Claude と Codex の利用枠を消費します。計画検討モード 1 回で、通常は両サービスを並行して 30〜60 分ほど使います。
- Codex は毎回サンドボックスを明示して起動します。レビューは `read-only`、実装ではワークスペースへの書き込みを許可するサンドボックスを使います。例外はシミュレーターが必要な UI の受け入れ確認だけで、このときはフルアクセスで起動し、厳密な作業範囲をタスク指示書に定めます。承認する前に指示書に目を通してください。
- モデル名・利用枠の状況区分・価格は 2026 年 10 月時点の作者の環境に基づきます。ご自身の環境に合わせて `skill/references/models.md` を書き換えてください。
- skill 本体と記録は中国語で書かれています。
- [MIT ライセンス](LICENSE)のもと、現状のまま提供します。

---

<p align="center"><sub>README のビジュアルは <a href="https://github.com/oil-oil/beautify-github-readme">beautify-github-readme</a> の手法で制作。旧名は roundtable（2026-09-24〜10-04）。</sub></p>
