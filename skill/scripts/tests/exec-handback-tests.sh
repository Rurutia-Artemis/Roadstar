#!/usr/bin/env bash
# 离线交回契约；全部推理和额度请求都走 tests/bin/codex 桩。
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/RSG2-handback.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'echo "FAIL: handback line $LINENO" >&2' ERR
export PATH="$TMP/bin:$TEST_DIR/bin:$PATH"
export PYTHONDONTWRITEBYTECODE=1
export ROADSTAR_CONFIG_DIR="$TMP/config"
export RURUCODE_ROOT="$TMP/RuruCode"
export WS_GUARD_DIR="$TMP/no-ws-guard"
export PROJECT_SHELL_DIR="$TMP/no-project-shell"
export RURU_APPROVALS_CMD="$TMP/no-approvals"
export FAKE_TRACE_FILE="$TMP/trace.jsonl"
export STUB_CODEX="$TEST_DIR/bin/codex"
unset FAKE_CODEX_USED FAKE_CODEX_DELAY FAKE_CODEX_EXIT FAKE_CODEX_REPORT FAKE_CODEX_REPLY
unset ROADSTAR_MINUTE_SECONDS ROADSTAR_PROJECTS RSG2_REPLY_MODE
unset BRIEF_CHECK ROADSTAR_DESIGN_CHECK
mkdir -p "$TMP/bin" "$TMP/plan"
PLAN="$TMP/plan"
BRIEF="$PLAN/brief.md"
cat > "$BRIEF" <<'BRIEF'
# 离线任务
## 目标与做完的样子
检查交回契约。完成线：离线桩返回预期结果。
## 涉及模块
任务执行与验收
## 不许动什么
仓库外
## 执行环境
离线 stub
## 验收命令与期望输出
`true` 期望退出 0
## 资源上限与止损
预计 1 分钟，上限 5 分钟
BRIEF
# 保持公共桩不变；包装器仅在桩成功后模拟 -o 文件丢失或被截成 0 字节。
cat > "$TMP/bin/codex" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
rc=0
bash "$STUB_CODEX" "$@" || rc=$?
output=""; next=0
for arg in "$@"; do
  if [[ "$next" -eq 1 ]]; then output="$arg"; break; fi
  if [[ "$arg" == -o ]]; then next=1; fi
done
if [[ "$rc" -eq 0 && -n "$output" ]]; then
  case "${RSG2_REPLY_MODE:-}" in
    missing) rm -f "$output" ;;
    zero) : > "$output" ;;
  esac
fi
exit "$rc"
WRAPPER
chmod +x "$TMP/bin/codex"
COUNT=0
pass() { COUNT=$((COUNT + 1)); printf 'ok %d - %s\n' "$COUNT" "$1"; }
expect_exit() {
  local expected="$1" actual=0
  shift
  "$@" > "$TMP/last-output" 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    cat "$TMP/last-output" >&2
    printf 'expected exit %s, got %s\n' "$expected" "$actual" >&2
    return 1
  fi
}
run_task() {
  bash "$SCRIPTS/dex-exec.sh" "$PLAN" "$1" --model m --effort high --class 补全 --est-minutes 1 --brief "$BRIEF" --root "$TMP" "${@:2}"
}
wait_done() {
  local i
  for ((i=0; i<100; i++)); do
    [[ -f "$1" ]] && return 0
    sleep 0.1
  done
  return 1
}
for flags in '' '--resume old-session' '--dry-run' '--resume old-session --dry-run'; do
  # flags 是本文件写死的选项，不含路径。
  expect_exit 2 run_task T1 --write $flags
  grep -q '写活必须带 --max-minutes（常规 120、难活 240、窄回归 60）' "$TMP/last-output"
  [[ ! -e "$PLAN/rounds" && ! -e "$ROADSTAR_CONFIG_DIR" && ! -e "$FAKE_TRACE_FILE" ]]
done
expect_exit 2 bash "$SCRIPTS/dex-exec.sh" "$PLAN" T1 --write
grep -q '写活必须带 --max-minutes' "$TMP/last-output"
pass 'C1 写活含 resume/dry-run 缺上限先于 model 被拒，且无产物'
run_task T1 --write --max-minutes 5 --dry-run > "$TMP/with-cap"
grep -q '时间上限：5 分钟' "$TMP/with-cap"
[[ ! -e "$PLAN/rounds" && ! -e "$ROADSTAR_CONFIG_DIR" && ! -e "$FAKE_TRACE_FILE" ]]
run_task T1 --write --max-minutes 5 > "$TMP/with-cap"
grep -q '^exit=0$' "$PLAN/rounds/exec-T1.meta"
pass 'C1 带上限 dry-run 与写活放行'
for mode in missing zero; do
  RSG2_REPLY_MODE="$mode" expect_exit 4 run_task T2
  [[ "$(cat "$PLAN/rounds/exec-T2.exit")" == 4 ]]
  grep -q '^handback=empty$' "$PLAN/rounds/exec-T2.meta"
  grep -q '^exit=4$' "$PLAN/rounds/exec-T2.meta"
  grep -q '^警告：.*exec-T2.md.*exec-T2-stdout.log' "$TMP/last-output"
  grep -q '交回为空' "$TMP/last-output"
  ! grep -q 'codex 退出码 4' "$TMP/last-output"
  if [[ "$mode" == missing ]]; then [[ ! -e "$PLAN/rounds/exec-T2.md" ]];
  else [[ -f "$PLAN/rounds/exec-T2.md" && ! -s "$PLAN/rounds/exec-T2.md" ]]; fi
  pass "C2 $mode 交回退出 4，meta/警告/失败说明齐全"
done
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T2 --write --status > "$TMP/status" 2>&1
grep -q '^handback=empty$' "$TMP/status"
grep -q '退出码：4' "$TMP/status"
! grep -q 'codex 退出码 4' "$TMP/status"
pass 'C1/C2 status 无需写活上限且展示 handback 与退出码 4'
for bytes in 1 199; do
  reply="$(python3 -c 'import sys; print("x" * (int(sys.argv[1])-1), end="")' "$bytes")"
  FAKE_CODEX_REPLY="$reply" expect_exit 0 run_task T3
  [[ "$(wc -c < "$PLAN/rounds/exec-T3.md" | tr -d ' ')" == "$bytes" ]]
  [[ "$(cat "$PLAN/rounds/exec-T3.exit")" == 0 ]]
  grep -q '^handback=short$' "$PLAN/rounds/exec-T3.meta"
  grep -q "^警告：.*${bytes} 字节.*exec-T3.md.*exec-T3-stdout.log" "$TMP/last-output"
  pass "C2 $bytes 字节交回只警告不改退出码"
done
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T3 --status > "$TMP/short-status"
grep -q '^handback=short$' "$TMP/short-status"
pass 'C2 status 展示 short'
reply="$(python3 -c 'print("x" * 199, end="")')"
FAKE_CODEX_REPLY="$reply" expect_exit 0 run_task T3
[[ "$(wc -c < "$PLAN/rounds/exec-T3.md" | tr -d ' ')" == 200 ]]
! grep -q '^handback=' "$PLAN/rounds/exec-T3.meta"
! grep -q '^警告：.*交回' "$TMP/last-output"
pass 'C2 200 字节无 handback，重派不残留 short'
FAKE_CODEX_REPORT="$PLAN/rounds/exec-T4.md" FAKE_CODEX_REPLY=done expect_exit 0 run_task T4
[[ "$(grep -c '^detail line' "$PLAN/rounds/exec-T4.md")" == 40 ]]
! grep -q '^handback=' "$PLAN/rounds/exec-T4.meta"
pass 'C2 自写长报告加简短最终回复不误报'
FAKE_CODEX_EXIT=3 expect_exit 3 run_task T5
[[ "$(cat "$PLAN/rounds/exec-T5.exit")" == 3 ]]
grep -q '^handback=empty$' "$PLAN/rounds/exec-T5.meta"
pass 'C2 非零原码 3 不改成 4'
FAKE_CODEX_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 expect_exit 124 run_task T6 --max-minutes 1
[[ "$(cat "$PLAN/rounds/exec-T6.exit")" == 124 ]]
grep -q '^timed_out=1$' "$PLAN/rounds/exec-T6.meta"
grep -q '^handback=empty$' "$PLAN/rounds/exec-T6.meta"
pass 'C2 超时仍 124'
reply="$(python3 -c 'print("\n".join("line-%s-%s" % (i, "x"*35) for i in range(1,8)), end="")')"
FAKE_CODEX_REPLY="$reply" expect_exit 0 run_task T7 --wait
grep -q '^exit：0$' "$TMP/last-output"
tail -n 5 "$PLAN/rounds/exec-T7.md" > "$TMP/expected-tail"
tail -n 5 "$TMP/last-output" > "$TMP/actual-tail"
cmp "$TMP/expected-tail" "$TMP/actual-tail"
! grep -q '^line-[12]-' "$TMP/last-output"
pass 'C3 wait 打印退出码和恰好最后 5 行'
FAKE_CODEX_REPLY=short expect_exit 0 run_task T8 --wait
grep -q '^handback=short$' "$TMP/last-output"
grep -q '^exit：0$' "$TMP/last-output"
pass 'C2/C3 wait 展示 short'
for mode in missing zero; do
  RSG2_REPLY_MODE="$mode" expect_exit 4 run_task T9 --wait
  grep -q '^handback=empty$' "$TMP/last-output"
  grep -q '^exit：4$' "$TMP/last-output"
  if [[ "$mode" == missing ]]; then grep -q '结果文件不存在：.*exec-T9.md' "$TMP/last-output"; fi
  pass "C3 wait $mode 交回退出码与 .exit 一致"
done
FAKE_CODEX_EXIT=3 expect_exit 3 run_task T10 --wait
grep -q '^exit：3$' "$TMP/last-output"
pass 'C3 wait 非零退出仍打印摘要'
for conflict in --detach --status --dry-run; do
  expect_exit 2 run_task T11 --wait "$conflict"
  [[ ! -e "$PLAN/rounds/exec-T11.meta" && ! -e "$PLAN/rounds/exec-T11-request.md" ]]
  pass "C3 wait 与 $conflict 互斥"
done
RSG2_REPLY_MODE=missing run_task T12 --detach > "$TMP/detach"
wait_done "$PLAN/rounds/exec-T12.exit"
[[ "$(cat "$PLAN/rounds/exec-T12.exit")" == 4 ]]
grep -q '^handback=empty$' "$PLAN/rounds/exec-T12.meta"
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T12 --status > "$TMP/detach-status" 2>&1
grep -q '^handback=empty$' "$TMP/detach-status"
pass 'C2/C3 detach 仍立即返回，空交回最终 .exit 为 4'
expect_exit 0 run_task T13
! grep -q '^exit：' "$TMP/last-output"
grep -q '^已结束；结果：' "$TMP/last-output"
pass 'C3 普通只读无上限调用保持原有结束输出'
bash "$SCRIPTS/dex-exec.sh" --help > "$TMP/help"
grep -q -- '--wait' "$TMP/help"
grep -q -- '--force' "$TMP/help"
pass 'C6 help 包含 wait 及原有末行选项'
printf 'PASS %d checks\n' "$COUNT"
