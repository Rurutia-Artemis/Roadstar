#!/usr/bin/env bash
# 第二遍：Fable 5.1 按《补充交代-第二遍.md》对照、修正、打磨。用法：run-fable-pass2.sh [花钱上限美元，默认 30]
set -euo pipefail
BUDGET="${1:-30}"
WT=/Users/rurutia/Documents/RuruCode/Roadstar-wt-1.12
DOCS=/Users/rurutia/Documents/RuruCode/Roadstar/docs/2026-10-16-多家型号与自检闭环
LOG="$DOCS/fable-pass2-$(date +%Y%m%d-%H%M).jsonl"
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || { echo "没有 ANTHROPIC_API_KEY，停止" >&2; exit 2; }
cd "$WT"
claude -p --bare \
  --model claude-fable-5-1 --effort high \
  --max-budget-usd "$BUDGET" \
  --permission-mode acceptEdits \
  --allowedTools "Read Write Edit Glob Grep Bash" \
  --add-dir /Users/rurutia/Documents/RuruCode/RuruAgent \
  --add-dir /Users/rurutia/Documents/RuruCode/cardestiny/cardestiny-data/spec/copy-style \
  --add-dir /Users/rurutia/Documents/RuruCode/AI任务/roadstar-calibration \
  --append-system-prompt-file "$WT/CLAUDE.md" \
  --output-format stream-json --verbose \
  "这是 Roadstar 1.12 重构的第二遍。第一遍已经完成并在本分支提交，先读 git log、docs/2026-10-16-多家型号与自检闭环/重构报告-1.12.md 和 重构任务书-Fable.md，再按 docs/2026-10-16-多家型号与自检闭环/补充交代-第二遍.md 全文执行（它压过第一遍的任务书）。$(cat "$WT/docs/2026-10-16-多家型号与自检闭环/补充交代-第二遍.md")" \
  > "$LOG" 2>&1
echo "完成，日志：$LOG"
