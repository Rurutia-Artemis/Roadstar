#!/bin/bash
# 标记分支与真实合并钩子；所有写入限制在临时目录。
set -euo pipefail
unset HISTFILE
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/RSG3-marker-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1
python3 - "$SCRIPTS" "$TMP" <<'PY'
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

scripts = Path(sys.argv[1])
base = Path(sys.argv[2])
guard = scripts / 'guard.py'
plan = 'docs/roadstar/测试场次'
env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_') and not k.startswith('ROADSTAR_')}
env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
           GIT_TERMINAL_PROMPT='0', GIT_EDITOR='true', LC_ALL='C',
           ROADSTAR_CONFIG_DIR=str(base / 'config'))
count = 0
progress = Path(os.environ['ROADSTAR_MARKER_PROGRESS']) if os.environ.get('ROADSTAR_MARKER_PROGRESS') else None
tests = []

def test(description):
    def register(fn):
        tests.append((description, fn))
        return fn
    return register

def run(root, *args, expected=0, extra=None):
    p = subprocess.run([str(a) for a in args], cwd=root, env=dict(env, **(extra or {})),
                       text=True, capture_output=True)
    assert p.returncode == expected, (args, p.returncode, expected, p.stdout, p.stderr)
    return p

def git(root, *args, **kwargs):
    return run(root, 'git', *args, **kwargs)

def call(root, *args, **kwargs):
    return run(root, 'python3', guard, *args, **kwargs)

def write(root, name, body):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding='utf-8')
    return path

def fixture():
    root = Path(subprocess.check_output(['mktemp', '-d', str(base / 'case.XXXXXX')], text=True).strip())
    git(root, 'init', '-q', '--template=')
    git(root, 'symbolic-ref', 'HEAD', 'refs/heads/main')
    git(root, 'config', 'user.name', 'Marker Test')
    git(root, 'config', 'user.email', 'marker@example.invalid')
    write(root, 'readme.md', 'initial\n')
    write(root, plan + '/rounds/exec-T1-request.md', '## 涉及模块\n无地图\n')
    git(root, 'add', '.')
    git(root, 'commit', '-qm', 'initial')
    return root

def passed(description):
    global count
    count += 1
    print('ok %d - %s' % (count, description))
    record(description, 'pass', 'marker-branch-tests ok %d' % count)

def record(description, status, evidence):
    if progress:
        with progress.open('a', encoding='utf-8') as f:
            f.write('%s\t%s\t%s\t%s\n' %
                    (datetime.datetime.now().astimezone().isoformat(), description, status,
                     evidence.replace('\n', '\\n').replace('\t', ' ')))

def topic(root, name='topic', task=False, code=False):
    git(root, 'checkout', '-qb', name)
    write(root, name + ('.py' if code else '.md'), 'value = 1\n' if code else name + '\n')
    git(root, 'add', '.')
    message = 'topic' + ('\n\nRoadstar-Task: ' + plan + '/T1' if task else '')
    git(root, 'commit', '-qm', message)
    git(root, 'checkout', '-q', 'main')

def install(root):
    run(root, 'bash', scripts / 'install-guard.sh', root)

def marker(root):
    return root / '.git/roadstar-task'

def mark_branch(root, branch='topic'):
    git(root, 'checkout', '-q', branch)
    call(root, 'mark', root / plan, 'T1')
    git(root, 'checkout', '-q', 'main')

def legacy(root):
    value = json.loads(marker(root).read_text())
    del value['branch']
    marker(root).write_text(json.dumps(value), encoding='utf-8')

def merge_call(root, entry, ref, **kwargs):
    if entry == 'check-merge':
        return call(root, 'check-merge', ref, **kwargs)
    return call(root, 'hook', 'pre-merge-commit', extra={'GIT_REFLOG_ACTION': 'merge ' + ref}, **kwargs)

@test('C3 真实 --no-ff 钩子顺序与匹配标记作废')
def hook_order():
    # .local 钩子先记现场，再让 wrapper 调 guard；post-merge 记提交完成。
    root = fixture()
    topic(root, task=True, code=True)
    write(root, plan + '/rounds/check-T1.md', '已验收\n')
    mark_branch(root)
    for name in ('pre-merge-commit', 'prepare-commit-msg', 'commit-msg', 'post-merge'):
        suffix = '' if name == 'post-merge' else '.local'
        hook = write(root, '.git/hooks/' + name + suffix,
                     '#!/bin/bash\n'
                     'state=absent; [ ! -f .git/MERGE_HEAD ] || state=present\n'
                     'marker=absent; [ ! -f .git/roadstar-task ] || marker=present\n'
                     'printf "%s\\t%s\\t%s\\t%s\\n" ' + name +
                     ' "$state" "$marker" "$GIT_REFLOG_ACTION" >> .git/hook-order\n')
        hook.chmod(0o755)
    install(root)
    result = git(root, 'merge', '--no-ff', '--no-edit', 'topic')
    assert '警告：' not in result.stderr, result.stderr
    rows = (root / '.git/hook-order').read_text().splitlines()
    assert [row.split('\t')[0] for row in rows] == [
        'pre-merge-commit', 'prepare-commit-msg', 'commit-msg', 'post-merge'], rows
    assert [row.split('\t')[1] for row in rows] == ['absent', 'present', 'present', 'present'], rows
    assert [row.split('\t')[2] for row in rows] == ['present', 'present', 'present', 'absent'], rows
    assert len(git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').stdout.split()) == 3
    assert not marker(root).exists()
    print('钩子顺序实测：' + ' → '.join(rows))

@test('C1 mark 格式保持原四键；匹配时静默、幂等添加 trailer 且标记不变')
def matching_prepare():
    root = fixture()
    call(root, 'mark', root / plan, 'T1')
    data = json.loads(marker(root).read_text())
    assert set(data) == {'plan_dir', 'task', 'branch', 'time'} and data['branch'] == 'main', data
    before = marker(root).read_bytes()
    msg = write(root, '.git/message', 'change\n')
    for _ in range(2):
        p = call(root, 'hook', 'prepare-commit-msg', msg)
        assert p.stdout == p.stderr == '', (p.stdout, p.stderr)
    assert msg.read_text().count('Roadstar-Task: ') == 1
    assert str((root / plan).resolve() / 'T1') in msg.read_text()
    assert marker(root).read_bytes() == before

@test('C1 无标记 prepare 静默且不改消息')
def no_marker_prepare():
    root = fixture()
    msg = write(root, '.git/message', 'change\n')
    before = msg.read_bytes()
    p = call(root, 'hook', 'prepare-commit-msg', msg)
    assert p.stdout == p.stderr == '' and msg.read_bytes() == before

for mode in ('different', 'legacy', 'detached', 'legacy-detached'):
    @test('C1 %s 提示任务、标记分支、当前分支及 mark 命令；消息和标记不变' % mode)
    def mismatching_prepare(mode=mode):
        root = fixture()
        call(root, 'mark', root / plan, 'T1')
        if mode.startswith('legacy'):
            legacy(root)
        if 'detached' in mode:
            git(root, 'checkout', '-q', '--detach')
            current = 'detached HEAD'
        elif mode == 'different':
            git(root, 'checkout', '-qb', 'another')
            current = 'another'
        else:
            current = 'main'
        before = marker(root).read_bytes()
        msg = write(root, '.git/message', 'change\n')
        original = msg.read_bytes()
        p = call(root, 'hook', 'prepare-commit-msg', msg)
        assert p.stdout == '' and len(p.stderr.splitlines()) == 1 and p.stderr.startswith('提示：'), p.stderr
        assert all(part in p.stderr for part in ('T1', current, 'guard.py mark <场次目录> T<n>',
                   '旧格式，没有分支' if mode.startswith('legacy') else 'main')), p.stderr
        assert msg.read_bytes() == original and marker(root).read_bytes() == before

for entry in ('check-merge', 'pre-merge-commit'):
    for target in ('branch', 'sha'):
        @test('C2 %s %s：匹配静默，不匹配提示，均保留标记' % (entry, target))
        def merge_identity(entry=entry, target=target):
            root = fixture()
            topic(root)
            mark_branch(root)
            ref = 'topic' if target == 'branch' else git(root, 'rev-parse', 'topic').stdout.strip()
            before = marker(root).read_bytes()
            p = merge_call(root, entry, ref)
            assert p.stdout == p.stderr == '' and marker(root).read_bytes() == before, p.stderr
            call(root, 'mark', root / plan, 'T1')  # main 标记不属于 topic。
            before = marker(root).read_bytes()
            p = merge_call(root, entry, ref)
            assert p.stdout == '' and len(p.stderr.splitlines()) == 1 and p.stderr.startswith('提示：'), p.stderr
            assert 'T1' in p.stderr and '不属于这次合并，不当作任务标记，需要时重新 mark' in p.stderr
            assert marker(root).read_bytes() == before

    for mode in ('none', 'legacy', 'deleted', 'malformed'):
        @test('C2 %s %s：放行且不改标记，无标记无新输出' % (entry, mode))
        def missing_merge_marker(entry=entry, mode=mode):
            root = fixture()
            topic(root)
            if mode != 'none':
                mark_branch(root)
                if mode == 'legacy':
                    legacy(root)
                elif mode == 'deleted':
                    git(root, 'branch', '-D', 'topic')
                else:
                    marker(root).write_text('{bad', encoding='utf-8')
            ref = 'main' if mode == 'deleted' else 'topic'
            before = marker(root).read_bytes() if marker(root).exists() else None
            p = merge_call(root, entry, ref)
            assert p.stdout == '', p.stdout
            if mode == 'none':
                assert p.stderr == '' and not marker(root).exists(), p.stderr
            else:
                assert p.stderr.startswith('提示：') and len(p.stderr.splitlines()) == 1, p.stderr
                assert marker(root).read_bytes() == before

    @test('C2 %s 不匹配标记仍照常拦缺失验收，补齐后放行' % entry)
    def records_unchanged(entry=entry):
        root = fixture()
        topic(root, task=True)
        call(root, 'mark', root / plan, 'T1')
        before = marker(root).read_bytes()
        p = merge_call(root, entry, 'topic', expected=1)
        assert '提示：' in p.stderr and 'check-T1.md' in p.stderr and '不能合并' in p.stderr, p.stderr
        write(root, plan + '/rounds/check-T1.md', '已验收\n')
        p = merge_call(root, entry, 'topic')
        assert p.stderr.startswith('提示：') and '拦下了' not in p.stderr, p.stderr
        assert marker(root).read_bytes() == before

@test('C2 多目标中有标记分支即匹配，使用提交 SHA 比较')
def multiple_targets():
    root = fixture()
    topic(root)
    mark_branch(root)
    write(root, '.git/MERGE_HEAD', git(root, 'rev-parse', 'main', 'topic').stdout)
    p = call(root, 'hook', 'pre-merge-commit')
    assert p.stdout == p.stderr == '', p.stderr

@test('C3 真合并被 pre-merge-commit 拦下、abort 后标记均原样保留')
def blocked_merge():
    root = fixture()
    topic(root, task=True)
    mark_branch(root)
    before = marker(root).read_bytes()
    head = git(root, 'rev-parse', 'HEAD').stdout
    install(root)
    p = git(root, 'merge', '--no-ff', '--no-edit', 'topic', expected=1)
    assert 'check-T1.md' in p.stderr and '拦下了' in p.stderr, p.stderr
    assert marker(root).read_bytes() == before and git(root, 'rev-parse', 'HEAD').stdout == head
    git(root, 'merge', '--abort')
    assert marker(root).read_bytes() == before and not (root / '.git/MERGE_HEAD').exists()

for mode in ('unrelated', 'legacy', 'none', 'sha'):
    @test('C3 真合并 %s：只清匹配标记，合并无缺 trailer 警告' % mode)
    def real_merge(mode=mode):
        root = fixture()
        topic(root, code=True)
        if mode != 'none':
            mark_branch(root, 'main' if mode == 'unrelated' else 'topic')
            if mode == 'legacy':
                legacy(root)
        before = marker(root).read_bytes() if marker(root).exists() else None
        install(root)
        ref = git(root, 'rev-parse', 'topic').stdout.strip() if mode == 'sha' else 'topic'
        p = git(root, 'merge', '--no-ff', '--no-edit', ref)
        assert '警告：' not in p.stderr, p.stderr
        assert len(git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').stdout.split()) == 3
        if mode in ('none', 'sha'):
            assert not marker(root).exists()
            if mode == 'none':
                assert p.stderr == '', p.stderr
        else:
            assert marker(root).read_bytes() == before
            assert '不属于这次合并' in p.stderr, p.stderr

@test('C3 --no-commit 后 abort 保留标记，重新合并并手动 commit 后作废')
def manual_merge():
    root = fixture()
    topic(root)
    mark_branch(root)
    before = marker(root).read_bytes()
    install(root)
    git(root, 'merge', '--no-ff', '--no-commit', 'topic')
    assert marker(root).read_bytes() == before
    git(root, 'merge', '--abort')
    assert marker(root).read_bytes() == before
    git(root, 'merge', '--no-ff', '--no-commit', 'topic')
    git(root, 'commit', '--no-edit')
    assert not marker(root).exists()

for mode in ('code', 'docs', 'trailer', 'unstaged', 'mixed', 'empty'):
    @test('C4 %s：仅无 trailer 的暂存代码提交打一行警告并放行' % mode)
    def code_warning(mode=mode):
        root = fixture()
        msg = write(root, '.git/message', 'change\n' +
                    ('\nRoadstar-Task: ' + plan + '/T1\n' if mode == 'trailer' else ''))
        if mode != 'empty':
            name = 'readme.md' if mode in ('docs', 'unstaged') else 'src/a "\n name.py'
            write(root, name, 'content\n')
            git(root, 'add', '--', name)
        if mode == 'unstaged':
            write(root, 'unstaged.py', 'content\n')
        if mode == 'mixed':
            write(root, 'readme.md', 'changed\n')
            git(root, 'add', 'readme.md')
        before = msg.read_bytes()
        p = call(root, 'hook', 'commit-msg', msg)
        if mode in ('code', 'mixed'):
            assert p.stderr.startswith('警告：') and len(p.stderr.splitlines()) == 1, p.stderr
            assert 'Roadstar-Task' in p.stderr, p.stderr
        else:
            assert p.stderr == '', p.stderr
        assert msg.read_bytes() == before and not marker(root).exists()

@test('C4 guard_rules.CODE 每个后缀均产生缺 trailer 警告，非代码不误报')
def code_suffixes():
    sys.path.insert(0, str(scripts))
    import guard_rules
    root = fixture()
    msg = write(root, '.git/message', 'change\n')
    for suffix in sorted(guard_rules.CODE):
        git(root, 'reset', '-q')
        write(root, 'file' + suffix, 'content\n')
        git(root, 'add', '--', 'file' + suffix)
        p = call(root, 'hook', 'commit-msg', msg)
        assert p.stderr.startswith('警告：') and len(p.stderr.splitlines()) == 1, (suffix, p.stderr)
    git(root, 'reset', '-q')
    for suffix in ('.md', '.txt', '.json'):
        write(root, 'file' + suffix, 'content\n')
        git(root, 'add', '--', 'file' + suffix)
    assert call(root, 'hook', 'commit-msg', msg).stderr == ''

@test('C4 安装真钩子后无标记代码提交告警但成功，带 mark 无缺 trailer 警告')
def real_code_commit():
    root = fixture()
    install(root)
    write(root, 'code.py', 'value = 1\n')
    git(root, 'add', 'code.py')
    p = git(root, 'commit', '-qm', 'unmarked code')
    assert p.stderr.startswith('警告：') and len(p.stderr.splitlines()) == 1, p.stderr
    call(root, 'mark', root / plan, 'T1')
    before = marker(root).read_bytes()
    write(root, 'code.py', 'value = 2\n')
    git(root, 'add', 'code.py')
    p = git(root, 'commit', '-qm', 'marked code')
    assert p.stderr == '这个项目没有模块地图，范围检查跳过\n', p.stderr
    assert marker(root).read_bytes() == before
    assert 'Roadstar-Task: ' in git(root, 'log', '-1', '--format=%B').stdout

for target in ('branch', 'sha'):
    @test('T3d %s 正常合并全过程没有提示行，匹配标记仍作废' % target)
    def merge_without_branch_notice(target=target):
        root = fixture()
        topic(root, task=True, code=True)
        write(root, plan + '/rounds/check-T1.md', '已验收\n')
        mark_branch(root)
        install(root)
        ref = 'topic' if target == 'branch' else git(root, 'rev-parse', 'topic').stdout.strip()
        p = git(root, 'merge', '--no-ff', '--no-edit', ref)
        assert not any(line.startswith('提示：') for line in p.stderr.splitlines()), p.stderr
        assert not marker(root).exists()
        assert len(git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').stdout.split()) == 3

    @test('T3d %s 无关分支标记只提示一次不属于本次合并，标记保留' % target)
    def unrelated_merge_notice_once(target=target):
        root = fixture()
        topic(root, task=True, code=True)
        topic(root, name='other')
        write(root, plan + '/rounds/check-T1.md', '已验收\n')
        mark_branch(root, 'other')
        before = marker(root).read_bytes()
        install(root)
        ref = 'topic' if target == 'branch' else git(root, 'rev-parse', 'topic').stdout.strip()
        p = git(root, 'merge', '--no-ff', '--no-edit', ref)
        hints = [line for line in p.stderr.splitlines() if line.startswith('提示：')]
        assert len(hints) == 1 and '不属于这次合并' in hints[0], p.stderr
        assert p.stderr.count('不属于这次合并') == 1, p.stderr
        assert '当前分支为' not in p.stderr, p.stderr
        assert marker(root).read_bytes() == before
        assert len(git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').stdout.split()) == 3

for description, fn in tests:
    try:
        fn()
    except Exception as exc:
        record(description, 'fail', repr(exc))
        raise
    passed(description)

print('PASS %d checks' % count)
PY
