#!/usr/bin/env python3
"""跳过开关记账（2026-11-10）：检查的开关设成 0 时跳过，但每次都往 skip-log.tsv 记一行并在 stderr 说一句。
Python 里用 skipped(检查名, 开关名, 项目根)；bash 里用 `python3 skiplog.py <检查名> <开关名> [项目根] [说明]`，
退出 0 表示开关是 0、已记账、调用方应跳过；退出 1 表示照常检查。账在 $ROADSTAR_CONFIG_DIR（默认 ~/.config/roadstar）/skip-log.tsv，
每行：时间、检查名、开关名、项目根、当前目录、说明（制表符分隔）。
"""
import datetime
import os
from pathlib import Path
import sys


def log_path():
    return Path(os.environ.get('ROADSTAR_CONFIG_DIR') or '~/.config/roadstar').expanduser() / 'skip-log.tsv'


def record(check, switch, root='', note=''):
    path = log_path()
    fields = (datetime.datetime.now().astimezone().isoformat(timespec='seconds'), check, switch, root, os.getcwd(), note)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('a', encoding='utf-8') as handle:
            handle.write('\t'.join(str(v).replace('\t', ' ').replace('\n', ' ') for v in fields) + '\n')
    except OSError as exc:
        print(f'{check}：记账失败，不跳过，照常检查（{exc}）', file=sys.stderr)
        return False
    print(f'{check}：{switch}=0，这次跳过（记在 {path}）', file=sys.stderr)
    return True


def skipped(check, switch, root='', note=''):
    if os.environ.get(switch) != '0':
        return False
    return record(check, switch, root, note)


if __name__ == '__main__':
    args = sys.argv[1:]
    if not 2 <= len(args) <= 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(0 if skipped(*args) else 1)
