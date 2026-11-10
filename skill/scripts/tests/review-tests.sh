#!/usr/bin/env bash
# Offline review request, schema and plan/design compatibility tests (Bash 3.2).
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
export PATH="$TEST_DIR/bin:$PATH"
export PYTHONDONTWRITEBYTECODE=1
unset FAKE_CODEX_USED FAKE_CODEX_CARDS FAKE_CODEX_FIVE_HOUR FAKE_CODEX_DELAY FAKE_CODEX_EXIT FAKE_CODEX_REPORT FAKE_CODEX_REPLY
unset BRIEF_CHECK ROADSTAR_DESIGN_CHECK
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-review-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'echo "FAIL: line $LINENO" >&2' ERR
export FAKE_TRACE_FILE="$TMP/trace.jsonl"
export ROADSTAR_CONFIG_DIR="$TMP/config"
PLAN="$TMP/plan dir"
mkdir -p "$PLAN"
printf '%s\n' '# Brief' '保留原文。' > "$PLAN/brief.md"
printf '%s\n' '# Plan' 'Do the assigned task.' > "$PLAN/plan.md"
printf '%s\n' '# Ledger' '| # | 题目 | 来源 | 级别 | 处置 | 状态 |' > "$PLAN/ledger.md"
COUNT=0
pass() { COUNT=$((COUNT + 1)); printf 'ok %d - %s\n' "$COUNT" "$1"; }
json_check() {
  python3 - "$1" "$2" <<'PYJSON'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert eval(sys.argv[2]), d
PYJSON
}
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

python3 - "$SCRIPTS" "$TMP" "$COUNT" <<'PYTEST'
import copy
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

scripts, tmp = Path(sys.argv[1]), Path(sys.argv[2])
count = int(sys.argv[3])

def check(item, title, action):
    global count
    status, evidence = 'pass', title
    try:
        action()
    except Exception as exc:
        status, evidence = 'fail', title + ': ' + str(exc)
        raise
    finally:
        if os.environ.get('ROADSTAR_T4_PROGRESS'):
            with open(os.environ['ROADSTAR_T4_PROGRESS'], 'a') as f:
                f.write(datetime.datetime.now().astimezone().isoformat() + '\t' + item + '\t' + status + '\t' + evidence.replace('\n', ' ') + '\n')
    count += 1
    print(f'ok {count} - {title}', flush=True)

def run(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=120, check=True)

# Capture dry-run artifacts in the EXIT cleanup, then run the real rm.
# This tests the public --dry-run without adding a production test switch.
harness = 'rm() { if [[ "$1" == -rf && -d "$2" ]]; then command cp "$2"/* "$CAPTURE_DIR/"; fi; command rm "$@"; }; export -f rm; bash "$@"'
serial = 0

def dry(scene, n, *extra):
    global serial
    serial += 1
    capture = tmp / f'capture{serial}'
    capture.mkdir()
    env = dict(os.environ, CAPTURE_DIR=str(capture))
    r = subprocess.run(['bash', '-c', harness, 'capture', str(scripts/'dex-review.sh'), str(scene), '--root', str(tmp), '--dry-run', *extra], capture_output=True, text=True, timeout=120, env=env)
    assert r.returncode == 0, r.stderr
    request = (capture/f'r{n}-dex-request.md').read_text()
    # Production dry-run still cleans up and must not persist any round artifacts.
    assert not (scene/f'rounds/r{n}-dex-request.md').exists()
    assert not (scene/f'rounds/r{n}-design.md').exists()
    return request, capture

def scene(name):
    p = tmp / name
    p.mkdir()
    for f in ('brief.md', 'plan.md', 'ledger.md'):
        (p/f).write_bytes((tmp/'plan dir'/f).read_bytes())
    return p

contract = (scripts.parent/'references/dex-review-prompt.md').read_text().split('---\n', 1)[1]
# Frozen payloads generated by the PRE-T4 dex-review.sh (HEAD before this change).
# C4 intentionally changes the contract, so prepend the current contract verbatim.
# Only temp roots and diff timestamps are normalized; all other bytes must match.
EXPECTED1 = '# 本轮：第 1 轮\n\n## brief\n\n# Brief\n保留原文。\n\n## plan（当前全文）\n\n# Plan\nDo the assigned task.\n\n## 账本\n\n# Ledger\n| # | 题目 | 来源 | 级别 | 处置 | 状态 |\n'
EXPECTED2 = '# 本轮：第 2 轮\n\n## brief\n\n# Brief\n保留原文。\n\n## plan 全文没有附在这里（省额度）\n\n全文在 `<PLAN_DIR>/plan.md`。本轮只审下面的 diff 和账本里的开放议题；需要核对上下文时自己按段读（sed -n 或 rg -n），不要整份 cat。\n\n## plan 自上轮的 diff\n\n```diff\n--- <PLAN_DIR>/rounds/r1-plan.md\n+++ <WORK_ROUNDS>/r2-plan.md\n@@ -1,2 +1,3 @@\n # Plan\n Do the assigned task.\n+New change.\n```\n\n## 账本\n\n# Ledger\n| # | 题目 | 来源 | 级别 | 处置 | 状态 |\n\n'

def normalized(request, scene):
    request = request.replace(str(scene), '<PLAN_DIR>')
    def diff_header(m):
        path = re.sub(r'.*/dex-review\.[^/]+/', '<WORK_ROUNDS>/', m[2])
        return m[1] + ' ' + path
    return re.sub(r'^(---|\+\+\+) ([^\t\n]+)\t[^\n]*', diff_header, request, flags=re.M)

legacy = scene('without design')

def first_legacy():
    text, _ = dry(legacy, 1)
    assert normalized(text, legacy) == contract + '\n' + EXPECTED1
check('C3', '无设计页首轮请求与改前逐字相同（契约按 C4 更新）', first_legacy)
run('bash', str(scripts/'dex-review.sh'), str(legacy), '--root', str(tmp))
with (legacy/'plan.md').open('a') as f:
    f.write('New change.\n')

def second_legacy():
    text, _ = dry(legacy, 2)
    assert normalized(text, legacy) == contract + '\n' + EXPECTED2
check('C3', '无设计页第二轮精简请求与改前逐字相同', second_legacy)

with_design = scene('with design')
(with_design/'design.md').write_text('# Design\n## 为什么做\n首轮设计唯一正文。\n')

def first_design():
    text, capture = dry(with_design, 1)
    assert '## 设计页（design.md 全文）\n\n' + (with_design/'design.md').read_text() in text
    assert text.index('## brief') < text.index('## 设计页（design.md 全文）') < text.index('## plan（当前全文）')
    assert (capture/'r1-design.md').read_bytes() == (with_design/'design.md').read_bytes()
check('C3', '有设计页首轮在 brief 后附全文并做设计快照', first_design)
run('bash', str(scripts/'dex-review.sh'), str(with_design), '--root', str(tmp))
with (with_design/'design.md').open('a') as f:
    f.write('第二轮设计改动。\n')

def compact_design():
    text, capture = dry(with_design, 2)
    assert '## 设计页（design.md 全文）' not in text
    assert f'`{with_design}/design.md`' in text
    assert '## design.md 自上轮的 diff' in text
    assert '+第二轮设计改动。' in text
    assert '\n首轮设计唯一正文。\n' not in text  # diff 上下文带空格，不是全文
    assert (capture/'r2-design.md').read_bytes() == (with_design/'design.md').read_bytes()
    assert '+第二轮设计改动。' in (capture/'r2-design.diff').read_text()
    assert (with_design/'rounds/r1-design.md').read_text() != (capture/'r2-design.md').read_text()
check('C3', '第二轮精简模式只附设计页路径与 diff，快照基于上轮', compact_design)

def full_design():
    text, _ = dry(with_design, 2, '--full')
    assert '## 设计页（design.md 全文）\n\n' + (with_design/'design.md').read_text() in text
    assert '## plan（当前全文）' in text
check('C3', '--full 同时恢复设计页和 plan 全文', full_design)

introduced = scene('introduced design')
run('bash', str(scripts/'dex-review.sh'), str(introduced), '--root', str(tmp))
(introduced/'design.md').write_text('# Design\n本轮新增设计页。\n')

def new_design():
    text, _ = dry(introduced, 2)
    assert '--- /dev/null' in text and '+本轮新增设计页。' in text
check('C3', '第二轮才新增设计页时 diff 显示全部新增内容', new_design)

def unchanged_design():
    run('bash', str(scripts/'dex-review.sh'), str(with_design), '--root', str(tmp))
    text, capture = dry(with_design, 3)
    assert '## design.md 自上轮的 diff\n\n（无改动）' in text
    assert (capture/'r3-design.diff').stat().st_size == 0
check('C3', '设计页未变时明确显示无改动', unchanged_design)

schema = json.loads((scripts.parent/'references/dex-review.schema.json').read_text())

# Standard-library validator for the schema vocabulary used by this contract.
# Unknown keywords fail the test rather than silently skipping a constraint.
def validate(value, rule):
    assert not set(rule) - {'type', 'properties', 'required', 'additionalProperties', 'items', 'enum', 'const', 'contains', 'description'}, rule
    kind = rule.get('type')
    if kind:
        assert isinstance(value, {'object': dict, 'array': list, 'string': str}[kind]), (value, kind)
    if 'const' in rule:
        assert value == rule['const']
    if 'enum' in rule:
        assert value in rule['enum']
    if isinstance(value, dict):
        assert set(rule.get('required', [])) <= value.keys()
        if rule.get('additionalProperties') is False:
            assert value.keys() <= rule['properties'].keys()
        for key, val in value.items():
            if key in rule.get('properties', {}):
                validate(val, rule['properties'][key])
    if isinstance(value, list):
        for val in value:
            if 'items' in rule:
                validate(val, rule['items'])
        if 'contains' in rule:
            for val in value:
                try:
                    validate(val, rule['contains'])
                    break
                except AssertionError:
                    pass
            else:
                raise AssertionError('missing required checklist item lowering')

def invalid(value, rule):
    try:
        validate(value, rule)
    except AssertionError:
        return
    raise AssertionError('invalid schema fixture accepted')

items = re.findall(r'^- ([a-z_]+)：', contract, re.M)
valid = dict(verdict='PASS', checklist=[dict(item=k, status='ok', note='无 diff，不适用' if k == 'lowering' else '已核对') for k in items], new_issues=[], open_issue_verdicts=[], alternative='', reply_to_chair='', questions_for_chair=[])

def mandatory_lowering():
    assert 'checklist' in schema['required']
    rule = schema['properties']['checklist']
    assert rule['contains']['properties']['item']['const'] == 'lowering'
    assert 'item' in rule['contains']['required']
    validate(valid, schema)
    for rows in ([], [c for c in valid['checklist'] if c['item'] != 'lowering']):
        missing = dict(valid, checklist=rows)
        invalid(missing, schema)
    missing_note = copy.deepcopy(valid)
    del missing_note['checklist'][-1]['note']
    invalid(missing_note, schema)
check('C4', 'schema 合法且缺 lowering、缺 note 均不能过契约', mandatory_lowering)

def prompt_contract():
    for key in ['goals_nongoals', 'approach_alternatives', 'open_questions', 'prior_art']:
        assert re.search(r'^- ' + key + r'：[^\n]*看 design.md，没有就看 plan', contract, re.M)
    assert len(items) == 13 and 'lowering' in items
    for word in ['下调门槛', '跳过或删测试', '关掉检查', '留桩或半成品', '新增没人同意的例外', '@ts-ignore', 'eslint-disable', '# noqa', 'XCTSkip', '.skip', 'new_issues', '方案没明确同意就是 `blocking`', '无 diff，不适用']:
        assert word in contract, word
check('C4', '四项改读设计页，降标准五类、阻塞与无 diff 配方齐全', prompt_contract)

def render_lowering():
    data = copy.deepcopy(valid)
    data['verdict'] = 'NO_PASS'
    data['checklist'][-1] = dict(item='lowering', status='weak', note='diff 删除了未获同意的测试')
    data['new_issues'] = [dict(severity='blocking', scope='in', title='未经同意删除测试', evidence='tests.py:8 diff -test_failure', suggestion='恢复测试')]
    p = tmp/'render.json'; p.write_text(json.dumps(data))
    text = run(sys.executable, str(scripts/'render-review.py'), str(p)).stdout
    assert 'lowering（弱）：diff 删除了未获同意的测试' in text and '[阻塞]' in text
check('C4', '现有渲染器完整呈现 lowering 未过项与 blocking', render_lowering)

plan_scene = scene('brief checks')
plan = plan_scene/'plan.md'
design = plan_scene/'design.md'

def brief(expected, marker=''):
    r = subprocess.run([sys.executable, str(scripts/'brief-check.py'), '--plan', str(plan)], capture_output=True, text=True, timeout=120)
    assert r.returncode == expected, (r.returncode, r.stderr)
    assert marker in r.stderr, r.stderr
    return r.stderr

one = '- 案例 A；取校验，不取托管；MIT https://example.com/a\n'
three = one + '- 案例 B；MIT https://example.com/b\n- 案例 C；MIT https://example.com/c\n'

def bad_design():
    for title in ['为什么做', '做完的样子']:
        design.write_text('## ' + title + '\n做一个新系统。\n## 同类方案\n' + one)
        stderr = brief(2, 'design.md：')
        assert '只有 1 条带链接的条目' in stderr
check('C2', '无目标节时两个设计目标节各自触发，一条同类方案拒派', bad_design)

def good_design():
    design.write_text('## 做完的样子\n新系统通过测试。\n## 同类方案\n' + three)
    brief(0)
    design.write_text('## 为什么做\n新系统。\n## 同类方案\n查过：local design gate，无\n')
    brief(0)
    design.write_text('## 为什么做\n修复小缺陷。\n## 这次不做什么\n不做新系统。\n')
    brief(0)
check('C2', '设计页三条案例或查过无放行，只从两个目标节取触发词', good_design)

def legacy_plan():
    design.write_text('## 做完的样子\n新系统。\n## 同类方案\n' + one)
    plan.write_text('## 1 目标与非目标\n维护既有校验。\n- 非目标：新系统。\n')
    brief(0)  # legacy numeric goal takes priority even if design would fail
    plan.write_text('## 1 目标与非目标\n新系统。\n## 3b 同类方案\n' + one)
    stderr = brief(2, '只有 1 条')
    assert 'design.md：' not in stderr
    plan.write_text('## 7 目标\n新系统。\n## 3b 同类方案\n' + three)
    brief(0)
check('C2', '老 plan 有数字目标节时优先查原节，拒派与放行行为不变', legacy_plan)

def no_design():
    plan.write_text('# Plan\n## 10 拆分表\n待派活。\n')
    design.unlink()
    brief(0)
check('C2', '无目标节也无 design.md 时放行', no_design)

def headings():
    text = (scripts.parent/'references/plan-template.md').read_text()
    assert re.findall(r'^## (\d+) ', text, re.M) == ['0', '2', '3', '5', '6', '7', '8', '10', '11', '12']
    assert not re.search(r'^## (1 |3b |4 |9 )', text, re.M)
    assert '目标、做法、同类方案、要问主人的问题都在同目录 design.md' in text
    assert '降标准五查' in text and '§3b 写满' not in text
    assert len((scripts/'brief-check.py').read_text().splitlines()) <= 300
check('C1', 'plan 删重复节且不重排，降标准槽位同步，brief-check 不超过 300 行', headings)
(tmp/'count').write_text(str(count))
PYTEST
COUNT="$(cat "$TMP/count")"
printf 'PASS %d checks\n' "$COUNT"
