#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-baseline-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export ROADSTAR_CONFIG_DIR="$TMP/config"
# 从 run.sh 搬出的旧 registry 冒烟检查，仍由全量套件执行。
python3 "$SCRIPTS/providers-check.py" > "$TMP/providers.txt"
grep -q '合法' "$TMP/providers.txt"
python3 - "$SCRIPTS" "$TMP" <<'PY'
import contextlib
import importlib.util
import io
import json
import os
import select
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch

scripts, tmp = map(Path, sys.argv[1:])
sys.path.insert(0, str(scripts))
import baselines as b
import skiplog as s
count = 0

def passed(name):
    global count
    count += 1
    print(f'ok {count} - {name}', flush=True)

def error(name):
    try:
        b.load(name)
    except b.BaselineError as exc:
        assert exc.path == b.path(name)
    else:
        raise AssertionError(f'{name} did not raise BaselineError')

passed('迁移旧 providers-check 合法性检查')
with patch.dict(os.environ, {'TEST_SKIP': '0'}):
    assert s.record('test', 'TEST_SKIP') is True
    assert s.skipped('test', 'TEST_SKIP') is True
    assert len(s.log_path().read_text().splitlines()) == 2
    for operation in ('mkdir', 'open'):
        out = io.StringIO()
        with patch.object(Path, operation, side_effect=PermissionError('readonly')), contextlib.redirect_stderr(out):
            assert s.record('test', 'TEST_SKIP') is False
            assert s.skipped('test', 'TEST_SKIP') is False
        assert '记账失败，不跳过，照常检查' in out.getvalue()
    for operation in ('write', '__exit__'):
        handle = contextlib.nullcontext()
        from unittest.mock import MagicMock
        handle = MagicMock()
        handle.__enter__.return_value = handle
        getattr(handle, operation).side_effect = OSError('disk failure')
        with patch.object(Path, 'open', return_value=handle), contextlib.redirect_stderr(io.StringIO()):
            assert s.skipped('test', 'TEST_SKIP') is False
passed('R1 record/skipped 仅落账成功才跳过，mkdir/open/write/close 失败照查')
blocked = tmp / 'not-a-directory'
blocked.write_text('blocked')
result = subprocess.run([sys.executable, scripts / 'skiplog.py', 'test', 'TEST_SKIP'],
                        env={**os.environ, 'TEST_SKIP': '0', 'ROADSTAR_CONFIG_DIR': str(blocked)},
                        capture_output=True, text=True, timeout=10)
assert result.returncode == 1 and '记账失败，不跳过，照常检查' in result.stderr
passed('R1 CLI 记账失败退出 1')
assert b.load('missing') == {}
b.ratchet('serial', '/p', 7)
assert b.ratchet('serial', '/p', 5) == b.ratchet('serial', '/p', 6) == 5
with patch.object(b, 'load', wraps=b.load) as load:
    b.ratchet('serial', '/p', 4)
    assert load.call_count == 1
passed('R2 ratchet 只降不升且只读取一份快照')

# A 在 save 前暂停（锁必须仍持有）；B 已开始，再让 A 写 5、B 尝试写 6。
# B 若抢读到旧值 7，最后就会写回 6。使用独立解释器验证真实 flock。
worker = r'''
import os, sys
sys.path.insert(0, sys.argv[1])
import baselines as b
role = sys.argv[2]
load, save = b.load, b.save
paused = False
def delayed_load(name):
    global paused
    data = load(name)
    if role == 'B' and not paused:
        paused = True
        print('loaded', flush=True)
        assert sys.stdin.readline().strip() == 'go'
    return data
def delayed_save(name, data):
    if role == 'A':
        print('saving', flush=True)
        assert sys.stdin.readline().strip() == 'go'
    save(name, data)
b.load, b.save = delayed_load, delayed_save
print('started', flush=True)
print(b.ratchet(sys.argv[3], '/p', int(sys.argv[4])), flush=True)
'''
b.ratchet('concurrent', '/p', 7)
children = []
try:
    for role, value in (('A', 5), ('B', 6)):
        child = subprocess.Popen([sys.executable, '-u', '-c', worker, str(scripts), role, 'concurrent', str(value)],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        children.append(child)
        assert child.stdout.readline().strip() == 'started'
        if role == 'A':
            assert child.stdout.readline().strip() == 'saving'
    a, z = children
    assert not select.select([z.stdout], [], [], 0.2)[0], 'B 在 A 释放锁前读取了快照'
    a.stdin.write('go\n'); a.stdin.flush()
    out_a, err_a = a.communicate(timeout=10)
    assert a.returncode == 0 and out_a.strip() == '5', (out_a, err_a)
    assert z.stdout.readline().strip() == 'loaded'
    out_b, err_b = z.communicate('go\n', timeout=10)
    assert z.returncode == 0 and out_b.strip() == '5', (out_b, err_b)
    assert b.get('concurrent', '/p') == 5
    assert b.path('concurrent').with_suffix('.json.lock').is_file()
finally:
    for child in children:
        if child.poll() is None:
            child.kill()
        child.communicate()
passed('R2 双进程交错 ratchet 7→5 / 7→6 最终为 5')

# 每一种读改写都必须持锁；add/mark_since 保留其他键。
import fcntl
for operation in (lambda: b.add('locked', ['/a', '/b']), lambda: b.mark_since('locked')):
    original = b.load
    def locked_load(name):
        with b.path(name).with_suffix('.json.lock').open('a') as other:
            try:
                fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                pass
            else:
                raise AssertionError('read-modify-write is not locked')
        return original(name)
    with patch.object(b, 'load', locked_load):
        operation()
assert b.listed('locked', '/a') and b.listed('locked', '/b') and b.since('locked') > 0
passed('R2 add/mark_since 在锁内读取且不丢其他键')
for i, text in enumerate(('{broken', '[]', '{"/p": 7}', '{"/p": {"value": 7}}',
                          '{"/p": {"value": "seven", "updated": "now"}}')):
    name = 'uncommitted'
    b.path(name).write_text(text)
    error(name)
with patch.object(Path, 'read_text', side_effect=PermissionError('readonly')):
    error('uncommitted')
link = b.path('broken-link')
link.symlink_to(tmp / 'missing-target')
error('broken-link')
b.path('legacy-since').write_text('{"_since": {"value": 1}}')
assert b.since('legacy-since') == 1
passed('R3 损坏 JSON/结构/值、不可读和断链均抛 BaselineError；仅缺文件返回空')

# 实际 gate CLI 使用本地 checker，不触碰项目或真实配置。
root, shell = tmp / 'RuruCode/p', tmp / 'shell'
root.mkdir(parents=True); shell.mkdir()
(shell / 'check.py').write_text('print(\'{"structural_gaps": [], "open_tasks": []}\')')
target = b.path('open-tasks')
target.write_text('{broken')
result = subprocess.run([sys.executable, scripts / 'entry-check.py', 'gate', root],
                        env={**os.environ, 'RURUCODE_ROOT': str(root.parent), 'PROJECT_SHELL_DIR': str(shell)},
                        capture_output=True, text=True, timeout=10)
assert result.returncode == 3, result
assert f'基线文件坏了：{target}，先修好或删掉再派（删掉等于按现状重记）' in result.stderr
assert target.read_text() == '{broken'
passed('R3 gate 坏基线退出 3，输出修复提示且不覆盖原文件')
print(f'PASS {count} checks')
PY
