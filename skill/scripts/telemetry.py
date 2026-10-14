#!/usr/bin/env python3
"""Export consented Roadstar dispatch statistics; failures never block dispatch."""

import argparse
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


CLASSES = ("取证", "批量", "页面实现", "窄回归", "跨模块", "根因", "性能",
           "视觉照做", "复核", "审方案", "补全")
CLAUDE = ("haiku", "sonnet", "opus", "fable")
MODELS = CLAUDE + ("gpt-6.1-sol", "gpt-6-astra", "other")
EFFORTS = ("low", "medium", "high", "xhigh", "max", "ultra", "default")
OUTCOMES = ("done", "partial", "stalled", "failed")
PLANS = ("max", "pro", "plus", "team", "unknown")
KEYS = {"id", "week", "class", "model", "model_version", "effort", "outcome",
        "done_ratio", "minutes", "escalated", "quota_delta", "plan"}
QUOTA = r"(claude|codex)_(week|5h)=[+-]?[0-9]{1,3}"
VERSION = r"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"


def config_dir():
    # Read-only commands and dry runs must not even create this directory.
    return Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser()


def read_config(directory):
    try:
        value = json.loads((directory / "telemetry.json").read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, UnicodeError):
        return {}


def enabled(config):
    return (os.environ.get("ROADSTAR_TELEMETRY") != "0"
            and config.get("enabled") is True and config.get("consent_version") == 1)


def iso_time(value):
    at = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if at.tzinfo is None:
        at = at.replace(tzinfo=timezone.utc)
    return at.astimezone(timezone.utc)


def model_fields(value):
    lowered = value.lower()
    model = next((name for name in CLAUDE if name in lowered),
                 value if value in MODELS else "other")
    # Versions may be written as Claude's dash-separated or display names.
    match = re.search(r"(?<![0-9])[0-9]+(?:[.-][0-9]+)?", lowered)
    version = match.group().replace("-", ".") if match else "unknown"
    return model, version


def rounded_minutes(meta):
    if meta.get("minutes"):
        value = Decimal(meta["minutes"])
    elif meta.get("started") and meta.get("finished"):
        seconds = (iso_time(meta["finished"]) - iso_time(meta["started"])).total_seconds()
        value = Decimal(str(seconds)) / 60
    else:
        value = Decimal(0)
    if not value.is_finite():
        raise ValueError("invalid duration")
    value = min(Decimal(1440), max(Decimal(0), value))
    return int((value / 5).quantize(Decimal(1), rounding=ROUND_HALF_UP)) * 5


def export_record(meta, content, plan):
    identity = meta.get("session_id", "").encode("utf-8") or content
    week = iso_time(meta.get("finished") or meta.get("started", "")).strftime("%G-W%V")
    model, version = model_fields(meta.get("model", ""))
    ratio = Decimal(1 if meta["outcome"] == "done" else 0)
    if meta.get("done_items"):
        if not re.fullmatch(r"[0-9]+/[0-9]+", meta["done_items"]):
            raise ValueError("invalid done_items")
        done, total = map(Decimal, meta["done_items"].split("/"))
        if total == 0 or done > total:
            raise ValueError("invalid done_items")
        ratio = (done / total).quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)
    quota = next((token for line in content.decode("utf-8").splitlines() if "=" in line
                  for token in line.partition("=")[2].split()
                  if re.fullmatch(QUOTA, token)), None)
    return {"id": hashlib.sha1(identity).hexdigest()[:16], "week": week,
            "class": meta["class"], "model": model, "model_version": version,
            "effort": meta.get("effort") if meta.get("effort") in EFFORTS else "default",
            "outcome": meta["outcome"], "done_ratio": float(ratio),
            "minutes": rounded_minutes(meta), "escalated": bool(meta.get("escalated_to")),
            "quota_delta": quota, "plan": plan}


def validate_record(record):
    """Built-in schema-1 validation, including exact keys and JSON value types."""
    if not isinstance(record, dict) or set(record) != KEYS:
        return False
    patterns = {"id": r"[0-9a-f]{16}", "week": r"20[0-9]{2}-W(0[1-9]|[1-4][0-9]|5[0-3])",
                "model_version": r"([0-9]{1,2}(\.[0-9]{1,2})?|unknown)"}
    for key, pattern in patterns.items():
        if not isinstance(record[key], str) or not re.fullmatch(pattern, record[key]):
            return False
    for key, choices in (("class", CLASSES), ("model", MODELS), ("effort", EFFORTS),
                         ("outcome", OUTCOMES), ("plan", PLANS)):
        if record[key] not in choices:
            return False
    return (type(record["done_ratio"]) in (int, float)
            and record["done_ratio"] in [n / 10 for n in range(11)]
            and type(record["minutes"]) is int and 0 <= record["minutes"] <= 1440
            and record["minutes"] % 5 == 0 and type(record["escalated"]) is bool
            and (record["quota_delta"] is None or
                 isinstance(record["quota_delta"], str)
                 and re.fullmatch(QUOTA, record["quota_delta"]) is not None))


def validate_batch(batch):
    return (set(batch) == {"schema", "client", "skill_version", "records"}
            and type(batch["schema"]) is int and batch["schema"] == 1
            and batch["client"] == "roadstar"
            and isinstance(batch["skill_version"], str)
            and re.fullmatch(VERSION, batch["skill_version"]) is not None
            and isinstance(batch["records"], list) and 1 <= len(batch["records"]) <= 200
            and all(validate_record(record) for record in batch["records"]))


def pending(directory, config):
    registry = directory / "projects.txt"
    projects = registry.read_text(encoding="utf-8").splitlines() if registry.exists() else []
    projects += os.environ.get("ROADSTAR_PROJECTS", "").split(":")
    roots = {Path(value).expanduser().resolve() / "docs/roadstar"
             for value in projects if value.strip()}
    paths = sorted({path for root in roots if root.is_dir()
                    for path in root.rglob("exec-*.meta")
                    if path.parent.name == "rounds" and path.is_file()})
    uploaded = directory / "telemetry-uploaded.txt"
    seen = set(uploaded.read_text(encoding="utf-8").splitlines()) if uploaded.exists() else set()
    records = []
    plan = config.get("plan", "unknown")
    for path in paths:
        try:
            content = path.read_bytes()
            meta = {}
            for line in content.decode("utf-8").splitlines():
                key, sep, value = line.partition("=")
                if sep and key.strip():
                    meta[key.strip()] = value.strip()
            if meta.get("class") not in CLASSES or meta.get("outcome") not in OUTCOMES:
                continue
            record = export_record(meta, content, plan)
            if not validate_record(record):
                raise ValueError("schema mismatch")
            if record["id"] not in seen:
                seen.add(record["id"])
                records.append(record)
        except (OSError, UnicodeError, ValueError, ArithmeticError):
            # No raw metadata or paths in diagnostics either.
            print("已丢弃一条不符合 schema 1 的记录", file=sys.stderr)
    return records


def skill_version():
    content = (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")
    frontmatter = content.split("---", 2)[1] if content.startswith("---\n") else ""
    match = re.search(r'^\s*version:\s*[\"\']?(' + VERSION + r')[\"\']?\s*$',
                      frontmatter, re.MULTILINE)
    return match.group(1) if match else "unknown"


def send(directory, config, repo, args):
    if not args.dry_run and not enabled(config):
        return
    records = pending(directory, config)
    if not records:
        if args.dry_run:
            print("[]")
            print("预览：没有待回传记录；未调用 gh，未修改状态", file=sys.stderr)
        return
    version = skill_version()
    batches = []
    for offset in range(0, len(records), 200):
        batch = {"schema": 1, "client": "roadstar", "skill_version": version,
                 "records": records[offset:offset + 200]}
        if not validate_batch(batch):
            print("已丢弃一批不符合 schema 1 的记录", file=sys.stderr)
            continue
        batches.append(batch)
    if args.dry_run:
        # Multiple batches remain one parseable JSON document, not joined objects.
        preview = batches[0] if len(batches) == 1 else batches
        print(json.dumps(preview, ensure_ascii=False, indent=2))
        print(f"预览：共 {sum(len(batch['records']) for batch in batches)} 条；"
              "未调用 gh，未修改状态", file=sys.stderr)
        return
    receipts = []
    for batch in batches:
        payload = json.dumps(batch, ensure_ascii=False, indent=2) + "\n"
        uploads = directory / "uploads"
        uploads.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        backup = uploads / (stamp + ".json")
        backup.write_text(payload, encoding="utf-8")
        title = "dispatch-data · schema 1 · " + max(row["week"] for row in batch["records"])
        try:
            with tempfile.TemporaryDirectory(prefix="roadstar-telemetry-") as temporary:
                body = Path(temporary) / "body.md"
                body.write_text("<!-- roadstar-dispatch-data -->\n```json\n" + payload + "```\n",
                                encoding="utf-8")
                result = subprocess.run(["gh", "issue", "create", "-R", repo, "--title", title,
                                         "--body-file", str(body)], timeout=30,
                                        capture_output=True, text=True)
            if result.returncode:
                reason = f"gh 退出码 {result.returncode}，请检查登录与网络"
            else:
                reason = None
        except FileNotFoundError:
            reason = "没装 gh"
        except subprocess.TimeoutExpired:
            reason = "gh 超时 30 秒"
        except OSError:
            reason = "无法调用 gh"
        if reason:
            print(f"回传没成功（{reason}），下次完工时补传", file=sys.stderr)
            break
        with (directory / "telemetry-uploaded.txt").open("a", encoding="utf-8") as handle:
            handle.writelines(row["id"] + "\n" for row in batch["records"])
        message = f"已回传 {len(batch['records'])} 条，内容见 {backup}"
        receipts.append({"sent": len(batch["records"]), "file": str(backup), "message": message})
        if not args.json:
            print(message)
    if args.json and receipts:
        print(json.dumps({"sent": sum(row["sent"] for row in receipts), "uploads": receipts},
                         ensure_ascii=False))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    commands.add_parser("disable")
    consent = commands.add_parser("enable")
    consent.add_argument("--plan", choices=PLANS, default="unknown")
    sender = commands.add_parser("send")
    sender.add_argument("--dry-run", action="store_true")
    sender.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    directory = config_dir()
    config = read_config(directory)
    repo = os.environ.get("ROADSTAR_TELEMETRY_REPO") or "Rurutia-Artemis/roadstar-data"
    try:
        if args.command in ("enable", "disable"):
            config = {"enabled": args.command == "enable", "consent_version": 1,
                      "decided_at": datetime.now(timezone.utc).isoformat(),
                      "plan": args.plan if args.command == "enable" else "unknown"}
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "telemetry.json").write_text(
                json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        elif args.command == "status":
            state = "已开启" if enabled(config) else "已关闭"
            if not config and os.environ.get("ROADSTAR_TELEMETRY") != "0":
                state = "还没问过"
            print(f"{state}，待回传 {len(pending(directory, config))} 条，目标仓库 {repo}")
        else:
            send(directory, config, repo, args)
    except (OSError, UnicodeError, ValueError, InvalidOperation):
        print("回传没成功（本地数据读写失败），下次完工时补传", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
