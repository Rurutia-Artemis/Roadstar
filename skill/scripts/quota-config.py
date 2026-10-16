#!/usr/bin/env python3
"""Read and write ~/.config/roadstar/quota.json (standard library only).

Keys (nothing else is accepted; no API budget in 1.12):
  default_strategy   auto | quality | thrift | rush      默认策略，开场回车就用它
  try_new_models     true | false                        试新型号开关（Luna、grok-4.7-build-fast 接取证和批量试用）
  grok_plan          free | plus | premium | super | ultra | null   grok.com 订阅档位（自报，只决定上限）
  grace.enabled      true | false                        调研类活交 Grace
  grace.folder       文本                                Google Drive 交接目录
"""

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile


STRATEGIES = ("auto", "quality", "thrift", "rush")
GROK_PLANS = ("free", "plus", "premium", "super", "ultra")
DEFAULTS = {
    "schema": 1,
    "default_strategy": "auto",
    "try_new_models": False,
    "grok_plan": None,
    "grace": {"enabled": True, "folder": "Grace × Cloud 交接 / 05-Roadstar 引路星"},
}
LABELS = {"auto": "自动分配", "quality": "质量优先", "thrift": "省着用", "rush": "赶时间"}


def config_path():
    return Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser() / "quota.json"


def load(path):
    """Return (config, exists).  Missing or broken files fall back to defaults."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return json.loads(json.dumps(DEFAULTS)), False
    except (OSError, ValueError):
        return json.loads(json.dumps(DEFAULTS)), False
    merged = json.loads(json.dumps(DEFAULTS))
    if isinstance(data, dict):
        for key, value in data.items():
            if key == "grace" and isinstance(value, dict):
                merged["grace"].update({k: v for k, v in value.items() if k in merged["grace"]})
            elif key in merged:
                merged[key] = value
    merged["default_strategy"] = merged["default_strategy"] if merged["default_strategy"] in STRATEGIES else "auto"
    merged["try_new_models"] = bool(merged["try_new_models"])
    merged["grok_plan"] = merged["grok_plan"] if merged["grok_plan"] in GROK_PLANS else None
    merged["grace"]["enabled"] = bool(merged["grace"]["enabled"])
    return merged, True


def save(path, config):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, prefix=".quota.", suffix=".tmp", delete=False)
    try:
        with handle:
            json.dump(config, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(handle.name, path)
    except BaseException:
        try:
            os.unlink(handle.name)
        except OSError:
            pass
        raise


def parse_bool(value):
    lowered = value.strip().lower()
    if lowered in ("true", "1", "yes", "on", "开", "是"):
        return True
    if lowered in ("false", "0", "no", "off", "关", "否"):
        return False
    raise ValueError("要 true 或 false")


def apply(config, key, value):
    if key == "default_strategy":
        if value not in STRATEGIES:
            raise ValueError("default_strategy 只收 auto / quality / thrift / rush")
        config[key] = value
    elif key == "try_new_models":
        config[key] = parse_bool(value)
    elif key == "grok_plan":
        if value in ("null", "none", "", "未填"):
            config[key] = None
        elif value in GROK_PLANS:
            config[key] = value
        else:
            raise ValueError("grok_plan 只收 free / plus / premium / super / ultra / null")
    elif key == "grace.enabled":
        config["grace"]["enabled"] = parse_bool(value)
    elif key == "grace.folder":
        if not value.strip() or "\n" in value:
            raise ValueError("grace.folder 要一行文本")
        config["grace"]["folder"] = value.strip()
    else:
        raise KeyError(key)


def show(config, exists, as_json):
    if as_json:
        print(json.dumps({**config, "exists": exists}, ensure_ascii=False))
        return
    state = "" if exists else "（还没建文件，下面是默认值；说「填额度」或跑 init 建）"
    print(f"quota.json{state}")
    print(f"默认策略：{LABELS[config['default_strategy']]}（{config['default_strategy']}）")
    print(f"试新型号：{'开' if config['try_new_models'] else '关'}")
    print(f"Grok 档位：{config['grok_plan'] or '未填'}（自报）")
    grace = config["grace"]
    print(f"Grace：{'接调研活' if grace['enabled'] else '不接'}；交接目录 {grace['folder']}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="读写 quota.json（默认策略、试新型号、Grok 档位、Grace）")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init", help="建文件（已存在不改）")
    shower = sub.add_parser("show", help="显示（文件不存在也不报错）")
    shower.add_argument("--json", action="store_true")
    setter = sub.add_parser("set", help="改一个键")
    setter.add_argument("key")
    setter.add_argument("value")
    args = parser.parse_args(argv)
    path = config_path()
    config, exists = load(path)
    if args.command == "init":
        if exists:
            print(f"已有 {path}")
            return 0
        save(path, config)
        print(f"已建 {path}")
        return 0
    if args.command == "show":
        show(config, exists, args.json)
        return 0
    try:
        apply(config, args.key, args.value)
    except KeyError:
        print(f"未知键：{args.key}；只收 default_strategy、try_new_models、grok_plan、grace.enabled、grace.folder", file=sys.stderr)
        return 2
    except ValueError as error:
        print(f"值无效：{error}", file=sys.stderr)
        return 2
    try:
        save(path, config)
    except OSError as error:
        print(f"写入失败：{error}", file=sys.stderr)
        return 1
    print(f"已写 {args.key}={json.dumps(config['grace'][args.key[6:]] if args.key.startswith('grace.') else config[args.key], ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
