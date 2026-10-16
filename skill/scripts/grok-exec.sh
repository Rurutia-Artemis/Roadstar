#!/usr/bin/env bash
# Roadstar · Grok 只读派活线，与 dex-exec.sh 共用产物契约。
# 用法：grok-exec.sh <plan-dir> <T#> --brief FILE --class 取证|复核 [--model M] [--effort E] [--max-turns N]
#   --model M       默认 grok-4.7；--effort E 默认 high；--max-turns N 默认 30。
#   --root DIR      默认 plan-dir 所在 git 根，找不到用 plan-dir 的上级。
#   --max-minutes N 到点 TERM，十秒后 KILL；退出码 124，meta 记 timed_out=1。
#   --est-minutes N 排活表预估分钟，写入 meta；--strategy auto|quality|thrift|rush 同样写入。
#   --detach        后台执行并保存 PID；--status 查询，不需要 brief / class 或 Grok 登录。
#   --dry-run       只打印命令、时间上限与产物路径，不查登录、不写产物。
#   --write         直接退出 2：写活等后续版本。只收取证、复核两类，--class 必填。
#   产物 rounds/exec-T#.md、-request.md、-stdout.log、.meta、.pid（后台）、.exit。
#   重派保留请求快照，锁不自动回收；成功派活登记项目，未安装或未登录退出 3。
#   仅在 try_new_models 开启且 Grok 已登录时由 Argo 试派，复核方须和执行方不同家。
#   不支持 resume / force，令每次只读复核独立，不能绕过登录门槛。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
LOCK_OWNED=0

usage_error() { printf '%s\n' "$*" >&2; exit 2; }
timestamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

print_command() {
  # macOS Bash 3.2 的 %q 会把中文多字节字符拆成无效 UTF-8。
  python3 - "$@" <<'COMMAND'
import shlex
import sys
print(shlex.join(sys.argv[1:]))
COMMAND
}

release_lock() {
  if [[ "$LOCK_OWNED" -eq 1 ]]; then
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
  fi
}

write_meta() {
  local tmp="$META.tmp.$$"
  {
    printf 'model=%s\neffort=%s\nsandbox=%s\nroot=%s\n' "$META_MODEL" "$EFFORT" "$META_SANDBOX" "$META_ROOT"
    printf 'started=%s\nfinished=%s\nexit=%s\n' "$STARTED" "$FINISHED" "$RESULT"
    printf 'session_id=%s\ntokens_used=%s\nresumed_from=%s\nattempt=%s\n' "$SESSION_ID" "$TOKENS_USED" "$RESUME" "$ATTEMPT"
    printf 'max_minutes=%s\ntimed_out=%s\n' "$MAX_MINUTES" "$TIMED_OUT"
    if [[ -n "$CLASS" ]]; then printf 'class=%s\n' "$CLASS"; fi
    if [[ -n "$EST_MINUTES" ]]; then printf 'est_minutes=%s\n' "$EST_MINUTES"; fi
    if [[ -n "$STRATEGY" ]]; then printf 'strategy=%s\n' "$STRATEGY"; fi
  } > "$tmp"
  mv -f "$tmp" "$META"
}

show_failure() {
  printf 'grok 退出码 %s；日志：%s\n' "$1" "$LOG" >&2
  if [[ -f "$LOG" ]]; then tail -n 20 "$LOG" >&2; fi
}

stop_job() {
  # 先 TERM 让 grok 收尾，十秒不退再 KILL；子进程（沙箱里的 shell）一起清。
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
  local rc=0 pid cap waited=0
  TIMED_OUT=0
  # 子 shell 里 exec，拿到的 pid 就是 grok 本身，止损时能直接停它。
  (cd "$META_ROOT" 2>/dev/null || cd "$ROOT"; exec "${CMD[@]}" < "$REQ" > "$LOG" 2>&1) &
  pid=$!
  if [[ -n "$MAX_MINUTES" ]]; then
    # ROADSTAR_MINUTE_SECONDS 只给桩测试把「一分钟」缩短用。
    cap=$((MAX_MINUTES * ${ROADSTAR_MINUTE_SECONDS:-60}))
    while kill -0 "$pid" 2>/dev/null; do
      if (( waited >= cap )); then
        TIMED_OUT=1
        printf '\ngrok-exec：到时间上限 %s 分钟，已停止 grok（%s）\n' "$MAX_MINUTES" "$(timestamp)" >> "$LOG"
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
  # Plain 输出没有稳定的 session / token 字段，保留空值。
  SESSION_ID=""; TOKENS_USED=""
  if [[ "$rc" -eq 0 ]]; then cp "$LOG" "$OUT"; fi
  write_meta
  # .exit 是完成标记，保证 --status 看见它时完整 meta 已经可读。
  printf '%s\n' "$rc" > "$EXIT_FILE.tmp.$$"
  mv -f "$EXIT_FILE.tmp.$$" "$EXIT_FILE"
  if [[ "$rc" -ne 0 ]]; then show_failure "$rc"; fi
  return "$rc"
}

# nohup 启动同一脚本的 worker，避免依赖导出的函数或拼接 shell 命令。
# worker 的 stdin 不连接终端；任务书全文作为 -p 的单个参数传入。
if [[ "${1:-}" == --_worker ]]; then
  [[ $# -ge 19 ]] || usage_error '后台 worker 参数不完整'
  shift
  LOCK="$1"; REQ="$2"; OUT="$3"; LOG="$4"; META="$5"; EXIT_FILE="$6"
  META_MODEL="$7"; EFFORT="$8"; META_SANDBOX="$9"; shift 9
  META_ROOT="$1"; STARTED="$2"; RESUME="$3"; ATTEMPT="$4"; MAX_MINUTES="$5"; shift 5
  CLASS="$1"; EST_MINUTES="$2"; STRATEGY="$3"; shift 3
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

PLAN_DIR=""; TASK=""; MODEL="grok-4.7"; EFFORT="high"; BRIEF=""; ROOT=""; RESUME=""; MAX_MINUTES=""; TIMED_OUT=0; CLASS=""; EST_MINUTES=""; STRATEGY=""; MAX_TURNS=30
DETACH=0; STATUS=0; DRY=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model|--effort|--brief|--root|--max-turns|--max-minutes|--class|--est-minutes|--strategy)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || usage_error "$1 缺参数"
      case "$1" in
        --model) MODEL="$2" ;;
        --effort) EFFORT="$2" ;;
        --brief) BRIEF="$2" ;;
        --root) ROOT="$2" ;;
        --max-turns)
          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--max-turns 要正整数：$2"
          MAX_TURNS="$2" ;;
        --class)
          case "$2" in
            取证|复核) CLASS="$2" ;;
            *) usage_error "--class 类别无效：$2" ;;
          esac ;;
        --max-minutes)
          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--max-minutes 要正整数分钟数：$2"
          MAX_MINUTES="$2" ;;
        --est-minutes)
          [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || usage_error "--est-minutes 要正整数分钟数：$2"
          EST_MINUTES="$2" ;;
        --strategy)
          case "$2" in
            auto|quality|thrift|rush) STRATEGY="$2" ;;
            *) usage_error "--strategy 只收 auto / quality / thrift / rush：$2" ;;
          esac ;;
      esac
      shift 2 ;;
    --write) usage_error "写活等后续版本" ;;
    --detach) DETACH=1; shift ;;
    --status) STATUS=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
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

[[ -n "$CLASS" ]] || usage_error '缺 --class（只收取证 / 复核）'
case "$EFFORT" in low|medium|high|xhigh|none|minimal|max) ;; *) usage_error "--effort 无效：$EFFORT" ;; esac
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
CAP_TEXT=无
[[ -z "$MAX_MINUTES" ]] || CAP_TEXT="$MAX_MINUTES 分钟"
# -p 接任务书全文，包括末尾换行；数组传参，不经 shell 求值。
PROMPT=""
IFS= read -r -d '' PROMPT < "$BRIEF" || true
CMD=(grok -p "$PROMPT" -m "$MODEL" --cwd "$ROOT" --sandbox read-only --permission-mode bypassPermissions --max-turns "$MAX_TURNS" --reasoning-effort "$EFFORT" --output-format plain)

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
  printf '命令：'; print_command "${CMD[@]}"
  printf '请求副本：%s\n结果：%s\n日志：%s\nmeta：%s\n退出码：%s\n' "$REQ" "$OUT" "$LOG" "$META" "$EXIT_FILE"
  printf '时间上限：%s\n' "$CAP_TEXT"
  if [[ "$DETACH" -eq 1 ]]; then printf '后台 PID：%s\n' "$PID_FILE"; fi
  exit 0
fi

if ! command -v grok > /dev/null 2>&1; then
  printf '没装 grok；安装并用 grok login 登录后再派活。\n' >&2
  exit 3
fi
if ! python3 - <<'LOGIN'
import subprocess
import sys
try:
    result = subprocess.run(["grok", "models"], capture_output=True, text=True, timeout=15)
    text = (result.stdout + result.stderr).lower()
    ready = result.returncode == 0 and "you are logged in" in text and "not logged in" not in text
except (OSError, subprocess.TimeoutExpired):
    ready = False
if not ready:
    print("Grok 未登录或登录状态读不到；请用 grok login 登录后再派活。", file=sys.stderr)
    sys.exit(3)
LOGIN
then
  exit 3
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


choose_request
cp "$BRIEF" "$REQ"
# 最新结果只对应本次派活，失败时不把上一次的回复留作本次结果。
rm -f "$OUT" "$PID_FILE" "$EXIT_FILE"
STARTED="$(timestamp)"; FINISHED=""; RESULT=""; SESSION_ID=""; TOKENS_USED=""
META_MODEL="$MODEL"; META_SANDBOX="$SANDBOX"; META_ROOT="$ROOT"
write_meta
if ! python3 - "$ROOT" <<'PY'
import fcntl
import os
from pathlib import Path
import sys

try:
    config = Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser()
    config.mkdir(parents=True, exist_ok=True)
    project = os.path.abspath(sys.argv[1])
    with (config / "projects.txt").open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        projects = list(dict.fromkeys(os.path.abspath(Path(line.rstrip("\r\n")).expanduser())
                                     for line in handle if line.strip()))
        if project not in projects:
            projects.append(project)
        handle.seek(0)
        handle.truncate()
        handle.write("".join(value + "\n" for value in projects))
except (OSError, UnicodeError, ValueError) as exc:
    print(f"警告：项目登记失败，继续派活：{exc}", file=sys.stderr)
    sys.exit(1)
PY
then
  : # Registration must never block an otherwise valid dispatch.
fi
printf '模型 %s / 强度 %s；第 %s 次派活：%s；时间上限：%s\n' "$MODEL" "$EFFORT" "$ATTEMPT" "$TASK" "$CAP_TEXT"

if [[ "$DETACH" -eq 1 ]]; then
  nohup bash "$SCRIPT_PATH" --_worker "$LOCK" "$REQ" "$OUT" "$LOG" "$META" "$EXIT_FILE" \
    "$META_MODEL" "$EFFORT" "$META_SANDBOX" "$META_ROOT" "$STARTED" "$RESUME" "$ATTEMPT" "$MAX_MINUTES" "$CLASS" "$EST_MINUTES" "$STRATEGY" \
    -- "${CMD[@]}" < /dev/null > /dev/null 2>&1 &
  PID=$!
  printf '%s\n' "$PID" > "$PID_FILE"
  # 锁 PID 只由 worker 接手写，避免父进程晚写而覆盖下一次派活的锁。
  LOCK_OWNED=0
  printf '已后台启动，PID：%s；查状态用 --status：\n' "$PID"
  printf '  '; print_command "$SCRIPT_PATH" "$PLAN_DIR" "$TASK" --status
  exit 0
fi

run_job
printf '已结束；结果：%s\n' "$OUT"
