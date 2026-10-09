#!/usr/bin/env bash
# All subprocesses use local protocol stubs. No network or real CLI is needed.
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
export PATH="$TEST_DIR/bin:$PATH"
unset FAKE_CODEX_USED FAKE_CODEX_CARDS FAKE_CODEX_FIVE_HOUR FAKE_CODEX_DELAY FAKE_CODEX_EXIT
unset FAKE_CLAUDE_USED FAKE_CLAUDE_FABLE FAKE_CLAUDE_NO_FABLE
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'echo "FAIL: line $LINENO" >&2' ERR
export FAKE_TRACE_FILE="$TMP/trace.jsonl"
PLAN="$TMP/plan dir"
mkdir -p "$PLAN"
BRIEF="$PLAN/brief.md"
printf '%s\n' '# Offline task' '保留原文与换行。' > "$BRIEF"
printf '%s\n' '# Plan' 'Do the assigned task.' > "$PLAN/plan.md"
printf '%s\n' '# Ledger' '| # | 题目 | 来源 | 级别 | 处置 | 状态 |' > "$PLAN/ledger.md"
COUNT=0
pass() { COUNT=$((COUNT + 1)); printf 'ok %d - %s\n' "$COUNT" "$1"; }
json_check() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert eval(sys.argv[2]), d
PY
}
expect_exit() {
  local expected="$1" actual=0
  shift
  "$@" > "$TMP/last-output" 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    cat "$TMP/last-output" >&2
    echo "expected exit $expected, got $actual" >&2
    return 1
  fi
}
wait_done() {
  local target="$1" i
  for ((i=0; i<100; i++)); do
    [[ -f "$target" ]] && return 0
    sleep 0.1
  done
  echo "timed out waiting for $target" >&2
  return 1
}
run_task() {
  bash "$SCRIPTS/dex-exec.sh" "$PLAN" "$1" --model gpt-6-astra --effort high --brief "$BRIEF" "${@:2}"
}

python3 "$SCRIPTS/quota-status.py" > "$TMP/quota.txt"
python3 - "$TMP/quota.txt" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
for text in ("Claude：", "Codex：", "5 小时", "本周", "Fable", "重置卡 2 张", "credits 62500", "JST", "实时读数", "→ 宽"):
    assert text in s, (text, s)
assert re.search(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2} JST", s), s
assert "DO_NOT_PRINT_ACCOUNT_ID" not in s and "读不到：" not in s, s
PY
pass 'quota Chinese output, JST, no account identity'
python3 "$SCRIPTS/quota-status.py" --json > "$TMP/base.json"
json_check "$TMP/base.json" 'd["claude"]["tier"] == d["codex"]["tier"] == "宽" and d["claude"]["source"] == d["codex"]["source"] == "live" and d["claude"]["plan"] == "max" and d["codex"]["plan"] == "pro" and d["codex"]["credits"] == "62500" and d["codex"]["reset_cards"] == 2 and d["claude"]["fable"]["used"] == 1 and "DO_NOT_PRINT_ACCOUNT_ID" not in str(d)'
pass 'quota JSON windows, plans, credits and cards'
FAKE_CODEX_USED=97 python3 "$SCRIPTS/quota-status.py" --json > "$TMP/empty.json"
json_check "$TMP/empty.json" 'd["codex"]["tier"] == "空" and d["claude"]["tier"] == "宽"'
pass '97 percent weekly quota is empty'
FAKE_CODEX_USED=70 python3 "$SCRIPTS/quota-status.py" --json > "$TMP/normal.json"
json_check "$TMP/normal.json" 'd["codex"]["tier"] == "正常"'
pass 'normal tier'
FAKE_CODEX_USED=80 python3 "$SCRIPTS/quota-status.py" --json > "$TMP/tight.json"
json_check "$TMP/tight.json" 'd["codex"]["tier"] == "紧"'
pass 'ahead-of-window consumption is tight'
FAKE_CLAUDE_FABLE=97 python3 "$SCRIPTS/quota-status.py" --json > "$TMP/fable.json"
json_check "$TMP/fable.json" 'd["claude"]["tier"] == "空" and d["claude"]["five_hour"]["used"] == 1'
pass 'Claude takes worst Fable window'
FAKE_CLAUDE_NO_FABLE=1 FAKE_CODEX_FIVE_HOUR=90 FAKE_CODEX_CARDS=4 python3 "$SCRIPTS/quota-status.py" --json > "$TMP/optional.json"
json_check "$TMP/optional.json" 'd["claude"]["fable"] is None and d["codex"]["five_hour"]["used"] == 90 and d["codex"]["tier"] == "紧" and d["codex"]["reset_cards"] == 4'
pass 'optional Fable, Codex five-hour window and custom reset cards'
FAKE_CODEX_USED=97 python3 "$SCRIPTS/quota-status.py" --json --prev "$TMP/base.json" > "$TMP/pending.json"
json_check "$TMP/pending.json" 'd["codex"]["tier"] == "宽" and any("沿用上次档位" in n for n in d["note"])'
pass 'hysteresis holds first changed reading'
FAKE_CODEX_USED=97 python3 "$SCRIPTS/quota-status.py" --json --prev "$TMP/pending.json" > "$TMP/confirmed.json"
json_check "$TMP/confirmed.json" 'd["codex"]["tier"] == "空"'
pass 'hysteresis switches on second consecutive reading'
FAKE_CODEX_USED=70 python3 "$SCRIPTS/quota-status.py" --json --prev "$TMP/pending.json" > "$TMP/changed.json"
json_check "$TMP/changed.json" 'd["codex"]["tier"] == "宽"'
python3 "$SCRIPTS/quota-status.py" --json --prev "$TMP/changed.json" > "$TMP/recovered.json"
FAKE_CODEX_USED=97 python3 "$SCRIPTS/quota-status.py" --json --prev "$TMP/recovered.json" > "$TMP/pending-again.json"
json_check "$TMP/pending-again.json" 'd["codex"]["tier"] == "宽"'
pass 'nonconsecutive candidate does not trigger hysteresis'

# Import-only checks exercise failure paths without ever touching real sessions.
PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPTS/quota-status.py" "$TMP" <<'PY'
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
import importlib.util
import io
import json
import os
from pathlib import Path
import select
import signal
import sys
import time
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("quota_status", sys.argv[1])
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
now = datetime.now(timezone.utc)
def win(used, remaining):
    return {"used": used, "resets_at": (now + timedelta(hours=remaining)).isoformat()}
for used, remaining, expected in ((95, 6, "紧"), (95, 6.01, "空"), (85, 20, "紧"),
                                  (65, 84, "紧"), (35, 84, "宽"), (70, 25.2, "正常"),
                                  (79, 12, "宽"), (80, 12, "正常")):
    assert q.window_tier(win(used, remaining), 168, now) == expected, (used, remaining)
assert q.window_tier(win(97, 5), 5, now) == "紧"

fixture = Path(sys.argv[2]) / "quota fixture"
sessions = fixture / ".codex" / "sessions" / "2026" / "10" / "04"
sessions.mkdir(parents=True)
def event(at, used):
    return {"timestamp": q.iso(at), "type": "event_msg", "payload": {"type": "token_count", "rate_limits": {
        "primary": {"used_percent": used, "window_minutes": 10080, "resets_at": int((now + timedelta(days=3)).timestamp())},
        "secondary": None, "plan_type": "pro"}}}
older = sessions / "rollout-older.jsonl"
newer = sessions / "rollout-newer.jsonl"
older.write_text(json.dumps(event(now - timedelta(hours=5), 20)) + "\n", encoding="utf-8")
newer.write_text(json.dumps(event(now - timedelta(hours=3), 25)) + "\n" +
                 json.dumps(event(now - timedelta(hours=2), 30)) + "\n{bad trailing json\n", encoding="utf-8")
# Deliberately make the older record have the newest file mtime.
os.utime(older, (time.time() + 60, time.time() + 60))
with patch.object(q.Path, "home", return_value=fixture), patch.object(q, "live_probe", side_effect=q.ProbeError("命令不存在")):
    fallback = q.rollout_fallback()
    assert fallback["weekly"]["used"] == 30 and fallback["source"] == "rollout", fallback
    out = io.StringIO()
    with redirect_stdout(out):
        assert q.main(["--json"]) == 0
    report = json.loads(out.getvalue())
    assert report["claude"]["source"] == "none" and report["claude"]["tier"] is None, report
    assert report["codex"]["source"] == "rollout" and report["codex"]["reset_cards"] is None, report
    assert any("2.0 小时前的记录" in note for note in report["note"]), report
    out = io.StringIO()
    with redirect_stdout(out):
        assert q.main([]) == 0
    assert "读不到：Claude" in out.getvalue() and "2.0 小时前的记录" in out.getvalue(), out.getvalue()
with patch.object(q.Path, "home", return_value=Path(sys.argv[2]) / "no sessions"), patch.object(q.shutil, "which", return_value=None):
    out = io.StringIO()
    with redirect_stdout(out):
        assert q.main(["--json"]) == 2
    report = json.loads(out.getvalue())
    assert all(report[p]["source"] == "none" for p in ("claude", "codex")), report

# A real local child hangs; shorten only the imported deadline for the test.
with patch.object(q, "TIMEOUT", 0.1):
    session = q.JSONSession([sys.executable, "-u", "-c", "import time; print(\"noise\", flush=True); time.sleep(60)"], sys.argv[2], os.environ.copy())
    started = time.monotonic()
    try:
        try:
            session.receive(lambda m: True)
            raise AssertionError("timeout did not fire")
        except q.ProbeError:
            pass
    finally:
        session.close()
    assert session.process.poll() is not None and time.monotonic() - started < 2

# The wrapper exits on TERM; its child deliberately ignores TERM. EOF on the
# duplicated pipe proves the child was killed even after the leader exited.
wrapper = '''import json, os, signal, time
if os.fork() == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    print(json.dumps({"ready": True}), flush=True)
time.sleep(60)
'''
session = q.JSONSession([sys.executable, "-u", "-c", wrapper], sys.argv[2], os.environ.copy())
pipe = os.dup(session.process.stdout.fileno())
try:
    session.receive(lambda m: m.get("ready") is True)
    session.close()
    assert select.select([pipe], [], [], 2)[0], "wrapper child survived close"
    assert os.read(pipe, 1024) == b"", "unexpected output after close"
finally:
    try:
        os.killpg(session.process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    os.close(pipe)
PY
pass 'quota exact thresholds, latest rollout, stale age, both unavailable and timeout cleanup'

: > "$FAKE_TRACE_FILE"
run_task T9 --dry-run > "$TMP/dry.txt"
[[ ! -s "$FAKE_TRACE_FILE" ]]
python3 - "$TMP/dry.txt" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
for text in ("codex exec", "--skip-git-repo-check", "-C ", "-s read-only", "-m gpt-6-astra", "model_reasoning_effort=high", "--disable fast_mode", "-o ", "exec-T9.md", "exec-T9-request.md", "exec-T9-stdout.log", "exec-T9.meta"):
    assert text in s, (text, s)
PY
[[ ! -d "$PLAN/rounds" ]] || [[ -z "$(ls -A "$PLAN/rounds")" ]]
pass 'exec dry-run command and artifact paths, no CLI or artifacts'
run_task T9 > "$TMP/exec.txt"
cmp "$BRIEF" "$PLAN/rounds/exec-T9.md"
cmp "$BRIEF" "$PLAN/rounds/exec-T9-request.md"
python3 - "$PLAN/rounds/exec-T9.meta" "$TMP" <<'PY'
import os, sys
d = dict(line.rstrip("\n").split("=", 1) for line in open(sys.argv[1], encoding="utf-8"))
assert d["model"] == "gpt-6-astra" and d["effort"] == "high" and d["sandbox"] == "read-only", d
assert os.path.samefile(d["root"], sys.argv[2]), d
assert d["session_id"] == "00000000-0000-4000-8000-000000000009", d
assert d["tokens_used"] == "1234" and d["exit"] == "0" and d["attempt"] == "1", d
assert d["started"] and d["finished"] and d["resumed_from"] == "", d
PY
pass 'exec result, request, metadata, session and token count'
run_task T9 > "$TMP/exec-r2.txt"
cmp "$BRIEF" "$PLAN/rounds/exec-T9-request-r2.md"
grep -q '^attempt=2$' "$PLAN/rounds/exec-T9.meta"
pass 'second dispatch keeps r2 request snapshot'
run_task T9b --write --root "$PLAN" > "$TMP/write.txt"
grep -q '^sandbox=workspace-write$' "$PLAN/rounds/exec-T9b.meta"
python3 - "$PLAN/rounds/exec-T9b.meta" "$PLAN" <<'PY'
import os, sys
d = dict(line.rstrip("\n").split("=", 1) for line in open(sys.argv[1], encoding="utf-8"))
assert os.path.samefile(d["root"], sys.argv[2]), d
PY
pass 'T9b task ID, write sandbox and explicit root'
run_task T10 --resume 00000000-0000-4000-8000-000000000001 > "$TMP/resume.txt"
grep -q '^resumed: 00000000-0000-4000-8000-000000000001$' "$PLAN/rounds/exec-T10-stdout.log"
grep -q '^resumed_from=00000000-0000-4000-8000-000000000001$' "$PLAN/rounds/exec-T10.meta"
pass 'resume uses resume subcommand without unsupported flags'
FAKE_CODEX_DELAY=1 run_task T11 --detach > "$TMP/detach.txt"
grep -q '查状态用 --status' "$TMP/detach.txt"
[[ -s "$PLAN/rounds/exec-T11.pid" ]]
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T11 --status > "$TMP/running.txt"
grep -q '运行中' "$TMP/running.txt"
expect_exit 2 run_task T11
pass 'detach returns with PID, running status, active task protected'
wait_done "$PLAN/rounds/exec-T11.exit"
[[ "$(cat "$PLAN/rounds/exec-T11.exit")" == 0 ]]
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T11 --status > "$TMP/finished.txt"
grep -q '已结束' "$TMP/finished.txt"
grep -q '^tokens_used=1234$' "$TMP/finished.txt"
pass 'detach completion records exit, final metadata and status'
FAKE_CODEX_USED=97 expect_exit 3 run_task T12
[[ ! -f "$PLAN/rounds/exec-T12.md" ]]
pass 'empty Codex quota blocks dispatch with exit 3'
FAKE_CODEX_USED=97 run_task T12 --force > "$TMP/force.txt"
cmp "$BRIEF" "$PLAN/rounds/exec-T12.md"
pass 'force overrides empty quota gate'
FAKE_CODEX_EXIT=7 expect_exit 7 run_task T13
[[ ! -f "$PLAN/rounds/exec-T13.md" ]]
grep -q 'exec-T13-stdout.log' "$TMP/last-output"
grep -q 'stub failure line 24' "$TMP/last-output"
grep -q '^exit=7$' "$PLAN/rounds/exec-T13.meta"
pass 'failed exec retains exit, metadata and log tail without substitute result'
FAKE_CODEX_EXIT=8 run_task T14 --detach > "$TMP/detach-failure.txt"
wait_done "$PLAN/rounds/exec-T14.exit"
[[ "$(cat "$PLAN/rounds/exec-T14.exit")" == 8 ]]
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T14 --status > "$TMP/failed-status.txt" 2>&1
grep -q '^exit=8$' "$TMP/failed-status.txt"
grep -q 'stub failure line 24' "$TMP/failed-status.txt"
pass 'detached failure is visible from status and exit file'
FAKE_CODEX_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 expect_exit 124 run_task T17 --max-minutes 2
[[ ! -f "$PLAN/rounds/exec-T17.md" ]]
grep -q '^exit=124$' "$PLAN/rounds/exec-T17.meta"
grep -q '^max_minutes=2$' "$PLAN/rounds/exec-T17.meta"
grep -q '^timed_out=1$' "$PLAN/rounds/exec-T17.meta"
grep -q '时间上限 2 分钟' "$PLAN/rounds/exec-T17-stdout.log"
grep -q '^timed_out=0$' "$PLAN/rounds/exec-T9.meta"
pass 'max-minutes stops codex at the cap: exit 124, timed_out meta, no substitute result'
FAKE_CODEX_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 run_task T18 --detach --max-minutes 1 > "$TMP/detach-cap.txt"
wait_done "$PLAN/rounds/exec-T18.exit"
[[ "$(cat "$PLAN/rounds/exec-T18.exit")" == 124 ]]
grep -q '^timed_out=1$' "$PLAN/rounds/exec-T18.meta"
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T18 --status > "$TMP/cap-status.txt" 2>&1
grep -q '到时间上限被停止' "$TMP/cap-status.txt"
pass 'detached max-minutes records exit 124 and status reports the cap'
expect_exit 2 run_task T19 --max-minutes 0
expect_exit 2 run_task T19 --max-minutes abc
[[ ! -f "$PLAN/rounds/exec-T19.meta" ]]
run_task T19 --dry-run --max-minutes 3 > "$TMP/dry-cap.txt"
grep -q '时间上限：3 分钟' "$TMP/dry-cap.txt"
pass 'max-minutes rejects bad values and dry-run shows the cap'
expect_exit 2 bash "$SCRIPTS/dex-exec.sh" "$PLAN" ../T9 --model x --effort high --brief "$BRIEF"
expect_exit 2 bash "$SCRIPTS/dex-exec.sh" "$PLAN" T15 --model x --effort high --brief "$TMP/missing"
expect_exit 2 bash "$SCRIPTS/dex-exec.sh" "$TMP/missing" T15 --model x --effort high --brief "$BRIEF"
pass 'invalid task ID, missing brief and missing plan rejected'

# Reclaiming a stale lock non-atomically can remove another dispatchs live lock.
mkdir "$PLAN/rounds/.exec-T17.lock"
printf '%s\n' '2147483647' > "$PLAN/rounds/.exec-T17.lock/pid"
expect_exit 2 run_task T17
[[ -f "$PLAN/rounds/.exec-T17.lock/pid" && ! -f "$PLAN/rounds/exec-T17-request.md" ]]
pass 'stale task lock is not reclaimed unsafely'

# A failing probe must warn and still execute. Keep this fixture under mktemp.
mkdir -p "$TMP/failed probe"
cp "$SCRIPTS/dex-exec.sh" "$TMP/failed probe/dex-exec.sh"
printf '%s\n' 'raise SystemExit(2)' > "$TMP/failed probe/quota-status.py"
bash "$TMP/failed probe/dex-exec.sh" "$PLAN" T16 --model gpt-6-astra --effort high --brief "$BRIEF" > "$TMP/probe-warning.txt" 2>&1
grep -q '警告' "$TMP/probe-warning.txt"
cmp "$BRIEF" "$PLAN/rounds/exec-T16.md"
pass 'quota probe failure warns without blocking execution'

REVIEW="$TMP/review dir"
mkdir -p "$REVIEW"
cp "$PLAN/brief.md" "$PLAN/plan.md" "$PLAN/ledger.md" "$REVIEW/"
: > "$FAKE_TRACE_FILE"
bash "$SCRIPTS/dex-review.sh" "$REVIEW" --dry-run > "$TMP/review-dry1.txt"
bash "$SCRIPTS/dex-review.sh" "$REVIEW" --dry-run > "$TMP/review-dry2.txt"
[[ -z "$(ls -A "$REVIEW/rounds")" && ! -s "$FAKE_TRACE_FILE" ]]
grep -q '第 1 轮' "$TMP/review-dry1.txt"
grep -q '第 1 轮' "$TMP/review-dry2.txt"
pass 'review dry-run twice leaves no snapshots, diff or request, still round 1'
bash "$SCRIPTS/dex-review.sh" "$REVIEW" > "$TMP/review.txt"
grep -q '模型 gpt-6-astra / 强度 high' "$TMP/review.txt"
grep -q '用时 ' "$TMP/review.txt"
json_check "$REVIEW/rounds/r1-dex-review.json" 'd == {"verdict": "PASS", "checklist": [], "new_issues": [], "open_issue_verdicts": [], "alternative": "", "reply_to_chair": "", "questions_for_chair": []}'
python3 - "$FAKE_TRACE_FILE" "$SCRIPTS/../references/dex-review.schema.json" "$REVIEW/rounds/r1-dex-review.json" <<'PY'
import json, sys
calls = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8")]
args = calls[-1]["args"]
assert args[args.index("-m")+1] == "gpt-6-astra", args
assert args[args.index("-c")+1] == "model_reasoning_effort=high", args
assert args[args.index("--disable")+1] == "fast_mode", args
schema = json.load(open(sys.argv[2], encoding="utf-8"))
data = json.load(open(sys.argv[3], encoding="utf-8"))
assert set(data) == set(schema["required"]) == set(schema["properties"])
for key, value in data.items():
    rule = schema["properties"][key]
    assert isinstance(value, {"string": str, "array": list}[rule["type"]])
    assert "enum" not in rule or value in rule["enum"]
PY
pass 'review default model, effort, fast_mode, schema JSON and timing'
printf '%s\n' 'New change.' >> "$REVIEW/plan.md"
bash "$SCRIPTS/dex-review.sh" "$REVIEW" --dry-run > "$TMP/review-dry3.txt"
[[ ! -f "$REVIEW/rounds/r2-plan.md" && ! -f "$REVIEW/rounds/r2-plan.diff" && ! -f "$REVIEW/rounds/r2-dex-request.md" ]]
bash "$SCRIPTS/dex-review.sh" "$REVIEW" --model custom-model --effort medium > "$TMP/review-r2.txt"
grep -q 'plan 全文没有附在这里' "$REVIEW/rounds/r2-dex-request.md"
grep -q '^+New change\.' "$REVIEW/rounds/r2-plan.diff"
grep -q '^model: custom-model$' "$REVIEW/rounds/r2-dex-stdout.log"
pass 'review later dry-run preserves compact mode, diff and model overrides'
bash "$SCRIPTS/dex-review.sh" "$REVIEW" --full > "$TMP/review-r3.txt"
grep -q 'plan（当前全文）' "$REVIEW/rounds/r3-dex-request.md"
pass 'review full mode preserved'

printf 'PASS %d checks\n' "$COUNT"
