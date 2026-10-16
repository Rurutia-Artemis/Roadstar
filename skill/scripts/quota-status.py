#!/usr/bin/env python3
"""Read subscription quotas without a model request (Python standard library only).

``pending_tier`` is the persisted candidate for --prev hysteresis.  Keep the
complete --json output between invocations; no state is written by this script.
Codex rollout records are a Codex-only fallback, never a Claude quota source.

1.12 adds two read-only columns, both backward compatible (old keys untouched):
``grok``      ``grok models`` tells login state and the model list; the grok.com
              quota has no CLI interface, so no percentage is ever reported.
``api_keys``  which families' API key environment variables are set, by name
              only (``providers.json`` lists the names). Values are never read
              into the report.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import json
import math
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import tempfile
import time


UTC = timezone.utc
JST = timezone(timedelta(hours=9), "JST")
TIMEOUT = 15
TIERS = {"宽": 0, "正常": 1, "紧": 2, "空": 3}
PROVIDERS_FILE = Path(__file__).resolve().parent.parent / "references" / "providers.json"
# Fallback list when providers.json is unreadable; names only, values never leave the process.
API_KEY_ENV = {"anthropic": "ANTHROPIC_API_KEY", "openai": "OPENAI_API_KEY", "xai": "XAI_API_KEY",
               "deepseek": "DEEPSEEK_API_KEY", "moonshot": "MOONSHOT_API_KEY", "alibaba": "DASHSCOPE_API_KEY",
               "zhipu": "ZHIPUAI_API_KEY", "minimax": "MINIMAX_API_KEY"}


class ProbeError(Exception):
    """A safe diagnostic that never embeds CLI output or account identifiers."""


def instant(value):
    try:
        if isinstance(value, bool):
            return None
        if isinstance(value, (int, float)):
            return datetime.fromtimestamp(value, UTC)
        if isinstance(value, str):
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed.replace(tzinfo=UTC) if parsed.tzinfo is None else parsed.astimezone(UTC)
    except (ValueError, OverflowError, OSError):
        pass
    return None


def iso(value):
    return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def number(value):
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if not math.isfinite(result):
        return None
    return int(result) if result.is_integer() else result


def window(value, used_key, reset_key):
    if not isinstance(value, dict):
        return None
    used = number(value.get(used_key))
    reset = instant(value.get(reset_key))
    if used is None or used < 0 or reset is None:
        return None
    return {"used": used, "resets_at": iso(reset)}


def window_tier(value, hours, now):
    remaining = (instant(value["resets_at"]) - now).total_seconds() / 3600
    elapsed = min(1, max(0, 1 - remaining / hours))
    used = value["used"]
    ahead = used - elapsed * 100
    if used >= 95 and remaining > 6:
        return "空"
    if used >= 85 or ahead >= 15:
        return "紧"
    if (ahead <= -15 and used < 70) or (remaining <= 12 and used < 80):
        return "宽"
    return "正常"


def classify(side, provider, now):
    names = (("five_hour", 5), ("seven_day", 168), ("fable", 168)) if provider == "claude" else (("weekly", 168), ("five_hour", 5))
    tiers = [window_tier(side[key], hours, now) for key, hours in names if side.get(key)]
    return max(tiers, key=TIERS.get) if tiers else None


class JSONSession:
    def __init__(self, command, cwd, env):
        self.deadline = time.monotonic() + TIMEOUT
        self.process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, cwd=cwd, env=env, start_new_session=True,
        )
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer = b""

    def send(self, message):
        try:
            self.process.stdin.write((json.dumps(message) + "\n").encode())
            self.process.stdin.flush()
        except (BrokenPipeError, OSError) as error:
            raise ProbeError("命令提前退出") from error

    def receive(self, matches):
        while True:
            if time.monotonic() >= self.deadline:
                raise ProbeError("读取超时（15 秒）")
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    continue
                if isinstance(message, dict) and matches(message):
                    return message
            if not self.selector.select(max(0, self.deadline - time.monotonic())):
                raise ProbeError("读取超时（15 秒）")
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise ProbeError("命令未返回所需数据")
            self.buffer += chunk
            if len(self.buffer) > 4 * 1024 * 1024:
                raise ProbeError("返回数据过大")

    def close(self):
        try:
            self.process.stdin.close()
        except OSError:
            pass
        # Terminate the private process group as wrappers may spawn a child.
        try:
            os.killpg(self.process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            self.process.wait(timeout=0.2)
        except subprocess.TimeoutExpired:
            pass
        finally:
            # A wrapper may exit before its children. Always clean the private
            # group, even when waiting for the group leader already succeeded.
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        self.process.wait()
        self.selector.close()
        self.process.stdout.close()


def claude_result(body, fetched_at):
    limits = body.get("rate_limits")
    if body.get("rate_limits_available") is not True or not isinstance(limits, dict):
        raise ProbeError("额度不可用或尚未登录")
    five = window(limits.get("five_hour"), "utilization", "resets_at")
    seven = window(limits.get("seven_day"), "utilization", "resets_at")
    # Some versions expose the same two windows only through limits[].
    for item in limits.get("limits") or []:
        if not isinstance(item, dict):
            continue
        if item.get("kind") == "session" and five is None:
            five = window(item, "percent", "resets_at")
        elif item.get("kind") == "weekly_all" and seven is None:
            seven = window(item, "percent", "resets_at")
    fable = None
    for item in limits.get("model_scoped") or []:
        if isinstance(item, dict) and str(item.get("display_name", "")).strip().casefold() == "fable":
            fable = window(item, "utilization", "resets_at")
            if fable:
                break
    if not any((five, seven, fable)):
        raise ProbeError("没有可用的额度窗口")
    return {"five_hour": five, "seven_day": seven, "fable": fable,
            "plan": body.get("subscription_type"), "source": "live", "fetched_at": iso(fetched_at)}


def codex_result(limits, fetched_at, source="live", reset_credits=None):
    if not isinstance(limits, dict):
        raise ProbeError("缺少额度数据")
    result = {"weekly": None, "five_hour": None, "reset_cards": None, "credits": None,
              "plan": limits.get("planType", limits.get("plan_type")),
              "source": source, "fetched_at": iso(fetched_at)}
    for key in ("primary", "secondary"):
        item = limits.get(key)
        if not isinstance(item, dict):
            continue
        minutes = number(item.get("windowDurationMins", item.get("window_minutes")))
        target = {10080: "weekly", 300: "five_hour"}.get(minutes)
        if target:
            parsed = window(item, "usedPercent", "resetsAt") if source == "live" else window(item, "used_percent", "resets_at")
            if parsed:
                result[target] = parsed
    if not any((result["weekly"], result["five_hour"])):
        raise ProbeError("没有可用的额度窗口")
    credits = limits.get("credits")
    if isinstance(credits, dict) and credits.get("hasCredits", credits.get("has_credits")) is True:
        balance = credits.get("balance")
        if isinstance(balance, (str, int, float)) and not isinstance(balance, bool):
            result["credits"] = str(balance)
    if isinstance(reset_credits, dict):
        count = number(reset_credits.get("availableCount"))
        if isinstance(count, int) and count >= 0:
            result["reset_cards"] = count
    return result


def live_probe(provider):
    executable = shutil.which(provider)
    if executable is None:
        raise ProbeError("命令不存在")
    env = os.environ.copy()
    if provider == "claude":
        env["DISABLE_AUTOUPDATER"] = "1"
        args = ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                "--strict-mcp-config", "--no-session-persistence", "--settings", '{"remoteControlAtStartup":false}']
    else:
        args = ["-s", "read-only", "-a", "never", "app-server"]
    with tempfile.TemporaryDirectory(prefix="roadstar-quota-") as cwd:
        session = JSONSession([executable] + args, cwd, env)
        try:
            if provider == "claude":
                def control(request_id, request):
                    session.send({"type": "control_request", "request_id": request_id, "request": request})
                    reply = session.receive(lambda m: m.get("type") == "control_response"
                                            and isinstance(m.get("response"), dict)
                                            and m["response"].get("request_id") == request_id)["response"]
                    if reply.get("subtype") != "success":
                        raise ProbeError("控制请求失败")
                    return reply.get("response")

                control("i1", {"subtype": "initialize"})
                body = control("u1", {"subtype": "get_usage", "skip_behaviors": True})
                if not isinstance(body, dict):
                    raise ProbeError("缺少额度数据")
                return claude_result(body, datetime.now(UTC))
            session.send({"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "roadstar", "version": "1.0"}}})
            initial = session.receive(lambda m: m.get("id") == 1)
            if "error" in initial:
                raise ProbeError("初始化失败")
            session.send({"method": "initialized"})
            session.send({"id": 2, "method": "account/rateLimits/read"})
            response = session.receive(lambda m: m.get("id") == 2)
            if "error" in response:
                raise ProbeError("读取额度失败或尚未登录")
            result = response.get("result")
            if not isinstance(result, dict):
                raise ProbeError("缺少额度数据")
            return codex_result(result.get("rateLimits"), datetime.now(UTC), reset_credits=result.get("rateLimitResetCredits"))
        finally:
            session.close()


def reverse_lines(path):
    """Read the tail first without loading potentially large rollout files."""
    with path.open("rb") as stream:
        position = stream.seek(0, os.SEEK_END)
        buffer = b""
        while position:
            size = min(position, 65536)
            position -= size
            stream.seek(position)
            parts = (stream.read(size) + buffer).split(b"\n")
            buffer = parts[0]
            yield from reversed(parts[1:])
        if buffer:
            yield buffer


def rollout_fallback():
    latest = None
    root = Path.home() / ".codex" / "sessions"
    for path in root.glob("*/*/*/rollout-*.jsonl"):
        try:
            for line in reverse_lines(path):
                if b'"token_count"' not in line or b'"rate_limits"' not in line:
                    continue
                try:
                    event = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    continue
                if not isinstance(event, dict):
                    continue
                payload = event.get("payload", event)
                if not isinstance(payload, dict) or payload.get("type") != "token_count":
                    continue
                stamp = instant(event.get("timestamp")) or datetime.fromtimestamp(path.stat().st_mtime, UTC)
                try:
                    result = codex_result(payload.get("rate_limits"), stamp, source="rollout")
                except ProbeError:
                    continue
                if latest is None or stamp > latest[0]:
                    latest = stamp, result
                break
        except OSError:
            continue
    return latest[1] if latest else None


def api_key_env_names():
    try:
        data = json.loads(PROVIDERS_FILE.read_text(encoding="utf-8"))
        names = {family: spec["api_key_env"] for family, spec in data["families"].items()
                 if isinstance(spec.get("api_key_env"), str) and spec["api_key_env"]}
        if names:
            return names
    except (OSError, ValueError, KeyError, AttributeError, TypeError):
        pass
    return dict(API_KEY_ENV)


def api_keys_probe(environ=None):
    """Report which families have a key set.  Only variable names are inspected."""
    environ = os.environ if environ is None else environ
    names = api_key_env_names()
    present = sorted(family for family, variable in names.items() if environ.get(variable, "").strip())
    return {"present": present, "checked": sorted(names.values())}


def grok_probe():
    """Run ``grok models`` (read-only, no inference).  Never reports a quota."""
    now = datetime.now(UTC)
    result = {"source": "none", "logged_in": None, "default_model": None, "models": [], "fetched_at": iso(now), "note": None}
    executable = shutil.which("grok")
    if executable is None:
        result["note"] = "命令不存在"
        return result
    try:
        process = subprocess.Popen([executable, "models"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    except OSError:
        result["note"] = "命令启动失败"
        return result
    try:
        output, _ = process.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        process.communicate()
        result["note"] = f"读取超时（{TIMEOUT:g} 秒）"
        return result
    text = output.decode("utf-8", "replace")
    models = []
    default = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.lower().startswith("default model:"):
            default = line.split(":", 1)[1].strip() or None
        elif line[:2] in ("* ", "- "):
            name = line[2:].split()[0] if line[2:].split() else ""
            if name:
                models.append(name)
                if line.startswith("*") or "(default)" in line:
                    default = default or name
    logged_in = "logged in" in text.lower() and "not logged in" not in text.lower()
    if process.returncode != 0 and not models:
        result["note"] = "未登录或命令失败"
        result["logged_in"] = False if "log" in text.lower() else None
        return result
    if not models:
        result["note"] = "未登录或没有型号"
        result["logged_in"] = False
        return result
    result.update({"source": "live", "logged_in": logged_in or True, "default_model": default, "models": models})
    return result


def unavailable(provider, now):
    result = {"tier": None, "plan": None, "source": "none", "fetched_at": iso(now)}
    keys = ("five_hour", "seven_day", "fable") if provider == "claude" else ("weekly", "five_hour", "reset_cards", "credits")
    result.update(dict.fromkeys(keys))
    return result


def fetch(provider):
    try:
        return live_probe(provider), None
    except ProbeError as error:
        reason = str(error)
    except (OSError, ValueError, TypeError):
        reason = "命令启动失败或返回格式无效"
    if provider == "codex":
        result = rollout_fallback()
        if result:
            return result, reason
    return unavailable(provider, datetime.now(UTC)), reason


def hysteresis(side, previous, provider, notes):
    current = side["tier"]
    side["pending_tier"] = None
    if current is None or not isinstance(previous, dict):
        return
    old = previous.get("tier")
    if old not in TIERS or previous.get("source") == "none" or current == old:
        return
    if previous.get("pending_tier") == current:
        return
    side["tier"] = old
    side["pending_tier"] = current
    notes.append(f"{provider}：沿用上次档位（{old}）；本次算出{current}，连续两次一致后切换")


def age_text(stamp, now):
    hours = max(0, (now - instant(stamp)).total_seconds() / 3600)
    return f"{hours:.1f} 小时前的记录"


def human_output(report, now, problems):
    def value_text(label, value, weekly=False):
        reset = instant(value["resets_at"]).astimezone(JST)
        pattern = "%m-%d %H:%M" if weekly else "%H:%M"
        return f"{label} {value['used']:g}%（{reset.strftime(pattern)} 重置）"

    for provider, title in (("claude", "Claude"), ("codex", "Codex")):
        side = report[provider]
        parts = []
        if provider == "claude":
            if side["five_hour"]:
                parts.append(value_text("5 小时", side["five_hour"]))
            if side["seven_day"]:
                parts.append(value_text("本周", side["seven_day"], True))
            if side["fable"]:
                parts.append(f"Fable {side['fable']['used']:g}%（上限是周额度一半）")
        else:
            if side["weekly"]:
                parts.append(value_text("本周", side["weekly"], True))
            if side["five_hour"]:
                parts.append(value_text("5 小时", side["five_hour"]))
            if side["reset_cards"] is not None:
                parts.append(f"重置卡 {side['reset_cards']} 张")
            if side["credits"] is not None:
                parts.append(f"credits {side['credits']}")
        print(f"{title}：" + ("｜".join(parts) + f" → {side['tier']}" if parts else "读不到"))
    grok = report.get("grok") or {}
    if grok.get("source") == "live":
        print(f"Grok：已登录 {grok.get('default_model') or grok['models'][0]}（{len(grok['models'])} 个型号）｜额度读不到（CLI 没有接口） → ？")
    else:
        print(f"Grok：读不到（{grok.get('note') or '未接入'}）")
    keys = (report.get("api_keys") or {}).get("present") or []
    print("API key：" + ("有（" + "、".join(keys) + "）；1.12 只记有无，派活不用" if keys else "无"))
    if all(report[key]["source"] == "live" for key in ("claude", "codex")):
        sources = "两边都是实时读数"
    else:
        sources = "，".join(
            f"{title} " + ({"live": "实时读数", "none": "读不到"}.get(report[key]["source"])
                           or age_text(report[key]["fetched_at"], now))
            for key, title in (("claude", "Claude"), ("codex", "Codex"))
        )
    print(f"读数：{now.astimezone(JST).strftime('%Y-%m-%d %H:%M JST')}，{sources}")
    if problems:
        print("读不到：" + "；".join(problems))
    extra = [note for note in report["note"] if note not in problems]
    if extra:
        print("备注：" + "；".join(extra))


def main(argv=None):
    parser = argparse.ArgumentParser(description="只读查询 Claude / Codex 额度；时间以 JST 显示")
    parser.add_argument("--json", action="store_true", help="输出 JSON（含滞回所需 pending_tier）")
    parser.add_argument("--prev", type=Path, help="上一次 --json 输出，用于两次确认后换档")
    args = parser.parse_args(argv)
    notes = []
    previous = {}
    if args.prev:
        try:
            previous = json.loads(args.prev.read_text(encoding="utf-8"))
            if not isinstance(previous, dict):
                raise ValueError("not an object")
        except (OSError, ValueError):
            previous = {}
            notes.append("上次读数无法读取，使用本次档位")
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = {provider: pool.submit(fetch, provider) for provider in ("claude", "codex")}
        grok_future = pool.submit(grok_probe)
        fetched = {provider: future.result() for provider, future in futures.items()}
        grok = grok_future.result()
    now = datetime.now(UTC)
    report = {provider: value[0] for provider, value in fetched.items()}
    report["grok"] = grok
    report["api_keys"] = api_keys_probe()
    problems = []
    for provider, title in (("claude", "Claude"), ("codex", "Codex")):
        side, error = fetched[provider]
        side["tier"] = classify(side, provider, now)
        if side["source"] == "none":
            problems.append(f"{title}（{error}）")
        elif side["source"] == "rollout":
            notes.append(f"Codex 实时读取失败（{error}），使用 {age_text(side['fetched_at'], now)}")
        hysteresis(side, previous.get(provider), title, notes)
    report["note"] = notes + problems
    if args.json:
        print(json.dumps(report, ensure_ascii=False, separators=(",", ":"), allow_nan=False))
    else:
        human_output(report, now, problems)
    return 2 if all(report[key]["source"] == "none" for key in ("claude", "codex")) else 0


if __name__ == "__main__":
    raise SystemExit(main())
