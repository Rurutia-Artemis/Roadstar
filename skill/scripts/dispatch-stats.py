#!/usr/bin/env python3
"""Summarize deduplicated Roadstar dispatch metadata using only local files."""

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import unicodedata


FAMILIES = (("haiku", "sonnet", "opus", "fable"), ("gpt-6.1-sol", "gpt-6-astra"))


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
    args = parser.parse_args(argv)
    roots = args.roots or sorted((Path.home() / "Documents/RuruCode").glob("*/docs/roadstar"))
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
