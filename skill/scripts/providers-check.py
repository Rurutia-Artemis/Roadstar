#!/usr/bin/env python3
"""Validate references/providers.json (standard library only).

Exit 0 when valid, 2 when a required field is missing, a family is unknown or a
value has the wrong shape.  ``--list`` prints the registry as a table.
"""

import argparse
from datetime import date
import json
from pathlib import Path
import sys
import unicodedata


DEFAULT = Path(__file__).resolve().parent.parent / "references" / "providers.json"
ACCESS = {"subscription-cli", "api"}
ROLES = {"主会话", "难活", "复核", "取证", "审方案", "实现", "试用", "不派"}
MODEL_KEYS = ("id", "family", "label", "access", "price", "price_checked", "price_source",
              "context", "max_output", "bench", "default_role", "unit_multiplier", "note")
BENCH_KEYS = ("aa_index", "aa_rank", "lmarena_elo", "tb4", "swe_verified", "checked", "source")
FAMILY_KEYS = ("label", "access", "cli", "api_key_env", "quota_windows", "points_per_unit")


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_date(value):
    try:
        date.fromisoformat(value)
        return True
    except (TypeError, ValueError):
        return False


def check(data):
    problems = []
    if not isinstance(data, dict):
        return ["顶层不是对象"]
    if data.get("schema") != 1:
        problems.append("schema 必须为 1")
    if not is_date(data.get("checked")):
        problems.append("checked 必须是 YYYY-MM-DD")
    families = data.get("families")
    if not isinstance(families, dict) or not families:
        return problems + ["families 缺失或为空"]
    for name, family in families.items():
        for key in FAMILY_KEYS:
            if key not in family:
                problems.append(f"families.{name} 缺 {key}")
        if family.get("access") not in ACCESS:
            problems.append(f"families.{name}.access 无效")
        if not isinstance(family.get("api_key_env"), str) or not family["api_key_env"]:
            problems.append(f"families.{name}.api_key_env 必须是变量名")
        ppu = family.get("points_per_unit")
        if not isinstance(ppu, dict) or "value" not in ppu or "source" not in ppu:
            problems.append(f"families.{name}.points_per_unit 要有 value 和 source")
        elif ppu["value"] is not None and not (is_number(ppu["value"]) and ppu["value"] > 0):
            problems.append(f"families.{name}.points_per_unit.value 必须是正数或 null")
    multipliers = data.get("effort_multiplier")
    if not isinstance(multipliers, dict) or not all(is_number(v) and v > 0 for v in multipliers.values()):
        problems.append("effort_multiplier 必须是正数表")
    partners = data.get("partners")
    if not isinstance(partners, dict) or "grace" not in partners:
        problems.append("partners 缺 grace")
    else:
        for key in ("label", "role", "channel", "convention"):
            if not isinstance(partners["grace"].get(key), str):
                problems.append(f"partners.grace 缺 {key}")
    models = data.get("models")
    if not isinstance(models, list) or not models:
        return problems + ["models 缺失或为空"]
    seen = set()
    for index, model in enumerate(models):
        where = f"models[{index}]"
        if not isinstance(model, dict):
            problems.append(f"{where} 不是对象")
            continue
        where = f"models[{model.get('id', index)}]"
        for key in MODEL_KEYS:
            if key not in model:
                problems.append(f"{where} 缺 {key}")
        if model.get("id") in seen:
            problems.append(f"{where} id 重复")
        seen.add(model.get("id"))
        if model.get("family") not in families:
            problems.append(f"{where} family 未知：{model.get('family')}")
        if model.get("access") not in ACCESS:
            problems.append(f"{where} access 无效")
        if model.get("default_role") not in ROLES:
            problems.append(f"{where} default_role 无效：{model.get('default_role')}")
        price = model.get("price")
        if price is not None:
            if not isinstance(price, dict):
                problems.append(f"{where} price 必须是对象或 null")
            else:
                for key in ("input", "output"):
                    if not is_number(price.get(key)):
                        problems.append(f"{where} price.{key} 必须是数字")
                if price.get("currency") not in {"USD", "CNY"}:
                    problems.append(f"{where} price.currency 必须是 USD 或 CNY")
                if not is_date(model.get("price_checked")):
                    problems.append(f"{where} 有价格就要有 price_checked 日期")
                if not isinstance(model.get("price_source"), str) or not model["price_source"]:
                    problems.append(f"{where} 有价格就要有 price_source")
        for key in ("context", "max_output"):
            value = model.get(key)
            if value is not None and not (isinstance(value, int) and value > 0):
                problems.append(f"{where} {key} 必须是正整数或 null")
        bench = model.get("bench")
        if not isinstance(bench, dict):
            problems.append(f"{where} bench 必须是对象")
        else:
            for key in BENCH_KEYS:
                if key not in bench:
                    problems.append(f"{where} bench 缺 {key}")
            for key in ("aa_index", "aa_rank", "lmarena_elo", "tb4", "swe_verified"):
                value = bench.get(key)
                if value is not None and not is_number(value):
                    problems.append(f"{where} bench.{key} 必须是数字或 null")
            if not is_date(bench.get("checked")):
                problems.append(f"{where} bench.checked 必须是日期")
        multiplier = model.get("unit_multiplier")
        if multiplier is not None and not (is_number(multiplier) and multiplier > 0):
            problems.append(f"{where} unit_multiplier 必须是正数或 null")
    return problems


def width(text):
    return sum(2 if unicodedata.east_asian_width(char) in "WF" else 1 for char in text)


def table(data):
    rows = [["家", "型号", "接法", "输入/输出", "上下文", "AA", "TB4", "默认角色", "倍率"]]
    for model in data["models"]:
        price = model.get("price")
        price_text = "null" if price is None else f"{price['input']:g}/{price['output']:g} {price['currency']}"
        bench = model["bench"]
        rows.append([data["families"][model["family"]]["label"], model["label"], model["access"], price_text,
                     "null" if model["context"] is None else f"{model['context'] // 1000}K",
                     "null" if bench["aa_index"] is None else f"{bench['aa_index']:g}",
                     "null" if bench["tb4"] is None else f"{bench['tb4']:g}",
                     model["default_role"],
                     "null" if model["unit_multiplier"] is None else f"{model['unit_multiplier']:g}"])
    widths = [max(width(row[column]) for row in rows) for column in range(len(rows[0]))]
    for row in rows:
        print("  ".join(cell + " " * (size - width(cell)) for cell, size in zip(row, widths)).rstrip())


def main(argv=None):
    parser = argparse.ArgumentParser(description="校验 providers.json 型号登记表")
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT)
    parser.add_argument("--list", action="store_true", help="打印登记表")
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(f"读不到或不是 JSON：{args.path}（{error}）", file=sys.stderr)
        return 2
    problems = check(data)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 2
    if args.list:
        table(data)
    else:
        print(f"providers.json 合法：{len(data['families'])} 家、{len(data['models'])} 个型号、查证 {data['checked']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
