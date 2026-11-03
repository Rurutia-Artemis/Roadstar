#!/usr/bin/env bash
# 用 API 跑 Fable 5.1 无头会话重构 Roadstar 1.12。
# 用法：run-fable-refactor.sh [花钱上限美元，默认 50]
# 只认 ANTHROPIC_API_KEY（--bare 不读订阅登录），在独立 worktree 的 roadstar-1.12 分支上干活，不 push。
set -euo pipefail
BUDGET="${1:-50}"
REPO=/Users/rurutia/Documents/RuruCode/Roadstar
WT=/Users/rurutia/Documents/RuruCode/Roadstar-wt-1.12
DOCS="$REPO/docs/2026-10-16-多家型号与自检闭环"
LOG="$DOCS/fable-refactor-$(date +%Y%m%d-%H%M).jsonl"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  # shellcheck disable=SC1090
  source ~/.zshrc >/dev/null 2>&1 || true
fi
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || { echo "没有 ANTHROPIC_API_KEY，停止" >&2; exit 2; }

if [[ ! -d "$WT" ]]; then
  git -C "$REPO" worktree add -b roadstar-1.12 "$WT" HEAD
fi
# 设计、调研、校准材料在主仓库 docs 里（未提交），复制进 worktree 供读取
mkdir -p "$WT/docs/2026-10-16-多家型号与自检闭环"
rsync -a --exclude 'fable-refactor-*.jsonl' "$DOCS/" "$WT/docs/2026-10-16-多家型号与自检闭环/"

cd "$WT"
claude -p --bare \
  --model claude-fable-5-1 --effort high \
  --max-budget-usd "$BUDGET" \
  --permission-mode acceptEdits \
  --allowedTools "Read Write Edit Glob Grep Bash WebFetch" \
  --add-dir /Users/rurutia/Documents/RuruCode/RuruAgent \
  --add-dir /Users/rurutia/Documents/RuruCode/cardestiny/cardestiny-data/spec/copy-style \
  --add-dir /Users/rurutia/Documents/RuruCode/AI任务/roadstar-calibration \
  --append-system-prompt-file "$WT/CLAUDE.md" \
  --output-format stream-json --verbose \
  "$(cat "$WT/docs/2026-10-16-多家型号与自检闭环/重构任务书-Fable.md")" \
  > "$LOG" 2>&1
echo "完成，日志：$LOG"
