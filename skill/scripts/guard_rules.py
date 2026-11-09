#!/usr/bin/env python3
"""提交行数、合并降标准与可选设计命令；只使用标准库。"""
from contextlib import redirect_stderr
import fnmatch
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import baselines
import skiplog

CODE = set('.py .ts .tsx .js .jsx .mjs .cjs .swift .go .rs .kt .java .vue .svelte .css .scss .html .sh .rb .php .m .mm .c .h .cpp .cs .dart .lua'.split())
GENERATED = set('vendor third_party node_modules dist build .build Pods Carthage DerivedData generated __generated__'.split())
CONFIG = ('.eslintrc*', 'eslint.config.*', '.prettierrc*', 'tsconfig*.json', 'jest.config.*', 'vitest.config.*', 'playwright.config.*', 'pytest.ini', 'tox.ini', 'setup.cfg', '.coveragerc', 'ruff.toml', '.ruff.toml', 'mypy.ini', '.flake8', '.pylintrc', '.swiftlint.yml', '.pre-commit-config.yaml')
CATEGORIES = ('下调门槛', '跳过或删测试', '关掉检查', '留桩或半成品', '新增例外 / 改检查配置')
SKIP = re.compile(r'\.skip\(|\bit\.skip\b|\bdescribe\.skip\b|\btest\.skip\b|\bx(?:it|describe|test)\(|\.only\(|@pytest\.mark\.skip|pytest\.skip\(|@unittest\.skip|skipTest\(|XCTSkip|t\.Skip\(|#\[ignore\]')
DISABLE = re.compile(r'@ts-ignore|@ts-nocheck|@ts-expect-error|eslint-disable|# noqa|type: ignore|pylint: disable|istanbul ignore|c8 ignore|nosemgrep|gitleaks:allow|swiftlint:disable|nolint|@SuppressWarnings|--no-verify')
STUB = re.compile(r'TODO|FIXME|XXX|NotImplementedError|fatalError\(|unimplemented!|todo!\(|not implemented', re.I)
ASSERT = re.compile(r'assert|XCTAssert|expect\(')
NUMBER = re.compile(r'''["']?([\w.-]+)["']?\s*(?::|=|\s)\s*(-?\d+(?:\.\d+)?)''')
TOOLS = re.compile(r'^\s*\[tool\.(?:ruff[^\]]*|pytest[^\]]*|mypy[^\]]*|coverage[^\]]*|pylint[^\]]*|black|isort)\]\s*(?:#.*)?$')


def git(root, *args, optional=False, data=None):
    p = subprocess.run(['git', '-C', str(root), *args], input=data, text=True,
                       encoding='utf-8', errors='surrogateescape', capture_output=True)
    if p.returncode and not optional:
        raise ValueError('git ' + ' '.join(args) + '：' + p.stderr.strip())
    return None if p.returncode else p.stdout


def config(root, revision=':', fallback='HEAD'):
    for rev in dict.fromkeys((revision, fallback)):
        body = git(root, 'show', (rev.rstrip(':') + ':') + '.roadstar/guard.json', optional=True)
        if body is not None:
            break
    else:
        path = root / '.roadstar/guard.json'
        body = path.read_text(encoding='utf-8') if path.is_file() else '{}'
    value = json.loads(body)
    if not isinstance(value, dict):
        raise ValueError('.roadstar/guard.json 必须是 JSON 对象')
    return value


def changes(root, old, new=None):
    args = ['diff', '-M', '--name-status', '-z']
    args += ['--cached'] if new is None else [old, new]
    fields = iter(git(root, *args, '--').split('\0'))
    for status in fields:
        if not status:
            break
        before = after = next(fields)
        if status.startswith(('R', 'C')):
            after = next(fields)
        yield status, before, after


def exempt(path, settings):
    p = Path(path)
    patterns = settings.get('length_exempt', [])
    if not isinstance(patterns, list) or any(not isinstance(v, str) for v in patterns):
        raise ValueError('length_exempt 必须是 glob 字符串列表')
    return (p.suffix not in CODE or bool(set(p.parts[:-1]) & GENERATED)
            or any(fnmatch.fnmatchcase(p.name, pat) for pat in ('*.min.*', '*.pb.*', '*_pb2.py', '*.generated.*'))
            or any(fnmatch.fnmatchcase(path, pat) for pat in patterns))


def length_changes(root, old='HEAD', new=None):
    settings = config(root, new or ':', old)
    problems = []
    for status, before, after in changes(root, old, new):
        if status == 'D' or exempt(after, settings):
            continue
        body = git(root, 'show', (new or '') + ':' + after, optional=True)
        if body is None:
            continue
        previous = None if status == 'A' else git(root, 'show', old + ':' + before, optional=True)
        size, original = len(body.splitlines()), len((previous or '').splitlines())
        if size > 800 and size > original:
            problems.append(f'{after} {size}（原 {original}）')
    return problems


def length_problems(root, message):
    if skiplog.skipped('行数检查', 'ROADSTAR_LENGTH_CHECK', root):
        return [], None
    problems = length_changes(root)
    parsed = git(root, 'interpret-trailers', '--parse', data=message)
    reasons = [line.partition(':')[2].strip() for line in parsed.splitlines()
               if line.partition(':')[0].lower() == 'roadstar-length']
    reason = next((v for v in reasons if v), None) if problems else None
    return ([], reason) if reason else (problems, None)


def test_file(path):
    return (any(part in path for part in ('tests/', 'test/', '__tests__/', 'UITests/'))
            or any(fnmatch.fnmatchcase(Path(path).name, p) for p in
                   ('test_*.py', '*_test.py', '*_test.go', '*.test.*', '*.spec.*', '*Tests.swift')))


def protected(path):
    return (any(fnmatch.fnmatchcase(Path(path).name, p) for p in CONFIG)
            or fnmatch.fnmatchcase(path, '.github/workflows/*') or path == '.roadstar/guard.json')


def config_file(path):
    return (protected(path) or Path(path).suffix in {'.json', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.properties'}
            or bool(re.search(r'(?:^|[.-])(?:config|conf)\.', Path(path).name)))


def numeric_keys(line):
    return {m[0].lower().lstrip('-'): float(m[1]) for m in NUMBER.findall(line)}


def lowering_hits(root, base, ref):
    """一类／一文件只报第一处；用完整旧新文件解析配置段，避免零上下文漏段名。"""
    base = git(root, 'merge-base', base, ref).strip()
    hits = {}
    for status, before, after in changes(root, base, ref):
        def hit(category, line):
            hits.setdefault((CATEGORIES[category], after), line[:80])
        if status == 'D' and test_file(before):
            hit(1, '删除测试文件 ' + before)
        patch = git(root, 'diff', '--no-ext-diff', '--no-textconv', '--no-color', '--unified=0',
                    base, ref, '--', before, after)
        added, removed = [], []
        new_line, old_line = 0, 0
        in_hunk = False
        changed_old, changed_new = set(), set()
        for line in patch.splitlines():
            if line.startswith('diff --git '):
                in_hunk = False
            elif line.startswith('@@'):
                m = re.match(r'@@ -(\d+)(?:,\d+)? \+(\d+)', line)
                if m:
                    old_line, new_line = map(int, m.groups())
                    in_hunk = True
            elif not in_hunk:
                continue
            elif line.startswith('+'):
                added.append(line[1:]); changed_new.add(new_line); new_line += 1
            elif line.startswith('-'):
                removed.append(line[1:]); changed_old.add(old_line); old_line += 1
            elif line.startswith(' '):
                old_line += 1; new_line += 1
        if protected(after) or (status.startswith('R') and protected(before)):
            hit(4, (added or removed or ['改动检查配置 ' + after])[0])
        for line in added:
            if SKIP.search(line):
                hit(1, line)
            if DISABLE.search(line):
                hit(2, line)
            if Path(after).suffix in CODE and STUB.search(line):
                hit(3, line)
        if test_file(after) and sum(bool(ASSERT.search(l)) for l in removed) > sum(bool(ASSERT.search(l)) for l in added):
            hit(1, next(l for l in removed if ASSERT.search(l)))
        if config_file(after):
            old_keys = {}
            for line in removed:
                for key, value in numeric_keys(line).items():
                    old_keys.setdefault(key, []).append(value)
            for line in added:
                for key, value in numeric_keys(line).items():
                    if not old_keys.get(key):
                        continue
                    previous = old_keys[key].pop(0)
                    if ((any(k in key for k in ('cover', 'threshold', 'fail_under', 'fail-under', 'minimum', 'min_', 'branches', 'lines', 'functions', 'statements')) and value < previous)
                            or (key in ('max-warnings', 'maxwarnings') and value > previous)):
                        hit(0, line)
        if Path(after).name == 'pyproject.toml':
            for revision, name, changed in ((base, before, changed_old), (ref, after, changed_new)):
                body = git(root, 'show', revision + ':' + name, optional=True) or ''
                inside = False
                for number, line in enumerate(body.splitlines(), 1):
                    if line.lstrip().startswith('['):
                        inside = bool(TOOLS.match(line))
                    if inside and number in changed:
                        hit(4, line)
    return [(category, path, line) for (category, path), line in hits.items()]


def unnamed(hits, sections_text):
    paths = {path for _, path, _ in hits}
    names = [Path(path).name for path in paths]
    def mentioned(token):
        return re.search(r'(?<![A-Za-z0-9_./-])' + re.escape(token) + r'(?![A-Za-z0-9_./-])', sections_text) is not None
    return [h for h in hits if not mentioned(h[1]) and not
            (names.count(Path(h[1]).name) == 1 and mentioned(Path(h[1]).name))]


def section(body):
    match = re.search(r'^##[ \t]+降标准五查[ \t]*\r?$', body, re.M)
    return re.split(r'^#{1,2}[ \t]+', body[match.end():], maxsplit=1, flags=re.M)[0] if match else ''


def recent_records(main, tasks):
    since = baselines.since('lowering-scan')
    records = []
    for value in tasks:
        plan, _, task = value.rpartition('/')
        rounds = main / plan / 'rounds'
        request = rounds / ('exec-' + task + '-request.md')
        if since is None or (request.is_file() and request.stat().st_mtime >= since):
            records.append(rounds / ('check-' + task + '.md'))
    return records


def command(name):
    candidates = [os.environ.get(name.upper().replace('-', '_') + '_BIN'),
                  str(Path.home() / 'Documents/RuruCode/RuruAgent/tools/design-lint' / name), name]
    return next((found for c in candidates if c and (found := shutil.which(c))), None)


def design_run(root, name, args, block):
    binary = command(name)
    if not binary:
        with redirect_stderr(io.StringIO()):
            skiplog.record('设计检查', '命令缺失', root)
        print('设计检查命令还没装好（design-lint / design-audit），这次跳过', file=sys.stderr)
        return False
    try:
        p = subprocess.run([binary, *map(str, args)], cwd=root, capture_output=True, timeout=110)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print('警告：设计检查没跑完，这次放行：' + str(exc), file=sys.stderr)
        return
    if p.returncode:
        sys.stdout.flush(); sys.stderr.flush()
        sys.stdout.buffer.write(p.stdout); sys.stdout.buffer.flush()
        sys.stderr.buffer.write(p.stderr); sys.stderr.buffer.flush()
        if p.returncode == 1:
            raise block('设计检查未通过', '怎么办：按上面的设计检查输出修复后重试。')
        print(f'警告：{name} 退出 {p.returncode}，这次放行', file=sys.stderr)
    return True


def design_enabled(root):
    return config(root).get('design_lint') is True and not skiplog.skipped('设计检查', 'ROADSTAR_DESIGN_GATE', root)


def commit_checks(root, message, block):
    problems, reason = length_problems(root, message)
    if problems:
        raise block('提交包含超长代码文件', *problems,
                    '怎么办：按职责拆文件；',
                    '第三方或生成代码写进 .roadstar/guard.json 的 length_exempt；',
                    '确需例外在提交说明末尾空一行加 Roadstar-Length: <理由>。')
    if reason:
        print('超长已放行：' + reason)
    if design_enabled(root):
        design_run(root, 'design-lint', ['check', '--project', root, '--staged'], block)


def ui_file(path):
    return (Path(path).suffix in {'.tsx', '.jsx', '.vue', '.svelte', '.css', '.scss', '.less', '.html'}
            or (path.endswith('.swift') and (bool({'Views', 'UI'} & set(Path(path).parts[:-1]))
                                            or path.endswith(('View.swift', 'Screen.swift')))))


def merge_checks(root, refs, tasks, main, block):
    records = recent_records(main, tasks)
    if not records:
        return
    oids = [git(root, 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}').strip() for ref in refs]
    if not skiplog.skipped('降标准检查', 'ROADSTAR_LOWERING_CHECK', root):
        hits = list(dict.fromkeys(h for oid in oids for h in lowering_hits(root, 'HEAD', oid)))
        sections = '\n'.join(section(path.read_text(encoding='utf-8')) for path in records)
        missing = unnamed(hits, sections)
        if missing:
            raise block('这次合并有降标准的改动，验收记录没点名',
                        *(f'{c}：{p}（{line}）' for c, p, line in missing),
                        '怎么办：在 check-T<n>.md 的「## 降标准五查」一节逐个点名这些文件并写为什么可以接受，再重试 git merge --no-ff。')
    if design_enabled(root) and any(ui_file(p) or ui_file(old) for oid in oids
                                   for _, old, p in changes(root, git(root, 'merge-base', 'HEAD', oid).strip(), oid)):
        for path in records:
            if design_run(root, 'design-audit', ['verify', '--check', path.resolve()], block) is False:
                break


def audit(root, ref):
    count = 0
    try:
        oid = git(root, 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}').strip()
        for category, path, line in lowering_hits(root, 'HEAD', oid):
            print(f'{category}：{path}（{line}）'); count += 1
        for commit in git(root, 'rev-list', '--reverse', 'HEAD..' + oid).splitlines():
            parent = git(root, 'rev-parse', commit + '^', optional=True)
            if parent:
                for problem in length_changes(root, parent.strip(), commit):
                    print(f'超长文件：{commit[:12]} {problem}'); count += 1
    except (OSError, ValueError, TypeError) as exc:
        print('audit 读取失败：' + str(exc), file=sys.stderr)
    print(f'命中 {count} 条')
