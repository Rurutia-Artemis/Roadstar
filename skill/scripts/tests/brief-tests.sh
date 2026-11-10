#!/usr/bin/env bash
# All subprocesses use local protocol stubs. No network or real CLI is needed.
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TEST_DIR/.." && pwd)"
export PATH="$TEST_DIR/bin:$PATH"
unset FAKE_CODEX_USED FAKE_CODEX_CARDS FAKE_CODEX_FIVE_HOUR FAKE_CODEX_DELAY FAKE_CODEX_EXIT FAKE_CODEX_REPORT FAKE_CODEX_REPLY
unset FAKE_CLAUDE_USED FAKE_CLAUDE_FABLE FAKE_CLAUDE_NO_FABLE
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'echo "FAIL: line $LINENO" >&2' ERR
export FAKE_TRACE_FILE="$TMP/trace.jsonl"
export ROADSTAR_CONFIG_DIR="$TMP/config"
export RURU_APPROVALS_CMD="$TMP/fake approvals.py"
export PYTHONDONTWRITEBYTECODE=1
unset BRIEF_CHECK ROADSTAR_DESIGN_CHECK
unset ROADSTAR_PROJECTS
PLAN="$TMP/plan dir"
mkdir -p "$PLAN"
BRIEF="$PLAN/brief.md"
printf '%s\n' '# T1 · Offline task' '' '## 目标与做完的样子' '保留原文与换行。完成线：stub 返回 ok。' '' '## 涉及模块' 'tests' '' '## 不许动什么' '仓库外' '' '## 执行环境' 'stub' '' '## 验收命令与期望输出' '`true` 期望退出 0' '' '## 资源上限与止损' '预计 5 分钟，上限 10 分钟' > "$BRIEF"
printf '%s\n' '# Plan' 'Do the assigned task.' > "$PLAN/plan.md"
printf '%s\n' '# Ledger' '| # | 题目 | 来源 | 级别 | 处置 | 状态 |' > "$PLAN/ledger.md"
COUNT=0
pass() { COUNT=$((COUNT + 1)); printf 'ok %d - %s\n' "$COUNT" "$1"; }
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
python3 "$SCRIPTS/brief-check.py" "$BRIEF" && pass "brief-check 放行六栏齐全的任务书"
if python3 "$SCRIPTS/brief-check.py" "$SCRIPTS/../references/task-brief-template.md" >/dev/null 2>&1; then echo 'FAIL: 模板占位应被 brief-check 拦下' >&2; exit 1; fi
pass "brief-check 拦下只有占位的模板"
# 同类方案（主席 11-07 定，当天收窄）：目标里有 新系统/大改版/立项… 时，缺节或带链接条目少于 3 条就拦。
prior_brief() {  # $1 目标一句；$2 同类方案节正文（空 = 不写这一节）
  printf '%s\n' '# T2 · prior art' '' '## 目标与做完的样子' "$1 完成线：测试通过。" '' '## 涉及模块' 'tests' '' '## 不许动什么' '仓库外' '' '## 执行环境' 'stub' '' '## 验收命令与期望输出' '`true` 期望退出 0' '' '## 资源上限与止损' '预计 5 分钟，上限 10 分钟'
  [[ -z "$2" ]] || printf '\n## 同类方案\n%s\n' "$2"
}
PA_ROWS='| 项目 | 它怎么做 | 取 | 不取 | 许可证 | 链接 |
|---|---|---|---|---|---|
| Hindsight | 小模型分诊 | 分诊 | 整套替换 | MIT | https://github.com/vectorize-io/hindsight |
| mem0 | 向量+BM25 | 重排 | 托管 | Apache-2.0 | https://github.com/mem0ai/mem0 |'
PA_THIRD='| claude-mem | 会话压缩 | 开场短索引 | 插件形态 | AGPL-3.0 | https://github.com/thedotmack/claude-mem |'
prior_brief '新系统：本机记忆服务。' "$PA_ROWS
$PA_THIRD" > "$TMP/pa-ok.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-ok.md"
pass "brief-check 放行目标是新系统、同类方案 3 条带链接的任务书"
prior_brief '新系统：本机记忆服务。' '' > "$TMP/pa-missing.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/pa-missing.md"
grep -q '目标里有「新系统」，缺「同类方案」一节' "$TMP/last-output"
pass "brief-check 拦下目标是新系统却缺同类方案一节的任务书，并说缺什么"
prior_brief '记忆模块大改版。' "$PA_ROWS
| Letta | 记忆块 | 字数上限 | 全套 | Apache-2.0 | 链接待补 |" > "$TMP/pa-two.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/pa-two.md"
grep -q '「同类方案」只有 2 条带链接的条目，要至少 3 条' "$TMP/last-output"
pass "brief-check 拦下同类方案少于 3 条带链接的任务书（没链接的那条不算）"
prior_brief '修复登录页按钮点击两次才响应的 bug。' '' > "$TMP/pa-bugfix.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-bugfix.md"
pass "brief-check 普通修 bug 不要求同类方案"
# 11-07 收窄：单独的 新建 / 新增 / 新模块 不触发，整体性说法才拦。
prior_brief '补上新建的测试文件，覆盖导出失败分支。' '' > "$TMP/pa-newfile.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-newfile.md"
pass "brief-check 目标是「新建的测试文件」不要求同类方案"
prior_brief '新建 `quota.py`，读额度探针输出。' '' > "$TMP/pa-newpy.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-newpy.md"
pass "brief-check 目标是「新建 quota.py」不要求同类方案"
prior_brief '加一个新模块，把导出拆出来。' '' > "$TMP/pa-newmod.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-newmod.md"
pass "brief-check 单独的「新模块」不要求同类方案"
prior_brief '记忆检索新系统。' '' > "$TMP/pa-newsys.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/pa-newsys.md"
grep -q '目标里有「新系统」，缺「同类方案」一节' "$TMP/last-output"
pass "brief-check 目标是「新系统」缺同类方案就拦"
prior_brief '设置页大改版。' '' > "$TMP/pa-revamp.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/pa-revamp.md"
grep -q '目标里有「大改版」' "$TMP/last-output"
pass "brief-check 目标是「大改版」缺同类方案就拦"
prior_brief '加一个新模块，做成常驻的同步服务。' '' > "$TMP/pa-modsvc.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/pa-modsvc.md"
grep -q '目标里有「新模块」+「服务」' "$TMP/last-output"
pass "brief-check 目标是「新模块」又有「服务」缺同类方案就拦"
prior_brief '新系统：本机语音备忘。' '查过：voice memo open source、本地语音转写 备忘（GitHub、wigolo search），无' > "$TMP/pa-none.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/pa-none.md"
pass "brief-check 同类方案写「查过：关键词…，无」放行"
printf '%s\n' '# Plan' '## 1 目标与非目标' '- 目标：修好导出。' '- 非目标：不做大改版。' > "$TMP/plan-ok.md"
printf '%s\n' '# Plan' '## 1 目标与非目标' '- 目标：重做记忆服务。' '- 非目标：不换数据库。' '## 3b 同类方案' "$PA_ROWS" > "$TMP/plan-two.md"
python3 "$SCRIPTS/brief-check.py" "$TMP/plan-ok.md"
python3 "$SCRIPTS/brief-check.py" --plan "$SCRIPTS/../references/plan-template.md"
expect_exit 2 python3 "$SCRIPTS/brief-check.py" "$TMP/plan-two.md"
grep -q '^plan不合格' "$TMP/last-output"
grep -q '只有 2 条' "$TMP/last-output"
pass "brief-check 认出 plan：只查同类方案，「非目标」行不触发，plan 模板本身放行"
mkdir -p "$TMP/pa plan"
printf '%s\n' '# Plan' '## 1 目标与非目标' '- 目标：重做记忆服务。' > "$TMP/pa plan/plan.md"
expect_exit 2 bash "$SCRIPTS/dex-exec.sh" "$TMP/pa plan" T1 --model gpt-6-astra --effort high --brief "$BRIEF" --max-minutes 10 --dry-run
grep -q 'plan.md 缺同类方案' "$TMP/last-output"
[[ ! -e "$TMP/pa plan/rounds" ]]
pass "dex-exec 派活前查场次 plan.md：目标是重做却缺同类方案，退出 2 不派"

# New checks stay isolated even when invoked by the full suite.
export RURU_APPROVALS_CMD="$TMP/fake approvals.py"
export RURUCODE_ROOT="$TMP/rurucode"
unset BRIEF_CHECK ROADSTAR_DESIGN_CHECK
python3 - "$SCRIPTS" "$TMP" "$COUNT" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

scripts, tmp, count = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
sys.path.insert(0, str(scripts))
import baselines
import design_page as dp
session = tmp / 'design session'
session.mkdir()
brief, design = session / 'task.md', session / 'design.md'
base = (tmp / 'plan dir/brief.md').read_text().replace('tests\n', '流程与调度契约、任务执行与验收\n')
required = ['大小', '为什么做', '做完的样子', '这次不做什么', '哪种情况技术上跑通也算失败', '只有主人能答的问题']

def page(size='中活', question='无', rows=2):
    fields = {'大小': size + '，影响两个模块。', '为什么做': '用户派活缺少设计检查。',
              '做完的样子': '缺设计的写活被拒绝。', '这次不做什么': '不修改其他钩子。',
              '哪种情况技术上跑通也算失败': '误拦只读派活就算失败。',
              '两三种做法和选的那种': '纯文字约定或程序检查，选择程序检查。',
              '同类方案': '跳过：改已有检查。',
              '模块表': '| 模块 | 职责 | 依赖谁 | 先后顺序 |\n|---|---|---|---|\n' +
                   '\n'.join(f'| 模块{i} | 校验 | 无 | {i} |' for i in range(rows)),
              '只有主人能答的问题': question,
              '小事自己定的清单': '决定：只读记录；理由：不伪造；判错的代价：重新接接口。',
              '主人点头': '2026-11-10「好」'}
    return '\n\n'.join(f'## {k}\n{v}' for k, v in fields.items()) + '\n'

def check(label, fn):
    global count
    fn()
    count += 1
    print(f'ok {count} - {label}', flush=True)

def expect(code, args=(), text=None, env=None, contains='', warn=''):
    brief.write_text(base if text is None else text)
    cmd = [sys.executable, str(scripts / 'brief-check.py'), str(brief), *args]
    r = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, **(env or {})}, timeout=20)
    assert r.returncode == code, (cmd, r.returncode, r.stdout, r.stderr)
    assert contains in r.stderr, r.stderr
    assert warn in r.stderr, r.stderr
    return r

write = ['--write', '--class', '跨模块', '--est-minutes', '90', '--plan-dir', str(session)]
reference = base + '\n设计页：`design.md`\n'
check('C3 旧调用不带新参数仍放行', lambda: expect(0))
check('C3 跨模块写活没有设计页退出 2', lambda: expect(2, write, contains='缺设计页：中活以上的写活'))
check('C3 引用了不存在的设计页退出 2', lambda: expect(2, write, base + '\n设计页: missing.md', contains='缺设计页'))
for title in required:
    def missing(title=title):
        fields = dp.sections(page())
        design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items() if k != title))
        expect(2, write, reference, contains=title)
    check('C2/C3 中活缺必填节：' + title, missing)

def placeholders():
    design.write_text(page().replace('用户派活缺少设计检查。', '<只有占位\n包含<嵌套>，不算填写>'))
    expect(2, write, reference, contains='为什么做')
check('C2 去掉跨行嵌套占位后没有内容则拒绝', placeholders)

def one_row():
    design.write_text(page(rows=1))
    expect(2, write, reference, contains='模块表')
check('C2 两模块任务仅一行模块表拒绝', one_row)
for delimiter in [',', '，', '、', '\n']:
    check('C3 模块栏按分隔符计数 ' + repr(delimiter), lambda d=delimiter: expect(2, write, reference.replace('流程与调度契约、任务执行与验收', '甲' + d + '乙'), contains='模块表'))

for question in ['无', '无。', '无，因为沿用已确认的方案']:
    def no_questions(question=question):
        design.write_text(page(question=question))
        expect(0, write, reference)
    check('C2 中活问题为 ' + question + '，不需点头', no_questions)

# The fake writer owns the verdict. No real approval store or command is used.
command = Path(os.environ['RURU_APPROVALS_CMD'])
response = tmp / 'verify-response.json'
mode = tmp / 'verify-mode'
calls = tmp / 'verify-calls.jsonl'
command.write_text(r"""import json, sys, time
from pathlib import Path
root = Path(__file__).parent
with (root / 'verify-calls.jsonl').open('a') as handle:
    handle.write(json.dumps(sys.argv[1:]) + '\n')
assert sys.argv[1] == 'verify' and sys.argv[3:] == ['--json']
assert Path(sys.argv[2]).is_absolute()
mode = (root / 'verify-mode').read_text()
if mode == 'timeout':
    time.sleep(30)
if mode == 'bad-encoding':
    sys.stdout.buffer.write(b'\xff')
else:
    sys.stdout.write((root / 'verify-response.json').read_text())
sys.exit(1 if mode == 'nonzero' else 0)
""")
row = dict(design=str(tmp / 'main repo/design.md'), time='2000-01-01T00:00:00Z',
           tool_use_id='writer-tool', fingerprint='1234567890abcdef')

def reply(ok=False, reason='没有点头记录', record=None, behavior='normal'):
    mode.write_text(behavior)
    response.write_text(json.dumps(dict(ok=ok, record=record, reason=reason), ensure_ascii=False))

def call_rows():
    return [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []

def rejected(reason='没有点头记录', env=None):
    used_command = (env or {}).get('RURU_APPROVALS_CMD', str(command))
    message = (f'缺主人点头记录：{reason}。用 `python3 {used_command} ask {design.resolve()}` '
               '生成问题，在选项框里问主人')
    r = expect(2, write, reference, env=env, contains=message)
    assert '把 ask 输出的 question 原样放进选项框，选项只放「批准」「不批准」。' in r.stderr
    assert '点头依据：' not in r.stderr
    assert not r.stdout

def accepted():
    before = len(call_rows())
    r = expect(0, write, reference)
    evidence = (f'点头依据：{row["design"]} {row["time"]} '
                f'tool_use_id={row["tool_use_id"]} 指纹={row["fingerprint"]}')
    assert [line for line in r.stderr.splitlines() if line.startswith('点头依据：')] == [evidence], r.stderr
    assert '警告' not in r.stderr  # Old record time does not trigger an mtime rule.
    assert not r.stdout
    assert call_rows()[before:] == [['verify', str(design.resolve()), '--json']]

for size, question in [('中活', '是否保留旧入口？推荐：保留。'), ('大活', '无'), ('新项目', '无')]:
    def no_record(size=size, question=question):
        design.write_text(page(size, question))
        reply()
        rejected()
    check('T2 ' + size + '写方未批准，手写主人点头无效', no_record)
    def yes_record():
        reply(True, '有效批准', row)
        accepted()
    check('T2 ' + size + '写方 ok 放行，原样打印记录路径时间调用号指纹', yes_record)

def inconsistent_exit():
    reply(True, '有效批准', row, 'nonzero')
    rejected('点头核对退出码与结果不一致')
check('G1 写方 ok=true 且 record 完整但退出 1，派活拒绝', inconsistent_exit)

for reason in ['主人不批准', '最近一次拿不准', '批准后设计页改过，要重新点头', '写方新增的拒绝理由']:
    for behavior in ['normal', 'nonzero']:
        def denied(reason=reason, behavior=behavior):
            reply(False, reason, row, behavior)
            rejected(reason)
        check('T2 ok=false 原样报告理由（' + behavior + '）：' + reason, denied)

for reason in ['缺主人点头记录', '缺主人点头记录：需要重新询问']:
    for behavior in ['normal', 'nonzero']:
        def missing_prefix(reason=reason, behavior=behavior):
            reply(False, reason, behavior=behavior)
            r = expect(2, write, reference, contains=reason + '。用 ')
            assert r.stderr.count('缺主人点头记录') == 1, r.stderr
            assert '把 ask 输出的 question 原样放进选项框，选项只放「批准」「不批准」。' in r.stderr
            assert '点头依据：' not in r.stderr
        check('G2/G3 缺记录前缀只出现一次且说明怎么问（' + behavior + '）：' + reason, missing_prefix)

def missing_command():
    missing = str(tmp / 'missing approvals.py')
    before = len(call_rows())
    rejected('点头核对命令不在：' + missing, {'RURU_APPROVALS_CMD': missing})
    assert len(call_rows()) == before
check('T2 命令不在则拒绝并报告路径', missing_command)

def timed_out():
    import time
    reply(behavior='timeout')
    start = time.monotonic()
    rejected('点头核对超时')
    assert 9 <= time.monotonic() - start < 20
check('T2 命令真实等待 10 秒后超时拒绝', timed_out)

for output in ['not json', '', '{"ok": true', '[]', 'null',
               '{"ok": "true", "record": {}, "reason": ""}',
               '{"ok": true, "record": null, "reason": ""}']:
    def bad_output(output=output):
        reply()
        response.write_text(output)
        rejected('点头核对输出看不懂')
    check('T2 非 JSON 或协议形状错误拒绝：' + repr(output), bad_output)

def bad_encoding():
    reply(behavior='bad-encoding')
    rejected('点头核对输出看不懂')
check('T2 非 UTF-8 输出拒绝', bad_encoding)

def no_approval_required():
    reply(behavior='timeout')  # Calling it would fail or time out, never silently pass.
    calls.write_text('')
    for question in ['无', '无。', '无，因为沿用已确认的方案']:
        design.write_text(page(question=question))
        r = expect(0, write, reference)
        assert '点头依据：' not in r.stderr
    assert call_rows() == []
    reply()
    design.write_text(page('大活'))
check('T2 不需点头的设计页完全不调核对命令，调用数为 0', no_approval_required)

def literal_none():
    for q in ['无。是否迁移？推荐：不迁移。', '无权限修改的模块要不要包含？推荐：不包含。']:
        assert dp.needs_approval(page(question=q))
    fields = dp.sections(page())
    fields['为什么做'] = '- <说明>'
    design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items()))
    expect(2, write, reference, contains='为什么做')
    design.write_text(page('大活'))
check('C2 无字开头的问题仍要点头；纯 Markdown 标记不算已填写', literal_none)


for cls in ['取证', '复核', '审方案', '补全']:
    check('C2/C3 ' + cls + '不要求设计', lambda c=cls: expect(0, ['--write', '--class', c]))
for cls in ['批量', '窄回归']:
    check('C2/C3 ' + cls + '预计 60 分钟免设计', lambda c=cls: expect(0, ['--write', '--class', c, '--est-minutes', '60']))
    check('C2/C3 ' + cls + '预计 61 分钟要设计', lambda c=cls: expect(2, ['--write', '--class', c, '--est-minutes', '61'], contains='缺设计页'))
    check('C2/C3 ' + cls + '未给预计要设计', lambda c=cls: expect(2, ['--write', '--class', c], contains='缺设计页'))
for est in [60, 61]:
    check('C2/C3 无类别按预计 ' + str(est) + ' 判', lambda e=est: expect(0 if e <= 60 else 2, ['--write', '--est-minutes', str(e)], contains='' if e <= 60 else '缺设计页'))
check('C2/C3 类别预计都未给的写活要设计', lambda: expect(2, ['--write'], contains='缺设计页'))
check('C2/C3 只读跨模块不要求设计', lambda: expect(0, write[1:]))

def exempt():
    baselines.add('design-exempt', [session])
    expect(0, write, warn='老场次（上线前已有），设计页豁免')
    baselines.path('design-exempt').unlink()
check('C4 老场次按场次目录 realpath 豁免', exempt)

def skip_design():
    log = Path(os.environ['ROADSTAR_CONFIG_DIR']) / 'skip-log.tsv'
    before = len(log.read_text().splitlines()) if log.exists() else 0
    expect(0, write, env={'ROADSTAR_DESIGN_CHECK': '0'})
    lines = log.read_text().splitlines()
    assert len(lines) == before + 1 and '\t设计页检查\tROADSTAR_DESIGN_CHECK\t' in lines[-1]
    expect(2, write, text='无六栏', env={'ROADSTAR_DESIGN_CHECK': '0'}, contains='缺「目标与做完的样子」')
check('C5 设计跳过只跳过设计项，skip-log.tsv 加一行', skip_design)

def skip_brief():
    log = Path(os.environ['ROADSTAR_CONFIG_DIR']) / 'skip-log.tsv'
    before = len(log.read_text().splitlines())
    expect(0, write, text='无六栏', env={'BRIEF_CHECK': '0'})
    lines = log.read_text().splitlines()
    assert len(lines) == before + 1 and '\t任务书检查\tBRIEF_CHECK\t' in lines[-1]
check('C5 BRIEF_CHECK=0 保持全跳过并记账', skip_brief)
check('C1 模板本身当设计页拒绝', lambda: expect(2, write, base + '\n设计页：' + str(scripts.parent / 'references/design-template.md'), contains='大小'))

def prior_art():
    for title in ['为什么做', '做完的样子']:
        fields = dp.sections(page())
        fields[title] = '做一个新系统，保留现有接口。'
        design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items()))
        expect(2, write, reference, contains='同类方案')
        fields['同类方案'] = '\n'.join(f'- 案例{i}，取校验，不取托管，MIT https://example.com/{i}' for i in range(3))
        design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items()))
        expect(0, write, reference)
        fields['同类方案'] = '查过：local design gate，无'
        design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items()))
        expect(0, write, reference)
check('C2 两个目标节复用同类方案：不足拒、3 条链接或查过无放行', prior_art)

def extra_sections():
    for size in ['大活', '新项目']:
        for title in ['两三种做法和选的那种', '小事自己定的清单']:
            fields = dp.sections(page(size))
            fields[title] = '<待填写>'
            design.write_text('\n'.join(f'## {k}\n{v}' for k, v in fields.items()))
            expect(2, write, reference, contains=title)
check('C2 大活新项目额外两节不可空', extra_sections)

def paths():
    a, b = tmp / 'first', tmp / 'second'
    a.mkdir(); b.mkdir()
    for p in [a, b]:
        (p / 'design file.md').write_text(page())
    assert dp.find_design_page('设计页: `design file.md`', [a, b]) == (a / 'design file.md').resolve()
    assert dp.find_design_page('设计页：' + str(b / 'design file.md'), [a]) == (b / 'design file.md').resolve()
    assert dp.find_design_page('无引用', [a]) is None
    design.write_text(page())
    # bases 第二项：场次目录；第一项：任务书目录。
    nested = session / 'rounds'; nested.mkdir()
    external = nested / 'task.md'; external.write_text(reference)
    r = subprocess.run([sys.executable, str(scripts/'brief-check.py'), str(external), *write], capture_output=True, text=True, timeout=20)
    assert r.returncode == 0, r.stderr
    # bases 第三项：场次所属 git 根；第四项：当前目录。
    repo = tmp / 'paths repo'; repo.mkdir()
    subprocess.run(['git', 'init', '-q', str(repo)], check=True, timeout=10)
    scene = repo / 'docs/roadstar/new'; scene.mkdir(parents=True)
    (repo / 'root-design.md').write_text(page())
    for filename, cwd in [('root-design.md', session), ('cwd-design.md', tmp)]:
        if filename.startswith('cwd'):
            (cwd / filename).write_text(page())
        external.write_text(base + '\n设计页：`' + filename + '`')
        r = subprocess.run([sys.executable, str(scripts/'brief-check.py'), str(external), '--write', '--class', '跨模块', '--plan-dir', str(scene)], cwd=cwd, capture_output=True, text=True, timeout=20)
        assert r.returncode == 0, r.stderr
check('C2/C3 全半角冒号、反引号、空格路径与 bases 四级查找', paths)

def baseline_init():
    repo = tmp / 'main repo'; repo.mkdir()
    subprocess.run(['git', 'init', '-q', str(repo)], check=True, timeout=10)
    subprocess.run(['git', '-C', str(repo), '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--allow-empty', '-qm', 'init'], check=True, timeout=10)
    wt = tmp / 'slot'
    subprocess.run(['git', '-C', str(repo), 'worktree', 'add', '-qb', 'slot', str(wt)], check=True, timeout=10)
    ordinary = tmp / 'non-git'
    ai = Path(os.environ['RURUCODE_ROOT']) / 'AI任务/roadstar/old'
    sessions = [repo / 'docs/roadstar/old', ordinary / 'docs/roadstar/old', ai]
    for p in sessions:
        p.mkdir(parents=True)
    config = Path(os.environ['ROADSTAR_CONFIG_DIR'])
    (config / 'projects.txt').write_text(str(wt) + '\n' + str(ordinary) + '\n' + str(repo) + '\n')
    cmd = [sys.executable, str(scripts/'brief-check.py'), '--init-design-baseline']
    r = subprocess.run(cmd + ['--dry-run'], capture_output=True, text=True, timeout=20)
    assert r.returncode == 0 and '新增 3 条，总计 3 条' in r.stdout, r
    assert not baselines.path('design-exempt').exists()
    for expected in ['新增 3 条，总计 3 条', '新增 0 条，总计 3 条']:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        assert r.returncode == 0 and expected in r.stdout, r
    assert all(baselines.listed('design-exempt', p) for p in sessions)
    assert not baselines.listed('design-exempt', wt / 'docs/roadstar/old')
check('C4 基线 dry-run 不写；主仓/非 git/AI 场次收集；重复不增加', baseline_init)

def dex():
    for text, expected in [(base, '缺设计页'), (reference, '缺主人点头记录')]:
        brief.write_text(text)
        design.write_text(page('大活'))
        cmd = ['bash', str(scripts/'dex-exec.sh'), str(session), 'T1', '--model', 'x', '--effort', 'high', '--class', '跨模块', '--est-minutes', '90', '--write', '--dry-run', '--brief', str(brief)]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        assert r.returncode == 2 and expected in r.stderr, (cmd, r.returncode, r.stdout, r.stderr)
        assert not (session/'rounds/exec-T1.meta').exists()
    # 保证短活豁免参数确实从 dex-exec 传给 brief-check。
    r = subprocess.run(['bash', str(scripts/'dex-exec.sh'), str(session), 'T1', '--model', 'x', '--effort', 'high', '--class', '批量', '--est-minutes', '60', '--write', '--dry-run', '--brief', str(brief)], capture_output=True, text=True, timeout=20)
    assert r.returncode == 0, r.stderr
check('C6/C9 dex-exec --write --dry-run 两种缺项均退出 2；短活放行', dex)

# 给原样搬来的写沙箱回归准备有效的中活设计，旧断言不改。
fixture = tmp / 'plan dir/fixture-design.md'; fixture.write_text(page())
with (tmp / 'plan dir/brief.md').open('a') as handle:
    handle.write('\n设计页：`fixture-design.md`\n')
(tmp/'new-count').write_text(str(count))
PY
COUNT="$(cat "$TMP/new-count")"
run_task() {
  bash "$SCRIPTS/dex-exec.sh" "$PLAN" "$1" --model gpt-6-astra --effort high --brief "$BRIEF" "${@:2}"
}
run_task T9b --write --root "$PLAN" > "$TMP/write.txt"
grep -q '^sandbox=workspace-write$' "$PLAN/rounds/exec-T9b.meta"
python3 - "$PLAN/rounds/exec-T9b.meta" "$PLAN" <<'PY'
import os, sys
d = dict(line.rstrip("\n").split("=", 1) for line in open(sys.argv[1], encoding="utf-8"))
assert os.path.samefile(d["root"], sys.argv[2]), d
PY
pass 'T9b task ID, write sandbox and explicit root'
printf 'PASS %d checks\n' "$COUNT"
