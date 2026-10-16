# Sourced by run.sh. All dispatches use tests/bin/grok and isolated configuration.
GROK_PLAN="$TMP/grok plan"
GROK_CFG="$TMP/grok config"
mkdir -p "$GROK_PLAN"
GROK_BRIEF="$GROK_PLAN/brief.md"
printf '%s\n' '# 只读取证' '逐项复核，保留原文与换行。' '$(touch should-not-exist)' '' > "$GROK_BRIEF"
grok_task() { ROADSTAR_CONFIG_DIR="$GROK_CFG" bash "$SCRIPTS/grok-exec.sh" "$GROK_PLAN" "$1" --brief "$GROK_BRIEF" --root "$TMP" --class 取证 "${@:2}"; }
: > "$FAKE_TRACE_FILE"
grok_task T1 --dry-run --max-minutes 2 > "$TMP/grok-dry.txt"
python3 - "$TMP/grok-dry.txt" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
for flag in ['grok -p ', '-m grok-4.7', '--cwd ', '--sandbox read-only', '--permission-mode bypassPermissions', '--max-turns 30', '--reasoning-effort high', '--output-format plain', 'exec-T1.md', 'exec-T1.meta', 'exec-T1-stdout.log', 'exec-T1.exit', '时间上限：2 分钟']:
    assert flag in s, (flag, s)
PY
[[ ! -s "$FAKE_TRACE_FILE" && ! -e "$GROK_CFG" && ! -e "$GROK_PLAN/rounds" ]]
pass 'Grok C3 dry-run: complete fixed read-only command, default model/effort/turns, no CLI or artifacts'
expect_exit 2 grok_task T1 --write
grep -q '写活等后续版本' "$TMP/last-output"
expect_exit 2 grok_task T1 --class 批量
expect_exit 2 grok_task T1 --max-turns 0
expect_exit 2 grok_task T1 --max-minutes abc
expect_exit 2 grok_task T1 --est-minutes 0
expect_exit 2 grok_task T1 --strategy fast
expect_exit 2 grok_task T1 --effort bogus
expect_exit 2 bash "$SCRIPTS/grok-exec.sh" "$GROK_PLAN" T1 --brief "$GROK_BRIEF"
[[ ! -e "$GROK_PLAN/rounds" ]]
pass 'Grok C3/C4: --write rejected with exit 2; only evidence/review classes and valid values accepted'
FAKE_GROK_STATE=logged_out expect_exit 3 grok_task T1
grep -q '未登录' "$TMP/last-output"
[[ ! -e "$GROK_CFG/projects.txt" && ! -e "$GROK_PLAN/rounds" ]]
# PATH with just the bootstrap utilities, so a real installed Grok can never leak in.
NO_GROK="$TMP/no grok"
mkdir -p "$NO_GROK"
for command in dirname basename; do ln -s "$(command -v "$command")" "$NO_GROK/$command"; done
expect_exit 3 env PATH="$NO_GROK" /bin/bash "$SCRIPTS/grok-exec.sh" "$GROK_PLAN" T1 --brief "$GROK_BRIEF" --root "$TMP" --class 取证
grep -q '没装 grok' "$TMP/last-output"
[[ ! -e "$GROK_CFG/projects.txt" && ! -e "$GROK_PLAN/rounds" ]]
pass 'Grok C3: missing binary and logged out exit 3 with reason, no task artifacts or registry'
: > "$FAKE_TRACE_FILE"
grok_task T1 --max-minutes 2 --est-minutes 1 --strategy quality > "$TMP/grok-ok.txt"
for suffix in md meta exit; do [[ -s "$GROK_PLAN/rounds/exec-T1.$suffix" ]]; done
[[ -s "$GROK_PLAN/rounds/exec-T1-stdout.log" ]]
cmp "$GROK_BRIEF" "$GROK_PLAN/rounds/exec-T1.md"
cmp "$GROK_BRIEF" "$GROK_PLAN/rounds/exec-T1-request.md"
python3 - "$GROK_PLAN/rounds/exec-T1.meta" "$FAKE_TRACE_FILE" "$GROK_BRIEF" "$TMP" <<'PY'
from pathlib import Path
import json, sys
m = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines())
expected = dict(model='grok-4.7', effort='high', sandbox='read-only', exit='0', max_minutes='2', timed_out='0', est_minutes='1', strategy='quality', tokens_used='', session_id='', resumed_from='', attempt='1', **{'class': '取证'})
assert all(m[k] == v for k, v in expected.items()), m
assert m['started'] and m['finished'] and Path(m['root']).samefile(sys.argv[4]), m
calls = [json.loads(line)['args'] for line in Path(sys.argv[2]).read_text().splitlines()]
assert calls[0] == ['models'], calls
assert calls[1] == ['-p', Path(sys.argv[3]).read_text(), '-m', 'grok-4.7', '--cwd', m['root'], '--sandbox', 'read-only', '--permission-mode', 'bypassPermissions', '--max-turns', '30', '--reasoning-effort', 'high', '--output-format', 'plain'], calls
PY
[[ ! -e "$TMP/should-not-exist" ]]
grok_task T1 --model grok-4.6 --effort medium --max-turns 7 --class 复核 > /dev/null
grep -q '^model=grok-4.6$' "$GROK_PLAN/rounds/exec-T1.meta"
grep -q '^effort=medium$' "$GROK_PLAN/rounds/exec-T1.meta"
grep -q '^class=复核$' "$GROK_PLAN/rounds/exec-T1.meta"
grep -q '^attempt=2$' "$GROK_PLAN/rounds/exec-T1.meta"
cmp "$GROK_BRIEF" "$GROK_PLAN/rounds/exec-T1-request-r2.md"
[[ "$(cat "$GROK_CFG/projects.txt")" == "$(cd "$TMP" && pwd)" && "$(wc -l < "$GROK_CFG/projects.txt" | tr -d ' ')" == 1 ]]
pass 'Grok C3: complete result/log/request/meta/exit, exact multiline prompt and argv, overrides, request snapshots, exactly one registry line'
FAKE_GROK_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 expect_exit 124 grok_task T2 --max-minutes 1
grep -q '^exit=124$' "$GROK_PLAN/rounds/exec-T2.meta"
grep -q '^timed_out=1$' "$GROK_PLAN/rounds/exec-T2.meta"
grep -q '^124$' "$GROK_PLAN/rounds/exec-T2.exit"
[[ ! -e "$GROK_PLAN/rounds/exec-T2.md" ]]
pass 'Grok C3 timeout: stopped, exit 124, timed_out=1, no success report'
FAKE_GROK_DELAY=2 grok_task T3 --detach --class 复核 --est-minutes 5 --strategy rush > "$TMP/grok-detach.txt"
[[ -s "$GROK_PLAN/rounds/exec-T3.pid" ]]
FAKE_GROK_STATE=logged_out bash "$SCRIPTS/grok-exec.sh" "$GROK_PLAN" T3 --status > "$TMP/grok-status.txt"
grep -q '运行中' "$TMP/grok-status.txt"
expect_exit 2 grok_task T3
wait_done "$GROK_PLAN/rounds/exec-T3.exit"
cmp "$GROK_BRIEF" "$GROK_PLAN/rounds/exec-T3.md"
grep -q '^class=复核$' "$GROK_PLAN/rounds/exec-T3.meta"
grep -q '^est_minutes=5$' "$GROK_PLAN/rounds/exec-T3.meta"
grep -q '^strategy=rush$' "$GROK_PLAN/rounds/exec-T3.meta"
FAKE_GROK_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 grok_task T4 --detach --max-minutes 1 > /dev/null
wait_done "$GROK_PLAN/rounds/exec-T4.exit"
[[ "$(cat "$GROK_PLAN/rounds/exec-T4.exit")" == 124 ]]
bash "$SCRIPTS/grok-exec.sh" "$GROK_PLAN" T4 --status > "$TMP/grok-time-status.txt" 2>&1
grep -q '到时间上限被停止' "$TMP/grok-time-status.txt"
pass 'Grok C3 background: PID, running status without login, lock, full meta, completion and detached timeout'
FAKE_GROK_EXIT=7 expect_exit 7 grok_task T1
grep -q '^exit=7$' "$GROK_PLAN/rounds/exec-T1.meta"
grep -q '^7$' "$GROK_PLAN/rounds/exec-T1.exit"
[[ ! -e "$GROK_PLAN/rounds/exec-T1.md" ]]
grep -q 'stub Grok failure' "$GROK_PLAN/rounds/exec-T1-stdout.log"
pass 'Grok failure: nonzero status retained, stale success removed, log available'

PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPTS" "$GROK_PLAN/rounds/exec-T3.meta" <<'PYTEST'
import importlib.util, json, sys
from pathlib import Path
scripts = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('telemetry_113', scripts / 'telemetry.py')
t = importlib.util.module_from_spec(spec); spec.loader.exec_module(t)
raw = Path(sys.argv[2]).read_bytes()
meta = dict(line.split('=', 1) for line in raw.decode().splitlines())
meta['outcome'] = 'done'
record = t.export_record(meta, raw, 'unknown')
assert record['model'] == 'other' and record['model_version'] == '4.7', record
assert t.validate_record(record), record
assert t.validate_batch(dict(schema=1, client='roadstar', skill_version='1.13.0', records=[record]))
trials = json.loads((scripts.parent / 'references/strategies.json').read_text())['trials']['grok-4.7']
assert trials['enabled_by'] == 'try_new_models' and trials['requires_login'] is True
assert trials['classes'] == ['取证', '复核'] and trials['sandbox'] == 'read-only' and trials['min_records'] == 5
providers = json.loads((scripts.parent / 'references/providers.json').read_text())
assert next(m for m in providers['models'] if m['id'] == 'grok-4.7')['default_role'] == '试用：取证、复核（只读）'
PYTEST
pass 'Grok C4: trial policy restricted to two classes and five samples, provider role valid, real meta exports as other in unchanged telemetry schema 1'
