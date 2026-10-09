#!/usr/bin/env bash
# 圆桌 · 把一份任务书交给 Dex（codex exec）执行。
# 用法：dex-exec.sh <plan-dir> <T#> --model M --effort E --brief FILE [--root DIR] [--write] [--max-minutes N] [--resume SESSION_ID] [--detach] [--status] [--force] [--dry-run]
#   T#        如 T3、T3b；产物写到 plan-dir/rounds/exec-T#*。
#   --root    默认 plan-dir 所在 git 根，找不到用 plan-dir 的上级。
#   --write   使用 workspace-write；默认 read-only。
#   --max-minutes N  止损：到 N 分钟还没结束就停掉 codex，退出码 124，meta 记 timed_out=1（常规 120、难活 240）。
#   --resume  续接会话；resume 不接 -m/-s/-C，脚本改用 -c model= / sandbox_mode= 覆盖并在 root 里启动（不传模型会退回 config 默认）。
#   --detach  后台执行；--status 查询状态，不需要 model/effort/brief。
#   --force   Codex 额度为「空」时仍执行；--dry-run 不读额度、不调用 codex。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
LOCK_OWNED=0

usage_error() { printf '%s\n' "$*" >&2; exit 2; }
timestamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

release_lock() {
  if [[ "$LOCK_OWNED" -eq 1 ]]; then
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
  fi
}

log_header() {
  awk -v key="$1: " 'index($0, key) == 1 { sub(/\r$/, ""); print substr($0, length(key) + 1); exit }' "$LOG"
}

write_meta() {
  local tmp="$META.tmp.$$"
  {
    printf 'model=%s\neffort=%s\nsandbox=%s\nroot=%s\n' "$META_MODEL" "$EFFORT" "$META_SANDBOX" "$META_ROOT"
    printf 'started=%s\nfinished=%s\nexit=%s\n' "$STARTED" "$FINISHED" "$RESULT"
    printf 'session_id=%s\ntokens_used=%s\nresumed_from=%s\nattempt=%s\n' "$SESSION_ID" "$TOKENS_USED" "$RESUME" "$ATTEMPT"
    printf 'max_minutes=%s\ntimed_out=%s\n' "$MAX_MINUTES" "$TIMED_OUT"
  } > "$tmp"
  mv -f "$tmp" "$META"
}

show_failure() {
  printf 'codex 退出码 %s；日志：%s\n' "$1" "$LOG" >&2
  if [[ -f "$LOG" ]]; then tail -n 20 "$LOG" >&2; fi
}

stop_job() {
  # 先 TERM 让 codex 收尾，十秒不退再 KILL；子进程（沙箱里的 shell）一起清。
  local pid="$1" i
  pkill -TERM -P "$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true
  for i in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 1
  done
  pkill -KILL -P "$pid" 2>/dev/null || true
  kill -KILL "$pid" 2>/dev/null || true
}

run_job() {
  local rc=0 value pid cap waited=0
  TIMED_OUT=0
  # 子 shell 里 exec，拿到的 pid 就是 codex 本身，止损时能直接停它。
  (cd "$META_ROOT" 2>/dev/null || cd "$ROOT"; exec "${CMD[@]}" < "$REQ" > "$LOG" 2>&1) &
  pid=$!
  if [[ -n "$MAX_MINUTES" ]]; then
    # ROADSTAR_MINUTE_SECONDS 只给桩测试把「一分钟」缩短用。
    cap=$((MAX_MINUTES * ${ROADSTAR_MINUTE_SECONDS:-60}))
    while kill -0 "$pid" 2>/dev/null; do
      if (( waited >= cap )); then
        TIMED_OUT=1
        printf '\ndex-exec：到时间上限 %s 分钟，已停止 codex（%s）\n' "$MAX_MINUTES" "$(timestamp)" >> "$LOG"
        stop_job "$pid"
        break
      fi
      sleep 1
      waited=$((waited + 1))
    done
  fi
  wait "$pid" || rc=$?
  [[ "$TIMED_OUT" -eq 0 ]] || rc=124
  RESULT="$rc"
  FINISHED="$(timestamp)"
  SESSION_ID="$(log_header 'session id')"
  TOKENS_USED="$(awk '
    /^tokens used\r?$/ { pending=1; next }
    pending {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if ($0 ~ /^[0-9][0-9,]*$/) { value=$0; gsub(/,/, "", value) }
      pending=0
    }
    END { print value }
  ' "$LOG")"
  # 日志头部记录的是 codex 实际用的模型与沙箱，以它为准回填 meta。
  value="$(log_header model)"; [[ -z "$value" ]] || META_MODEL="$value"
  value="$(log_header sandbox)"; [[ -z "$value" ]] || META_SANDBOX="${value%% *}"
  write_meta
  # .exit 是完成标记，保证 --status 看见它时完整 meta 已经可读。
  printf '%s\n' "$rc" > "$EXIT_FILE.tmp.$$"
  mv -f "$EXIT_FILE.tmp.$$" "$EXIT_FILE"
  if [[ "$rc" -ne 0 ]]; then show_failure "$rc"; fi
  return "$rc"
}

# nohup 启动同一脚本的 worker，避免依赖导出的函数或拼接 shell 命令。
# worker 的 stdin 不连接终端；codex 单独从已保存的任务书副本读取。
if [[ "${1:-}" == --_worker ]]; then
  [[ $# -ge 16 ]] || usage_error '后台 worker 参数不完整'
  shift
  LOCK="$1"; REQ="$2"; OUT="$3"; LOG="$4"; META="$5"; EXIT_FILE="$6"
  META_MODEL="$7"; EFFORT="$8"; META_SANDBOX="$9"; shift 9
  META_ROOT="$1"; STARTED="$2"; RESUME="$3"; ATTEMPT="$4"; MAX_MINUTES="$5"; shift 5
  [[ "${1:-}" == -- ]] || usage_error '后台 worker 缺命令分隔符'
  shift
  CMD=("$@")
  FINISHED=""; RESULT=""; SESSION_ID=""; TOKENS_USED=""; TIMED_OUT=0
  LOCK_OWNED=1
  trap release_lock EXIT
  printf '%s\n' "$$" > "$LOCK/pid"
  run_job
  exit 0
fi

PLAN_DIR=""; TASK=""; MODEL=""; EFFORT=""; BRIEF=""; ROOT=""; RESUME=""; MAX_MINUTES=""; TIMED_OUT=0
WRITE=0; DETACH=0; STATUS=0; FORCE=0; DRY=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model|--effort|--brief|--root|--resume|--max-minutes)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || usage_error "$1 缺参数"
      case "$1" in
        --model) MODEL="$2" ;;
        --effort) EFFORT="$2" ;;
        --brief) BRIEF="$2" ;;
        --root) ROOT="$2" ;;
        --resume) RESUME="$2" ;;
        --max-minutes)
          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--max-minutes 要正整数分钟数：$2"
          MAX_MINUTES="$2" ;;
      esac
      shift 2 ;;
    --write) WRITE=1; shift ;;
    --detach) DETACH=1; shift ;;
    --status) STATUS=1; shift ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    --) shift; while [[ $# -gt 0 ]]; do POSITIONAL+=("$1"); shift; done ;;
    -*) usage_error "未知选项：$1" ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
[[ ${#POSITIONAL[@]} -eq 2 ]] || usage_error '需要 plan-dir 和任务编号（如 T3 或 T3b）'
PLAN_DIR="${POSITIONAL[0]}"; TASK="${POSITIONAL[1]}"
[[ "$TASK" =~ ^T[0-9]+[a-z]?$ ]] || usage_error "任务编号无效：$TASK"
[[ -d "$PLAN_DIR" ]] || usage_error "plan-dir 不存在：$PLAN_DIR"
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
ROUNDS="$PLAN_DIR/rounds"
OUT="$ROUNDS/exec-$TASK.md"; LOG="$ROUNDS/exec-$TASK-stdout.log"
META="$ROUNDS/exec-$TASK.meta"; PID_FILE="$ROUNDS/exec-$TASK.pid"
EXIT_FILE="$ROUNDS/exec-$TASK.exit"; LOCK="$ROUNDS/.exec-$TASK.lock"

if [[ "$STATUS" -eq 1 ]]; then
  if [[ -f "$EXIT_FILE" ]]; then
    RESULT="$(cat "$EXIT_FILE")"
    printf '%s 已结束；退出码：%s\n' "$TASK" "$RESULT"
  else
    PID=""
    if [[ -f "$PID_FILE" ]]; then PID="$(cat "$PID_FILE")"
    elif [[ -f "$LOCK/pid" ]]; then PID="$(cat "$LOCK/pid")"; fi
    if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
      printf '%s 运行中；PID：%s；退出码：待定\n' "$TASK" "$PID"
    elif [[ -f "$META" || -n "$PID" ]]; then
      printf '%s 已结束；退出码：未知（未写入完成标记）\n' "$TASK"
    else
      printf '%s 尚未执行；退出码：无\n' "$TASK"
    fi
    RESULT=""
  fi
  if [[ -f "$META" ]]; then
    cat "$META"
    if grep -q '^timed_out=1$' "$META"; then printf '%s 到时间上限被停止，结果不完整；先由 Argo 诊断再定收下、换环境判还是缩窄重派。\n' "$TASK"; fi
  fi
  if [[ -n "$RESULT" && "$RESULT" != 0 ]]; then show_failure "$RESULT"; fi
  exit 0
fi

[[ -n "$MODEL" ]] || usage_error '缺 --model'
[[ -n "$EFFORT" ]] || usage_error '缺 --effort'
[[ -n "$BRIEF" && -f "$BRIEF" ]] || usage_error "brief 文件不存在：$BRIEF"
BRIEF="$(cd "$(dirname "$BRIEF")" && pwd)/$(basename "$BRIEF")"
if [[ -z "$ROOT" ]]; then
  ROOT="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$PLAN_DIR")"
fi
[[ -d "$ROOT" ]] || usage_error "root 不存在：$ROOT"
ROOT="$(cd "$ROOT" && pwd)"
for value in "$PLAN_DIR" "$MODEL" "$EFFORT" "$ROOT" "$RESUME"; do
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || usage_error 'meta 字段不能包含换行'
done
SANDBOX=read-only
[[ "$WRITE" -eq 0 ]] || SANDBOX=workspace-write
CAP_TEXT=无
[[ -z "$MAX_MINUTES" ]] || CAP_TEXT="$MAX_MINUTES 分钟"
if [[ -n "$RESUME" ]]; then
  # codex exec resume 不接 -m/-s/-C，而且不沿用原会话的模型（实测 2026-10-04：不传就用 config 默认，当时默认的 gpt-6.1-sol 直接 400）。
  # 所以模型、沙箱用 -c 覆盖，工作目录靠在 ROOT 里启动（见 run_codex）。
  CMD=(codex exec resume "$RESUME" --skip-git-repo-check -c "model=\"$MODEL\"" -c "sandbox_mode=\"$SANDBOX\"" -c "model_reasoning_effort=$EFFORT" --disable fast_mode -o "$OUT" -)
else
  CMD=(codex exec --skip-git-repo-check -C "$ROOT" -s "$SANDBOX" -m "$MODEL" -c "model_reasoning_effort=$EFFORT" --disable fast_mode -o "$OUT" -)
fi

choose_request() {
  ATTEMPT=1
  REQ="$ROUNDS/exec-$TASK-request.md"
  while [[ -e "$REQ" || -L "$REQ" ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    REQ="$ROUNDS/exec-$TASK-request-r$ATTEMPT.md"
  done
}

if [[ "$DRY" -eq 1 ]]; then
  choose_request
  printf '命令：'; printf '%q ' "${CMD[@]}"; printf '< %q\n' "$BRIEF"
  printf '请求副本：%s\n结果：%s\n日志：%s\nmeta：%s\n退出码：%s\n' "$REQ" "$OUT" "$LOG" "$META" "$EXIT_FILE"
  printf '时间上限：%s\n' "$CAP_TEXT"
  if [[ "$DETACH" -eq 1 ]]; then printf '后台 PID：%s\n' "$PID_FILE"; fi
  exit 0
fi

mkdir -p "$ROUNDS"
if ! mkdir "$LOCK" 2>/dev/null; then
  LOCK_PID=""
  [[ ! -f "$LOCK/pid" ]] || LOCK_PID="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [[ "$LOCK_PID" =~ ^[0-9]+$ ]] && ! kill -0 "$LOCK_PID" 2>/dev/null; then
    # 不自动回收旧锁：另一个启动者可能已接管，检查后删除会误删活锁。
    usage_error "$TASK 存在旧锁：${LOCK}；确认任务已停止后手动清理，再重新派活"
  else
    usage_error "$TASK 正在启动或运行；请用 --status 查询"
  fi
fi
LOCK_OWNED=1
trap release_lock EXIT
printf '%s\n' "$$" > "$LOCK/pid"

if QUOTA="$(python3 "$SCRIPT_DIR/quota-status.py" --json 2>&1)"; then
  if TIER="$(printf '%s' "$QUOTA" | python3 -c 'import json, sys; print(json.load(sys.stdin)["codex"]["tier"])' 2>/dev/null)"; then
    if [[ "$TIER" == 空 && "$FORCE" -eq 0 ]]; then
      printf 'Codex 额度为「空」，本次未派活；需要继续时加 --force。\n' >&2
      exit 3
    fi
  else
    printf '警告：额度探针输出无法解析，继续派活。\n' >&2
  fi
else
  printf '警告：额度探针失败，继续派活。\n' >&2
fi

choose_request
cp "$BRIEF" "$REQ"
# 最新结果只对应本次派活，失败时不把上一次的回复留作本次结果。
rm -f "$OUT" "$PID_FILE" "$EXIT_FILE"
STARTED="$(timestamp)"; FINISHED=""; RESULT=""; SESSION_ID=""; TOKENS_USED=""
META_MODEL="$MODEL"; META_SANDBOX="$SANDBOX"; META_ROOT="$ROOT"
write_meta
printf '模型 %s / 强度 %s；第 %s 次派活：%s；时间上限：%s\n' "$MODEL" "$EFFORT" "$ATTEMPT" "$TASK" "$CAP_TEXT"

if [[ "$DETACH" -eq 1 ]]; then
  nohup bash "$SCRIPT_PATH" --_worker "$LOCK" "$REQ" "$OUT" "$LOG" "$META" "$EXIT_FILE" \
    "$META_MODEL" "$EFFORT" "$META_SANDBOX" "$META_ROOT" "$STARTED" "$RESUME" "$ATTEMPT" "$MAX_MINUTES" \
    -- "${CMD[@]}" < /dev/null > /dev/null 2>&1 &
  PID=$!
  printf '%s\n' "$PID" > "$PID_FILE"
  # 锁 PID 只由 worker 接手写，避免父进程晚写而覆盖下一次派活的锁。
  LOCK_OWNED=0
  printf '已后台启动，PID：%s；查状态用 --status：\n' "$PID"
  printf '  %q %q %q --status\n' "$SCRIPT_PATH" "$PLAN_DIR" "$TASK"
  exit 0
fi

run_job
printf '已结束；结果：%s\n' "$OUT"
