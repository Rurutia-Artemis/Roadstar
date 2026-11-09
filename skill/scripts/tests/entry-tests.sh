#!/usr/bin/env bash
# --legacy-exec 由主套件原位置 source；原测试块逐字搬出，沿用调用方夹具。
if [[ "${1:-}" == --legacy-exec ]]; then
# dex-exec.sh --est-minutes / --strategy land in meta, including the detached worker.
run_task T30 --class 页面实现 --est-minutes 25 --strategy quality > "$TMP/est.txt"
grep -q '^est_minutes=25$' "$PLAN/rounds/exec-T30.meta" && grep -q '^strategy=quality$' "$PLAN/rounds/exec-T30.meta"
! grep -q '^est_minutes=' "$PLAN/rounds/exec-T20.meta"
expect_exit 2 run_task T31 --est-minutes 0
expect_exit 2 run_task T31 --est-minutes abc
expect_exit 2 run_task T31 --strategy fastest
[[ ! -f "$PLAN/rounds/exec-T31.meta" ]]
run_task T32 --detach --est-minutes 40 --strategy rush > /dev/null
wait_done "$PLAN/rounds/exec-T32.exit"
grep -q '^est_minutes=40$' "$PLAN/rounds/exec-T32.meta" && grep -q '^strategy=rush$' "$PLAN/rounds/exec-T32.meta"
bash "$SCRIPTS/dex-exec.sh" --help | grep -q -- '--est-minutes'
pass 'exec --est-minutes and --strategy write meta (foreground and detached), reject bad values before dispatch, documented in help'

return 0
fi
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
export PATH="$TEST_DIR/bin:$PATH"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-entry-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'echo "FAIL: entry line $LINENO" >&2' ERR
export ROADSTAR_CONFIG_DIR="$TMP/legacy-config"
export RURUCODE_ROOT="$TMP/RuruCode"
export PROJECT_SHELL_DIR="$TMP/missing-shell"
export WS_GUARD_DIR="$TMP/no-ws-guard"
export FAKE_TRACE_FILE="$TMP/trace.jsonl"
unset FAKE_CODEX_USED FAKE_CODEX_DELAY FAKE_CODEX_EXIT FAKE_CODEX_REPORT FAKE_CODEX_REPLY
unset ROADSTAR_PROJECT_CHECK ROADSTAR_OPEN_CHECK ROADSTAR_DIRTY_CHECK
export ROADSTAR_DIRTY_STALE_HOURS=0  # 旧用例按「立刻算积压」写；24 小时口径单测见末尾
PLAN="$TMP/legacy-plan"
mkdir -p "$PLAN"
BRIEF="$PLAN/brief.md"
printf '%s\n' '# T1' '## 目标与做完的样子' '完成线：桩通过。' '## 涉及模块' 'tests' '## 不许动什么' '仓库外' '## 执行环境' 'stub' '## 验收命令与期望输出' 'true 期望退出 0' '## 资源上限与止损' '预计 5 分钟，上限 10 分钟' > "$BRIEF"
COUNT=0
pass() { COUNT=$((COUNT + 1)); printf 'ok %d - %s\n' "$COUNT" "$1"; }
expect_exit() {
  local expected="$1" actual=0
  shift
  "$@" > "$TMP/last-output" 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then cat "$TMP/last-output" >&2; return 1; fi
}
wait_done() {
  local i
  for ((i=0; i<100; i++)); do
    [[ -f "$1" ]] && return 0
    sleep 0.1
  done
  return 1
}
run_task() { bash "$SCRIPTS/dex-exec.sh" "$PLAN" "$1" --model gpt-6-astra --effort high --brief "$BRIEF" "${@:2}"; }
run_task T20 > /dev/null
source "$TEST_DIR/entry-tests.sh" --legacy-exec
python3 - "$SCRIPTS" "$TMP" "$BRIEF" "$COUNT" <<'PYTEST'
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from unittest.mock import patch

scripts, tmp, brief = (Path(value).resolve() for value in sys.argv[1:4])
count = int(sys.argv[4])
sys.path.insert(0, str(scripts))
import baselines
spec = importlib.util.spec_from_file_location('entry_check', scripts / 'entry-check.py')
entry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)
progress = Path(os.environ['ROADSTAR_ENTRY_PROGRESS']) if os.environ.get('ROADSTAR_ENTRY_PROGRESS') else None
if progress: progress.parent.mkdir(parents=True, exist_ok=True)  # 不设就不写进度（验收建议：别往真实场次追加）

class Check:
    def __init__(self, name):
        self.name = name
    def __enter__(self):
        return self
    def __exit__(self, kind, value, trace):
        global count
        from datetime import datetime
        state = 'fail' if kind else 'pass'
        evidence = str(value).replace('\n', ' ') if kind else self.name
        if progress:
            with progress.open('a') as out:
                out.write(f'{datetime.now().astimezone().isoformat()}\t{self.name}\t{state}\t{evidence}\n')
        if kind is None:
            count += 1
            print(f'ok {count} - {self.name}', flush=True)

base = tmp / 'RuruCode'
base.mkdir()
shell = tmp / 'project-shell'
shell.mkdir()
data_file, check_trace = tmp / 'check-data.json', tmp / 'check-trace.jsonl'
(shell / 'check.py').write_text('''import json, os, sys
from pathlib import Path
with open(os.environ['ENTRY_CHECK_TRACE'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
print(Path(os.environ['ENTRY_CHECK_DATA']).read_text())
''')
env = {**os.environ, 'PROJECT_SHELL_DIR': str(shell),
       'ENTRY_CHECK_DATA': str(data_file), 'ENTRY_CHECK_TRACE': str(check_trace),
       'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull,
       'GIT_AUTHOR_NAME': 'Entry Test', 'GIT_AUTHOR_EMAIL': 'test@example.invalid',
       'GIT_COMMITTER_NAME': 'Entry Test', 'GIT_COMMITTER_EMAIL': 'test@example.invalid'}
for switch in ('ROADSTAR_PROJECT_CHECK', 'ROADSTAR_OPEN_CHECK', 'ROADSTAR_DIRTY_CHECK'):
    env.pop(switch, None)

def run(args, code=0, extra=None):
    result = subprocess.run(list(map(str, args)), env={**env, **(extra or {})},
                            capture_output=True, text=True, timeout=20)
    assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
    return result

def git(root, *args):
    return run(['git', '-C', root, *args]).stdout

def fixture(name, repo=False):
    root = base / name
    root.mkdir()
    env['ROADSTAR_CONFIG_DIR'] = str(tmp / ('config-' + name))
    data_file.write_text(json.dumps({'structural_gaps': [], 'open_tasks': []}))
    if repo:
        git(root, 'init', '-q')
    return root

def gate(root, code=0, dry=False, extra=None):
    return run([sys.executable, scripts / 'entry-check.py', 'gate', root] +
               (['--dry-run'] if dry else []), code, extra)

def dispatch(root, task='T1', code=0, extra=None, flags=('--write', '--dry-run'), brief_path=None):
    plan = root / 'docs/roadstar/new'
    plan.mkdir(parents=True, exist_ok=True)
    return run(['bash', scripts / 'dex-exec.sh', plan, task, '--model', 'gpt-6.1-sol',
                '--effort', 'high', '--class', '取证', '--brief', brief_path or brief,
                '--root', root, '--max-minutes', '1', *flags], code, extra)

def set_baseline(name, root, value):
    run([sys.executable, '-c', 'import sys; sys.path.insert(0, sys.argv[1]); import baselines; '
         'baselines.ratchet(sys.argv[2], sys.argv[3], int(sys.argv[4]))', scripts, name, root, value])

def get_baseline(name, root):
    file = Path(env['ROADSTAR_CONFIG_DIR']) / 'baselines' / (name + '.json')
    return json.loads(file.read_text())[str(root)]['value']

def tasks(root, n, running=()):
    items = []
    for i in range(1, n + 1):
        rounds = root / 'docs/roadstar/old/rounds'
        rounds.mkdir(parents=True, exist_ok=True)
        req = rounds / f'exec-T{i}-request.md'
        req.write_text('old request')
        modified = time.time() - 172800 + i
        if i in running:
            modified = time.time()
        os.utime(req, (modified, modified))
        items.append(f'old/T{i}')
    data_file.write_text(json.dumps({'structural_gaps': [], 'open_tasks': items}))

with Check('C1/C2 接入缺口拒派且无请求副本/CLI 调用'):
    root = fixture('gaps')
    data_file.write_text(json.dumps({'structural_gaps': ['没有 docs/模块地图.md', '没有 CLAUDE.md'], 'open_tasks': []}))
    Path(env['FAKE_TRACE_FILE']).write_text('')
    out = dispatch(root, code=3)
    assert '没有 docs/模块地图.md；没有 CLAUDE.md' in out.stderr
    assert not (root / 'docs/roadstar/new/rounds/exec-T1-request.md').exists()
    assert not Path(env['FAKE_TRACE_FILE']).read_text()
with Check('C2 写模式 resume 同样拒派'):
    out = dispatch(root, code=3, flags=('--write', '--resume', 'old-session', '--dry-run'))
    assert '拒派' in out.stderr
with Check('C1 ROADSTAR_PROJECT_CHECK=0 放行且只记一行'):
    dispatch(root, extra={'ROADSTAR_PROJECT_CHECK': '0'})
    lines = (Path(env['ROADSTAR_CONFIG_DIR']) / 'skip-log.tsv').read_text().splitlines()
    assert len(lines) == 1 and '\t接入检查\tROADSTAR_PROJECT_CHECK\t' in lines[0]
with Check('C1/C2 接入齐全放行且 dry-run 不建基线'):
    root = fixture('ready')
    dispatch(root)
    assert not Path(env['ROADSTAR_CONFIG_DIR']).exists()
with Check('C1 RuruCode 外跳过且不调用 check.py'):
    outside = tmp / 'outside'
    outside.mkdir()
    before = check_trace.read_bytes()
    assert '不在 RuruCode 项目里，跳过接入和存量检查' in gate(outside).stderr
    assert check_trace.read_bytes() == before
with Check('C1 AI任务 下跳过且不调用 check.py'):
    ai = base / 'AI任务/project'
    ai.mkdir(parents=True)
    before = check_trace.read_bytes()
    assert '跳过接入和存量检查' in gate(ai).stderr
    assert check_trace.read_bytes() == before
with Check('C1 check.py 缺失警告放行'):
    assert '找不到 check.py' in dispatch(root, extra={'PROJECT_SHELL_DIR': str(tmp / 'missing')}).stderr
with Check('C1 没有 structural_gaps 警告放行'):
    data_file.write_text('{"open_tasks": []}')
    assert 'JSON 没有 structural_gaps 字段' in dispatch(root).stderr
with Check('C1 非 JSON 警告放行'):
    data_file.write_text('not json')
    assert '警告' in gate(root).stderr
with Check('C1 check.py 超时警告放行（本地 mock）'):
    with patch.dict(os.environ, env), patch.object(entry.subprocess, 'run', side_effect=subprocess.TimeoutExpired('check.py', 60)):
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            assert entry.project_data(root) is None
        assert '超时（60 秒）' in stderr.getvalue()
with Check('C1 存量超过五件拒派并按旧到新只列十件'):
    root = fixture('open-limit')
    tasks(root, 12)
    set_baseline('open-tasks', root, 0)
    out = dispatch(root, code=3)
    assert '有 12 件活做完了还没验收（上限 5）' in out.stderr
    assert out.stderr.index('old/T1；') < out.stderr.index('old/T2；')
    assert 'old/T10' in out.stderr and 'old/T11' not in out.stderr
with Check('C1 在跑的无 exit 且近期请求不计，旧无 exit 仍计'):
    tasks(root, 12, running=range(2, 13))
    gate(root)
    assert get_baseline('open-tasks', root) == 0
with Check('C1 近期但有 exit 的任务仍计入存量'):
    for i in range(2, 13):
        (root / f'docs/roadstar/old/rounds/exec-T{i}.exit').write_text('0\n')
    assert '有 12 件' in gate(root, code=3).stderr
with Check('C1 ROADSTAR_OPEN_CHECK=0 放行且记账'):
    gate(root, extra={'ROADSTAR_OPEN_CHECK': '0'})
    assert '\t存量检查\tROADSTAR_OPEN_CHECK\t' in (Path(env['ROADSTAR_CONFIG_DIR']) / 'skip-log.tsv').read_text()
with Check('C1 初始七件记七，六件降六，再八件拒派且基线仍六'):
    root = fixture('ratchet')
    tasks(root, 7)
    gate(root)
    assert get_baseline('open-tasks', root) == 7
    tasks(root, 6)
    gate(root)
    assert get_baseline('open-tasks', root) == 6
    tasks(root, 8)
    assert '上限 6' in gate(root, code=3).stderr
    assert get_baseline('open-tasks', root) == 6
with Check('C1 dry-run 通过也不降低现有基线'):
    tasks(root, 2)
    gate(root, dry=True)
    assert get_baseline('open-tasks', root) == 6
with Check('C1 未提交超过十件拒派并最多列十个路径'):
    root = fixture('dirty-limit', repo=True)
    for i in range(12):
        (root / f'f{i:02}.txt').write_text('dirty')
    set_baseline('uncommitted', root, 0)
    out = dispatch(root, code=3)
    assert '主目录有 12 个没提交的文件（上限 10，不含 docs/roadstar/，只算 24 小时没动过的）' in out.stderr
    assert 'f09.txt' in out.stderr and 'f10.txt' not in out.stderr
with Check('C1 ROADSTAR_DIRTY_CHECK=0 放行且记账'):
    dispatch(root, extra={'ROADSTAR_DIRTY_CHECK': '0'})
    assert '\t未提交检查\tROADSTAR_DIRTY_CHECK\t' in (Path(env['ROADSTAR_CONFIG_DIR']) / 'skip-log.tsv').read_text()
with Check('C1 docs/roadstar 下新增/修改/重命名都不计，中文带空格路径计数'):
    root = fixture('dirty-docs', repo=True)
    docs = root / 'docs/roadstar/session'
    docs.mkdir(parents=True)
    (docs / 'tracked.md').write_text('initial')
    git(root, 'add', '.')
    git(root, 'commit', '-qm', 'fixture')
    git(root, 'mv', 'docs/roadstar/session/tracked.md', 'docs/roadstar/session/renamed.md')
    (docs / 'new.md').write_text('new')
    set_baseline('uncommitted', root, 0)
    gate(root)
    assert get_baseline('uncommitted', root) == 0
    for i in range(11):
        (root / f'中文 文件{i}.md').write_text('dirty')
    assert '主目录有 11 个' in gate(root, code=3).stderr
with Check('C1 未提交基线初始十二、降十一、十三拒派'):
    root = fixture('dirty-ratchet', repo=True)
    for i in range(12):
        (root / f'f{i}').write_text('x')
    gate(root)
    assert get_baseline('uncommitted', root) == 12
    (root / 'f11').unlink()
    gate(root)
    assert get_baseline('uncommitted', root) == 11
    (root / 'f11').write_text('x')
    (root / 'f12').write_text('x')
    assert '上限 11' in gate(root, code=3).stderr
    assert get_baseline('uncommitted', root) == 11
with Check('C2 只读派活三卡都不跑（真实桩派发）'):
    data_file.write_text(json.dumps({'structural_gaps': ['缺地图'], 'open_tasks': ['old/T1'] * 20}))
    before = check_trace.read_bytes()
    dispatch(root, flags=())
    assert check_trace.read_bytes() == before
    assert (root / 'docs/roadstar/new/rounds/exec-T1.meta').exists()
with Check('C1 未提交只算 24 小时没动过的：新改的不计、旧的计'):
    root = fixture('dirty-stale', repo=True)
    for i in range(12):
        (root / f'n{i:02}.txt').write_text('dirty')
    os.environ['ROADSTAR_DIRTY_STALE_HOURS'] = '24'
    try:
        assert len(entry.dirty(root)) == 0
        old = time.time() - 25 * 3600
        for i in range(3):
            os.utime(root / f'n{i:02}.txt', (old, old))
        assert len(entry.dirty(root)) == 3
    finally:
        os.environ['ROADSTAR_DIRTY_STALE_HOURS'] = '0'

with Check('C1 worktree 一律读取主目录接入/存量/未提交'):
    root = fixture('main-root', repo=True)
    git(root, 'commit', '--allow-empty', '-qm', 'fixture')
    slot = base / 'slot'
    git(root, 'worktree', 'add', '-qb', 'slot', slot)
    tasks(root, 6)
    set_baseline('open-tasks', root, 0)
    assert '拒派：main-root' in gate(slot, code=3).stderr
    assert json.loads(check_trace.read_text().splitlines()[-1])[0] == str(root)
    data_file.write_text('{"structural_gaps": [], "open_tasks": []}')
    for i in range(11):
        (root / f'dirty{i}').write_text('x')
    set_baseline('uncommitted', root, 0)
    assert '主目录有 11 个' in gate(slot, code=3).stderr
with Check('C1 baseline-init dry-run 去重/跳不存在与界外，完全不写文件'):
    config = Path(env['ROADSTAR_CONFIG_DIR'])
    config.mkdir(exist_ok=True)
    registry = config / 'projects.txt'
    registry.write_text('\n'.join(map(str, (root, slot, root, outside, base / 'missing', ai))))
    def snapshot():
        return {str(p.relative_to(config)): (p.read_bytes(), p.stat().st_mtime_ns)
                for p in config.rglob('*') if p.is_file()}
    before = snapshot()
    out = run([sys.executable, scripts / 'entry-check.py', 'baseline-init', '--dry-run'])
    assert out.stdout.splitlines() == [f'{root}\t0\t0\t11\t0']
    assert snapshot() == before
with Check('C1 baseline-init 实写两份共用基线，旧 check 无 structural 字段也能初始化'):
    data_file.write_text('{"open_tasks": []}')
    run([sys.executable, scripts / 'entry-check.py', 'baseline-init'])
    assert get_baseline('open-tasks', root) == get_baseline('uncommitted', root) == 0
with Check('C1 show 打印两份基线、参数错退出二'):
    out = run([sys.executable, scripts / 'entry-check.py', 'show'])
    assert f'open-tasks\t{root}\t0\t' in out.stdout
    assert f'uncommitted\t{root}\t0\t' in out.stdout
    run([sys.executable, scripts / 'entry-check.py', 'gate'], code=2)
with Check('C6 首次标准路径任务书复用，attempt=1 且无 r2；再次派发仍递增'):
    root = fixture('first-request')
    req = root / 'docs/roadstar/new/rounds/exec-T1-request.md'
    req.parent.mkdir(parents=True)
    req.write_bytes(brief.read_bytes())
    mtime = req.stat().st_mtime_ns
    alias = tmp / 'brief-alias.md'
    alias.symlink_to(req)
    dispatch(root, flags=('--write',), brief_path=alias)
    meta = req.with_name('exec-T1.meta')
    assert 'attempt=1\n' in meta.read_text()
    assert not req.with_name('exec-T1-request-r2.md').exists()
    assert req.stat().st_mtime_ns == mtime
    dispatch(root, flags=('--write',), brief_path=req)
    assert 'attempt=2\n' in meta.read_text()
    assert req.with_name('exec-T1-request-r2.md').read_bytes() == req.read_bytes()
with Check('C6 统计历史同内容 r2 算首次，不同内容/缺快照/r3 仍返工'):
    stats = tmp / 'stats/rounds'
    stats.mkdir(parents=True)
    for i, attempt in enumerate((2, 2, 2, 3, 1)):
        (stats / f'exec-T{i}.meta').write_text(f'session_id=stats{i}\nclass=取证\nmodel=gpt-6.1-sol\neffort=high\nattempt={attempt}\n')
        if i != 2:
            (stats / f'exec-T{i}-request.md').write_bytes(b'one\r\n')
            (stats / f'exec-T{i}-request-r2.md').write_bytes(b'one\n' if i == 1 else b'one\r\n')
    out = run([sys.executable, scripts / 'dispatch-stats.py', stats.parent, '--json'])
    group = json.loads(out.stdout)['groups'][0]
    assert group['count'] == 5 and group['rework_count'] == 3 and group['rework_rate'] == 0.6
with Check('C2 帮助明确三卡及退出码'):
    out = run(['bash', scripts / 'dex-exec.sh', '--help'])
    assert '未验收存量和未提交基线' in out.stdout and '退出 3' in out.stdout
print(f'PASS {count} checks', flush=True)
PYTEST
