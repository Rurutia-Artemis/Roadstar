#!/usr/bin/env python3
"""派写活前检查接入、未验收存量和主目录未提交改动（仅标准库）。"""
import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

import baselines
import skiplog


def warn(reason):
    print(f'警告：项目入口检查{reason}，这次放行', file=sys.stderr)


def git(root, *args):
    try:
        result = subprocess.run(['git', '-C', str(root), *args],
                                capture_output=True, timeout=20)
        return result.stdout if result.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def main_root(root):
    root = Path(root).expanduser().resolve()
    common = git(root, 'rev-parse', '--path-format=absolute', '--git-common-dir')
    return Path(os.fsdecode(common).strip()).parent.resolve() if common else root


def eligible(root):
    base = Path(os.environ.get('RURUCODE_ROOT') or '~/Documents/RuruCode').expanduser().resolve()
    try:
        relative = root.relative_to(base)
        return not relative.parts or relative.parts[0] != 'AI任务'
    except ValueError:
        return False


def project_data(root, structural=True):
    shell = Path(os.environ.get('PROJECT_SHELL_DIR') or
                 '~/Documents/RuruCode/RuruAgent/tools/project-shell').expanduser()
    check = shell / 'check.py'
    if not check.is_file():
        warn(f'找不到 check.py（{check}）')
        return None
    try:
        result = subprocess.run(['python3', str(check), str(root), '--json'],
                                capture_output=True, text=True, timeout=60)
        data = json.loads(result.stdout)
        if not isinstance(data, dict):
            raise ValueError('输出不是 JSON 对象')
        if structural and 'structural_gaps' not in data:
            raise ValueError('JSON 没有 structural_gaps 字段')
        if 'structural_gaps' in data and not isinstance(data['structural_gaps'], list):
            raise ValueError('structural_gaps 不是列表')
        if not isinstance(data.get('open_tasks', []), list):
            raise ValueError('open_tasks 不是列表')
        return data
    except subprocess.TimeoutExpired:
        warn('运行 check.py 超时（60 秒）')
    except (OSError, ValueError, UnicodeError) as exc:
        warn(f'无法读取 check.py JSON：{exc}')
    return None


def pending(root, data):
    tasks = []
    cutoff = time.time() - 86400
    for item in dict.fromkeys(data.get('open_tasks', [])):
        session, task = item.split('/')
        rounds = root / 'docs/roadstar' / session / 'rounds'
        request = rounds / f'exec-{task}-request.md'
        try:
            modified = request.stat().st_mtime
        except OSError:
            modified = 0
        if not (rounds / f'exec-{task}.exit').exists() and modified >= cutoff:
            continue
        tasks.append((modified, item))
    return [item for _, item in sorted(tasks)]


class DirtyHoursError(ValueError):
    pass


def _stale_hours():
    try:
        hours = float(os.environ.get('ROADSTAR_DIRTY_STALE_HOURS', '24'))
        if not math.isfinite(hours) or hours < 0:
            raise ValueError
        return hours
    except ValueError as exc:
        raise DirtyHoursError('ROADSTAR_DIRTY_STALE_HOURS 不合法') from exc


def dirty(root):
    hours = _stale_hours()
    # -z 保留中文、空格、换行等真实路径；rename 的第二个路径不是另一件改动。
    if git(root, 'rev-parse', '--git-dir') is None:
        return None
    # 先排除场次目录，避免未跟踪的 docs/ 被 Git 合并成一行而误计。
    status = git(root, 'status', '--porcelain', '-z', '--untracked-files=all', '--', '.',
                 ':(exclude)docs/roadstar/')
    if status is None:
        raise OSError('git status 失败')
    entries = iter(os.fsdecode(status).split('\0'))
    paths = []
    for entry in entries:
        if not entry:
            continue
        path = entry[3:]
        names = [path]
        if 'R' in entry[:2] or 'C' in entry[:2]:
            names.append(next(entries))
        if not all(name.startswith('docs/roadstar/') for name in names):
            paths.append(path)
    # 只算积压：24 小时内动过的文件是正在干的活，不计（删掉的文件读不到时间，照算）。
    cutoff = time.time() - hours * 3600

    def stale(path):
        try:
            return os.lstat(Path(root) / path.rstrip('/')).st_mtime < cutoff
        except OSError:
            return True
    return [path for path in paths if stale(path)]


def baseline(name, root, count):
    old = baselines.get(name, str(root))
    return old if isinstance(old, int) else count


def gate(root, dry_run):
    _stale_hours()
    requested = Path(root).expanduser().resolve()
    root = main_root(requested)
    if not eligible(requested):
        print('不在 RuruCode 项目里，跳过接入和存量检查', file=sys.stderr)
        return 0
    data = project_data(root)
    if data is None:
        return 0
    if not skiplog.skipped('接入检查', 'ROADSTAR_PROJECT_CHECK', root):
        gaps = data['structural_gaps']
        if gaps:
            print(f'拒派：{root.name} 接入没齐：{"；".join(gaps)}。先走 split-and-frame 补齐'
                  '（地图格式见 references/project-map.md，自动检查 scripts/install-guard.sh <项目根> --claude），'
                  '再派写活。急事 ROADSTAR_PROJECT_CHECK=0（会记账）。', file=sys.stderr)
            return 3
    counts = []
    if not skiplog.skipped('存量检查', 'ROADSTAR_OPEN_CHECK', root):
        tasks = pending(root, data)
        count = len(tasks)
        limit = max(baseline('open-tasks', root, count), 5)
        if count > limit:
            print(f'拒派：{root.name} 有 {count} 件活做完了还没验收（上限 {limit}）。'
                  '先补验收（写 rounds/check-T<n>.md）或在场次 plan.md 末尾写「## 收尾」说明作废，'
                  f'再派新活。最久的几件：{"；".join(tasks[:10])}', file=sys.stderr)
            return 3
        counts.append(('open-tasks', count))
    if not skiplog.skipped('未提交检查', 'ROADSTAR_DIRTY_CHECK', root):
        paths = dirty(root)
        if paths is not None:
            count = len(paths)
            limit = max(baseline('uncommitted', root, count), 10)
            if count > limit:
                print(f'拒派：{root.name} 主目录有 {count} 个没提交的文件（上限 {limit}，不含 docs/roadstar/，只算 24 小时没动过的）。'
                      f'先提交或清掉再派新活。最先的几个：{"；".join(paths[:10])}', file=sys.stderr)
                return 3
            counts.append(('uncommitted', count))
    if not dry_run:
        for name, count in counts:
            baselines.ratchet(name, str(root), count)
    return 0


def baseline_init(dry_run):
    _stale_hours()
    config = Path(os.environ.get('ROADSTAR_CONFIG_DIR') or '~/.config/roadstar').expanduser()
    registry = config / 'projects.txt'
    if not registry.exists():
        return 0
    seen = set()
    for line in registry.read_text(encoding='utf-8').splitlines():
        if not line.strip() or not Path(line).expanduser().is_dir():
            continue
        root = main_root(line)
        if root in seen or not root.is_dir() or not eligible(root):
            continue
        seen.add(root)
        data = project_data(root, structural=False)
        if data is None:
            continue
        count = len(pending(root, data))
        paths = dirty(root)
        uncommitted = len(paths) if paths is not None else 0
        values = []
        for name, value in (('open-tasks', count), ('uncommitted', uncommitted)):
            values.append(min(baseline(name, root, value), value) if dry_run else
                          baselines.ratchet(name, str(root), value))
        print(f'{root}\t{count}\t{values[0]}\t{uncommitted}\t{values[1]}')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    check = sub.add_parser('gate')
    check.add_argument('root')
    check.add_argument('--dry-run', action='store_true')
    init = sub.add_parser('baseline-init')
    init.add_argument('--dry-run', action='store_true')
    sub.add_parser('show')
    args = parser.parse_args()
    try:
        if args.command == 'gate':
            return gate(args.root, args.dry_run)
        if args.command == 'baseline-init':
            return baseline_init(args.dry_run)
        for name in ('open-tasks', 'uncommitted'):
            for root, item in sorted(baselines.load(name).items()):
                print(f'{name}\t{root}\t{item.get("value")}\t{item.get("updated")}')
        return 0
    except baselines.BaselineError as exc:
        print(f'基线文件坏了：{exc.path}，先修好或删掉再派（删掉等于按现状重记）', file=sys.stderr)
        return 3
    except DirtyHoursError as exc:
        print(str(exc), file=sys.stderr)
        return 3
    except (OSError, ValueError, TypeError) as exc:
        warn(f'失败：{exc}')
        return 0


if __name__ == '__main__':
    sys.exit(main())
