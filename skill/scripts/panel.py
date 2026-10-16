#!/usr/bin/env python3
"""Render the opening screens from quota-estimate.py JSON (standard library only).

Three blocks: the 接入与额度 panel (≤ 14 lines, ≤ 80 display columns), the
本项目分配 preview, and the 探讨开场说明 (only for 探讨).  ``--compact`` prints
the two-line version for 续接 and 协同.  The script copies numbers from the
input JSON and never computes new ones, so every figure on screen can be
traced back to a field (tests/run.sh asserts this).
"""

import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rs_tasks as rs  # noqa: E402


WIDTH = 80
MAX_LINES = 14
STRATEGIES = ("auto", "quality", "thrift", "rush")
STRATEGY_LABEL = {"auto": "自动分配", "quality": "质量优先", "thrift": "省着用", "rush": "赶时间"}
TIGHT = {"紧", "空", None}


def clip(text, width=WIDTH):
    while rs.display_width(text) > width:
        text = text[:-1]
    return text


def row(cells, widths):
    return clip(" " + "  ".join(rs.pad(clip(cell, w), w) for cell, w in zip(cells, widths)).rstrip())


def direction(estimate):
    """Which ladder implementation goes to, whether Claude's standing work retreats, single mode, and whether hard work prefers Opus."""
    codex, claude = estimate["providers"]["codex"], estimate["providers"]["claude"]
    codex_tier = codex.get("tier") if codex.get("connected") else None
    claude_tier = claude.get("tier") if claude.get("connected") else None
    # 重置卡只说明「到顶时能刷」，不等于现在就宽（division-of-labor §4）：空就是空。
    codex_ok = codex_tier in ("宽", "正常") or (codex_tier == "紧" and bool(codex.get("reset_cards")))
    claude_ok = claude_tier in ("宽", "正常")
    if codex.get("connected") and (codex_ok or not claude_ok):
        ladder = "codex"
    elif claude_ok:
        ladder = "claude"
    else:
        ladder = "codex" if codex.get("connected") else "claude"
    single = not codex.get("connected")
    claude_tight = claude_tier in TIGHT and not single
    codex_empty = codex.get("connected") and codex_tier == "空"
    # 主席 10-12 定、10-14 细化：两边都宽时难活优先 Claude 的 Opus（自动分配下）。
    both_wide = codex_tier == "宽" and claude_tier == "宽"
    return ladder, claude_tight, single, both_wide, codex_empty


def panel(estimate, strategy):
    p = estimate["providers"]
    version = ".".join(str(estimate.get("skill_version", "")).split(".")[:2]) or "1.13"
    title = f"Roadstar {version} · {estimate['connected_text']}" + ("＋Grace 调研" if estimate["grace"]["enabled"] else "")
    lines = [clip(rs.pad(title, WIDTH - rs.display_width(estimate["generated_at"])) + estimate["generated_at"]),
             "─" * (WIDTH - 8)]
    widths = [10, 56, 9]
    lines.append(row(["家", "读数（括号是重置时刻）→ 档位", "还能派"], widths))
    claude = p["claude"]
    if claude["connected"]:
        lines.append(row([f"Claude {claude['plan_text'].replace(' 订阅', '')}", claude["reading_text"], claude["units_text"] or "—"], widths))
    else:
        lines.append(row(["Claude", claude["reading_text"] + " → 紧", "按紧处理"], widths))
    codex = p["codex"]
    if codex["connected"]:
        lines.append(row([f"Codex {codex['plan_text'].replace(' 订阅', '')}", codex["reading_text"], codex["units_text"] or "—"], widths))
        for extra in codex["lines"]:
            lines.append(row(["", extra, ""], widths))
    else:
        lines.append(row(["Codex", codex["reading_text"] + " → 单家模式", "—"], widths))
    grok = p["grok"]
    lines.append(row(["Grok", grok["reading_text"], grok["self_reported_text"]], widths))
    lines.append(clip(f" API key  {estimate['api_keys']['text']}"))
    lines.append("─" * (WIDTH - 8))
    total = estimate["total"]
    if total["units"] is not None:
        points = "；".join(f"{p[k]['label']} {p[k]['available_points']} 点可用" for k in total["included"] if p[k].get("available_points") is not None)
        waiting = "；".join(f"{p[k]['label']} {p[k]['available_points']} 点" for k in total["points_only"])
        why = "已校准" if total["calibrated"] else "系数未校准"
        lines.append(clip(f" 这周合计：{total['units_text']}（置信度{total['confidence']}，{why}；{points}{'；' + waiting if waiting else ''}）"))
    elif total["points_only"]:
        lines.append(clip(" 这周合计：件数待校准（" + "；".join(f"{p[k]['label']} {p[k]['available_points']} 点可用" for k in total["points_only"]) + "）"))
    else:
        lines.append(" 这周合计：两边都读不到，派活前先把登录修好")
    second = [text for text in (total.get("unlockable_text"), total.get("resets_text")) if text]
    if second:
        lines.append(clip(" " + "｜".join(second)))
    others = "｜".join(STRATEGY_LABEL[s] for s in STRATEGIES if s != strategy)
    is_default = strategy == estimate["strategy"] and estimate.get("strategy_from") != "命令行"
    lines.append(clip(f" 策略：{STRATEGY_LABEL[strategy]}（{'默认，回车就按它' if is_default else '本场'}）｜{others}  试新型号：{'开' if estimate['try_new_models'] else '关'}"))
    if not estimate.get("config_exists"):
        lines.append(clip(" 第一次用：默认策略和 Grok 档位还没填，按读到的先跑；想填说「填额度」。"))
    lines.append(" 要改说一声，不改我就跑。")
    assert len(lines) <= MAX_LINES, len(lines)
    return lines


def pick(exec_text, ladder, claude_tight):
    if "｜" in exec_text:
        codex_part, claude_part = [part.strip() for part in exec_text.split("｜", 1)]
        return codex_part if ladder == "codex" else claude_part
    match = re.search(r"Claude 紧时\s*([^）)]+)", exec_text)
    if claude_tight and match:
        return match.group(1).strip()
    return exec_text


def label_of(text, fallback_effort="high"):
    text = re.split(r"[；;，,（(]", text, maxsplit=1)[0]
    model = rs.normalize_model(text)
    effort = rs.normalize_effort(text, fallback_effort if rs.family_of(model) in ("codex", "claude") else None)
    return rs.executor_label(model, effort) if model else text


def preview(estimate, strategy, strategies, title, usage, instructions, rounds):
    ladder, claude_tight, single, both_wide, codex_empty = direction(estimate)
    spec = strategies["strategies"][strategy]
    nothing = not estimate["providers"]["codex"]["connected"] and not estimate["providers"]["claude"]["connected"]
    classes = strategies["classes"]
    rounds = rounds or spec["review_rounds"]
    lines = [f"本项目分配 · {title} · {usage} · {STRATEGY_LABEL[strategy]}"]
    claude = estimate["providers"]["claude"]
    if nothing:
        lines.append("（两边都读不到：先修登录再派活，下面是默认分法，派前会再读一次）")
    elif single:
        lines.append("（本机没有 Codex，单家模式：审稿 Fable 子代理（同家），实现走 Claude 梯子）")
    elif codex_empty and ladder == "claude":
        codex = estimate["providers"]["codex"]
        lines.append(f"（Codex 空，到 {codex.get('reset_jst') or '重置'} 回满前实现走 Claude 梯子、复核同家；刷一张重置卡我就换回 Codex）")
    elif claude_tight:
        why = "读不到" if not claude["connected"] else claude["tier_text"]
        when = f"到 {claude['reset_jst']} 回满前" if claude.get("reset_jst") else "读到正常前"
        lines.append(f"（Claude {why}，{when}取证、复核都在 Codex 侧；实现走 Codex 梯子）")
    else:
        lines.append(f"（实现走 {'Codex' if ladder == 'codex' else 'Claude'} 梯子；取证、批量 Haiku，Codex 写的复核 Sonnet 只读）")
    reviewer = label_of(classes["审方案"][strategy]["exec"]) if not (single or codex_empty) else "Fable 子代理（同家）"
    lines.append(f" 讨论与审稿   我主持；审稿 {reviewer}，默认 {rounds} 轮，收敛了提前停")
    if usage == "探讨":
        mapper = label_of(classes["功能地图"][strategy]["exec"]) if not (single or codex_empty) else "Opus 子代理"
        tail = "，再审合并稿" if spec.get("feature_map_review", True) else "，审合并稿那步跳过"
        lines.append(f" 功能地图     我和 {mapper} 各想一遍{tail}")
    evidence = label_of(pick(classes["取证"][strategy]["exec"], ladder, claude_tight), "medium")
    batch = label_of(pick(classes["批量"][strategy]["exec"], ladder, claude_tight), "medium")
    why = claude["tier_text"] if claude["connected"] else "读不到"
    note = f"（Haiku 停用：Claude {why}）" if claude_tight and not single else ""
    lines.append(f" 取证、批量   {evidence}{'' if evidence == batch else ' / ' + batch}{note}")
    def reviewer_for(exec_label):
        if single or (codex_empty and ladder == "claude"):
            return "Opus 只读（同家）" if "Sonnet" in exec_label else "Sonnet 只读（同家）"
        if ladder == "codex" and claude_tight:
            return "Codex 的 6.1 Sol · 高 只读" if "Astra" in exec_label else "Codex 的 Astra · 高 只读"
        if ladder == "codex":
            return "Opus 只读" if strategy == "quality" else "Sonnet 只读"
        return "Codex 的 Astra · 高 只读" if strategy == "quality" else "Codex 的 6.1 Sol · 高 只读"
    page = label_of(pick(classes["页面实现"][strategy]["exec"], ladder, claude_tight))
    lines.append(f" 页面、窄回归 {rs.pad(page, 22)} 复核 {reviewer_for(page)}")
    hard = label_of(pick(classes["跨模块"][strategy]["exec"], ladder, claude_tight))
    if strategy == "auto" and both_wide and ladder == "codex":
        hard = "Opus"
        lines.append(f" 难活、根因   {rs.pad(hard, 22)} 复核 Codex 的 6.1 Sol · 高 只读（两边都宽，难活优先 Opus）")
    else:
        lines.append(f" 难活、根因   {rs.pad(hard, 22)} 复核 {reviewer_for(hard)}")
    visual = classes["视觉照做"][strategy]["exec"]
    doer = label_of(pick(visual.split("→")[-1], ladder, claude_tight)) if "→" in visual else label_of(visual)
    sketch = "Opus 出 2 到 3 版样张" if strategy == "quality" else "我出样张"
    lines.append(f" 视觉         {sketch} → 你点头 → {doer} 照做")
    if estimate["grace"]["enabled"]:
        lines.append(" 调研         Grace（任务书放 Google Drive 交接目录，交回后我并进来）")
    if estimate.get("try_new_models") and estimate["providers"]["grok"].get("logged_in") is True:
        lines.append(" 试用 Grok：取证、复核（只读，记战绩）")
    lines.append(f" 项目指令     {instructions or '无'}")
    return lines


def discuss_intro(estimate, strategy, strategies, host_model=None):
    session = estimate.get("session")
    spec = strategies["strategies"][strategy]
    reviewer = label_of(strategies["classes"]["审方案"][strategy]["exec"])
    rounds = session["rounds"] if session else spec["review_rounds"]
    host = f"我用 {host_model} 主持" if host_model else "我主持"
    lines = [f"探讨阶段用最强的：{host}，{reviewer} 审稿，默认 {rounds} 轮，收敛了提前停。"]
    if session and session.get("strategy") not in (None, strategy):
        lines.append(f"预计花：下面的数按{STRATEGY_LABEL.get(session['strategy'], session['strategy'])}算的，策略改了要准数再跑一次估算。")
    if session:
        lines.append(f"预计花：Codex 本周{session['codex_points_text']}（功能地图 {session['feature_map_calls']} 次 + 审稿 {rounds} 轮，{session['codex_units_text']}）；{session['claude_five_hour_text']}。")
        lines.append(f"预计用时 {session['minutes_text']}，中间不开口；功能地图分档和纪要时找你。")
    else:
        lines.append("预计花：没算（跑 quota-estimate.py --session 探讨 才有数字）。")
    return lines


def compact(estimate, strategy, title, remaining, finish):
    p = estimate["providers"]
    parts = []
    claude = p["claude"]
    parts.append(f"Claude 本周 {claude['weekly_used']:g}%（{claude['tier_text']}）" if claude["connected"] and claude.get("weekly_used") is not None else "Claude 读不到")
    codex = p["codex"]
    if codex["connected"] and codex.get("weekly_used") is not None:
        parts.append(f"Codex 本周 {codex['weekly_used']:g}%（{codex['tier_text']}" + (f"，重置卡 {codex['reset_cards']}" if codex.get("reset_cards") else "") + "）")
    else:
        parts.append("Codex 读不到")
    parts.append(f"Grok {p['grok']['tier_text']}")
    parts.append(f"策略{STRATEGY_LABEL[strategy]}")
    head = f"接着 {title} 那场，还剩 {remaining} 件。" if remaining is not None else f"这次走协同：{title}。"
    lines = [head + "｜".join(parts) + "。"]
    tail = f"预计 {finish} 完工。" if finish else ""
    lines.append(f"{tail}要改说一声，不改我就跑。")
    return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description="渲染开场面板、本项目分配预览、探讨开场说明")
    parser.add_argument("--estimate", type=Path, required=True, help="quota-estimate.py 的输出")
    parser.add_argument("--usage", choices=["探讨", "复盘", "协同", "续接"], default="协同")
    parser.add_argument("--strategy", choices=STRATEGIES, help="本场策略；默认用 estimate 里的")
    parser.add_argument("--title", default="这次的题目")
    parser.add_argument("--host-model", help="主会话实际型号；不填只写我主持")
    parser.add_argument("--instructions", default="", help="压过默认的项目指令，一句话")
    parser.add_argument("--rounds", type=int)
    parser.add_argument("--strategies", type=Path)
    parser.add_argument("--compact", action="store_true")
    parser.add_argument("--remaining", type=int, help="续接时还剩几件")
    parser.add_argument("--finish", help="续接或协同时的预计完工时刻文本")
    parser.add_argument("--json", action="store_true", help="输出各段文本的 JSON")
    args = parser.parse_args(argv)
    try:
        estimate = json.loads(args.estimate.read_text(encoding="utf-8"))
        strategies = rs.load_strategies(args.strategies)
    except (OSError, ValueError) as error:
        print(f"读不到输入：{error}", file=sys.stderr)
        return 2
    strategy = args.strategy or estimate.get("strategy", "auto")
    blocks = {}
    if args.compact:
        blocks["compact"] = compact(estimate, strategy, args.title, args.remaining, args.finish)
    else:
        blocks["panel"] = panel(estimate, strategy)
        blocks["preview"] = preview(estimate, strategy, strategies, args.title, args.usage, args.instructions, args.rounds)
        if args.usage == "探讨":
            blocks["discuss"] = discuss_intro(estimate, strategy, strategies, args.host_model)
    if args.json:
        print(json.dumps(blocks, ensure_ascii=False))
    else:
        print("\n\n".join("\n".join(lines) for lines in blocks.values()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
