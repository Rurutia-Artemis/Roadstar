#!/usr/bin/env bash
# 圆桌 · 送一轮方案给 Dex（codex exec）审稿，产出结构化 JSON。
# 用法：dex-review.sh <plan-dir> [--model M] [--effort E] [--root DIR] [--full] [--dry-run]
#   plan-dir  含 brief.md / plan.md / ledger.md 的圆桌目录
#   --model   传给 codex -m，默认 gpt-6-astra
#   --effort  model_reasoning_effort，默认 high
#   --root    codex 的工作目录（-C），默认 plan-dir 所在的 git 根，找不到就用 plan-dir 的上级
#   --dry-run 只拼请求不调用 codex
#   --full    第二轮起也发 plan 全文与整本账本（默认精简：只发 diff + 开放议题 + 上轮刚解决的议题，全文留路径让 Dex 按需读，省额度）
# 产物（都在 <plan-dir>/rounds/）：rN-plan.md 快照、rN-plan.diff、rN-dex-request.md、rN-dex-review.json、rN-dex-stdout.log
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT="$SKILL_DIR/references/dex-review-prompt.md"
SCHEMA="$SKILL_DIR/references/dex-review.schema.json"

PLAN_DIR=""; MODEL="gpt-6-astra"; EFFORT="high"; ROOT=""; DRY=0; FULL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --full) FULL=1; shift ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) PLAN_DIR="$1"; shift ;;
  esac
done
echo "模型 $MODEL / 强度 $EFFORT"
[[ -n "$PLAN_DIR" ]] || { echo "缺 plan-dir"; exit 2; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
for f in brief.md plan.md ledger.md; do
  [[ -f "$PLAN_DIR/$f" ]] || { echo "缺 $PLAN_DIR/$f"; exit 2; }
done
if [[ -z "$ROOT" ]]; then
  ROOT="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$PLAN_DIR")"
fi

ROUNDS="$PLAN_DIR/rounds"; mkdir -p "$ROUNDS"
shopt -s nullglob
existing=("$ROUNDS"/r*-dex-request.md)
N=$(( ${#existing[@]} + 1 ))
P=$((N - 1))

WORK_ROUNDS="$ROUNDS"
if [[ $DRY -eq 1 ]]; then
  WORK_ROUNDS="$(mktemp -d "${TMPDIR:-/tmp}/dex-review.XXXXXX")"
  trap 'rm -rf "$WORK_ROUNDS"' EXIT
fi
cp "$PLAN_DIR/plan.md" "$WORK_ROUNDS/r$N-plan.md"
DIFF="$WORK_ROUNDS/r$N-plan.diff"
if [[ $N -gt 1 && -f "$ROUNDS/r$P-plan.md" ]]; then
  diff -u "$ROUNDS/r$P-plan.md" "$WORK_ROUNDS/r$N-plan.md" > "$DIFF" || true
else
  : > "$DIFF"
fi

REQ="$WORK_ROUNDS/r$N-dex-request.md"
{
  # 契约正文：跳过 frontmatter 式标题段，从分隔线之后开始
  awk 'f{print} /^---$/{f=1}' "$CONTRACT"
  echo; echo "# 本轮：第 $N 轮"
  echo; echo "## brief"; echo; cat "$PLAN_DIR/brief.md"
  if [[ $N -eq 1 || $FULL -eq 1 ]]; then
    echo; echo "## plan（当前全文）"; echo; cat "$PLAN_DIR/plan.md"
  else
    echo; echo "## plan 全文没有附在这里（省额度）"; echo
    echo "全文在 \`$PLAN_DIR/plan.md\`。本轮只审下面的 diff 和账本里的开放议题；需要核对上下文时自己按段读（sed -n 或 rg -n），不要整份 cat。"
  fi
  if [[ $N -gt 1 ]]; then
    echo; echo "## plan 自上轮的 diff"; echo
    if [[ -s "$DIFF" ]]; then echo '```diff'; cat "$DIFF"; echo '```'; else echo "（无改动）"; fi
  fi
  echo; echo "## 账本"; echo
  if [[ $N -eq 1 || $FULL -eq 1 ]]; then
    cat "$PLAN_DIR/ledger.md"
  else
    python3 - "$PLAN_DIR/ledger.md" "$P" <<'PY'
import sys, io, re
path, prev = sys.argv[1], sys.argv[2]
out = []; in_table = False; dropped = 0
for line in io.open(path, encoding="utf-8").read().split("\n"):
    if line.startswith("| #") or line.startswith("|---"):
        out.append(line); in_table = True; continue
    if in_table and line.startswith("|"):
        cells = [c.strip() for c in line.strip("|").split("|")]
        status = cells[5] if len(cells) > 5 else ""
        unresolved = ("开放" in status or "问主席" in status or ("争议" in status and "已解决" not in status))
        keep = unresolved or f"（r{prev}" in status or f"(r{prev}" in status
        if keep: out.append(line)
        else: dropped += 1
        continue
    in_table = False
    out.append(line)
if dropped:
    out.append(f"\n（账本精简：省略了 {dropped} 条更早已解决的议题，全本在 `{path}`；被省略的议题一律视为已定，不重提。）")
print("\n".join(out))
PY
  fi
  if [[ -f "$ROUNDS/r$N-chair-to-dex.md" ]]; then
    echo; echo "## 主席问 Dex"; echo; cat "$ROUNDS/r$N-chair-to-dex.md"
  fi
} > "$REQ"

echo "第 $N 轮请求已拼好：$REQ"
[[ $DRY -eq 1 ]] && { echo "dry-run，未调用 codex；临时请求退出时清理"; exit 0; }

OUT="$ROUNDS/r$N-dex-review.json"; LOG="$ROUNDS/r$N-dex-stdout.log"
CMD=(codex exec --skip-git-repo-check -C "$ROOT" -s read-only -m "$MODEL" -c "model_reasoning_effort=$EFFORT" --disable fast_mode --output-schema "$SCHEMA" -o "$OUT" -)
echo "调用：${CMD[*]} < $REQ"
start=$(date +%s)
"${CMD[@]}" < "$REQ" > "$LOG" 2>&1 || { echo "codex 退出码非 0，看 $LOG"; exit 1; }
end=$(date +%s)
python3 - "$OUT" <<'PY' || { echo "输出不是合法 JSON，看 $LOG"; exit 1; }
import json, sys
d = json.load(open(sys.argv[1]))
nb = sum(1 for i in d.get("new_issues", []) if i["severity"] == "blocking")
print(f"verdict={d['verdict']} new_issues={len(d.get('new_issues', []))} new_blocking={nb} questions={len(d.get('questions_for_chair', []))}")
PY
echo "用时 $((end - start))s，结果：$OUT"
