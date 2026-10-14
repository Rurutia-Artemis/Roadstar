#!/usr/bin/env python3
"""Read a Roadstar progress log without modifying it or stopping any process."""

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path


def iso_time(value):
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"无效 ISO 时间：{value}") from exc
    # Naive ISO times are interpreted as UTC so all comparisons are consistent.
    if result.tzinfo is None:
        result = result.replace(tzinfo=timezone.utc)
    return result.astimezone(timezone.utc)


def minutes(value):
    try:
        result = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("分钟数必须为有限正数") from exc
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError("分钟数必须为有限正数")
    return result


def item_count(value):
    try:
        result = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("检查项总数必须为非负整数") from exc
    if result < 0:
        raise argparse.ArgumentTypeError("检查项总数必须为非负整数")
    return result


def read_progress(path):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return []
    rows = []
    for line in lines:
        fields = line.split("\t", 3)
        if len(fields) != 4:
            continue
        at, item, outcome, evidence = fields
        if not item.strip() or outcome not in ("pass", "fail") or not evidence.strip():
            continue
        try:
            rows.append((iso_time(at), item.strip(), outcome))
        except argparse.ArgumentTypeError:
            continue
    return rows


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("progress", type=Path)
    parser.add_argument("--cap", required=True, type=minutes)
    parser.add_argument("--started", type=iso_time)
    parser.add_argument("--now", type=iso_time)
    parser.add_argument("--idle", type=minutes)
    parser.add_argument("--items", type=item_count)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        rows = read_progress(args.progress)
    except (OSError, UnicodeError) as exc:
        parser.error(str(exc))
    now = args.now or datetime.now(timezone.utc)
    started = args.started or min((row[0] for row in rows), default=now)
    idle = args.idle if args.idle is not None else max(20, args.cap / 4)
    states, failures = {}, {}
    last_pass = None
    # File order defines each item's last result; every pass resets all streaks.
    for at, item, outcome in rows:
        if outcome == "pass":
            failures.clear()
            if states.get(item) != "pass":
                last_pass = max(last_pass, at) if last_pass is not None else at
        else:
            failures[item] = failures.get(item, 0) + 1
        states[item] = outcome
    done = sum(state == "pass" for state in states.values())
    total = args.items if args.items is not None else len(states)
    elapsed = max(0, (now - started).total_seconds() / 60)
    idle_elapsed = max(0, (now - (last_pass or started)).total_seconds() / 60)
    item = next((key for key, count in failures.items() if count >= 3), None)
    if item is not None:
        status, code = "STALL", 10
    elif elapsed >= args.cap * 0.9 and done < total:
        status, code = "WRAP", 12
    elif rows and idle_elapsed > idle:
        status, code = "IDLE", 11
    elif not rows and elapsed > idle:
        status, code = "NOPROGRESS", 13
    else:
        status, code = "OK", 0
    result = {"status": status, "item": item, "done": done, "total": total,
              "elapsed_min": elapsed, "cap_min": args.cap}
    if status == "IDLE":
        result["idle_elapsed_min"] = idle_elapsed
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    elif status == "IDLE":
        print(f"IDLE {idle_elapsed:g}m {done}/{total}")
    elif status == "NOPROGRESS":
        print(f"NOPROGRESS {elapsed:g}m")
    else:
        prefix = f"STALL {item} fail×3" if item is not None else status
        print(f"{prefix} {done}/{total} {elapsed:g}m/{args.cap:g}m")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
