#!/bin/bash
# 保留 run.sh 原有两条套件调用；source 分支沿用主套件的变量和计数。
if [[ "${1:-}" == --legacy ]]; then
  source "$TEST_DIR/guard-rules-tests.sh" --legacy
  bash "$TEST_DIR/review-tests.sh"
  return
fi
set -euo pipefail
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roadstar-trailer-path.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1
python3 - "$SCRIPTS" "$TMP" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

scripts, temp = map(Path, sys.argv[1:])
guard = scripts / 'guard.py'
env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'ROADSTAR_'))}
env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
           GIT_EDITOR='true', GIT_TERMINAL_PROMPT='0', LC_ALL='C',
           ROADSTAR_CONFIG_DIR=str(temp / 'config'))
count = 0


def run(root, *args, expected=0):
    result = subprocess.run(list(map(str, args)), cwd=root, env=env, text=True, capture_output=True)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    return result


def git(root, *args, **kw):
    return run(root, 'git', *args, **kw)


def call(root, *args, **kw):
    return run(root, 'python3', guard, *args, **kw)


def write(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding='utf-8')
    return path


def passed(description):
    global count
    count += 1
    print('ok %d - %s' % (count, description), flush=True)


# 含空格、非 ASCII 和双引号，验证 porcelain -z 不受 Git 路径引用影响。
base = temp.resolve() / '两个仓库 " space'
base.mkdir()
main, selene = base / 'RuruAgent', base / 'Selene'
for root in (main, selene):
    root.mkdir()
    git(root, 'init', '-q', '--template=', '-b', 'main')
    git(root, 'config', 'user.name', 'Trailer Test')
    git(root, 'config', 'user.email', 'trailer@example.invalid')
    write(root / 'file.txt', 'initial\n')
    git(root, 'add', '.')
    git(root, 'commit', '-qm', 'initial')
slot = base / 'RuruAgent-slots/s4'
git(main, 'worktree', 'add', '-qb', 'brain/t26', slot)
relative = '../../Selene/docs/roadstar/review'
plan = selene / 'docs/roadstar/review'
rounds = plan / 'rounds'
write(rounds / 'exec-T26-request.md', '## 涉及模块\n无地图\n')
record = write(rounds / 'check-T26.md', '已验收\n')
run(main, 'bash', scripts / 'install-guard.sh', main)
write(slot / 'file.txt', 'from slot\n')
git(slot, 'add', 'file.txt')
git(slot, 'commit', '-qm', 'legacy commit\n\nRoadstar-Task: ' + relative + '/T26')
oid = git(slot, 'rev-parse', 'HEAD').stdout.strip()
passed('副本旧相对尾注能找到另一仓库的任务书并真实提交')

call(main, 'check-merge', 'brain/t26')
git(main, 'merge', '--no-ff', '--no-edit', 'brain/t26')
assert len(git(main, 'rev-list', '--parents', '-n', '1', 'HEAD').stdout.split()) == 3
assert git(slot, 'rev-parse', 'HEAD').stdout.strip() == oid
passed('主目录真实合并通过，已有分支提交历史不变')

# 后续分支保留旧尾注，逐项改变目录／记录状态，无须重写任何提交。
write(slot / 'file.txt', 'second change\n')
git(slot, 'add', 'file.txt')
git(slot, 'commit', '-qm', 'legacy second\n\nRoadstar-Task: ' + relative + '/T26')
record.unlink()
error = call(main, 'check-merge', 'brain/t26', expected=1).stderr
assert '没有验收记录' in error and str(record) in error and '解析不出来' not in error, error
error = git(main, 'merge', '--no-ff', '--no-edit', 'brain/t26', expected=1).stderr
assert '没有验收记录' in error and '解析不出来' not in error, error
git(main, 'merge', '--abort')
passed('目录存在但缺验收时，准确报缺验收记录')

hidden = plan.with_name('hidden')
plan.rename(hidden)
error = call(main, 'check-merge', 'brain/t26', expected=1).stderr
main_candidate = (main / relative).resolve()
assert '场次目录解析不出来：' + relative + '/T26；试过：' in error, error
for path in (main_candidate, plan):
    assert str(path) + '（不存在）' in error, error
assert '没有验收记录' not in error
message = write(temp / 'message', 'legacy\n\nRoadstar-Task: ' + relative + '/T26\n')
assert '场次目录解析不出来' in call(slot, 'hook', 'commit-msg', message, expected=1).stderr
hidden.rename(plan)
passed('零候选时提交和合并均报解析失败，列出主目录与副本候选路径')

main_candidate.mkdir(parents=True)
write(record, '副本候选里已有验收\n')
error = call(main, 'check-merge', 'brain/t26', expected=1).stderr
assert '没有验收记录' in error and str(main_candidate / 'rounds/check-T26.md') in error, error
assert '解析不出来' not in error
error = call(slot, 'hook', 'commit-msg', message, expected=1).stderr
assert '找不到这件活的任务书' in error and str(main_candidate / 'rounds/exec-T26-request.md') in error, error
write(main_candidate / 'rounds/exec-T26-request.md', '## 涉及模块\n无地图\n')
call(slot, 'hook', 'commit-msg', message)
write(main_candidate / 'rounds/check-T26.md', '主目录验收\n')
call(main, 'check-merge', 'brain/t26')
passed('主目录与副本都有场次目录时用主目录，缺任务书或验收也不回退副本')
main_candidate.rename(main_candidate.with_name('not-a-candidate'))

# 第二个同深度副本拼出相同绝对路径，只算一个候选。
other_slot = base / 'RuruAgent-slots/s3'
git(main, 'worktree', 'add', '-qb', 'other-slot', other_slot)
write(record, '已验收\n')
call(main, 'check-merge', 'brain/t26')
passed('多个副本指向同一个实际目录时去重，不误判歧义')

# 主目录候选不存在；不同深度的副本拼出第二个实际目录才算歧义。
deep_slot = base / 'deep/worktrees/s2'
git(main, 'worktree', 'add', '-qb', 'deep-slot', deep_slot)
alternative = (deep_slot / relative).resolve()
write(alternative / 'rounds/exec-T26-request.md', '## 涉及模块\n无地图\n')
error = call(main, 'check-merge', 'brain/t26', expected=1).stderr
assert str(main_candidate) + '（不存在）' in error, error
for path in (plan, alternative):
    assert str(path) + '（存在）' in error, error
assert error.count(str(plan) + '（存在）') == 1, error
assert '场次目录解析不出来' in error and '没有验收记录' not in error
assert '场次目录解析不出来' in call(slot, 'hook', 'commit-msg', message, expected=1).stderr
passed('主目录不存在、两个不同副本候选存在时拦下，列出全部去重候选')
write(message, 'absolute\n\nRoadstar-Task: ' + str(plan / 'T26') + '\n')
call(slot, 'hook', 'commit-msg', message)
passed('绝对尾注直接定位，旧相对尾注的候选歧义不影响它')
alternative.rename(alternative.with_name('not-a-candidate'))

link = base / 'session-link'
link.symlink_to(plan, target_is_directory=True)
call(slot, 'mark', link, 'T26')
gitdir = Path(git(slot, 'rev-parse', '--path-format=absolute', '--git-dir').stdout.strip())
markfile = gitdir / 'roadstar-task'
data = json.loads(markfile.read_text())
assert data['plan_dir'] == str(plan.resolve()), data
write(slot / 'file.txt', 'new absolute commit\n')
git(slot, 'add', 'file.txt')
git(slot, 'commit', '-qm', 'new mark')
expected = 'Roadstar-Task: ' + str(plan / 'T26')
assert expected in git(slot, 'log', '-1', '--format=%B').stdout
call(main, 'check-merge', 'brain/t26')
passed('mark 解开符号链接写 realpath，新提交 prepare 尾注为绝对路径且可合并')

data['plan_dir'] = relative
markfile.write_text(json.dumps(data))
write(message, 'old mark\n')
for _ in range(2):
    call(slot, 'hook', 'prepare-commit-msg', message)
assert message.read_text().count(expected) == 1, message.read_text()
passed('旧相对标记经 prepare 统一解析为绝对尾注，重复执行不重复追加')

missing = base / 'missing-plan'
write(message, 'bad absolute\n\nRoadstar-Task: ' + str(missing / 'T26') + '\n')
error = call(slot, 'hook', 'commit-msg', message, expected=1).stderr
assert '计划目录不存在：' + str(missing) in error and '没有验收记录' not in error
write(message, 'bad task\n\nRoadstar-Task: ' + str(plan / 'not-a-task') + '\n')
assert 'Roadstar-Task 写法不对' in call(slot, 'hook', 'commit-msg', message, expected=1).stderr
passed('不存在的绝对目录准确报错，末段非任务号仍拒绝')

# 下游 guard_rules 的降标准五查也必须读取解析后的外仓验收记录。
call(slot, 'unmark')
write(slot / '.github/workflows/ci.yml', 'name: check\n')
git(slot, 'add', '.github/workflows/ci.yml')
git(slot, 'commit', '-qm', 'workflow\n\nRoadstar-Task: ' + relative + '/T26')
error = call(main, 'check-merge', 'brain/t26', expected=1).stderr
assert '降标准的改动' in error and '.github/workflows/ci.yml' in error, error
write(record, '已验收\n\n## 降标准五查\n.github/workflows/ci.yml 已检查\n')
call(main, 'check-merge', 'brain/t26')
passed('下游降标准检查读取同一解析结果，缺点名拦下、补点名放行')

# 副本内场次永远映射到主目录同位置；四个入口共用同一步归一化。
mapped_main = temp.resolve() / 'mapped-main'
mapped_main.mkdir()
git(mapped_main, 'init', '-q', '--template=', '-b', 'main')
git(mapped_main, 'config', 'user.name', 'Trailer Test')
git(mapped_main, 'config', 'user.email', 'trailer@example.invalid')
mapped_relative = 'docs/roadstar/mapped'
main_plan = mapped_main / mapped_relative
write(main_plan / 'rounds/exec-T31-request.md', '## 涉及模块\n无地图\n')
write(mapped_main / 'file.txt', 'initial\n')
git(mapped_main, 'add', '.')
git(mapped_main, 'commit', '-qm', 'initial')
mapped_slot = temp.resolve() / 'mapped-slots/s1'
git(mapped_main, 'worktree', 'add', '-qb', 'mapped-task', mapped_slot)
slot_plan = mapped_slot / mapped_relative
run(mapped_main, 'bash', scripts / 'install-guard.sh', mapped_main)
call(mapped_slot, 'mark', mapped_relative, 'T31')
mapped_gitdir = Path(git(mapped_slot, 'rev-parse', '--path-format=absolute', '--git-dir').stdout.strip())
mapped_mark = mapped_gitdir / 'roadstar-task'
assert json.loads(mapped_mark.read_text())['plan_dir'] == str(main_plan), mapped_mark.read_text()
write(mapped_slot / 'file.txt', 'mapped commit\n')
git(mapped_slot, 'add', 'file.txt')
git(mapped_slot, 'commit', '-qm', 'mapped mark')
assert 'Roadstar-Task: ' + str(main_plan / 'T31') in git(mapped_slot, 'log', '-1', '--format=%B').stdout
passed('副本 cwd 用副本场次打标记，mark 与真实提交尾注均写主目录路径')

legacy = json.loads(mapped_mark.read_text())
legacy['plan_dir'] = str(slot_plan)
mapped_mark.write_text(json.dumps(legacy))
write(message, 'legacy absolute mark\n')
call(mapped_slot, 'hook', 'prepare-commit-msg', message)
assert 'Roadstar-Task: ' + str(main_plan / 'T31') in message.read_text()
call(mapped_slot, 'unmark')
# 副本任务书缺失，commit-msg 必须读取主目录版本。
(slot_plan / 'rounds/exec-T31-request.md').unlink()
git(mapped_slot, 'commit', '--allow-empty', '-qm', 'legacy slot trailer\n\nRoadstar-Task: ' + str(slot_plan / 'T31'))
passed('prepare 迁移旧副本绝对标记，commit-msg 读取主目录任务书')

slot_record = write(slot_plan / 'rounds/check-T31.md', '只有副本验收\n')
main_record = main_plan / 'rounds/check-T31.md'
error = call(mapped_main, 'check-merge', 'mapped-task', expected=1).stderr
assert '没有验收记录' in error and str(main_record) in error, error
assert str(slot_record) not in error, error
error = git(mapped_main, 'merge', '--no-ff', '--no-edit', 'mapped-task', expected=1).stderr
assert '没有验收记录' in error and str(main_record) in error, error
git(mapped_main, 'merge', '--abort')
slot_record.unlink()
write(main_record, '主目录验收\n')
call(mapped_main, 'check-merge', 'mapped-task')
git(mapped_main, 'merge', '--no-ff', '--no-edit', 'mapped-task')
passed('主目录合并只认主目录验收，副本独有验收拦下，主目录独有验收放行')

for value in ('/T1', '//T1', '/./T1'):
    write(message, 'root plan\n\nRoadstar-Task: ' + value + '\n')
    error = call(main, 'hook', 'commit-msg', message, expected=1).stderr
    assert 'Roadstar-Task 写法不对' in error and '/rounds/check-' not in error, error
assert 'Roadstar-Task 写法不对' in call(mapped_slot, 'mark', '/', 'T1', expected=1).stderr
legacy['plan_dir'], legacy['task'] = '/', 'T1'
mapped_mark.write_text(json.dumps(legacy))
write(message, 'root mark\n')
assert 'Roadstar-Task 写法不对' in call(mapped_slot, 'hook', 'prepare-commit-msg', message, expected=1).stderr
call(mapped_slot, 'unmark')
git(mapped_slot, 'commit', '--allow-empty', '-qm', 'root task\n\nRoadstar-Task: /T1', expected=1)
passed('根目录 plan 在 mark、prepare、commit-msg 均直接拒绝')

# 收工检查只报告尾注原值，不解析或改写它；两个未合并分支各保留一个任务。
close_main = temp.resolve() / 'close-main'
close_main.mkdir()
git(close_main, 'init', '-q', '--template=', '-b', 'main')
git(close_main, 'config', 'user.name', 'Trailer Test')
git(close_main, 'config', 'user.email', 'trailer@example.invalid')
git(close_main, 'commit', '--allow-empty', '-qm', 'initial')
absolute_plan = str(close_main / 'raw/../absolute-plan')
for branch, label, task in (('lane-relative', 'docs/roadstar/relative', 'T41'),
                            ('lane-absolute', absolute_plan, 'T42')):
    git(close_main, 'checkout', '-qb', branch, 'main')
    git(close_main, 'commit', '--allow-empty', '-qm', 'pending\n\nRoadstar-Task: ' + label + '/' + task)
git(close_main, 'checkout', '-q', 'main')
result = run(close_main, 'python3', scripts / 'cleanup.py', '--project', close_main,
             '--check', '--json', expected=1)
items = json.loads(result.stdout)['items']
assert len(items) == 2 and all(item['kind'] == 'unmerged_task' for item in items), items
assert {(i['branch'], i['plan_dir'], i['task'], i['commits']) for i in items} == {
    ('lane-relative', 'docs/roadstar/relative', 'T41', 1),
    ('lane-absolute', absolute_plan, 'T42', 1)}, items
text = run(close_main, 'python3', scripts / 'cleanup.py', '--project', close_main,
           '--check', expected=1).stdout
assert 'T41（docs/roadstar/relative）' in text and 'T42（' + absolute_plan + '）' in text, text
passed('close_check 同时列出相对和绝对尾注的两条未合并任务，plan 原样显示')
git(close_main, 'checkout', '-qb', 'root-task', 'main')
git(close_main, 'commit', '--allow-empty', '-qm', 'old root task\n\nRoadstar-Task: /T1')
git(close_main, 'checkout', '-q', 'main')
error = call(close_main, 'check-merge', 'root-task', expected=1).stderr
assert 'Roadstar-Task 写法不对' in error and '/rounds/check-' not in error, error
passed('合并读取已有 /T1 坏提交时直接报写法错误')
print('PASS %d checks' % count)
PY
