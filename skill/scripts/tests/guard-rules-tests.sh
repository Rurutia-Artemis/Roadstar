#!/bin/bash
# run.sh 原有 ws-guard 断言原样迁入，source 时沿用它的桩与计数。
if [ "${1:-}" = "--legacy" ]; then
# ws-guard：--root 是临时 git 工作副本时拒派（退出码 2），项目主目录和 slots.json 允许的固定副本放行，WS_GUARD_OK=理由 放行并记日志。
WSG_SRC="${WS_GUARD_DIR:-$HOME/Documents/RuruCode/RuruAgent/tools/ws-guard}"
if [[ -f "$WSG_SRC/check_root.py" && -f "$WSG_SRC/wsconf.py" ]]; then
  WSG="$TMP/ws-guard"; RC="$TMP/rc"
  mkdir -p "$WSG" "$RC/Demo" "$RC/Demo-slots"
  cp "$WSG_SRC/check_root.py" "$WSG_SRC/wsconf.py" "$WSG/"
  python3 - "$WSG/slots.json" "$RC" <<'PY'
import json, sys
import os
json.dump({"root": os.path.realpath(sys.argv[2]), "limits": {"max_slots": 3, "max_gb_per_slot": 30},
           "fixed": ["^{root}/[^/]+-slots/s[1-3]$"], "extra": [], "legacy": [], "containers": [], "projects": {}},
          open(sys.argv[1], "w", encoding="utf-8"))
PY
  git -C "$RC/Demo" init -q
  git -C "$RC/Demo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit --allow-empty -qm init
  git -C "$RC/Demo" worktree add -q "$RC/Demo-slots/s1" -b slot-s1
  git -C "$RC/Demo" worktree add -q "$RC/stray" -b stray
  (
    export WS_GUARD_DIR="$WSG" WS_GUARD_LOG="$TMP/wsg.log"
    expect_exit 2 run_task T40 --dry-run --root "$RC/stray"
    grep -q '拒绝派活' "$TMP/last-output" && grep -q 'WS_GUARD_OK' "$TMP/last-output"
    expect_exit 0 run_task T40 --dry-run --root "$RC/Demo"
    expect_exit 0 run_task T40 --dry-run --root "$RC/Demo-slots/s1"
    [[ ! -e "$TMP/wsg.log" ]]
    (export WS_GUARD_OK='测试放行'; expect_exit 0 run_task T40 --dry-run --root "$RC/stray")
    grep -q '理由=测试放行' "$TMP/wsg.log"
  )
  [[ ! -f "$PLAN/rounds/exec-T40.meta" ]]
  pass 'ws-guard: temporary git worktree as --root is refused with exit 2, main checkout and fixed slot pass, WS_GUARD_OK logs the override'
else
  pass 'ws-guard: check_root.py not installed on this machine, root check skipped'
fi

  return
fi
set -euo pipefail
unset HISTFILE
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-rules-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1
python3 - "$SCRIPTS" "$TMP" <<'PY'
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

scripts, base = map(Path, sys.argv[1:])
guard = scripts / 'guard.py'
progress = Path(os.environ['ROADSTAR_GUARD_PROGRESS']) if os.environ.get('ROADSTAR_GUARD_PROGRESS') else None  # 不设就不写进度
plan = 'docs/roadstar/case'
tests = []
env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'ROADSTAR_', 'DESIGN_'))}
env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', GIT_EDITOR='true', LC_ALL='C')
# 规则导入用于精确核对命中；所有写入路径仍用装好真钩子的 git 命令。
sys.path.insert(0, str(scripts))
import guard_rules as rules


def test(number, title):
    def add(fn):
        tests.append((number, title, fn))
        return fn
    return add


def run(root, *args, expected=0, extra=None, input=None):
    e = dict(env, ROADSTAR_CONFIG_DIR=str(root.parent / 'config'), HOME=str(root.parent / 'home'))
    e.update(extra or {})
    p = subprocess.run(list(map(str, args)), cwd=root, env=e, capture_output=True, text=True, input=input, timeout=110)
    assert p.returncode == expected, (args, p.returncode, expected, p.stdout, p.stderr)
    return p


def git(root, *args, **kw):
    return run(root, 'git', *args, **kw)


def call(root, *args, **kw):
    return run(root, 'python3', guard, *args, **kw)


def write(root, name, body):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding='utf-8')
    return path


def stage(root, name, body):
    path = write(root, name, body)
    git(root, 'add', '--', name)
    return path


def commit(root, message='change', **kw):
    return git(root, 'commit', '-qm', message, **kw)


def fixture():
    directory = Path(subprocess.check_output(['mktemp', '-d', str(base / 'case.XXXXXX')], text=True).strip())
    root = directory / 'repo with space'
    root.mkdir()
    git(root, 'init', '-q', '--template=')
    git(root, 'symbolic-ref', 'HEAD', 'refs/heads/main')
    git(root, 'config', 'user.name', 'Rules Test')
    git(root, 'config', 'user.email', 'rules@example.invalid')
    for name, size in (('huge.py', 900), ('near.py', 790), ('test_old.py', 2)):
        stage(root, name, 'assert True\n' * size)
    stage(root, 'coverage.json', '{"threshold": 90, "maxWarnings": 1}\n')
    stage(root, 'pyproject.toml', '[project]\nname="x"\n[tool.ruff.lint]\nselect=["E"]\n')
    stage(root, plan + '/rounds/exec-T1-request.md', '## 涉及模块\n无地图\n')
    commit(root, 'initial')
    run(root, '/bin/bash', scripts / 'install-guard.sh', root)
    return root


def record(root, body='验收通过\n', task='T1'):
    return write(root, plan + '/rounds/check-' + task + '.md', body)


def topic(root, name='a.ts', body='// @ts-ignore\nlet x = 1;\n', task='T1'):
    git(root, 'checkout', '-qb', 'topic')
    stage(root, name, body)
    commit(root, 'topic\n\nRoadstar-Task: ' + plan + '/' + task)
    git(root, 'checkout', '-q', 'main')
    record(root)


def merge(root, **kw):
    return git(root, 'merge', '--no-ff', '--no-edit', 'topic', **kw)


def skip_lines(root):
    path = root.parent / 'config/skip-log.tsv'
    return path.read_text().splitlines() if path.exists() else []


def fake(root, name, code=0):
    path = write(root.parent, name, '#!/bin/bash\nprintf "%s\\n" "$*" >> "' + str(root.parent / (name + '.calls')) + '"\nprintf "design stdout\\n"\nprintf "design stderr\\n" >&2\nexit ' + str(code) + '\n')
    path.chmod(0o755)
    return {('DESIGN_LINT_BIN' if name == 'lint' else 'DESIGN_AUDIT_BIN'): str(path)}


def design(root):
    stage(root, '.roadstar/guard.json', '{"design_lint":true}\n')


@test('C2-new801', '新文件 801 行拦，暂存版本优先于工作树')
def new801(root):
    stage(root, 'new.py', 'x\n' * 801)
    write(root, 'new.py', 'x\n')
    p = commit(root, expected=1)
    assert 'new.py 801（原 0）' in p.stderr


@test('C2-new800', '新文件 800 行放')
def new800(root):
    stage(root, 'new.py', 'x\n' * 800)
    commit(root)


@test('C2-grow', '已有 900 行加 1 行拦')
def grow(root):
    stage(root, 'huge.py', 'assert True\n' * 901)
    assert 'huge.py 901（原 900）' in commit(root, expected=1).stderr


@test('C2-shrink', '已有 900 行减 1 行放')
def shrink(root):
    stage(root, 'huge.py', 'assert True\n' * 899)
    commit(root)


@test('C2-cross', '已有 790 行涨到 850 拦')
def cross(root):
    stage(root, 'near.py', 'assert True\n' * 850)
    assert '850（原 790）' in commit(root, expected=1).stderr


@test('C2-rename', '改名后 900 行不加行放，加行用原路径比较')
def rename(root):
    git(root, 'mv', 'huge.py', 'renamed space.py')
    commit(root)
    stage(root, 'renamed space.py', 'assert True\n' * 901)
    assert '901（原 900）' in commit(root, expected=1).stderr


@test('C2-vendor', 'vendor 及任一级生成目录、生成文件名豁免')
def vendor(root):
    for name in ('nested/vendor/a.py', 'third_party/a.ts', 'x/.build/a.swift', 'x/Pods/a.m', 'x/generated/a.go', 'x/__generated__/a.ts', 'a.min.js', 'a.pb.go', 'a_pb2.py', 'a.generated.swift'):
        stage(root, name, 'x\n' * 801)
    commit(root)


@test('C2-exempt', 'length_exempt 暂存配置优先于工作树')
def exempt(root):
    stage(root, '.roadstar/guard.json', '{"length_exempt":["legacy/*.py"]}\n')
    write(root, '.roadstar/guard.json', '{}')
    stage(root, 'legacy/a.py', 'x\n' * 801)
    commit(root)


@test('C2-headconfig', '配置缺暂存版本时回退 HEAD，再回退工作树')
def headconfig(root):
    stage(root, '.roadstar/guard.json', '{"length_exempt":["legacy.py"]}\n')
    commit(root)
    git(root, 'rm', '.roadstar/guard.json')
    stage(root, 'legacy.py', 'x\n' * 801)
    commit(root)
    write(root, '.roadstar/guard.json', '{"length_exempt":["work.py"]}')
    stage(root, 'work.py', 'x\n' * 801)
    commit(root)


@test('C2-md', '非代码 md 不限行数')
def markdown(root):
    stage(root, 'doc.md', 'x\n' * 1200)
    commit(root)


@test('C2-trailer', 'Roadstar-Length 放行并打印理由，无空行不能误放')
def trailer(root):
    stage(root, 'long.py', 'x\n' * 900)
    commit(root, 'change\nRoadstar-Length: no blank', expected=1)
    p = commit(root, 'change\n\nRoadstar-Length: 必须兼容旧接口')
    assert '超长已放行：必须兼容旧接口' in p.stdout


@test('C2-switch', '行数开关放行且只多一行 skip-log')
def length_switch(root):
    stage(root, 'long.py', 'x\n' * 900)
    before = len(skip_lines(root))
    p = commit(root, extra={'ROADSTAR_LENGTH_CHECK':'0'})
    assert '行数检查' in p.stderr and len(skip_lines(root)) == before + 1


@test('C3-merge', '@ts-ignore 真合并缺点名拦，点名后放')
def lowering_merge(root):
    topic(root)
    p = merge(root, expected=1)
    assert '这次合并有降标准的改动，验收记录没点名' in p.stderr and '关掉检查：a.ts' in p.stderr
    git(root, 'merge', '--abort')
    record(root, '## 降标准五查\n关掉检查：a.ts；兼容现有第三方定义。\n')
    merge(root)


@test('C3-threshold', '配置下调数字和增大 max-warnings，收紧不命中')
def thresholds(root):
    topic(root, 'coverage.json', '{"threshold": 80, "maxWarnings": 2}\n')
    hits = rules.lowering_hits(root, 'HEAD', 'topic')
    assert any(c == '下调门槛' and p == 'coverage.json' for c, p, _ in hits), hits
    record(root, '## 降标准五查\ncoverage.json 调整预算，已审查。\n')
    merge(root)
    git(root, 'checkout', '-qb', 'tight')
    stage(root, 'coverage.json', '{"threshold": 95, "maxWarnings": 0}\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    assert rules.lowering_hits(root, 'HEAD', 'tight') == []


@test('C3-tests', '删测试文件、跳过测试与减少断言都命中')
def deleted_tests(root):
    topic(root, 'tests/a.test.js', 'test.skip("x", () => {});\n')
    git(root, 'checkout', '-q', 'topic')
    git(root, 'rm', 'test_old.py')
    stage(root, 'tests/assert_test.py', 'assert 1 == 1\nassert 2 == 2\n')
    commit(root)
    stage(root, 'tests/assert_test.py', 'assert 1 == 1\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    hits = rules.lowering_hits(root, 'HEAD', 'topic')
    # 净新增的测试断言不能抵掉另一个被删测试文件。
    assert {p for c, p, _ in hits if c == '跳过或删测试'} == {'test_old.py', 'tests/a.test.js'}, hits
    stage(root, 'test_old.py', 'self.assertEqual(1, 1)\nself.assertEqual(2, 2)\n')
    commit(root)
    git(root, 'checkout', '-qb', 'less')
    stage(root, 'test_old.py', 'pass\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    assert any(c == '跳过或删测试' for c, _, _ in rules.lowering_hits(root, 'HEAD', 'less'))


@test('C3-stub', '代码留桩命中，文档 TODO 不算留桩')
def stubs(root):
    topic(root, 'stub.py', 'raise NotImplementedError("later")\n')
    assert any(c == '留桩或半成品' for c, _, _ in rules.lowering_hits(root, 'HEAD', 'topic'))
    p = merge(root, expected=1)
    assert 'stub.py' in p.stderr


@test('C3-config', '新增例外配置和 pyproject 工具段命中')
def configs(root):
    topic(root, '.eslintrc.json', '{}\n')
    git(root, 'checkout', '-q', 'topic')
    stage(root, 'pyproject.toml', '[project]\nname="x"\n[tool.ruff.lint]\nselect=["W"]\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    assert {p for c, p, _ in rules.lowering_hits(root, 'HEAD', 'topic') if c == rules.CATEGORIES[4]} == {'.eslintrc.json', 'pyproject.toml'}


@test('C3-projectsection', 'pyproject 项目段变化不误报工具配置')
def projectsection(root):
    topic(root, 'pyproject.toml', '[project]\nname="new"\n[tool.ruff.lint]\nselect=["E"]\n')
    assert not rules.lowering_hits(root, 'HEAD', 'topic')
    merge(root)


@test('C3-old', '任务修改时间早于 since 时不扫描')
def old_task(root):
    topic(root)
    request = root / plan / 'rounds/exec-T1-request.md'
    now = time.time()
    os.utime(request, (now - 100, now - 100))
    write(root.parent, 'config/baselines/lowering-scan.json', json.dumps({'_since': {'value': now}}))
    merge(root)


@test('C3-none', 'since 为 None 全部扫描，等于 since 也扫描')
def since_none(root):
    topic(root)
    request = root / plan / 'rounds/exec-T1-request.md'
    os.utime(request, (1, 1))
    call(root, 'check-merge', 'topic', expected=1)
    write(root.parent, 'config/baselines/lowering-scan.json', json.dumps({'_since': {'value': 1}}))
    call(root, 'check-merge', 'topic', expected=1)


@test('C3-switch', '降标准开关放行且记一行账')
def lowering_switch(root):
    topic(root)
    before = len(skip_lines(root))
    merge(root, extra={'ROADSTAR_LOWERING_CHECK':'0'})
    assert len(skip_lines(root)) == before + 1 and 'ROADSTAR_LOWERING_CHECK' in skip_lines(root)[-1]


@test('C3-section', '其他节的路径不能放行，只认五查，唯一文件名可放')
def sections(root):
    topic(root, 'src/a.ts')
    record(root, '## 复跑\nsrc/a.ts\n## 降标准五查\n无\n## 未验证\nsrc/a.ts\n')
    call(root, 'check-merge', 'topic', expected=1)
    record(root, '## 降标准五查\na.ts：类型库欠缺，已查运行。\n')
    call(root, 'check-merge', 'topic')
    hits = [('关掉检查', 'src/a.ts', 'x'), ('关掉检查', 'other/a.ts', 'x')]
    assert rules.unnamed(hits, 'a.ts') == hits
    assert rules.unnamed(hits, 'src/a.ts') == [hits[1]]
    assert rules.unnamed(hits, '已查src/a.ts，理由充分') == [hits[1]]


@test('C3-pretool', 'claude-pretool 对带降标准的 merge 命令返回 2')
def pretool(root):
    topic(root)
    payload = json.dumps({'tool_name':'Bash', 'tool_input':{'command':'git merge --no-ff topic'}})
    p = call(root, 'claude-pretool', input=payload, expected=2)
    assert '关掉检查：a.ts' in p.stderr


@test('C4-audit', 'audit 打印五查和每个提交的超长文件且退出 0')
def audit(root):
    topic(root)
    git(root, 'checkout', '-q', 'topic')
    stage(root, 'long.py', 'x\n' * 900)
    commit(root, 'long\n\nRoadstar-Length: 历史兼容')
    stage(root, 'long.py', 'x\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    before = git(root, 'status', '--porcelain').stdout
    p = call(root, 'audit', 'topic')
    assert '关掉检查：a.ts' in p.stdout and 'long.py 900（原 0）' in p.stdout and p.stdout.rstrip().endswith('命中 2 条'), p.stdout
    assert before == git(root, 'status', '--porcelain').stdout and not skip_lines(root)
    assert call(root, 'audit', 'missing').stdout.rstrip().endswith('命中 0 条')


@test('C9-lint1', 'design-lint 退出 1 拦且原样输出，参数含 --staged')
def lint_one(root):
    design(root)
    e = fake(root, 'lint', 1)
    p = commit(root, expected=1, extra=e)
    assert p.stderr.startswith('design stdout\ndesign stderr\n'), (p.stdout,p.stderr)
    assert (root.parent / 'lint.calls').read_text() == 'check --project ' + str(root) + ' --staged\n'


@test('C9-lint0', 'design-lint 退出 0 放行')
def lint_zero(root):
    design(root)
    commit(root, extra=fake(root, 'lint', 0))
    assert (root.parent / 'lint.calls').exists()


@test('C9-other', 'design-lint 其他非 0 退出警告放行')
def lint_other(root):
    design(root)
    p = commit(root, extra=fake(root, 'lint', 7))
    assert '退出 7' in p.stderr


@test('C9-absent', '没装 design_lint 或为 false 不跑也不提示')
def not_installed(root):
    e = fake(root, 'lint', 1)
    stage(root, 'x.ts', 'x\n')
    assert '设计' not in commit(root, extra=e).stderr
    stage(root, '.roadstar/guard.json', '{"design_lint":false}\n')
    commit(root, extra=e)
    assert not (root.parent / 'lint.calls').exists()


@test('C9-missing', '装了命令不存在不拦且 skip-log 多一行')
def missing(root):
    design(root)
    before = len(skip_lines(root))
    # 隔离 HOME 和 PATH 中的设计命令，Git/Python 用本地可执行文件链接。
    bindir = root.parent / 'bin'
    bindir.mkdir()
    for name in ('git','python3','dirname','bash'):
        (bindir / name).symlink_to(shutil.which(name))
    p = commit(root, extra={'DESIGN_LINT_BIN': str(root.parent/'missing'), 'PATH': str(bindir)})
    assert '设计检查命令还没装好（design-lint / design-audit），这次跳过' in p.stderr
    assert len(skip_lines(root)) == before + 1 and '命令缺失' in skip_lines(root)[-1]


@test('C9-gate', '设计开关留痕跳过 lint')
def design_switch(root):
    design(root)
    e = dict(fake(root, 'lint', 1), ROADSTAR_DESIGN_GATE='0')
    commit(root, extra=e)
    assert not (root.parent / 'lint.calls').exists() and len(skip_lines(root)) == 1


@test('C9-audit1', '界面合并 design-audit 退出 1 拦且原样输出，绝对 check 路径')
def audit_one(root):
    topic(root, 'src/App.tsx', 'export const App = 1;\n')
    write(root, '.roadstar/guard.json', '{"design_lint":true}')
    e = fake(root, 'audit', 1)
    p = merge(root, expected=1, extra=e)
    assert 'design stdout\ndesign stderr\n' in p.stderr, (p.stdout,p.stderr)
    assert (root.parent / 'audit.calls').read_text() == 'verify --check ' + str(root / plan / 'rounds/check-T1.md') + '\n'
    assert not (root.parent / 'lint.calls').exists()
    git(root, 'merge', '--abort')
    merge(root, extra=fake(root, 'audit', 0))


@test('C9-no-ui', '非界面合并不跑 design-audit')
def no_ui(root):
    topic(root, 'logic.py', 'value = 1\n')
    write(root, '.roadstar/guard.json', '{"design_lint":true}')
    merge(root, extra=fake(root, 'audit', 1))
    assert not (root.parent / 'audit.calls').exists()


@test('C9-prechecks', '设计合并门槛接 check-merge 与 claude-pretool，开关可跳过')
def design_prechecks(root):
    topic(root, 'app/UI/Thing.swift', 'let x = 1\n')
    write(root, '.roadstar/guard.json', '{"design_lint":true}')
    e = fake(root, 'audit', 1)
    call(root, 'check-merge', 'topic', extra=e, expected=1)
    payload = json.dumps({'tool_name':'Bash','tool_input':{'command':'git merge --no-ff topic'}})
    call(root, 'claude-pretool', input=payload, extra=e, expected=2)
    merge(root, extra=dict(e, ROADSTAR_DESIGN_GATE='0'))
    assert len((root.parent / 'audit.calls').read_text().splitlines()) == 2
    assert len(skip_lines(root)) == 1


@test('C2-rename-growth', '同次改名并加行拦，含空格及换行文件名按 NUL 解析')
def rename_growth(root):
    git(root, 'mv', 'huge.py', 'renamed\nfile.py')
    stage(root, 'renamed\nfile.py', 'assert True\n' * 901)
    assert '901（原 900）' in commit(root, expected=1).stderr


@test('C3-vocabulary', '五查所有跳过／关检查／留桩词以及配置路径覆盖')
def vocabulary(root):
    git(root, 'checkout', '-qb', 'topic')
    skips = ['.skip(', 'it.skip', 'describe.skip', 'test.skip', 'xit(', 'xdescribe(', 'xtest(', '.only(', '@pytest.mark.skip', 'pytest.skip(', '@unittest.skip', 'skipTest(', 'XCTSkip', 't.Skip(', '#[ignore]']
    disables = ['@ts-ignore', '@ts-nocheck', '@ts-expect-error', 'eslint-disable', '# noqa', 'type: ignore', 'pylint: disable', 'istanbul ignore', 'c8 ignore', 'nosemgrep', 'gitleaks:allow', 'swiftlint:disable', 'nolint', '@SuppressWarnings', '--no-verify']
    stubs = ['TODO', 'FIXME', 'XXX', 'NotImplementedError', 'fatalError(', 'unimplemented!', 'todo!(', 'Not Implemented']
    expected = set()
    for category, words in ((1, skips), (2, disables), (3, stubs)):
        for i, word in enumerate(words):
            name = f'samples/c{category}-{i}.py'
            stage(root, name, word + '\n')
            expected.add((rules.CATEGORIES[category], name))
    for pattern in rules.CONFIG:
        name = pattern.replace('*', 'test')
        stage(root, name, '{}\n')
        expected.add((rules.CATEGORIES[4], name))
    for name in ('.github/workflows/check.yml', '.roadstar/guard.json'):
        stage(root, name, '{}\n')
        expected.add((rules.CATEGORIES[4], name))
    stage(root, 'doc.md', 'TODO FIXME\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    actual = {(c, p) for c, p, _ in rules.lowering_hits(root, 'HEAD', 'topic')}
    assert expected <= actual and ('留桩或半成品', 'doc.md') not in actual, expected - actual


@test('C3-mergebase', '三点 diff 不把主干自有放宽反向算进合并')
def mergebase(root):
    topic(root, 'logic.py', 'x = 1\n')
    stage(root, 'coverage.json', '{"threshold": 95, "maxWarnings": 0}\n')
    commit(root)
    assert rules.lowering_hits(root, 'HEAD', 'topic') == []
    merge(root)


@test('C3-combined', '多个任务的五查合并使用，旧任务记录不能替新任务点名')
def combined(root):
    topic(root)
    write(root, plan + '/rounds/exec-T2-request.md', '## 涉及模块\n无地图\n')
    git(root, 'checkout', '-q', 'topic')
    stage(root, 'src/other.ts', '// @ts-ignore\nx\n')
    commit(root, 'other\n\nRoadstar-Task: ' + plan + '/T2')
    git(root, 'checkout', '-q', 'main')
    record(root, '## 降标准五查\na.ts 可接受。\n')
    record(root, '## 降标准五查\nsrc/other.ts 可接受。\n', 'T2')
    call(root, 'check-merge', 'topic')
    request = root / plan / 'rounds/exec-T1-request.md'
    now = time.time()
    os.utime(request, (now - 100, now - 100))
    write(root.parent, 'config/baselines/lowering-scan.json', json.dumps({'_since': {'value': now - 50}}))
    assert 'a.ts' in call(root, 'check-merge', 'topic', expected=1).stderr


@test('C9-audit-missing', '界面合并命令缺失只记一行，没装或旧任务不跑')
def audit_missing(root):
    topic(root, 'app/HomeView.swift', 'let x = 1\n')
    e = fake(root, 'audit', 1)
    call(root, 'check-merge', 'topic', extra=e)
    assert not (root.parent / 'audit.calls').exists()
    write(root, '.roadstar/guard.json', '{"design_lint":true}')
    bindir = root.parent / 'bin'
    bindir.mkdir()
    for name in ('git', 'python3', 'dirname', 'bash'):
        (bindir / name).symlink_to(shutil.which(name))
    p = call(root, 'check-merge', 'topic', extra={'PATH': str(bindir), 'DESIGN_AUDIT_BIN': str(root.parent/'missing')})
    assert len(p.stderr.splitlines()) == 1 and len(skip_lines(root)) == 1, p.stderr
    now = time.time()
    request = root / plan / 'rounds/exec-T1-request.md'
    os.utime(request, (now-100, now-100))
    write(root.parent, 'config/baselines/lowering-scan.json', json.dumps({'_since': {'value': now}}))
    merge(root, extra=e)
    assert not (root.parent / 'audit.calls').exists()


@test('C3-repeated', '重复门槛键都收紧不误报，max-warnings 增大仍命中')
def repeated(root):
    stage(root, 'coverage.json', '{"a": {"lines": 80},\n "b": {"lines": 90}}\n')
    stage(root, 'lint.conf.js', 'limit = "--max-warnings 1";\n')
    commit(root)
    git(root, 'checkout', '-qb', 'topic')
    stage(root, 'coverage.json', '{"a": {"lines": 85},\n "b": {"lines": 95}}\n')
    stage(root, 'lint.conf.js', 'limit = "--max-warnings 2";\n')
    commit(root)
    git(root, 'checkout', '-q', 'main')
    hits = rules.lowering_hits(root, 'HEAD', 'topic')
    assert [(c,p) for c,p,_ in hits] == [('下调门槛', 'lint.conf.js')], hits


@test('C3-testpaths', '测试目录按路径包含匹配，覆盖 AppUITests 及各测试文件名')
def testpaths(root):
    paths = ['tests/a.py', 'test/b.py', '__tests__/c.ts', 'AppUITests/Helper.swift', 'test_d.py', 'e_test.py', 'f_test.go', 'g.test.js', 'h.spec.ts', 'SomeTests.swift']
    for name in paths:
        stage(root, name, 'assert True\n')
    commit(root)
    git(root, 'checkout', '-qb', 'topic')
    git(root, 'rm', '--', *paths)
    commit(root)
    git(root, 'checkout', '-q', 'main')
    assert {p for c,p,_ in rules.lowering_hits(root, 'HEAD', 'topic') if c == '跳过或删测试'} == set(paths)


@test('C7', '拦住证据：900 行新代码提交与未点名降标准真合并')
def evidence(root):
    import shlex
    def show(*args, expected=0):
        print('$ ' + shlex.join(list(map(str,args))), flush=True)
        p = run(root, *args, expected=expected)
        print(p.stdout, end='')
        print(p.stderr, end='')
        print('[exit ' + str(p.returncode) + ']', flush=True)
        return p
    print('=== C7(a) ===', flush=True)
    show('/bin/bash', scripts/'install-guard.sh', root)
    show('python3', '-c', 'from pathlib import Path; Path("new900.py").write_text("x\\n" * 900)')
    show('git', '-C', root, 'add', 'new900.py')
    p = show('git', '-C', root, 'commit', '-m', 'new 900 lines', expected=1)
    assert 'new900.py 900（原 0）' in p.stderr
    show('git', '-C', root, 'reset', '-q', 'HEAD', '--', 'new900.py')
    print('=== C7(b) ===', flush=True)
    show('git', '-C', root, 'checkout', '-qb', 'topic')
    show('python3', '-c', 'from pathlib import Path; Path("lower.ts").write_text("// @ts-ignore\\nlet x = 1;\\n")')
    show('git', '-C', root, 'add', 'lower.ts')
    show('git', '-C', root, 'commit', '-qm', 'lower\n\nRoadstar-Task: ' + plan + '/T1')
    show('git', '-C', root, 'checkout', '-q', 'main')
    show('python3', '-c', 'from pathlib import Path; Path("' + plan + '/rounds/check-T1.md").write_text("已复跑通过\\n")')
    p = show('git', '-C', root, 'merge', '--no-ff', '--no-edit', 'topic', expected=1)
    assert '这次合并有降标准的改动，验收记录没点名' in p.stderr
    print('=== C7 end ===', flush=True)


@test('F1', '留桩：标识符和 mktemp 模板放行，独立标记与未实现照拦')
def stub_boundaries(root):
    clean = [
        ('calc.py', 'def count_done(todo_list):'),
        ('tests/test_x.py', 'def test_todo_done():'),
        ('mk.sh', 'f=$(mktemp "$archive_bin/.$script.XXXXXX")'),
        ('mk2.sh', 'mktemp /tmp/x.XXX'),
        ('constant.py', 'x = TODO_LIST'),
        ('comment.py', '# todo_list = []'),
    ]
    stubs = [
        '# TODO: 没做完', 'raise NotImplementedError', '# XXX 待补',
        '// todo: later', '/* fixme */', 'XXX', 'FIXME', 'todo!()', 'Not Implemented',
    ]
    for name, line in clean:
        stage(root, name, line + '\n')
        commit(root)
        actual = rules.lowering_hits(root, 'HEAD~1', 'HEAD')
        assert actual == [], (name, line, actual)
    for i, line in enumerate(stubs):
        name = f'stub-{i}.py'
        stage(root, name, line + '\n')
        commit(root)
        actual = rules.lowering_hits(root, 'HEAD~1', 'HEAD')
        assert actual == [('留桩或半成品', name, line)], (name, line, actual)


# 每项使用独立仓库；一项失败立即结束，重跑也保留连续失败次数。
streak = {}
if progress:
    progress.parent.mkdir(parents=True, exist_ok=True)
if progress and progress.exists():
    for line in progress.read_text().splitlines():
        parts = line.split('\t', 3)
        if len(parts) == 4:
            streak[parts[1]] = streak.get(parts[1], 0) + 1 if parts[2] == 'fail' else 0
count = 0
for number, title, fn in tests:
    if streak.get(number, 0) >= 3:
        raise SystemExit('连续三次失败，停止：' + number)
    root, failure = None, None
    try:
        root = fixture()
        fn(root)
    except Exception as exc:
        failure = str(exc).replace('\n', ' ')
    finally:
        if root is not None:
            shutil.rmtree(root.parent)
    status = 'fail' if failure else 'pass'
    evidence = failure or title
    if progress:
        with progress.open('a', encoding='utf-8') as f: f.write(datetime.datetime.now(datetime.timezone.utc).isoformat() + '\t' + number + '\t' + status + '\t' + evidence + '\n')
    print(status.upper() + ' ' + number + ' ' + evidence, flush=True)
    if failure:
        raise SystemExit(1)
    count += 1
print('PASS ' + str(count) + ' checks')
PY
