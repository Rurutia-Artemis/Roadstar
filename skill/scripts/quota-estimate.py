#!/usr/bin/env python3
"""Turn probe readings into "how many pieces can still be dispatched" (standard library only).

Reads quota-status.py --json, providers.json, quota.json and the local
estimates.json, then writes one JSON that panel.py renders verbatim.  Every
number the panel shows is a field here, including pre-formatted reset times.

Units: 1 standard piece (件) = one page-implementation lane on 6.1 Sol / high
or Sonnet.  points_per_unit comes from the local calibration (tokens per
weekly point × tokens per piece) when available, otherwise from the default
in providers.json; uncalibrated numbers are marked 约 with confidence 低 and
the raw percentage points are always given next to them.
"""

import argparse
from datetime import datetime
import json
import math
import os
import re
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rs_tasks as rs  # noqa: E402


LABELS = {"claude": "Claude", "codex": "Codex", "grok": "Grok"}
PLAN_LABEL = {"max": "Max 订阅", "pro": "Pro 订阅", "plus": "Plus 订阅", "team": "Team 订阅", "free": "免费"}
CONFIDENCE_RANK = {"高": 3, "中": 2, "低": 1, "无": 0}
TIER_RANK = {"宽": 0, "正常": 1, "紧": 2, "空": 3}
STRATEGY_LABEL = {"auto": "自动分配", "quality": "质量优先", "thrift": "省着用", "rush": "赶时间"}
HEADROOM = 90  # 留一成底，现有规矩


def skill_version():
    try:
        text = (Path(__file__).resolve().parent.parent / "SKILL.md").read_text(encoding="utf-8")
        match = re.search(r'version:\s*"([^"]+)"', text)
        return match.group(1) if match else "unknown"
    except OSError:
        return "unknown"


def run_probe():
    script = Path(__file__).resolve().parent / "quota-status.py"
    result = subprocess.run([sys.executable, str(script), "--json"], capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def load_config():
    path = rs.config_dir() / "quota.json"
    defaults = {"default_strategy": "auto", "try_new_models": False, "grok_plan": None,
                "grace": {"enabled": True, "folder": "Grace × Cloud 交接 / 05-Roadstar 引路星"}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        exists = True
    except (OSError, ValueError):
        return defaults, False
    if isinstance(data, dict):
        for key in ("default_strategy", "try_new_models", "grok_plan"):
            if key in data:
                defaults[key] = data[key]
        if isinstance(data.get("grace"), dict):
            defaults["grace"].update(data["grace"])
    if defaults["default_strategy"] not in STRATEGY_LABEL:
        defaults["default_strategy"] = "auto"
    return defaults, exists


def window_text(window, label, with_date):
    if not window:
        return None
    reset = rs.parse_iso(window["resets_at"])
    return f"{label} {window['used']:g}%（{rs.fmt_jst(reset, with_date)}）"


def points_per_unit(family_key, providers, local, defaults):
    """(value, calibrated, source).  Local calibration beats the default."""
    family_id = {"claude": "anthropic", "codex": "openai", "grok": "xai"}[family_key]
    local_family = (local.get("providers") or {}).get(family_key) if isinstance(local, dict) else None
    unit_tokens = defaults.get("standard_unit_tokens", 35000)
    cell = (local.get("cells") or {}).get("页面实现|gpt-6.1-sol|high") if isinstance(local, dict) else None
    if isinstance(cell, dict) and cell.get("p50_tokens"):
        unit_tokens = cell["p50_tokens"]
    if isinstance(local_family, dict) and local_family.get("calibrated") and local_family.get("tokens_per_point"):
        return unit_tokens / local_family["tokens_per_point"], True, "本机校准（token 累计反推）"
    spec = providers["families"].get(family_id, {}).get("points_per_unit") or {}
    return spec.get("value"), False, spec.get("source") or "默认"


def probe_reason(probe_notes, label):
    for note in probe_notes or []:
        if isinstance(note, str) and note.startswith(label):
            inner = note[len(label):].strip("（）() ")
            return inner or None
    return None


def side_estimate(key, side, providers, local, defaults, now, probe_notes=None):
    label = LABELS[key]
    connected = side.get("source") in ("live", "rollout")
    result = {"label": label, "connected": connected, "source": side.get("source"), "tier": side.get("tier"),
              "plan": side.get("plan"), "plan_text": PLAN_LABEL.get(side.get("plan") or "", side.get("plan") or "订阅"),
              "available_points": None, "weekly_used": None, "points_per_unit": None, "calibrated": False,
              "coefficient_source": None, "units": None, "units_text": None, "unlockable_units": None,
              "unlockable_points": None, "unlockable_text": None, "confidence": "无", "reading_text": None,
              "reset_text": None, "reset_at": None, "reset_jst": None, "note": None, "lines": []}
    if key == "claude":
        weekly, five = side.get("seven_day"), side.get("five_hour")
        parts = [window_text(five, "5h", False), window_text(weekly, "周", True)]
        fable = side.get("fable")
        if fable:
            result["fable_used"] = fable["used"]
            parts.append(f"Fable {fable['used']:g}%")
            result["lines"].append("Fable 单列上限是周额度一半，只影响主会话")
    else:
        weekly, five = side.get("weekly"), side.get("five_hour")
        parts = [window_text(weekly, "周", True), window_text(five, "5h", False) or ("5h 读不到" if side.get("source") == "live" else None)]
    parts = [part for part in parts if part]
    if not connected:
        result["note"] = probe_reason(probe_notes, label) or side.get("note") or ("本机没有 Codex" if key == "codex" else "未登录")
        result["reading_text"] = f"读不到（{result['note']}）"
        result["tier"] = None
        result["tier_text"] = "读不到，按紧处理"
        return result
    result["tier_text"] = side.get("tier") or "？"
    result["reading_text"] = ("｜".join(parts) if parts else "读不到") + f" → {result['tier_text']}"
    if weekly:
        result["weekly_used"] = weekly["used"]
        result["available_points"] = max(0, HEADROOM - weekly["used"])
        reset = rs.parse_iso(weekly["resets_at"])
        result["reset_at"] = weekly["resets_at"]
        result["reset_jst"] = rs.fmt_jst(reset, True)
        result["reset_text"] = f"{label} {result['reset_jst']}"
    value, calibrated, source = points_per_unit(key, providers, local, defaults)
    result.update({"points_per_unit": value, "calibrated": calibrated, "coefficient_source": source})
    if result["available_points"] is not None and value:
        result["units"] = int(math.floor(result["available_points"] / value))
        result["units_text"] = f"{'' if calibrated else '约 '}{result['units']} 件"
        result["confidence"] = ("高" if calibrated else "低") if side.get("source") == "live" else "中" if calibrated else "低"
    elif result["available_points"] is not None:
        result["units_text"] = f"{result['available_points']} 点"
        result["confidence"] = "低"
    cards = side.get("reset_cards")
    if key == "codex" and isinstance(cards, int) and cards > 0:
        result["unlockable_points"] = cards * HEADROOM
        result["reset_cards"] = cards
        if value:
            result["unlockable_units"] = int(math.floor(cards * HEADROOM / value))
            result["unlockable_text"] = f"重置卡 {cards} 张（解锁{'' if calibrated else '约'} {result['unlockable_units']} 件）"
        else:
            result["unlockable_text"] = f"重置卡 {cards} 张（可解锁 {result['unlockable_points']} 点）"
    if key == "codex" and side.get("credits") is not None:
        result["credits"] = True
        result["lines"].append("credits 有，动真钱先问你")
    if key == "codex" and result["unlockable_text"]:
        result["lines"].insert(0, result["unlockable_text"])
        result["lines"] = ["｜".join(result["lines"])]
    if side.get("source") == "rollout":
        result["lines"].append("Codex 是本地记录，不是实时读数")
    return result


def grok_estimate(grok, config):
    result = {"label": "Grok", "connected": grok.get("source") == "live", "logged_in": grok.get("logged_in"),
              "models": grok.get("models") or [], "default_model": grok.get("default_model"),
              "plan_text": "grok.com", "self_reported_plan": config.get("grok_plan"),
              "units": None, "units_text": None, "confidence": "无", "tier_text": "？", "note": grok.get("note")}
    if result["connected"]:
        result["reading_text"] = f"已登录 {result['default_model'] or result['models'][0]}；额度读不到（CLI 无接口） → ？"
    else:
        result["reading_text"] = f"读不到（{grok.get('note') or '未接入'}） → ？"
    result["self_reported_text"] = f"自报 {config.get('grok_plan') or '未填'}"
    return result


def session_cost(kind, rounds, size, strategy, providers, defaults, strategies, codex):
    """Codex points for the discussion phase: feature map calls + review rounds."""
    strategy_spec = strategies["strategies"][strategy]
    rounds = rounds or (strategy_spec["review_rounds_large"] if size == "大" else strategy_spec["review_rounds"])
    def head(text):
        return re.split(r"[；;，,（(]", text, maxsplit=1)[0]
    review_text = head(strategies["classes"]["审方案"][strategy]["exec"])
    map_text = head(strategies["classes"]["功能地图"][strategy]["exec"])
    reviewer = rs.normalize_model(review_text) or "gpt-6-astra"
    effort = rs.normalize_effort(review_text, "high")
    mapper = rs.normalize_model(map_text) or "gpt-6-astra"
    map_effort = rs.normalize_effort(map_text, "high")
    base = defaults["default_minutes"]["页面实现"]
    effort_mult = providers["effort_multiplier"]
    review_units = (rs.unit_multiplier(providers, reviewer) or 1) * effort_mult.get(effort, 1) * defaults["default_minutes"]["审方案"] / base
    map_units = (rs.unit_multiplier(providers, mapper) or 1) * effort_mult.get(map_effort, 1) * defaults["default_minutes"]["功能地图"] / base
    map_calls = 2 if (kind == "探讨" and strategy_spec.get("feature_map_review", True)) else (1 if kind == "探讨" else 0)
    units = review_units * rounds + map_units * map_calls
    ppu = codex.get("points_per_unit")
    points = units * ppu if ppu else None
    minutes = rounds * (defaults["default_minutes"]["探讨审稿"]) + map_calls * (defaults["default_minutes"]["功能地图"] + defaults["argo_minutes"]["feature_map"] / 2)
    available = codex.get("available_points")
    enough = None if points is None or available is None else points <= available
    return {"kind": kind, "strategy": strategy, "rounds": rounds, "feature_map_calls": map_calls, "reviewer": reviewer, "reviewer_label": rs.executor_label(reviewer, effort),
            "codex_units": round(units, 1), "codex_units_text": f"约 {int(round(units))} 件",
            "codex_points": None if points is None else round(points, 1),
            "codex_points_text": "待校准" if points is None else f"约 +{max(1, int(math.ceil(points)))} 点",
            "minutes": int(round(minutes)), "minutes_text": f"{rs.fmt_minutes(minutes * 0.8)} 到 {rs.fmt_minutes(minutes * 1.2)}",
            "claude_five_hour_text": "主会话只按 5 小时窗观察，不折件", "enough": enough,
            "enough_text": "够" if enough else ("不够：先停下来问" if enough is False else "系数待校准，按百分点看")}


def plan_cost(tasks, strategy, providers, defaults, local, estimates):
    """Per-family points for a split table, plus where the quota would run short."""
    effort_mult = providers["effort_multiplier"]
    base = defaults["default_minutes"]["页面实现"]
    totals = {"claude": 0.0, "codex": 0.0}
    rows = []
    shortfall = {}
    for index, task in enumerate(tasks, 1):
        units = 0.0
        family = rs.family_of(task["model"])
        if family in totals:
            minutes, _, _ = rs.estimate_minutes(task["class"], task["model"], task["effort"] or "medium", defaults, local)
            units = (rs.unit_multiplier(providers, task["model"]) or 1) * effort_mult.get(task["effort"] or "medium", 1) * minutes / (base * defaults.get("buffer", 1.3))
            totals[family] += units
            side = estimates.get(family) or {}
            if family not in shortfall and side.get("available_points") is not None and side.get("points_per_unit"):
                if totals[family] * side["points_per_unit"] > side["available_points"]:
                    shortfall[family] = index
        review_family = rs.family_of(task.get("reviewer"))
        if review_family in totals:
            review_units = (rs.unit_multiplier(providers, task["reviewer"]) or 1) * defaults["default_minutes"]["复核"] / base
            totals[review_family] += review_units
        rows.append({"id": task["id"], "family": family, "units": round(units, 2)})
    out = {"tasks": rows, "totals": {}, "shortfall": shortfall}
    for family, units in totals.items():
        side = estimates.get(family) or {}
        ppu = side.get("points_per_unit")
        points = units * ppu if ppu else None
        used = side.get("weekly_used")
        out["totals"][family] = {
            "units": round(units, 1), "points": None if points is None else round(points, 1),
            "text": (f"{LABELS[family]} 本周预计 {used:g}% → 约 {min(100, int(round(used + points)))}%" if points is not None and used is not None
                     else f"{LABELS[family]} 约 {int(round(units))} 件（系数待校准）"),
            "enough": None if points is None or side.get("available_points") is None else points <= side["available_points"]}
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description="按读数估各家还能派几件、这场够不够")
    parser.add_argument("--probe", type=Path, help="quota-status.py --json 的输出文件；不给就现跑探针")
    parser.add_argument("--providers", type=Path)
    parser.add_argument("--defaults", type=Path, help="默认值表（references/estimates.json）")
    parser.add_argument("--estimates", type=Path, help="本机校准表（默认 <配置目录>/estimates.json）")
    parser.add_argument("--strategies", type=Path)
    parser.add_argument("--strategy", choices=sorted(STRATEGY_LABEL), help="覆盖 quota.json 的默认策略（只管本场）")
    parser.add_argument("--session", choices=["探讨", "复盘", "协同", "续接"], help="算这场讨论阶段的消耗")
    parser.add_argument("--rounds", type=int)
    parser.add_argument("--size", choices=["小", "中", "大"], default="中")
    parser.add_argument("--plan", type=Path, help="含拆分表的 plan.md 或纪要，算执行阶段够不够")
    parser.add_argument("--now", help="ISO 时间（测试用）")
    args = parser.parse_args(argv)
    try:
        probe = json.loads(args.probe.read_text(encoding="utf-8")) if args.probe else run_probe()
        providers = rs.load_providers(args.providers)
        defaults = rs.load_defaults(args.defaults)
        strategies = rs.load_strategies(args.strategies)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"读不到输入：{error}", file=sys.stderr)
        return 2
    local = rs.load_local_estimates(args.estimates)
    config, config_exists = load_config()
    strategy = args.strategy or config["default_strategy"]
    now = rs.parse_iso(args.now) if args.now else datetime.now(rs.UTC)
    estimates = {key: side_estimate(key, probe.get(key) or {}, providers, local, defaults, now, probe.get("note")) for key in ("claude", "codex")}
    estimates["grok"] = grok_estimate(probe.get("grok") or {}, config)
    api_present = (probe.get("api_keys") or {}).get("present") or []
    family_labels = {name: spec["label"] for name, spec in providers["families"].items()}
    included = [key for key in ("claude", "codex") if estimates[key]["units"] is not None]
    total_units = sum(estimates[key]["units"] for key in included)
    confidences = [estimates[key]["confidence"] for key in ("claude", "codex") if estimates[key]["connected"]]
    confidence = min(confidences, key=CONFIDENCE_RANK.get) if confidences else "无"
    calibrated = all(estimates[key]["calibrated"] for key in included) if included else False
    connected = [key for key in ("claude", "codex", "grok") if estimates[key]["connected"]]
    points_only = [key for key in ("claude", "codex") if estimates[key]["connected"] and estimates[key]["units"] is None and estimates[key]["available_points"] is not None]
    unlock_units = estimates["codex"].get("unlockable_units")
    report = {
        "skill_version": skill_version(),
        "generated_at": rs.fmt_jst(now, True) + " JST",
        "generated_iso": now.isoformat(timespec="seconds"),
        "strategy": strategy, "strategy_label": STRATEGY_LABEL[strategy],
        "strategy_from": "命令行" if args.strategy else ("quota.json" if config_exists else "默认"),
        "config_exists": config_exists, "try_new_models": bool(config.get("try_new_models")),
        "providers": estimates,
        "connected_count": len(connected), "connected": connected,
        "connected_text": f"接了 {len(connected)} 家（{'、'.join(LABELS[key] for key in connected)}）" if connected else "一家都没接上",
        "api_keys": {"present": api_present, "labels": [family_labels.get(key, key) for key in api_present],
                     "text": ("有：" + "、".join(family_labels.get(key, key) for key in api_present) + "（只记有无，1.12 不派 API）") if api_present else "无"},
        "grace": {"enabled": bool(config["grace"].get("enabled", True)), "folder": config["grace"].get("folder"),
                  "role": providers["partners"]["grace"]["role"], "text": "调研类活交 Grace（不按额度折件）" if config["grace"].get("enabled", True) else "本机关闭"},
        "total": {"units": total_units if included else None, "included": included, "confidence": confidence, "calibrated": calibrated,
                  "units_text": (f"现有{'' if calibrated else '约'} {total_units} 件" if included else "件数待校准"),
                  "points_only": points_only,
                  "unlockable_units": unlock_units, "unlockable_text": (f"可解锁 +{unlock_units} 件（刷重置卡）" if unlock_units else None),
                  "resets": [estimates[key]["reset_text"] for key in ("claude", "codex") if estimates[key].get("reset_text")],
                  "resets_text": ("回满：" + "、".join(estimates[key]["reset_text"] for key in ("claude", "codex") if estimates[key].get("reset_text"))) or None},
        "probe": probe,
    }
    if args.session:
        report["session"] = session_cost(args.session, args.rounds, args.size, strategy, providers, defaults, strategies, estimates["codex"])
    if args.plan:
        try:
            tasks = rs.parse_tasks_markdown(args.plan.read_text(encoding="utf-8"))
        except OSError as error:
            print(f"读不到拆分表：{error}", file=sys.stderr)
            return 2
        report["plan"] = plan_cost(tasks, strategy, providers, defaults, local, estimates)
    print(json.dumps(report, ensure_ascii=False, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
