#!/usr/bin/env python3
"""Shared helpers for quota-estimate.py, schedule.py and panel.py (standard library only).

Parses the plan §10 split table (markdown), normalizes model names and efforts,
and loads the default and local estimate tables.  Importing this module has no
side effects.
"""

from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import unicodedata


HERE = Path(__file__).resolve().parent
REFERENCES = HERE.parent / "references"
JST = timezone(timedelta(hours=9), "JST")
UTC = timezone.utc
CLASSES = ("取证", "批量", "页面实现", "窄回归", "跨模块", "根因", "性能", "视觉照做", "复核", "审方案", "补全", "功能地图", "探讨审稿")
FAMILY_OF = {"haiku": "claude", "sonnet": "claude", "opus": "claude", "fable": "claude",
             "gpt-6.1-sol": "codex", "gpt-6-astra": "codex", "gpt-6-luna": "codex",
             "grok": "grok", "argo": "argo", "chair": "chair", "grace": "grace", "pro": "pro"}
MODEL_LABEL = {"haiku": "Haiku", "sonnet": "Sonnet", "opus": "Opus", "fable": "Fable",
               "gpt-6.1-sol": "6.1 Sol", "gpt-6-astra": "Astra", "gpt-6-luna": "Luna",
               "grok": "Grok", "argo": "我", "chair": "你", "grace": "Grace", "pro": "网页 Pro"}
EFFORT_LABEL = {"low": "低", "medium": "中", "high": "高", "xhigh": "很高", "max": "max", "ultra": "ultra"}
_MODEL_PATTERNS = (
    (re.compile(r"astra", re.I), "gpt-6-astra"),
    (re.compile(r"6\.1\s*sol|gpt-6\.1-sol|\bsol\b", re.I), "gpt-6.1-sol"),
    (re.compile(r"luna", re.I), "gpt-6-luna"),
    (re.compile(r"haiku", re.I), "haiku"),
    (re.compile(r"sonnet", re.I), "sonnet"),
    (re.compile(r"opus", re.I), "opus"),
    (re.compile(r"fable", re.I), "fable"),
    (re.compile(r"grok", re.I), "grok"),
    (re.compile(r"grace", re.I), "grace"),
    (re.compile(r"网页\s*pro|\bpro\b", re.I), "pro"),
    (re.compile(r"^(我|argo)\b|^我[（(]|^我$|argo", re.I), "argo"),
    (re.compile(r"^你|主席|你点头", re.I), "chair"),
)
_EFFORT_PATTERNS = (
    (re.compile(r"很高|xhigh", re.I), "xhigh"),
    (re.compile(r"ultra", re.I), "ultra"),
    (re.compile(r"\bmax\b", re.I), "max"),
    (re.compile(r"(?<![a-z])high|·\s*高|/\s*高|\s高(?![a-z])", re.I), "high"),
    (re.compile(r"medium|·\s*中|/\s*中|\s中(?![a-z])", re.I), "medium"),
    (re.compile(r"(?<![a-z])low|·\s*低|/\s*低|\s低(?![a-z])", re.I), "low"),
)


def normalize_model(text):
    """Map any human or CLI spelling to a model key; None when nothing matches."""
    if not text:
        return None
    for pattern, key in _MODEL_PATTERNS:
        if pattern.search(text):
            return key
    return None


def normalize_effort(text, default=None):
    if not text:
        return default
    for pattern, key in _EFFORT_PATTERNS:
        if pattern.search(text):
            return key
    return default


def family_of(model):
    return FAMILY_OF.get(model)


def executor_label(model, effort=None):
    label = MODEL_LABEL.get(model, model or "待定")
    family = family_of(model)
    if family == "codex":
        label = f"Codex 的 {label}"
    if effort and family == "codex":
        label += f" · {EFFORT_LABEL.get(effort, effort)}"
    return label


def normalize_class(text):
    if not text:
        return None
    text = text.strip()
    if text in CLASSES:
        return text
    aliases = {"页面": "页面实现", "实现": "页面实现", "功能": "页面实现", "回归": "窄回归", "修 bug": "窄回归",
               "底座": "跨模块", "合并": "跨模块", "根因诊断": "根因", "视觉": "视觉照做", "照做": "视觉照做",
               "审稿": "审方案", "调研": "取证", "扫描": "取证"}
    for key, value in aliases.items():
        if key in text:
            return value
    return None


def parse_duration(text):
    """'3h15' / '45 分' / '1.5h' / '90' / '2 小时' → minutes (int) or None."""
    if not text:
        return None
    text = text.strip().replace("小时", "h").replace("分钟", "分")
    match = re.match(r"^(\d+(?:\.\d+)?)\s*h\s*(\d+)?$", text)
    if match:
        return int(round(float(match.group(1)) * 60 + int(match.group(2) or 0)))
    match = re.match(r"^(\d+(?:\.\d+)?)\s*分?$", text)
    if match:
        return int(round(float(match.group(1))))
    return None


def split_row(line):
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return cells


def parse_tasks_markdown(text):
    """Find the split table in a plan or minutes and return task dicts.

    Header cells are matched by meaning so both the plan §10 layout and the
    minutes layout work: id (T#/#), name (任务/事), class (类别), executor
    (执行方/给谁), cap (上限), reviewer (审查人/谁审), deps (依赖), est (预估),
    reason (理由/为什么).
    """
    lines = text.splitlines()
    tasks = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.strip().startswith("|") and index + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{2,}", lines[index + 1]):
            header = [re.sub(r"\s+", "", cell) for cell in split_row(line)]
            columns = {}
            for position, cell in enumerate(header):
                if cell in ("T#", "#", "编号") and "id" not in columns:
                    columns["id"] = position
                elif any(word in cell for word in ("任务", "事")) and "name" not in columns and "任务书" not in cell:
                    columns["name"] = position
                elif "类别" in cell:
                    columns["class"] = position
                elif any(word in cell for word in ("执行方", "给谁")):
                    columns["executor"] = position
                elif "上限" in cell:
                    columns["cap"] = position
                elif any(word in cell for word in ("审查", "谁审")):
                    columns["reviewer"] = position
                elif "依赖" in cell:
                    columns["deps"] = position
                elif "预估" in cell or "多久" in cell:
                    columns["est"] = position
                elif any(word in cell for word in ("理由", "为什么")):
                    columns["reason"] = position
                elif "模块" in cell:
                    columns["module"] = position
            if "name" in columns and "executor" in columns:
                index += 2
                while index < len(lines) and lines[index].strip().startswith("|"):
                    cells = split_row(lines[index])
                    def cell(key):
                        position = columns.get(key)
                        return cells[position] if position is not None and position < len(cells) else ""
                    name = cell("name")
                    if name and not set(name) <= set("-: "):
                        tasks.append(task_from_cells(cell("id") or f"T{len(tasks) + 1}", name, cell("class"), cell("executor"),
                                                     cell("cap"), cell("reviewer"), cell("deps"), cell("est"), cell("reason"), cell("module")))
                    index += 1
                if tasks:
                    return tasks
                continue
        index += 1
    return tasks


def task_from_cells(task_id, name, klass, executor, cap, reviewer, deps, est, reason, module=""):
    task_id = re.sub(r"[^A-Za-z0-9]", "", task_id) or task_id
    if re.fullmatch(r"\d+", task_id):
        task_id = f"T{task_id}"
    dependencies = []
    for token in re.split(r"[，,、\s;；]+", deps or ""):
        token = token.strip()
        if not token or token in ("无", "—", "-", "none"):
            continue
        token = re.sub(r"[^A-Za-z0-9]", "", token)
        if re.fullmatch(r"\d+", token):
            token = f"T{token}"
        if token:
            dependencies.append(token)
    model = normalize_model(executor)
    effort = normalize_effort(executor)
    return {"id": task_id, "name": name, "class": normalize_class(klass) or guess_class(name, model),
            "class_text": klass, "executor_text": executor, "model": model, "effort": effort,
            "reviewer_text": reviewer, "reviewer": normalize_model(reviewer), "deps": dependencies,
            "cap_minutes": parse_duration(cap), "est_minutes": parse_duration(est), "reason": reason, "module": module}


def guess_class(name, model):
    lowered = name.lower()
    for word, klass in (("取证", "取证"), ("扫", "取证"), ("批量", "批量"), ("改名", "批量"), ("回归", "窄回归"), ("修", "窄回归"),
                        ("合并", "跨模块"), ("底座", "跨模块"), ("数据层", "跨模块"), ("根因", "根因"), ("性能", "性能"),
                        ("样张", "视觉照做"), ("复核", "复核"), ("审", "审方案"), ("补全", "补全"), ("页面", "页面实现")):
        if word in lowered:
            return klass
    if model in ("gpt-6-astra", "opus"):
        return "跨模块"
    return "页面实现"


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def config_dir():
    return Path(os.environ.get("ROADSTAR_CONFIG_DIR") or "~/.config/roadstar").expanduser()


def load_defaults(path=None):
    return load_json(path or REFERENCES / "estimates.json")


def load_local_estimates(path=None):
    path = Path(path) if path else config_dir() / "estimates.json"
    try:
        data = load_json(path)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def load_providers(path=None):
    return load_json(path or REFERENCES / "providers.json")


def load_strategies(path=None):
    return load_json(path or REFERENCES / "strategies.json")


def unit_multiplier(providers, model):
    ids = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5", "opus": "claude-opus-5-5", "fable": "claude-fable-5-1"}
    wanted = ids.get(model, model)
    for entry in providers.get("models", []):
        if entry["id"] == wanted:
            return entry.get("unit_multiplier")
    return None


def estimate_minutes(task_class, model, effort, defaults, local, strategy_mult=1.0):
    """P50 minutes for one execution lane plus the source of that number.

    Order: local cell (class × model × effort) with ≥10 samples → P80, no buffer;
    local cell with ≥5 samples → P50 × buffer; local model × effort with ≥5 →
    P50 × buffer; default table × effort × model speed × buffer.
    """
    buffer = defaults.get("buffer", 1.3)
    cells = local.get("cells", {}) if isinstance(local, dict) else {}
    cell = cells.get(f"{task_class}|{model}|{effort}")
    if cell and cell.get("count", 0) >= 10 and cell.get("p80_minutes") is not None:
        return cell["p80_minutes"] * strategy_mult, "本机 P80", "高"
    if cell and cell.get("count", 0) >= 5 and cell.get("p50_minutes") is not None:
        return cell["p50_minutes"] * buffer * strategy_mult, "本机 P50", "中"
    cell = cells.get(f"*|{model}|{effort}")
    if cell and cell.get("count", 0) >= 5 and cell.get("p50_minutes") is not None:
        return cell["p50_minutes"] * buffer * strategy_mult, "本机型号 P50", "中"
    base = defaults["default_minutes"].get(task_class, defaults["default_minutes"]["页面实现"])
    effort_mult = defaults["effort_multiplier"].get(effort or "medium", 1.0)
    speed = defaults["model_speed"].get(model, 1.0)
    return base * effort_mult * speed * buffer * strategy_mult, "默认值表", "低"


def fmt_minutes(minutes):
    minutes = int(round(minutes))
    if minutes < 60:
        return f"{minutes} 分"
    hours, rest = divmod(minutes, 60)
    return f"{hours}h{rest:02d}" if rest else f"{hours}h"


def fmt_jst(moment, with_date=False):
    local = moment.astimezone(JST)
    return local.strftime("%m-%d %H:%M" if with_date else "%H:%M")


def parse_iso(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed.replace(tzinfo=UTC) if parsed.tzinfo is None else parsed.astimezone(UTC)


def display_width(text):
    return sum(2 if unicodedata.east_asian_width(char) in "WF" else 1 for char in text)


def pad(text, width):
    return text + " " * max(0, width - display_width(text))
