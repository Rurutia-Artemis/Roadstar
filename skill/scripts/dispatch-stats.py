#!/usr/bin/env python3
"""Summarize deduplicated Roadstar dispatch metadata using only local files."""

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import fcntl
import json
import math
import os
from pathlib import Path
import sys
import unicodedata


FAMILIES = (("haiku", "sonnet", "opus", "fable"), ("gpt-6.1-sol", "gpt-6-astra"))


def config_dir():
    path = Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser()
    path.mkdir(parents=True, exist_ok=True)
    return path


def register_project(project):
    project = os.path.abspath(project.expanduser())
    if "\n" in project or "\r" in project:
        raise ValueError("项目路径不能包含换行")
    # Lock the file itself so concurrent dispatches keep every project, in order.
    with (config_dir() / "projects.txt").open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        projects = list(dict.fromkeys(os.path.abspath(Path(line.rstrip("\r\n")).expanduser())
                                     for line in handle if line.strip()))
        existed = project in projects
        if not existed:
            projects.append(project)
        handle.seek(0)
        handle.truncate()
        handle.write("".join(value + "\n" for value in projects))
    return project, existed


def default_roots():
    registry = config_dir() / "projects.txt"
    projects = registry.read_text(encoding="utf-8").splitlines() if registry.exists() else []
    projects += os.environ.get("ROADSTAR_PROJECTS", "").split(":")
    projects = list(dict.fromkeys(Path(os.path.abspath(Path(value).expanduser()))
                                 for value in projects if value.strip()))
    return projects, [project / "docs/roadstar" for project in projects
                      if (project / "docs/roadstar").is_dir()]


def normalize_model(value):
    lowered = value.lower()
    for model in FAMILIES[0]:
        if model in lowered:
            return model
    return value


def model_order(model):
    for family, models in enumerate(FAMILIES):
        if model in models:
            return family, models.index(model), model
    return len(FAMILIES), 0, model


def positive_int(value):
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("样本门槛必须为正整数") from exc
    if number < 1:
        raise argparse.ArgumentTypeError("样本门槛必须为正整数")
    return number


def iso_time(value):
    at = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if at.tzinfo is None:
        at = at.replace(tzinfo=timezone.utc)
    return at.astimezone(timezone.utc)


def duration(record):
    try:
        value = float(record["minutes"])
        if math.isfinite(value) and value >= 0:
            return value
    except (KeyError, ValueError):
        pass
    try:
        value = (iso_time(record["finished"]) - iso_time(record["started"])).total_seconds() / 60
        return value if value >= 0 else None
    except (KeyError, ValueError, OverflowError):
        return None


def collect(roots):
    seen, records = set(), []
    paths = sorted({path for root in roots for path in root.rglob("exec-*.meta")
                    if path.parent.name == "rounds" and path.is_file()})
    for path in paths:
        content = path.read_bytes()
        record = {}
        for line in content.decode("utf-8").splitlines():
            key, sep, value = line.partition("=")
            if sep and key.strip():
                record[key.strip()] = value.strip()
        session = record.get("session_id")
        identity = ("session", session) if session else ("sha1", hashlib.sha1(content).hexdigest())
        if identity in seen:
            continue
        seen.add(identity)
        records.append(record)
    return records


def summarize(records, min_samples):
    grouped = defaultdict(list)
    for record in records:
        key = (record.get("class") or "未分类",
               normalize_model(record.get("model") or "未知"), record.get("effort") or "未知")
        grouped[key].append(record)
    result = []
    for (category, model, effort), rows in sorted(
            grouped.items(), key=lambda entry: (entry[0][0], model_order(entry[0][1]), entry[0][2])):
        count = len(rows)
        outcomes = [row["outcome"] for row in rows if row.get("outcome")]
        completed = outcomes.count("done") / len(outcomes) if outcomes else None
        stalled = outcomes.count("stalled") / len(outcomes) if outcomes else None
        escalated = sum(bool(row.get("escalated_to")) for row in rows) / count
        durations = [value for row in rows if (value := duration(row)) is not None]
        if count < min_samples:
            recommendation = "样本不足"
        elif completed is None:
            recommendation = "待补验收"
        elif completed < 0.6 or stalled > 0.3:
            recommendation = "起步层该升"
        elif completed >= 0.9:
            recommendation = "可作起步层"
        else:
            recommendation = "继续观察"
        result.append({"class": category, "model": model, "effort": effort,
                       "count": count, "outcome_count": len(outcomes),
                       "completion_rate": completed, "stall_rate": stalled,
                       "escalation_rate": escalated,
                       "average_minutes": sum(durations) / len(durations) if durations else None,
                       "recommendation": recommendation})
    return result


def print_table(groups):
    def percent(value):
        return "—" if value is None else f"{value:.1%}"

    def width(value):
        return sum(2 if unicodedata.east_asian_width(char) in "WF" else 1 for char in value)

    rows = [["类别", "型号", "强度", "次数", "有结果", "完成率", "碰壁率", "升级率", "平均分钟", "建议"]]
    for group in groups:
        average = group["average_minutes"]
        rows.append([group["class"], group["model"], group["effort"], str(group["count"]),
                     str(group["outcome_count"]), percent(group["completion_rate"]),
                     percent(group["stall_rate"]), percent(group["escalation_rate"]),
                     "—" if average is None else f"{average:.1f}", group["recommendation"]])
    widths = [max(width(row[column]) for row in rows) for column in range(len(rows[0]))]
    for row in rows:
        print("  ".join(value + " " * (size - width(value)) for value, size in zip(row, widths)).rstrip())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("roots", nargs="*", type=lambda value: Path(value).expanduser())
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--min-samples", type=positive_int, default=5)
    parser.add_argument("--register", type=Path, metavar="目录")
    args = parser.parse_args(argv)
    if args.register is not None:
        if not args.register.expanduser().is_dir():
            parser.error(f"项目目录不存在或不是目录：{args.register}")
        try:
            project, existed = register_project(args.register)
        except (OSError, UnicodeError, ValueError) as exc:
            print(f"登记失败：{exc}", file=sys.stderr)
            return 1
        print(f"{'已在登记表里' if existed else '已登记'} {project}")
        return 0
    roots = args.roots
    if not roots:
        try:
            projects, roots = default_roots()
        except (OSError, UnicodeError) as exc:
            parser.error(str(exc))
        if not projects:
            print("还没有登记过项目，派过一次活或用 --register 登记后再看")
            return 0
    for root in roots:
        if not root.is_dir():
            parser.error(f"根目录不存在或不是目录：{root}")
    try:
        records = collect(roots)
    except (OSError, UnicodeError) as exc:
        parser.error(str(exc))
    groups = summarize(records, args.min_samples)
    if args.json:
        print(json.dumps({"total_records": len(records), "groups": groups}, ensure_ascii=False))
    else:
        print_table(groups)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
