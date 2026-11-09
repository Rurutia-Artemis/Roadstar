#!/usr/bin/env python3
"""本机基线与豁免清单（2026-11-10）：各道检查共用，一个名字一份，存 $ROADSTAR_CONFIG_DIR（默认 ~/.config/roadstar）/baselines/<名字>.json。
格式 {"<键>": {"value": <值>, "updated": "<ISO 时间>"}}，原子写。三种用法：
  豁免清单   listed(名字, 路径) / add(名字, [路径…])：路径一律按 realpath 存和比
  只降不升   ratchet(名字, 键, 当前值)：没有旧值写当前值，有就写 min(旧, 当前)，返回写入后的值；get(名字, 键)
  上线时刻   since(名字) / mark_since(名字)：检查只管上线之后的东西（时间戳，没记过返回 None）
命令行：baselines.py show <名字> 打印一行一个键。
"""
import datetime
import json
import os
from pathlib import Path
import sys
import tempfile

SINCE = '_since'


def path(name):
    return Path(os.environ.get('ROADSTAR_CONFIG_DIR') or '~/.config/roadstar').expanduser() / 'baselines' / f'{name}.json'


def load(name):
    try:
        data = json.loads(path(name).read_text(encoding='utf-8'))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(name, data):
    target = path(name)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=target.name + '.')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(data, handle, ensure_ascii=False, indent=1, sort_keys=True)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def get(name, key):
    item = load(name).get(key)
    return item.get('value') if isinstance(item, dict) else None


def listed(name, value):
    return os.path.realpath(value) in load(name)


def add(name, values):
    data, added = load(name), 0
    for value in values:
        key = os.path.realpath(value)
        if key not in data:
            data[key] = {'value': True, 'updated': now()}
            added += 1
    if added:
        save(name, data)
    return added


def ratchet(name, key, value):
    data = load(name)
    old = get(name, key)
    new = value if not isinstance(old, int) else min(old, value)
    if new != old:
        data[key] = {'value': new, 'updated': now()}
        save(name, data)
    return new


def since(name):
    return get(name, SINCE)


def mark_since(name):
    data = load(name)
    data[SINCE] = {'value': datetime.datetime.now().timestamp(), 'updated': now()}
    save(name, data)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] != 'show':
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    for key, item in sorted(load(sys.argv[2]).items()):
        print(f'{key}\t{item.get("value")}\t{item.get("updated")}')
