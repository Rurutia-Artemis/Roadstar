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
export ROADSTAR_CONFIG_DIR="$TMP/config"
unset ROADSTAR_PROJECTS
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
    except (ProcessLookupError, PermissionError):
        # macOS returns EPERM when the group only has zombies left; cleanup only.
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
[[ ! -e "$ROADSTAR_CONFIG_DIR/projects.txt" ]]
bash "$SCRIPTS/dex-exec.sh" "$PLAN" T9 --status > "$TMP/unstarted.txt"
[[ ! -e "$ROADSTAR_CONFIG_DIR/projects.txt" ]]
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
python3 - "$ROADSTAR_CONFIG_DIR/projects.txt" "$PLAN/rounds/exec-T9.meta" <<'PY'
from pathlib import Path
import sys
meta = dict(line.split("=", 1) for line in Path(sys.argv[2]).read_text().splitlines())
assert Path(sys.argv[1]).read_text() == meta["root"] + "\n"
PY
pass 'exec real dispatch registers exactly one absolute ROOT; dry-run and status do not register'
run_task T9 > "$TMP/exec-r2.txt"
cmp "$BRIEF" "$PLAN/rounds/exec-T9-request-r2.md"
grep -q '^attempt=2$' "$PLAN/rounds/exec-T9.meta"
pass 'second dispatch keeps r2 request snapshot'
[[ "$(wc -l < "$ROADSTAR_CONFIG_DIR/projects.txt" | tr -d ' ')" == 1 ]]
pass 'exec repeat dispatch does not duplicate the registered project'
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

# Fixed clocks keep progress monitoring tests independent of wall time.
PROGRESS="$TMP/progress fixtures"
mkdir -p "$PROGRESS"
python3 - "$PROGRESS" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
fixtures = {
    "ok": [(0, "C1", "fail"), (10, "C1", "pass"), (15, "C1", "pass")],
    "stall": [(0, "C1", "fail"), (1, "C1", "fail"), (2, "C2", "fail"), (3, "C1", "fail")],
    "wrap": [(0, "C1", "fail"), (109, "C1", "pass")],
    "idle": [(0, "C1", "fail"), (5, "C1", "pass"), (39, "C1", "pass")],
}
for name, rows in fixtures.items():
    text = "\ninvalid line\n2026-10-14T00:00:00Z\tC9\tmaybe\tbad status\n"
    text += "bad-time\tC9\tpass\tbad timestamp\n"
    for minute, item, outcome in rows:
        text += f"2026-10-14T{minute // 60:02d}:{minute % 60:02d}:00Z\t{item}\t{outcome}\tevidence\n"
    (root / name).write_text(text, encoding="utf-8")
PY
expect_exit 0 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap 120 --items 2 --now 2026-10-14T00:32:00Z
[[ "$(cat "$TMP/last-output")" == 'OK 1/2 32m/120m' ]]
pass 'stall-watch OK ignores invalid rows and repeated pass does not add done items'
expect_exit 10 "$SCRIPTS/stall-watch.py" "$PROGRESS/stall" --cap 120 --now 2026-10-14T01:50:00Z
[[ "$(cat "$TMP/last-output")" == 'STALL C1 fail×3 0/2 110m/120m' ]]
pass 'stall-watch STALL tracks per-item failures and takes priority over WRAP and IDLE'
expect_exit 12 "$SCRIPTS/stall-watch.py" "$PROGRESS/wrap" --cap 120 --items 2 --now 2026-10-14T01:50:00Z
[[ "$(cat "$TMP/last-output")" == 'WRAP 1/2 110m/120m' ]]
pass 'stall-watch WRAP with incomplete explicit item total'
expect_exit 11 "$SCRIPTS/stall-watch.py" "$PROGRESS/idle" --cap 120 --now 2026-10-14T00:40:00Z
[[ "$(cat "$TMP/last-output")" == 'IDLE 35m 1/1' ]]
pass 'stall-watch IDLE is measured from a transition to pass, not repeated pass'
expect_exit 13 "$SCRIPTS/stall-watch.py" "$PROGRESS/missing" --cap 60 --started 2026-10-14T00:00:00Z --now 2026-10-14T00:25:00Z
[[ "$(cat "$TMP/last-output")" == 'NOPROGRESS 25m' ]]
pass 'stall-watch NOPROGRESS for missing log after explicit start'
expect_exit 10 "$SCRIPTS/stall-watch.py" "$PROGRESS/stall" --cap 120 --now 2026-10-14T00:54:00Z --json
json_check "$TMP/last-output" 'd == {"status": "STALL", "item": "C1", "done": 0, "total": 2, "elapsed_min": 54, "cap_min": 120}'
pass 'stall-watch JSON preserves status, item, counts and minute values'

python3 - "$SCRIPTS/stall-watch.py" "$PROGRESS" <<'PY'
from pathlib import Path
import json
import subprocess
import sys
script, root = sys.argv[1], Path(sys.argv[2])
def check(rows, expected, code=0, **options):
    path = root / "boundary"
    path.write_text("".join(f"2026-10-14T00:{minute:02d}:00Z\t{item}\t{outcome}\tevidence\n"
                            for minute, item, outcome in rows), encoding="utf-8")
    args = [script, str(path), "--cap", "120", "--now", "2026-10-14T00:20:00Z", "--json"]
    for key, value in options.items():
        args += ["--" + key, str(value)]
    run = subprocess.run(args, capture_output=True, text=True)
    assert run.returncode == code, (run.returncode, run.stderr)
    data = json.loads(run.stdout)
    assert all(data[key] == value for key, value in expected.items()), data

# A pass for any item, even one already passed, clears ALL failure streaks.
check([(0, "C2", "pass"), (1, "C1", "fail"), (2, "C1", "fail"),
       (3, "C2", "pass"), (4, "C1", "fail")], {"status": "OK", "done": 1, "total": 2})
# Regressions remove an item from done; a later recovery starts a fresh idle clock.
check([(0, "C1", "pass"), (1, "C1", "fail")], {"done": 0})
check([(0, "C1", "pass"), (1, "C1", "fail"), (19, "C1", "pass")], {"status": "OK"}, idle=2)
# Empty/invalid files without a start use now, including missing-file handling above.
check([], {"status": "OK", "elapsed_min": 0, "total": 0})
check([], {"status": "OK"}, started="2026-10-14T00:00:00Z", idle=20)
check([], {"status": "NOPROGRESS"}, 13, started="2026-10-14T00:00:00Z", idle=19)
check([], {"status": "WRAP"}, 12, started="2026-10-13T22:20:00Z", items=1)
check([(0, "C1", "fail")], {"status": "OK"}, idle=20)
check([(0, "C1", "fail")], {"status": "WRAP"}, 12, now="2026-10-14T01:48:00Z")
# Started comes from the earliest timestamp, even when the file is not time-sorted.
check([(10, "C1", "fail"), (0, "C2", "pass")], {"elapsed_min": 20})
check([(0, "C1", "pass")], {"elapsed_min": 20}, now="2026-10-14T09:20:00+09:00")
PY
pass 'stall-watch global reset, regressions, empty log defaults, thresholds and ISO offsets'
expect_exit 2 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap nan
expect_exit 2 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap 0
expect_exit 2 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap 120 --idle -1
expect_exit 2 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap 120 --items -1
expect_exit 2 "$SCRIPTS/stall-watch.py" "$PROGRESS/ok" --cap 120 --started bad-time
pass 'stall-watch bad arguments exit 2'

STATS="$TMP/stats fixtures"
python3 - "$STATS" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
records = {
    "a/rounds/exec-T1.meta": "session_id=one\nclass=取证\nmodel=gpt-6.1-sol\neffort=high\noutcome=done\nminutes=10\nstarted=2026-10-14T00:00:00Z\nfinished=2026-10-14T01:00:00Z\n",
    "a/rounds/exec-T2.meta": "session_id=two\nclass=取证\nmodel=gpt-6.1-sol\neffort=high\noutcome=stalled\nstarted=2026-10-14T09:00:00+09:00\nfinished=2026-10-14T00:30:00Z\nescalated_to=gpt-6-astra\n",
    "a/rounds/exec-T3.meta": "session_id=three\nmodel=claude-sonnet-5-5\neffort=medium\nminutes=bad\n",
    "b/rounds/exec-T1.meta": "session_id=one\nclass=取证\nmodel=gpt-6.1-sol\neffort=high\noutcome=done\nminutes=10\n",
    "b/rounds/exec-T4.meta": "class=取证\nmodel=claude-haiku-5-5\neffort=medium\noutcome=done\nminutes=8\n",
}
records["c/rounds/exec-T4.meta"] = records["b/rounds/exec-T4.meta"]
for name, text in records.items():
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
PY
python3 "$SCRIPTS/dispatch-stats.py" "$STATS/a" "$STATS/b" "$STATS/c" --json > "$TMP/stats.json"
json_check "$TMP/stats.json" 'd["total_records"] == 4 and len(d["groups"]) == 3 and sum(g["count"] for g in d["groups"]) == 4 and all(g["recommendation"] == "样本不足" for g in d["groups"])'
python3 - "$TMP/stats.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
groups = {(g["class"], g["model"], g["effort"]): g for g in data["groups"]}
g = groups[("取证", "gpt-6.1-sol", "high")]
assert (g["count"], g["outcome_count"], g["completion_rate"], g["stall_rate"], g["escalation_rate"], g["average_minutes"]) == (2, 2, .5, .5, .5, 20), g
g = groups[("未分类", "sonnet", "medium")]
assert g["count"] == 1 and g["outcome_count"] == 0 and g["completion_rate"] is None and g["stall_rate"] is None and g["average_minutes"] is None, g
assert ("取证", "haiku", "medium") in groups
PY
pass 'dispatch-stats six metas deduplicate by session and SHA1; groups, denominators and durations'
python3 "$SCRIPTS/dispatch-stats.py" "$STATS" --min-samples 1 --json > "$TMP/stats-advice.json"
json_check "$TMP/stats-advice.json" 'next(g for g in d["groups"] if g["model"] == "haiku")["recommendation"] == "可作起步层" and next(g for g in d["groups"] if g["model"] == "gpt-6.1-sol")["recommendation"] == "起步层该升"'
python3 "$SCRIPTS/dispatch-stats.py" "$STATS" > "$TMP/stats.txt"
grep -q '未分类' "$TMP/stats.txt"
grep -q '完成率' "$TMP/stats.txt"
grep -q '样本不足' "$TMP/stats.txt"
expect_exit 2 python3 "$SCRIPTS/dispatch-stats.py" "$STATS" --min-samples 0
pass 'dispatch-stats starting-level advice, Chinese table and invalid sample threshold'
PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPTS/dispatch-stats.py" "$TMP" <<'PY'
import importlib.util
from pathlib import Path
from unittest.mock import patch
from contextlib import redirect_stdout
import io, json, sys
spec = importlib.util.spec_from_file_location("dispatch_stats", sys.argv[1])
stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stats)
assert [stats.normalize_model(m) for m in ("claude-OPUS-5-5", "claude-fable-5-1", "gpt-6-astra")] == ["opus", "fable", "gpt-6-astra"]
records = [{"class": "批量", "model": model, "effort": "high", "outcome": "done"}
           for model in ("fable", "gpt-6-astra", "sonnet", "opus", "haiku", "gpt-6.1-sol") for _ in range(5)]
groups = stats.summarize(records, 5)
assert [g["model"] for g in groups] == ["haiku", "sonnet", "opus", "fable", "gpt-6.1-sol", "gpt-6-astra"], groups
assert all(g["recommendation"] == "可作起步层" for g in groups), groups
records = [{"model": "haiku", **({"outcome": "done"} if n < 4 else {})} for n in range(5)]
g = stats.summarize(records, 5)[0]
assert g["outcome_count"] == 4 and g["completion_rate"] == 1, g
for n in (3, 4):
    g = stats.summarize([{"outcome": "done" if i < n else "partial"} for i in range(5)], 5)[0]
    assert g["recommendation"] == "继续观察", g
assert stats.duration({"minutes": "nan", "started": "2026-10-14T00:00:00Z", "finished": "2026-10-14T00:02:00Z"}) == 2
# Check registered discovery without reading the real user's archives.
config = Path(sys.argv[2]) / "discovery config"
project = Path(sys.argv[2]) / "registered project"
config.mkdir()
(project / "docs/roadstar").mkdir(parents=True)
(config / "projects.txt").write_text(str(project) + "\n", encoding="utf-8")
with patch.dict(stats.os.environ, {"ROADSTAR_CONFIG_DIR": str(config), "ROADSTAR_PROJECTS": ""}):
    output = io.StringIO()
    with redirect_stdout(output):
        assert stats.main(["--json"]) == 0
    assert json.loads(output.getvalue()) == {"total_records": 0, "groups": []}
PY
pass 'dispatch-stats family cost order, five-sample threshold, missing outcomes and registered discovery'

run_task T20 --class 取证 > "$TMP/class.txt"
grep -q '^class=取证$' "$PLAN/rounds/exec-T20.meta"
! grep -q '^class=' "$PLAN/rounds/exec-T9.meta"
pass 'exec --class writes metadata only when supplied'
expect_exit 2 run_task T21 --class 其他
expect_exit 2 run_task T21 --class
[[ ! -f "$PLAN/rounds/exec-T21.meta" ]]
pass 'exec --class rejects invalid and missing values before dispatch'
run_task T22 --detach --class 补全 > "$TMP/class-detach.txt"
wait_done "$PLAN/rounds/exec-T22.exit"
grep -q '^class=补全$' "$PLAN/rounds/exec-T22.meta"
bash "$SCRIPTS/dex-exec.sh" --help > "$TMP/exec-help.txt"
grep -q -- '--class' "$TMP/exec-help.txt"
for category in 取证 批量 页面实现 窄回归 跨模块 根因 性能 视觉照做 复核 审方案 补全; do
  run_task T23 --dry-run --class "$category" > "$TMP/class-dry.txt"
done
pass 'exec detached worker retains class, help documents it and all allowed values parse'

# Registry tests use isolated configs, including failure paths and relative input.
REGISTRY_CONFIG="$TMP/registry config"
ROADSTAR_CONFIG_DIR="$REGISTRY_CONFIG" python3 "$SCRIPTS/dispatch-stats.py" --register "$PLAN" > "$TMP/register.txt"
[[ "$(cat "$TMP/register.txt")" == "已登记 $PLAN" ]]
ROADSTAR_CONFIG_DIR="$REGISTRY_CONFIG" python3 "$SCRIPTS/dispatch-stats.py" --register "$PLAN/." > "$TMP/register-again.txt"
[[ "$(cat "$TMP/register-again.txt")" == "已在登记表里 $PLAN" ]]
[[ "$(cat "$REGISTRY_CONFIG/projects.txt")" == "$PLAN" ]]
pass 'dispatch-stats --register creates config, prints receipts and deduplicates absolute paths'

python3 - "$SCRIPTS/dispatch-stats.py" "$TMP" "$STATS" <<'PY'
from pathlib import Path
import json, os, subprocess, sys
script, root, stats = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
config = root / "default scan config"
env = {**os.environ, "ROADSTAR_CONFIG_DIR": str(config), "ROADSTAR_PROJECTS": ""}
def run(*args):
    result = subprocess.run([sys.executable, script, *args], env=env, cwd=root,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return result.stdout
assert run() == "还没有登记过项目，派过一次活或用 --register 登记后再看\n"
assert config.is_dir()
assert run("--register", "plan dir") == f"已登记 {root.resolve() / 'plan dir'}\n"
ordered = [root.resolve() / "plan dir", root / "trailing space "]
ordered[1].mkdir()
for project in (ordered[1], ordered[0], ordered[1]):
    run("--register", str(project))
assert (config / "projects.txt").read_text().splitlines() == list(map(str, ordered))
projects = [root / name for name in ("registered stats", "env stats", "missing stats")]
for index, source in enumerate((stats / "a", stats / "b")):
    import shutil
    shutil.copytree(source, projects[index] / "docs/roadstar/run")
(config / "projects.txt").write_text("\n".join(map(str, (projects[0], projects[2], projects[0]))) + "\n")
env["ROADSTAR_PROJECTS"] = f":{projects[1]}:{projects[0]}:"
assert json.loads(run("--json"))["total_records"] == 4
# Explicit roots must not include either the registry or environment projects.
assert json.loads(run(str(stats / "c"), "--json"))["total_records"] == 1
(config / "projects.txt").write_text("")
assert json.loads(run("--json"))["total_records"] == 4
PY
pass 'dispatch-stats default scans registry plus ROADSTAR_PROJECTS, explicit roots override, empty registry hints'

: > "$TMP/config-is-file"
ROADSTAR_CONFIG_DIR="$TMP/config-is-file" run_task T24 > "$TMP/register-warning.txt" 2>&1
cmp "$BRIEF" "$PLAN/rounds/exec-T24.md"
grep -q '警告：项目登记失败' "$TMP/register-warning.txt"
# A blocked dispatch must not register even when using a new config directory.
ROADSTAR_CONFIG_DIR="$TMP/blocked config" FAKE_CODEX_USED=97 expect_exit 3 run_task T25
[[ ! -e "$TMP/blocked config/projects.txt" ]]
pass 'registry write failure warns without blocking dispatch; quota-blocked tasks do not register'

# Every remote below is a local bare repository; forbid other Git transports.
PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPTS/update-check.py" "$TMP" > "$TMP/update-checks.txt" <<'PY'
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from unittest.mock import patch

source, base = Path(sys.argv[1]), Path(sys.argv[2]) / "update fixtures"
base.mkdir()
env = {**os.environ, "ROADSTAR_CONFIG_DIR": str(base / "config"),
       "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
       "GIT_TERMINAL_PROMPT": "0", "GIT_ALLOW_PROTOCOL": "file",
       "GIT_AUTHOR_NAME": "Offline Test", "GIT_AUTHOR_EMAIL": "offline@example.invalid",
       "GIT_COMMITTER_NAME": "Offline Test", "GIT_COMMITTER_EMAIL": "offline@example.invalid"}
def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], env=env,
                            capture_output=True, text=True)
    assert result.returncode == 0, (args, result.stderr)
    return result.stdout.strip()

def install_script(repo):
    script = repo / "skill/scripts/update-check.py"
    script.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, script)
    return script

def run(script, *args, code=0):
    result = subprocess.run([str(script), *args], env=env, cwd=base,
                            capture_output=True, text=True)
    assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
    assert not result.stderr, result.stderr
    return result.stdout

def commit_version(repo, number):
    (repo / "skill").mkdir(exist_ok=True)
    (repo / "skill/SKILL.md").write_text(
        f'---\nname: roadstar\nmetadata:\n  version: "{number}"\n---\n# Roadstar\n', encoding="utf-8")
    (repo / "CHANGELOG.md").write_text(f"# Changelog\n\n## {number} offline release\n\nDetails\n", encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "-m", "Version " + number)

def passed(label):
    print(label)

origin, seed, local = (base / name for name in ("origin.git", "seed", "local clone"))
git(base, "init", "--bare", "--initial-branch=main", str(origin))
git(base, "init", "--initial-branch=main", str(seed))
install_script(seed)
commit_version(seed, "1.0.0")
git(seed, "remote", "add", "origin", str(origin))
git(seed, "push", "-u", "origin", "main")
git(base, "clone", str(origin), str(local))
script = local / "skill/scripts/update-check.py"
cache = base / "config/update-check.json"
assert run(script) == ""
assert run(script, "--verbose") == "Roadstar 已是最新 1.0.0\n"
data = json.loads(run(script, "--json"))
assert data["behind"] == 0 and data["local_version"] == data["remote_version"] == "1.0.0"
assert set(json.loads(cache.read_text())) == {"checked_at", "behind", "local_version", "remote_version"}
passed('update-check current checkout is silent; verbose and JSON report version and cache fields')

commit_version(seed, "1.0.1")
commit_version(seed, "1.1.0")
git(seed, "push")
assert run(script) == ""  # The fresh cache still says current, with no fetch.
expected = 'Roadstar 有新版本：本机 1.0.0，最新 1.1.0（落后 2 个提交）。说「更新 Roadstar」就拉到最新。\n'
assert run(script, "--force") == expected
passed('update-check force fetch discovers two remote commits and prints exact version reminder')

cached = cache.read_bytes()
git(local, "remote", "set-url", "origin", str(base / "nonexistent-origin"))
assert run(script) == expected
assert run(script, "--force") == ""
assert cache.read_bytes() == cached
cache.unlink()
assert run(script, "--force", "--json") == "" and not cache.exists()
cache.write_bytes(cached)
git(local, "remote", "set-url", "origin", str(origin))
passed('update-check 24-hour cache avoids fetch; failed forced fetch is silent and never writes cache')

commit_version(seed, "1.2.0")
git(seed, "push")
assert run(script) == expected
forced = json.loads(run(script, "--force", "--json"))
assert (forced["behind"], forced["remote_version"]) == (3, "1.2.0")
data = json.loads(cache.read_text())
data["checked_at"] = time.time() - 25 * 3600
cache.write_text(json.dumps(data))
assert "1.2.0" in run(script)
assert json.loads(cache.read_text())["checked_at"] > data["checked_at"]
passed('update-check force and expired cache recheck the remote and refresh cached results')

head = git(local, "rev-parse", "HEAD")
(local / "skill/SKILL.md").write_text("local edit\n")
assert "已跟踪文件的未提交改动" in run(script, "--apply", code=1)
git(local, "add", "skill/SKILL.md")
assert "error" in json.loads(run(script, "--apply", "--json", code=1))
assert git(local, "rev-parse", "HEAD") == head
assert "local edit" in (local / "skill/SKILL.md").read_text()
git(local, "reset", "--hard", "HEAD")
(local / "untracked.txt").write_text("Keep me\n")
assert run(script, "--apply") == "已更新到 1.2.0\n## 1.2.0 offline release\n"
assert git(local, "rev-parse", "HEAD") == git(seed, "rev-parse", "HEAD")
assert (local / "untracked.txt").read_text() == "Keep me\n"
assert json.loads(cache.read_text())["behind"] == 0
applied = json.loads(run(script, "--apply", "--json"))
assert applied["local_version"] == "1.2.0" and applied["changelog"] == "## 1.2.0 offline release"
passed('update-check apply rejects staged/unstaged tracked edits, fast-forwards clean worktree and prints changelog')

(local / "local-only.txt").write_text("local commit\n")
git(local, "add", "local-only.txt")
git(local, "commit", "-m", "Local commit")
head = git(local, "rev-parse", "HEAD")
commit_version(seed, "1.3.0")
git(seed, "push")
cached = cache.read_bytes()
assert "无法快进" in run(script, "--apply", code=1)
assert git(local, "rev-parse", "HEAD") == head and cache.read_bytes() == cached
passed('update-check apply refuses divergent history without rewriting commits or refreshing cache')

# Test upstream branches containing slashes, then origin/HEAD and main fallbacks.
git(seed, "checkout", "-b", "release/stable")
commit_version(seed, "2.0.0")
git(seed, "push", "-u", "origin", "release/stable")
branch_local = base / "branch clone"
git(base, "clone", "--branch", "release/stable", str(origin), str(branch_local))
branch_script = branch_local / "skill/scripts/update-check.py"
commit_version(seed, "2.1.0")
git(seed, "push")
assert json.loads(run(branch_script, "--force", "--json"))["remote_version"] == "2.1.0"
git(branch_local, "branch", "--unset-upstream")
assert json.loads(run(branch_script, "--force", "--json"))["remote_version"] == "1.3.0"
git(branch_local, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
assert json.loads(run(branch_script, "--force", "--json"))["remote_version"] == "1.3.0"
assert run(branch_script, "--apply") == "已更新到 2.0.0\n## 2.0.0 offline release\n"
passed('update-check uses upstream slash branch, falls back to origin/HEAD then main, applies without upstream')

plain = base / "not a repo"
plain_script = install_script(plain)
assert run(plain_script) == run(plain_script, "--json") == ""
git(plain, "init", "--initial-branch=main")
assert run(plain_script) == ""
# A nested directory in a larger Git repository is not the script's own repo.
nested_script = install_script(local / "nested")
assert run(nested_script) == ""
link = base / "update-check-link"
link.symlink_to(script)
assert json.loads(run(link, "--force", "--json"))["local_version"] == "1.2.0"
bad = subprocess.run([str(script), "--unknown"], env=env, capture_output=True, text=True)
assert bad.returncode == 2
passed('update-check non-repo and missing origin are silent, symlinks locate real repo, bad arguments exit 2')

# Timeout behavior is injected at subprocess.run, never a real sleeping/network child.
spec = importlib.util.spec_from_file_location("update_check", source)
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)
real_run = subprocess.run
seen_fetch = []
def timeout_fetch(command, **kwargs):
    if "fetch" in command:
        seen_fetch.append(kwargs["timeout"])
        raise subprocess.TimeoutExpired(command, kwargs["timeout"])
    return real_run(command, **kwargs)
with patch.object(update, "ROOT", local.resolve()), patch.dict(os.environ, env), patch.object(update.subprocess, "run", side_effect=timeout_fetch):
    cached = cache.read_bytes()
    output = io.StringIO()
    with redirect_stdout(output):
        assert update.main(["--force"]) == 0
    assert output.getvalue() == "" and cache.read_bytes() == cached and seen_fetch == [8]
passed('update-check fetch timeout is exactly eight seconds, silent and leaves cache unchanged')
PY
while IFS= read -r check; do pass "$check"; done < "$TMP/update-checks.txt"

# Every telemetry project, config, receipt and gh trace stays in this test's TMP.
PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPTS/telemetry.py" "$TMP" <<'PY' > "$TMP/telemetry-checks.txt"
from contextlib import redirect_stdout, redirect_stderr
from datetime import datetime
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from unittest.mock import patch

script, base = Path(sys.argv[1]), Path(sys.argv[2]) / "telemetry fixtures"
base.mkdir()
schema = json.loads((script.parents[1] / "references/dispatch-v1.schema.json").read_text())
env = {**os.environ, "ROADSTAR_CONFIG_DIR": str(base / "config"),
       "ROADSTAR_PROJECTS": "", "FAKE_GH_TRACE_FILE": str(base / "gh.jsonl")}
for key in ("ROADSTAR_TELEMETRY", "ROADSTAR_TELEMETRY_REPO", "FAKE_GH_EXIT"):
    env.pop(key, None)
config = Path(env["ROADSTAR_CONFIG_DIR"])
trace = Path(env["FAKE_GH_TRACE_FILE"])
secret_project = base / "PRIVATE-PROJECT-NAME"
rounds = secret_project / "docs/roadstar/2026-secret/rounds"
rounds.mkdir(parents=True)
env["ROADSTAR_PROJECTS"] = str(secret_project)
assert os.access(script, os.X_OK)
assert os.access(script.parent / "tests/bin/gh", os.X_OK)

def run(*args, extra=None):
    result = subprocess.run([sys.executable, str(script), *args],
                            env={**env, **(extra or {})}, capture_output=True, text=True)
    assert result.returncode == 0, (args, result.returncode, result.stdout, result.stderr)
    return result

def calls():
    return [json.loads(line) for line in trace.read_text().splitlines()] if trace.exists() else []

def snapshot():
    return {str(path.relative_to(config)): path.read_bytes()
            for path in config.rglob("*") if path.is_file()} if config.exists() else {}

def write_meta(name, **changes):
    meta = {"session_id": name, "class": "页面实现", "outcome": "done",
            "model": "claude-haiku-5-5", "effort": "high",
            "started": "2026-10-11T23:50:00Z", "finished": "2026-10-12T00:22:30Z",
            "done_items": "9/10", "notes": "SECRET-TOKEN-123",
            "brief": "/private/SECRET-BRIEF-PATH/brief.md", "project": str(secret_project)}
    meta.update(changes)
    text = "".join(f"{key}={value}\n" for key, value in meta.items() if value is not None)
    (rounds / ("exec-" + name + ".meta")).write_text(text, encoding="utf-8")
    return text

def validate(value, rule):
    # Independent standard-library validator for every keyword in the source schema.
    if "anyOf" in rule:
        for option in rule["anyOf"]:
            try:
                validate(value, option)
                return
            except AssertionError:
                pass
        raise AssertionError(value)
    types = {"object": lambda v: isinstance(v, dict), "array": lambda v: isinstance(v, list),
             "string": lambda v: isinstance(v, str), "integer": lambda v: type(v) is int,
             "boolean": lambda v: type(v) is bool, "null": lambda v: v is None}
    if "type" in rule:
        assert types[rule["type"]](value), (value, rule)
    if "const" in rule:
        assert value == rule["const"]
    if "enum" in rule:
        assert value in rule["enum"]
    if "pattern" in rule:
        assert re.fullmatch(rule["pattern"], value), value
    if isinstance(value, dict):
        assert set(rule.get("required", [])) <= set(value)
        if rule.get("additionalProperties") is False:
            assert set(value) <= set(rule["properties"])
        for key, item in value.items():
            validate(item, rule["properties"][key])
    if isinstance(value, list):
        assert rule.get("minItems", 0) <= len(value) <= rule.get("maxItems", float("inf"))
        for item in value:
            validate(item, rule["items"])
    for keyword, check in (("minimum", lambda v, n: v >= n),
                           ("maximum", lambda v, n: v <= n),
                           ("multipleOf", lambda v, n: v % n == 0)):
        if keyword in rule:
            assert check(value, rule[keyword]), value

def batch(call):
    assert call["body"].startswith("<!-- roadstar-dispatch-data -->\n```json\n")
    assert call["body"].endswith("\n```\n")
    data = json.loads(call["body"].split("```json\n", 1)[1].rsplit("```", 1)[0])
    validate(data, schema)
    expected_keys = set(schema["properties"]["records"]["items"]["required"])
    assert len(expected_keys) == 12
    assert all(set(row) == expected_keys for row in data["records"])
    return data

write_meta("T1", quota_delta="bad claude_week=+2 codex_5h=-3", escalated_to="opus/high")
result = run("send")
assert result.stdout == result.stderr == "" and not calls() and not config.exists()
status = run("status")
assert status.stdout == "还没问过，待回传 1 条，目标仓库 Rurutia-Artemis/roadstar-data\n"
assert not config.exists()
preview = run("send", "--dry-run", "--json")
validate(json.loads(preview.stdout), schema)
assert "预览" in preview.stderr and not config.exists() and not calls()
print('telemetry undecided send is silent, status reports pending records without creating config')

run("enable", "--plan", "max")
settings = json.loads((config / "telemetry.json").read_text())
assert set(settings) == {"enabled", "consent_version", "decided_at", "plan"}
assert settings["enabled"] is True and settings["consent_version"] == 1 and settings["plan"] == "max"
assert datetime.fromisoformat(settings["decided_at"]).utcoffset().total_seconds() == 0
assert run("status").stdout.startswith("已开启，待回传 1 条")
run("disable")
settings = json.loads((config / "telemetry.json").read_text())
assert settings["enabled"] is False and settings["plan"] == "unknown"
before = snapshot()
assert run("send", "--json").stdout == "" and snapshot() == before and not calls()
assert run("status").stdout.startswith("已关闭，待回传 1 条")
run("enable")
assert json.loads((config / "telemetry.json").read_text())["plan"] == "unknown"
print('telemetry enable/disable persist consent version, UTC decision and default/explicit plan; disabled send is silent')

before = snapshot()
result = run("send", extra={"ROADSTAR_TELEMETRY": "0"})
assert result.stdout == result.stderr == "" and snapshot() == before and not calls()
assert run("status", extra={"ROADSTAR_TELEMETRY": "0"}).stdout.startswith("已关闭")
print('telemetry ROADSTAR_TELEMETRY=0 overrides persisted consent')

for extra in ({}, {"ROADSTAR_TELEMETRY": "0"}):
    before = snapshot()
    result = run("send", "--dry-run", "--json", extra=extra)
    data = json.loads(result.stdout)
    validate(data, schema)
    assert "预览" in result.stderr and "未调用 gh，未修改状态" in result.stderr
    assert snapshot() == before and not calls()
run("disable")
before = snapshot()
assert json.loads(run("send", "--dry-run").stdout)["records"]
assert snapshot() == before and not calls()
run("enable", "--plan", "pro")
print('telemetry dry-run prints schema-valid JSON and explanation whether enabled or disabled, with no state changes or gh')

# Registry plus environment, duplicates, missing projects and only rounds paths.
(config / "projects.txt").write_text(str(secret_project) + "\n" + str(base / "missing") + "\n")
env_project = base / "environment project"
env_rounds = env_project / "docs/roadstar/run/rounds"
env_rounds.mkdir(parents=True)
(env_rounds / "exec-copy.meta").write_bytes((rounds / "exec-T1.meta").read_bytes())
second = write_meta("T2", model="gpt-6-astra", finished="2026-10-19T00:00:00Z",
                    minutes="7.5", done_items="1/4", effort="SECRET-TOKEN-123", quota_delta="notes")
(env_rounds / "exec-T2.meta").write_text(second)
(rounds / "exec-T2.meta").unlink()
env["ROADSTAR_PROJECTS"] = f":{env_project}:{secret_project}:"
write_meta("missing-class", **{"class": None})
write_meta("missing-outcome", outcome=None)
write_meta("invalid-class", **{"class": "SECRET-TOKEN-123"})
write_meta("invalid-outcome", outcome="unknown")
(secret_project / "docs/roadstar/exec-not-rounds.meta").write_text(second.replace("T2", "not-rounds"))
result = run("send", extra={"ROADSTAR_TELEMETRY_REPO": "offline-owner/offline-data"})
assert result.stderr == "" and result.stdout.startswith("已回传 2 条，内容见 ")
assert len(calls()) == 1
call = calls()[0]
data = batch(call)
frontmatter = (script.parents[1] / "SKILL.md").read_text().split("---", 2)[1]
assert data["skill_version"] == re.search(r'version:\s*"([0-9.]+)"', frontmatter).group(1)
assert "--label" not in call["args"] and call["args"][call["args"].index("-R") + 1] == "offline-owner/offline-data"
assert call["args"][call["args"].index("--title") + 1] == "dispatch-data · schema 1 · 2026-W43"
assert len(list((config / "uploads").glob("*.json"))) == 1
assert json.loads(next((config / "uploads").glob("*.json")).read_text()) == data
assert len((config / "telemetry-uploaded.txt").read_text().splitlines()) == 2
for private in ("SECRET-TOKEN-123", "SECRET-BRIEF-PATH", "PRIVATE-PROJECT-NAME", str(secret_project), "brief.md"):
    assert private not in call["body"], private
rows = {row["id"]: row for row in data["records"]}
row = rows[hashlib.sha1(b"T1").hexdigest()[:16]]
assert (row["model"], row["model_version"], row["week"], row["minutes"], row["done_ratio"],
        row["quota_delta"], row["plan"], row["escalated"]) == ("haiku", "5.5", "2026-W42", 35, 0.9, "claude_week=+2", "pro", True)
row = rows[hashlib.sha1(b"T2").hexdigest()[:16]]
assert (row["model"], row["model_version"], row["minutes"], row["done_ratio"], row["effort"], row["quota_delta"]) == ("gpt-6-astra", "6", 10, 0.3, "default", None)
print('telemetry sends registry + env records, schema-exact private-free bodies, latest-week title without labels and identical backups')
print('telemetry normalizes models, versions, effort, ratios, UTC ISO week, five-minute half-up duration, quota and configured plan')

before = snapshot()
result = run("send")
assert result.stdout == result.stderr == "" and len(calls()) == 1 and snapshot() == before
assert run("status").stdout.startswith("已开启，待回传 0 条")
print('telemetry skips missing/invalid class or outcome and previously uploaded or duplicate sessions')

write_meta("retry", outcome="failed", done_items=None, model="other-model", minutes="5000")
uploaded = (config / "telemetry-uploaded.txt").read_bytes()
result = run("send", extra={"FAKE_GH_EXIT": "1"})
assert result.stdout == "" and "回传没成功（" in result.stderr and "下次完工时补传" in result.stderr
assert (config / "telemetry-uploaded.txt").read_bytes() == uploaded
assert run("status").stdout.startswith("已开启，待回传 1 条")
assert len(list((config / "uploads").glob("*.json"))) == 2
result = run("send", "--json")
receipt = json.loads(result.stdout)
assert receipt["sent"] == 1 and "已回传 1 条，内容见 " in receipt["uploads"][0]["message"]
assert batch(calls()[-1])["records"][0]["minutes"] == 1440
assert run("status").stdout.startswith("已开启，待回传 0 条")
print('telemetry gh failure preserves pending IDs and backup, next send succeeds; --json provides machine-readable receipts')

# Invalid values are dropped with a fixed, private-free diagnostic.
write_meta("bad-date", finished="not-a-date")
write_meta("bad-ratio", done_items="4/0")
write_meta("bad-duration", minutes="NaN")
result = run("send")
assert result.stdout == "" and result.stderr.count("已丢弃一条不符合 schema 1 的记录") == 3
assert "SECRET" not in result.stderr and len(calls()) == 3
for name in ("bad-date", "bad-ratio", "bad-duration"):
    (rounds / f"exec-{name}.meta").unlink()
print('telemetry rejects malformed dates, ratios and nonfinite duration before gh with non-sensitive diagnostics')

content = write_meta("no-session", session_id=None, finished=None, model="Sonnet 5.5", done_items=None,
                     started="2026-01-05T00:30:00+09:00", minutes="-12")
result = run("send")
row = batch(calls()[-1])["records"][0]
assert row["id"] == hashlib.sha1(content.encode()).hexdigest()[:16]
assert (row["week"], row["model_version"], row["done_ratio"], row["minutes"]) == ("2026-W01", "5.5", 1, 0)
print('telemetry hashes full meta when no session, uses started in UTC when unfinished and clamps negative duration')

previous = len(calls())
for index in range(401):
    write_meta(f"bulk-{index:03}", model="gpt-6.1-sol", minutes="10")
before = snapshot()
preview = json.loads(run("send", "--dry-run", "--json").stdout)
assert [len(data["records"]) for data in preview] == [200, 200, 1]
for data in preview:
    validate(data, schema)
assert snapshot() == before and len(calls()) == previous
result = run("send")
new_calls = calls()[previous:]
assert len(new_calls) == 3 and len(result.stdout.splitlines()) == 3
assert [len(batch(call)["records"]) for call in new_calls] == [200, 200, 1]
assert all(row["model_version"] == "6.1" for call in new_calls for row in batch(call)["records"])
assert all("--label" not in call["args"] for call in new_calls)
assert run("send").stdout == "" and len(calls()) == previous + 3
print('telemetry splits 401 records into 200/200/1 with valid batches and no repeated uploads')

# Inject transport errors without actually sleeping or using a real gh binary.
spec = importlib.util.spec_from_file_location("telemetry", script)
telemetry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(telemetry)
write_meta("transport", model="Fable 5.1", minutes="0")
for error, reason in ((FileNotFoundError(), "没装 gh"),
                      (subprocess.TimeoutExpired("gh", 30), "超时 30 秒")):
    before = (config / "telemetry-uploaded.txt").read_bytes()
    out, err = io.StringIO(), io.StringIO()
    with patch.dict(os.environ, env, clear=True), redirect_stdout(out), redirect_stderr(err), \
         patch.object(telemetry.subprocess, "run", side_effect=error) as mock:
        assert telemetry.main(["send"]) == 0
    assert out.getvalue() == "" and reason in err.getvalue()
    assert mock.call_args.kwargs["timeout"] == 30
    assert (config / "telemetry-uploaded.txt").read_bytes() == before
print('telemetry missing gh and exact 30-second timeout are nonblocking and preserve retry IDs')

# Cross-check built-in validation against actual schema constraints.
valid = batch(calls()[0])["records"][0]
assert telemetry.validate_record(valid)
for key, value in (("notes", "SECRET"), ("id", "zz"), ("week", "2026-W54"),
                   ("model", "arbitrary"), ("model_version", "5.5.1"), ("effort", "bad"),
                   ("outcome", "bad"), ("done_ratio", True), ("done_ratio", 0.25),
                   ("minutes", True), ("minutes", 11), ("minutes", 1445),
                   ("escalated", 1), ("quota_delta", "codex_week=1000"), ("plan", "free")):
    assert not telemetry.validate_record({**valid, key: value}), (key, value)
assert not telemetry.validate_record({key: value for key, value in valid.items() if key != "id"})
assert not telemetry.validate_batch({"schema": 1, "client": "roadstar", "skill_version": "bad", "records": [valid]})
assert not telemetry.validate_batch({"schema": 1, "client": "roadstar", "skill_version": "1.0.0", "records": [valid] * 201})
assert telemetry.model_fields("claude-opus-5-5") == ("opus", "5.5")
assert telemetry.model_fields("unversioned") == ("other", "unknown")
duplicate_quota = write_meta("first-quota", quota_delta="claude_week=+1") + "quota_delta=codex_week=+9\n"
meta = dict(line.split("=", 1) for line in duplicate_quota.splitlines())
assert telemetry.export_record(meta, duplicate_quota.encode(), "unknown")["quota_delta"] == "claude_week=+1"
(rounds / "exec-first-quota.meta").unlink()
print('telemetry built-in validation enforces exact keys, enum values, types, bounds, patterns and batch cap')
PY
while IFS= read -r check; do pass "$check"; done < "$TMP/telemetry-checks.txt"


# ---------------------------------------------------------------- 1.12 ----
# providers.json registry and its validator (no network; the data file is the fixture).
python3 "$SCRIPTS/providers-check.py" > "$TMP/providers.txt"
grep -q '合法' "$TMP/providers.txt"
python3 "$SCRIPTS/providers-check.py" --list | grep -q 'Fable 5.1'
python3 - "$SCRIPTS/../references/providers.json" "$TMP" <<'PY'
import json, sys
from pathlib import Path
data = json.load(open(sys.argv[1], encoding="utf-8"))
out = Path(sys.argv[2])
for model in data["models"]:
    assert set(("family", "access", "price", "context", "bench", "default_role")) <= set(model), model["id"]
    if model["price"] is not None:
        assert model["price_checked"] and model["price_source"], model["id"]
assert "grace" in data["partners"] and data["partners"]["grace"]["role"] == "调研协作方"
bad = json.loads(json.dumps(data)); del bad["models"][0]["bench"]; (out / "bad-missing.json").write_text(json.dumps(bad), encoding="utf-8")
bad = json.loads(json.dumps(data)); bad["models"][1]["family"] = "unknown-house"; (out / "bad-family.json").write_text(json.dumps(bad), encoding="utf-8")
bad = json.loads(json.dumps(data)); bad["models"][2]["default_role"] = "随便"; (out / "bad-role.json").write_text(json.dumps(bad), encoding="utf-8")
bad = json.loads(json.dumps(data)); bad["models"][3]["price_checked"] = "昨天"; (out / "bad-date.json").write_text(json.dumps(bad), encoding="utf-8")
PY
for bad in bad-missing bad-family bad-role bad-date; do expect_exit 2 python3 "$SCRIPTS/providers-check.py" "$TMP/$bad.json"; done
expect_exit 2 python3 "$SCRIPTS/providers-check.py" "$TMP/does-not-exist.json"
pass 'providers.json valid; every priced model has date and source; missing field, unknown family, bad role and bad date exit 2'

# quota-config.py: unknown key, missing file, atomic write, idempotent init.
QCFG="$TMP/quota config"
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" show > "$TMP/qc-show.txt"
grep -q '还没建文件' "$TMP/qc-show.txt" && grep -q '未填' "$TMP/qc-show.txt"
[[ ! -e "$QCFG/quota.json" ]]
expect_exit 2 env ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set api_budget_usd.openai 20
expect_exit 2 env ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set default_strategy fastest
expect_exit 2 env ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set grok_plan gold
[[ ! -e "$QCFG/quota.json" ]]
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set default_strategy thrift > /dev/null
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set try_new_models 开 > /dev/null
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set grok_plan premium > /dev/null
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" set grace.folder "Grace × Cloud 交接 / 05-Roadstar 引路星" > /dev/null
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" show --json > "$TMP/qc.json"
json_check "$TMP/qc.json" 'd["default_strategy"] == "thrift" and d["try_new_models"] is True and d["grok_plan"] == "premium" and d["grace"]["enabled"] is True and d["exists"] is True and "api_budget_usd" not in d'
[[ -z "$(ls "$QCFG" | grep -v '^quota.json$')" ]]
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" init | grep -q '已有'
printf 'not json' > "$QCFG/quota.json"
ROADSTAR_CONFIG_DIR="$QCFG" python3 "$SCRIPTS/quota-config.py" show | grep -q '还没建文件'
pass 'quota-config unknown key and bad values exit 2 without writing, set/show round-trip, atomic write leaves no temp file, init idempotent, broken file falls back'

# quota-status.py 1.12 columns: grok login states and api key names only.
: > "$FAKE_TRACE_FILE"
XAI_API_KEY='sk-SECRET-VALUE-DO-NOT-PRINT' python3 "$SCRIPTS/quota-status.py" --json > "$TMP/q112.json"
json_check "$TMP/q112.json" 'd["grok"]["source"] == "live" and d["grok"]["logged_in"] is True and d["grok"]["default_model"] == "grok-4.7" and len(d["grok"]["models"]) == 4 and "xai" in d["api_keys"]["present"] and "ANTHROPIC_API_KEY" in d["api_keys"]["checked"] and "SECRET" not in open(sys.argv[1]).read() and set(d["claude"]) >= {"tier","plan","source","fetched_at","five_hour","seven_day","fable","pending_tier"} and set(d["codex"]) >= {"weekly","five_hour","reset_cards","credits","plan","source","fetched_at","tier","pending_tier"}'
grep -q '"cli":"grok"' "$FAKE_TRACE_FILE"
XAI_API_KEY='sk-SECRET-VALUE-DO-NOT-PRINT' python3 "$SCRIPTS/quota-status.py" > "$TMP/q112.txt"
grep -q 'Grok：已登录 grok-4.7' "$TMP/q112.txt" && grep -q 'API key：有' "$TMP/q112.txt" && ! grep -q 'SECRET' "$TMP/q112.txt"
FAKE_GROK_STATE=logged_out python3 "$SCRIPTS/quota-status.py" --json > "$TMP/q112-out.json"
json_check "$TMP/q112-out.json" 'd["grok"]["source"] == "none" and d["grok"]["logged_in"] is False and d["grok"]["models"] == []'
FAKE_GROK_STATE=error python3 "$SCRIPTS/quota-status.py" --json > "$TMP/q112-err.json"
json_check "$TMP/q112-err.json" 'd["grok"]["source"] == "none" and d["codex"]["tier"] == "宽"'
PYTHONDONTWRITEBYTECODE=1 FAKE_GROK_STATE=hang python3 - "$SCRIPTS/quota-status.py" <<'PY'
import importlib.util, sys, time
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("quota_status", sys.argv[1]); q = importlib.util.module_from_spec(spec); spec.loader.exec_module(q)
with patch.object(q, "TIMEOUT", 0.3):
    started = time.monotonic(); r = q.grok_probe()
assert r["source"] == "none" and "超时" in r["note"] and time.monotonic() - started < 3, r
with patch.object(q.shutil, "which", return_value=None):
    r = q.grok_probe()
assert r["source"] == "none" and r["note"] == "命令不存在", r
assert q.api_keys_probe({"OPENAI_API_KEY": "x", "DEEPSEEK_API_KEY": "  "})["present"] == ["openai"]
PY
pass 'quota-status grok column: logged in, logged out, error, hang within patched timeout, missing binary; api_keys by name only, secrets never printed, old keys intact'

# quota-estimate.py: units, confidence, unlockable, unreadable family, calibrated path, session and plan.
EST="$TMP/estimate"
mkdir -p "$EST"
FAKE_CLAUDE_USED=97 FAKE_CLAUDE_FABLE=19 FAKE_CODEX_USED=8 FAKE_CODEX_CARDS=1 python3 "$SCRIPTS/quota-status.py" --json > "$EST/probe-a.json"
ROADSTAR_CONFIG_DIR="$EST/nocfg" python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/probe-a.json" --session 探讨 --now 2026-10-16T06:00:00Z > "$EST/a.json"
json_check "$EST/a.json" 'd["providers"]["codex"]["available_points"] == 82 and d["providers"]["codex"]["calibrated"] is False and d["providers"]["codex"]["units_text"].startswith("约 ") and d["providers"]["codex"]["confidence"] == "低" and d["providers"]["codex"]["unlockable_units"] is not None and d["providers"]["codex"]["units"] == int(82 / 0.3) and d["providers"]["claude"]["tier"] == "空" and d["providers"]["claude"]["units"] is None and d["providers"]["claude"]["available_points"] == 0 and d["total"]["included"] == ["codex"] and d["total"]["units"] == d["providers"]["codex"]["units"] and d["total"]["confidence"] == "低" and d["strategy"] == "auto" and d["strategy_from"] == "默认" and d["config_exists"] is False and d["session"]["rounds"] == 3 and d["session"]["feature_map_calls"] == 2 and d["session"]["codex_points"] > 0 and d["session"]["enough"] is True and d["connected_count"] == 3 and d["connected_text"].startswith("接了 3 家") and d["grace"]["role"] == "调研协作方" and d["skill_version"].startswith("1.12")'
python3 - "$EST/a.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
c = d["providers"]["codex"]
assert c["unlockable_points"] == 90 and c["unlockable_units"] == int(90 / 0.3), c
assert c["units"] + c["unlockable_units"] > c["units"] and d["total"]["unlockable_units"] == c["unlockable_units"]
assert "10-19" in c["reset_jst"] and d["providers"]["claude"]["reset_jst"]
assert d["providers"]["grok"]["connected"] and d["providers"]["grok"]["units"] is None and d["providers"]["grok"]["confidence"] == "无"
PY
# Unreadable Claude: not in the total, note carried from the probe, tier text says 按紧处理.
python3 - "$EST/probe-a.json" "$EST/probe-b.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["claude"] = {"tier": None, "plan": None, "source": "none", "fetched_at": d["claude"]["fetched_at"], "five_hour": None, "seven_day": None, "fable": None, "pending_tier": None}
d["note"] = ["Claude（额度不可用或尚未登录）"]
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY
ROADSTAR_CONFIG_DIR="$EST/nocfg" python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/probe-b.json" > "$EST/b.json"
json_check "$EST/b.json" 'd["providers"]["claude"]["connected"] is False and d["providers"]["claude"]["confidence"] == "无" and "尚未登录" in d["providers"]["claude"]["note"] and "按紧处理" in d["providers"]["claude"]["tier_text"] and d["total"]["included"] == ["codex"] and d["connected_count"] == 2'
# Calibrated local table removes 约 and lifts confidence; quota.json default strategy and --strategy override.
cat > "$EST/estimates.json" <<'JSON'
{"schema": 1, "cells": {"页面实现|gpt-6.1-sol|high": {"count": 12, "p50_minutes": 18, "p80_minutes": 25, "p50_tokens": 40000}}, "providers": {"codex": {"tokens_per_point": 80000, "points": 5, "calibrated": true}, "claude": {"tokens_per_point": null, "calibrated": false}}}
JSON
mkdir -p "$EST/cfg"
printf '{"default_strategy": "thrift", "try_new_models": true, "grok_plan": "super", "grace": {"enabled": false}}\n' > "$EST/cfg/quota.json"
ROADSTAR_CONFIG_DIR="$EST/cfg" python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/probe-a.json" --estimates "$EST/estimates.json" > "$EST/c.json"
json_check "$EST/c.json" 'd["providers"]["codex"]["calibrated"] is True and abs(d["providers"]["codex"]["points_per_unit"] - 0.5) < 1e-9 and d["providers"]["codex"]["units"] == 164 and d["providers"]["codex"]["units_text"] == "164 件" and d["providers"]["codex"]["confidence"] == "高" and d["total"]["calibrated"] is True and d["strategy"] == "thrift" and d["strategy_from"] == "quota.json" and d["try_new_models"] is True and d["providers"]["grok"]["self_reported_plan"] == "super" and d["grace"]["enabled"] is False and d["config_exists"] is True'
ROADSTAR_CONFIG_DIR="$EST/cfg" python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/probe-a.json" --strategy rush --session 探讨 --size 大 > "$EST/d.json"
json_check "$EST/d.json" 'd["strategy"] == "rush" and d["strategy_from"] == "命令行" and d["session"]["rounds"] == 2 and d["session"]["feature_map_calls"] == 1'
cat > "$EST/plan.md" <<'MD'
## 10 拆分表
| T# | 任务 | 类别 | 执行方（型号·强度） | 上限 | 审查人 | 依赖 | 理由 |
|---|---|---|---|---|---|---|---|
| T1 | 数据层 | 跨模块 | Codex 的 Astra · 高 | 4h | Codex 的 6.1 Sol 只读 | 无 | 底座 |
| T2 | 页面 A | 页面实现 | Codex 的 6.1 Sol · 高 | 2h | Sonnet 只读 | T1 | 规格清楚 |
| T3 | 页面 B | 页面实现 | Sonnet | 2h | Codex 的 6.1 Sol 只读 | T1 | Codex 线满 |
MD
ROADSTAR_CONFIG_DIR="$EST/nocfg" python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/probe-a.json" --plan "$EST/plan.md" > "$EST/e.json"
json_check "$EST/e.json" 'len(d["plan"]["tasks"]) == 3 and d["plan"]["tasks"][0]["family"] == "codex" and d["plan"]["tasks"][2]["family"] == "claude" and d["plan"]["totals"]["codex"]["units"] > d["plan"]["totals"]["claude"]["units"] > 0 and d["plan"]["totals"]["codex"]["points"] > 0 and "→" in d["plan"]["totals"]["codex"]["text"] and d["plan"]["shortfall"] == {}'
expect_exit 2 python3 "$SCRIPTS/quota-estimate.py" --probe "$EST/missing.json"
pass 'quota-estimate: uncalibrated 约 with points, reset cards only unlockable, unreadable family out of total, calibrated local table, quota.json default and --strategy override, session and plan costs'

# strategies.json / strategies.md consistency with SKILL §8.
python3 - "$SCRIPTS/../SKILL.md" "$SCRIPTS/../references/strategies.json" "$SCRIPTS/../references/strategies.md" <<'PY'
import json, re, sys
skill = open(sys.argv[1], encoding="utf-8").read()
data = json.load(open(sys.argv[2], encoding="utf-8"))
md = open(sys.argv[3], encoding="utf-8").read()
section = skill[skill.index("### 8 "):]
section = section[:section.index("\n### 9 ")]
rows = {}
for line in section.splitlines():
    if line.startswith("|") and not line.startswith("|---") and not line.startswith("| 活"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 4:
            rows[cells[0]] = cells
assert len(rows) >= 12, rows.keys()
checked = 0
for klass, spec in data["classes"].items():
    for strategy in ("auto", "quality", "thrift", "rush"):
        cell = spec[strategy]
        for key in ("exec", "cap", "review"):
            assert cell.get(key), (klass, strategy, key)
            assert "同左" not in cell[key] and "同上" not in cell[key], (klass, strategy, key)
    assert klass in md, klass
    if spec["skill_row"]:
        row = rows.get(spec["skill_row"])
        assert row, (klass, spec["skill_row"], list(rows))
        assert row[1] == spec["auto"]["exec"], (klass, row[1], spec["auto"]["exec"])
        assert row[2] == spec["auto"]["cap"], (klass, row[2], spec["auto"]["cap"])
        assert row[3] == spec["auto"]["review"], (klass, row[3], spec["auto"]["review"])
        checked += 1
assert checked >= 10, checked
for strategy, spec in data["strategies"].items():
    assert spec["label"] in md and set(spec["parallel"]) == {"codex", "claude", "simulator"}
PY
pass 'strategies.json auto column equals SKILL §8 row by row; four columns filled without 同左; strategies.md lists every class and strategy'

printf 'PASS %d checks\n' "$COUNT"
