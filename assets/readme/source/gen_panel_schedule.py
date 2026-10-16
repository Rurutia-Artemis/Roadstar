#!/usr/bin/env python3
"""Roadstar README: the 1.12 opening panel + schedule figure (en / zh-CN / ja). Same palette and star motif as the hero."""
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans', 'Noto Sans CJK SC', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
BG, CARD, INK, MUTED, LINE = "#F7F4EE", "#FFFFFF", "#2B2A3D", "#8A8798", "#E4DED3"
GOLD, CORAL, TEAL, GOLD_D, TEAL_D = "#F2B544", "#E07A5F", "#3E9C9E", "#9A6B0C", "#2E7C7E"


def star(cx, cy, r, fill, opacity=1.0):
    return (f'<path d="M{cx},{cy-r} Q{cx},{cy} {cx+r},{cy} Q{cx},{cy} {cx},{cy+r} '
            f'Q{cx},{cy} {cx-r},{cy} Q{cx},{cy} {cx},{cy-r} Z" fill="{fill}" opacity="{opacity}"/>')


T = {
    "en": dict(
        title="Opening panel, one question, then a schedule",
        panel_title="Connected: 3 providers + Grace",
        rows=[("Claude Max", "week 97%", 97, "0 pt", CORAL), ("Codex Pro", "week 8% · 1 reset card", 8, "≈ 273 pieces", TEAL), ("Grok", "logged in · quota unreadable", None, "?", MUTED)],
        total="≈ 273 pieces this week (low confidence) · +300 per reset card",
        strategy_label="Strategy", strategies=["Auto", "Quality", "Thrift", "Rush"],
        enter="Enter = Auto. One word switches, this run only.",
        sched_title="Schedule: who, why, estimate, done by",
        tasks=[("1", "Data layer", "Astra · high", 103, 0, "17:12"), ("2", "Mockups", "me", 37, 10, "15:58"), ("3", "Entry page", "6.1 Sol · high", 31, 63, "16:58"),
               ("4", "Monthly stats", "6.1 Sol · high", 31, 68, "17:23"), ("5", "CSV export", "6.1 Sol · medium", 13, 107, "17:34"), ("6", "Merge + full tests", "6.1 Sol · high", 94, 159, "19:24")],
        totals=("Lane time 5h48 · 3 Codex lanes · critical path 2 → 3 → 5 → 6", "All done by 19:24 JST, counted from your go"),
        caption="Every number comes from a script; the report later compares estimate with actual.",
    ),
    "zh-CN": dict(
        title="开场一张面板，问一次策略，排活给一张表",
        panel_title="接了 3 家 ＋ Grace 调研",
        rows=[("Claude Max", "周 97%", 97, "0 点", CORAL), ("Codex Pro", "周 8% · 重置卡 1 张", 8, "约 273 件", TEAL), ("Grok", "已登录 · 额度读不到", None, "？", MUTED)],
        total="这周合计约 273 件（置信度低）· 刷重置卡可解锁 +300 件",
        strategy_label="策略", strategies=["自动分配", "质量优先", "省着用", "赶时间"],
        enter="回车就是自动分配；说一个词就切，只管本场。",
        sched_title="排活表：给谁、为什么、预估、几点完成",
        tasks=[("1", "数据层", "Astra · 高", 103, 0, "17:12"), ("2", "样张", "我", 37, 10, "15:58"), ("3", "记一笔页面", "6.1 Sol · 高", 31, 63, "16:58"),
               ("4", "月度统计页", "6.1 Sol · 高", 31, 68, "17:23"), ("5", "导出 CSV", "6.1 Sol · 中", 13, 107, "17:34"), ("6", "合并、全量回归", "6.1 Sol · 高", 94, 159, "19:24")],
        totals=("线上工时 5h48 · 并行 3 条 Codex 线 · 关键路径 2 → 3 → 5 → 6", "预计 19:24 JST 全部完工，从你说开工起算"),
        caption="每个数字都来自脚本输出；完工报告再把预估和实际对账。",
    ),
    "ja": dict(
        title="最初にパネル、方針を一度だけ確認、そして工程表",
        panel_title="接続 3 社 ＋ Grace（調査担当）",
        rows=[("Claude Max", "週 97%", 97, "0 pt", CORAL), ("Codex Pro", "週 8% · リセット 1 枚", 8, "約 273 件", TEAL), ("Grok", "ログイン済 · 残量は読めない", None, "？", MUTED)],
        total="今週の合計 約 273 件（信頼度 低）· リセットで +300 件",
        strategy_label="方針", strategies=["自動", "品質優先", "節約", "急ぎ"],
        enter="Enter で自動。一言で切り替え、この回だけ有効。",
        sched_title="工程表：担当、理由、見積、完了時刻",
        tasks=[("1", "データ層", "Astra · high", 103, 0, "17:12"), ("2", "モック", "私", 37, 10, "15:58"), ("3", "入力画面", "6.1 Sol · high", 31, 63, "16:58"),
               ("4", "月次集計", "6.1 Sol · high", 31, 68, "17:23"), ("5", "CSV 出力", "6.1 Sol · medium", 13, 107, "17:34"), ("6", "統合と全テスト", "6.1 Sol · high", 94, 159, "19:24")],
        totals=("作業 5h48 · Codex 3 並列 · クリティカルパス 2 → 3 → 5 → 6", "19:24 JST 完了見込み、開始の合図から数えて"),
        caption="数字はすべてスクリプトの出力。完了時に見積と実績を突き合わせる。",
    ),
}


def figure(t):
    W, H = 1200, 580
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{t["title"]}</title>',
         f'<desc id="d">{t["panel_title"]}. ' + "; ".join(f"{r[0]} {r[1]} {r[3]}" for r in t["rows"]) + f". {t['total']}. {t['strategy_label']}: " + " / ".join(t["strategies"]) + f". {t['enter']} {t['sched_title']}: " + "; ".join(f"{a} {b} {c} {d} min {f}" for a, b, c, d, e, f in t["tasks"]) + f". {' '.join(t['totals'])} {t['caption']}</desc>",
         f'<rect width="{W}" height="{H}" rx="28" fill="{BG}"/>']
    s.append(f'<text x="56" y="66" font-family="{SANS}" font-size="40" font-weight="800" fill="{INK}">{t["title"]}</text>')
    # left card: panel
    x, y, w, h = 56, 96, 520, 396
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="22" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
    s.append(star(x + 30, y + 34, 12, GOLD))
    s.append(f'<text x="{x+52}" y="{y+42}" font-family="{SANS}" font-size="24" font-weight="700" fill="{INK}">{t["panel_title"]}</text>')
    ry = y + 84
    for name, reading, pct, pieces, color in t["rows"]:
        s.append(f'<text x="{x+28}" y="{ry}" font-family="{SANS}" font-size="21" font-weight="700" fill="{INK}">{name}</text>')
        s.append(f'<text x="{x+180}" y="{ry}" font-family="{SANS}" font-size="19" fill="{MUTED}">{reading}</text>')
        s.append(f'<rect x="{x+28}" y="{ry+12}" width="300" height="12" rx="6" fill="{LINE}"/>')
        if pct is not None:
            s.append(f'<rect x="{x+28}" y="{ry+12}" width="{3*pct}" height="12" rx="6" fill="{color}"/>')
        else:
            s.append(f'<text x="{x+178}" y="{ry+23}" text-anchor="middle" font-family="{MONO}" font-size="12" fill="{MUTED}">? ? ?</text>')
        s.append(f'<text x="{x+w-28}" y="{ry+22}" text-anchor="end" font-family="{SANS}" font-size="22" font-weight="800" fill="{color if pct is not None else MUTED}">{pieces}</text>')
        ry += 66
    s.append(f'<text x="{x+28}" y="{ry+2}" font-family="{SANS}" font-size="17" fill="{INK}">{t["total"]}</text>')
    py = ry + 44
    s.append(f'<text x="{x+28}" y="{py}" font-family="{SANS}" font-size="19" font-weight="700" fill="{INK}">{t["strategy_label"]}</text>')
    px = x + 28 + (100 if t["strategy_label"] == "Strategy" else 56)
    for i, name in enumerate(t["strategies"]):
        tw = 22 + 12 * len(name) + (8 if name.isascii() else 10 * len(name))
        fill = GOLD if i == 0 else CARD
        s.append(f'<rect x="{px}" y="{py-20}" width="{tw}" height="30" rx="15" fill="{fill}" stroke="{GOLD if i == 0 else LINE}" stroke-width="2"/>')
        s.append(f'<text x="{px+tw/2}" y="{py+1}" text-anchor="middle" font-family="{SANS}" font-size="18" font-weight="{700 if i == 0 else 500}" fill="{INK}">{name}</text>')
        px += tw + 10
    s.append(f'<text x="{x+28}" y="{py+34}" font-family="{SANS}" font-size="18" fill="{MUTED}">{t["enter"]}</text>')
    # right card: schedule gantt
    x, y, w, h = 612, 96, 532, 396
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="22" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
    s.append(star(x + 30, y + 34, 12, TEAL))
    s.append(f'<text x="{x+52}" y="{y+42}" font-family="{SANS}" font-size="24" font-weight="700" fill="{INK}">{t["sched_title"]}</text>')
    gx, gw, scale = x + 200, 240, 240 / 264  # 15:00 → 19:24 = 264 min
    ry = y + 84
    for num, name, who, dur, start, done in t["tasks"]:
        s.append(f'<text x="{x+24}" y="{ry+6}" font-family="{MONO}" font-size="16" fill="{MUTED}">{num}</text>')
        s.append(f'<text x="{x+44}" y="{ry+6}" font-family="{SANS}" font-size="18" font-weight="700" fill="{INK}">{name}</text>')
        s.append(f'<text x="{x+44}" y="{ry+26}" font-family="{SANS}" font-size="15" fill="{MUTED}">{who}</text>')
        color = GOLD if who in ("me", "我", "私") else (CORAL if "Astra" in who else TEAL)
        s.append(f'<rect x="{gx + start*scale:.0f}" y="{ry-8}" width="{max(8, dur*scale):.0f}" height="18" rx="9" fill="{color}" opacity="0.9"/>')
        s.append(f'<text x="{x+w-24}" y="{ry+6}" text-anchor="end" font-family="{MONO}" font-size="17" fill="{INK}">{done}</text>')
        ry += 46
    first, second = t["totals"]
    s.append(f'<text x="{x+24}" y="{ry+2}" font-family="{SANS}" font-size="16" fill="{INK}">{first}</text>')
    s.append(f'<text x="{x+24}" y="{ry+24}" font-family="{SANS}" font-size="16" fill="{INK}">{second}</text>')
    # caption strip
    s.append(f'<rect x="56" y="514" width="1088" height="44" rx="14" fill="{INK}"/>')
    s.append(star(84, 536, 8, GOLD))
    s.append(f'<text x="104" y="543" font-family="{SANS}" font-size="19" fill="#F7F4EE">{t["caption"]}</text>')
    s.append('</svg>')
    return "\n".join(s) + "\n"


for lang, t in T.items():
    sfx = "" if lang == "en" else f".{lang}"
    (OUT / f"panel{sfx}.svg").write_text(figure(t), encoding="utf-8")
print("ok")
