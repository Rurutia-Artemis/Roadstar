#!/usr/bin/env python3
"""Generate Roadstar README SVGs (hero + workflow) in en / zh-CN / ja, plus a dark hero variant for comparison."""
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
PREV = Path(sys.argv[2])

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans', 'Noto Sans CJK SC', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

# palette
BG, CARD, INK, MUTED, LINE = "#F7F4EE", "#FFFFFF", "#2B2A3D", "#8A8798", "#E4DED3"
GOLD, CORAL, TEAL = "#F2B544", "#E07A5F", "#3E9C9E"


def star(cx, cy, r, fill, opacity=1.0):
    return (f'<path d="M{cx},{cy-r} Q{cx},{cy} {cx+r},{cy} Q{cx},{cy} {cx},{cy+r} '
            f'Q{cx},{cy} {cx-r},{cy} Q{cx},{cy} {cx},{cy-r} Z" fill="{fill}" opacity="{opacity}"/>')


T = {
    "en": dict(
        lang="en", eyebrow="CLAUDE CODE SKILL · v1.13.0",
        tag1="Claude plans, splits and verifies.", tag2="Codex writes the code.",
        sub=["Both subscriptions get used,", "and the other vendor's model reviews every plan."],
        lanes=[("T1", "6.1 Sol", "≤ 2 h"), ("T2", "Astra", "≤ 4 h"), ("✓", "Review", "other model")],
        quota="Claude tight · Codex normal → Codex",
        alt_title="Roadstar: Claude dispatches, Codex builds",
        modes=[("Discuss", "You have an idea", "Features first, build second", "→ feature map + plan"),
               ("Review", "You have a project", "Both read it, then cross-check", "→ gap list + top 3 fixes"),
               ("Dispatch", "You have a plan", "Split, assign, verify", "→ a done report with evidence")],
        say="Type /roadstar (or 用 skill): it picks the mode, prints one setup line, and starts.",
        wf_title="Three modes, one entry",
    ),
    "zh-CN": dict(
        lang="zh-CN", eyebrow="CLAUDE CODE SKILL · v1.13.0",
        tag1="Claude 想方案、拆活、验收，", tag2="Codex 写代码。",
        sub=["两边订阅都用上，", "每份方案都有另一家模型挑错。"],
        lanes=[("T1", "6.1 Sol", "≤ 2 小时"), ("T2", "Astra", "≤ 4 小时"), ("✓", "复核", "换型号审")],
        quota="Claude 紧 · Codex 正常 → 走 Codex",
        alt_title="Roadstar 引路星：Claude 调度，Codex 干活",
        modes=[("探讨", "只有一个想法", "先把功能想全，再谈工程", "功能地图、方案、拆分表"),
               ("复盘", "项目已经有了", "两家各读一遍，交叉审", "出不足清单和先做三件事"),
               ("协同", "方案已经有了", "拆活、派活、验收", "交带证据的完工报告")],
        say="说一句「用 skill」，它自己判走哪种，报一行配置就开跑。",
        wf_title="三种用法，一个入口",
    ),
    "ja": dict(
        lang="ja", eyebrow="CLAUDE CODE SKILL · v1.13.0",
        tag1="計画と確認は Claude、", tag2="コードを書くのは Codex。",
        sub=["両方のサブスクを無駄なく使い、", "計画は必ずもう一社のモデルがレビュー。"],
        lanes=[("T1", "6.1 Sol", "≤ 2 時間"), ("T2", "Astra", "≤ 4 時間"), ("✓", "検証", "別モデル")],
        quota="Claude 逼迫 · Codex 通常 → Codex へ",
        alt_title="Roadstar：Claude が指揮し、Codex が作る",
        modes=[("計画検討", "アイデアだけある", "機能を出し切ってから設計", "機能マップ、計画、分担表"),
               ("レビュー", "既存のプロジェクト", "両者が読んで相互レビュー", "課題一覧と最初の 3 件"),
               ("実行", "計画はもうある", "分けて割り当て、検証", "根拠つきの完了レポート")],
        say="「用 skill」と一言。モードを選び、設定を一行で報告して走り出す。",
        wf_title="三つの使い方、入口は一つ",
    ),
}


def hero(t):
    W, H = 1200, 460
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{t["alt_title"]}</title>',
         f'<desc id="d">{t["tag1"]} {t["tag2"]} {"".join(t["sub"])}</desc>',
         f'<rect width="{W}" height="{H}" rx="28" fill="{BG}"/>']
    # faint sky stars
    for (x, y, r) in [(560, 70, 7), (1150, 60, 6), (590, 420, 5)]:
        s.append(star(x, y, r, GOLD, 0.45))
    # left column
    s.append(f'<text x="72" y="112" font-family="{MONO}" font-size="18" letter-spacing="3" fill="{MUTED}">{t["eyebrow"]}</text>')
    s.append(f'<text x="68" y="206" font-family="{SANS}" font-size="86" font-weight="800" fill="{INK}" letter-spacing="-1.5">Roadstar'
             f'<tspan dx="20" font-size="40" font-weight="600" fill="{MUTED}" letter-spacing="2">引路星</tspan></text>')
    s.append(f'<text x="72" y="276" font-family="{SANS}" font-size="30" font-weight="600" fill="{INK}">{t["tag1"]}</text>')
    s.append(f'<text x="72" y="320" font-family="{SANS}" font-size="30" font-weight="600" fill="{INK}">{t["tag2"]}</text>')
    for j, line in enumerate(t["sub"]):
        s.append(f'<text x="72" y="{372 + j*30}" font-family="{SANS}" font-size="20" fill="{MUTED}">{line}</text>')
    # right: system map
    sx, sy = 900, 96
    s.append(f'<circle cx="{sx}" cy="{sy}" r="46" fill="{GOLD}" opacity="0.16"/>')
    s.append(star(sx, sy, 38, GOLD))
    s.append(f'<rect x="{sx+50}" y="{sy-18}" width="96" height="36" rx="18" fill="{CORAL}"/>'
             f'<text x="{sx+98}" y="{sy+7}" text-anchor="middle" font-family="{SANS}" font-size="19" font-weight="700" fill="#FFFFFF">Claude</text>')
    cards_x = [640, 820, 1000]
    cw, ch, cy = 160, 112, 196
    for i, (cx, (k, name, cap)) in enumerate(zip(cards_x, t["lanes"])):
        mx = cx + cw / 2
        s.append(f'<path d="M{sx},{sy+40} C{sx},{sy+80} {mx},{cy-46} {mx},{cy-2}" fill="none" stroke="{GOLD}" stroke-width="2.5" stroke-dasharray="3 7" stroke-linecap="round"/>')
        color = CORAL if i == 2 else TEAL
        s.append(f'<rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" rx="20" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
        s.append(f'<text x="{cx+20}" y="{cy+34}" font-family="{MONO}" font-size="18" fill="{MUTED}">{k}</text>')
        s.append(f'<text x="{cx+20}" y="{cy+70}" font-family="{SANS}" font-size="26" font-weight="700" fill="{color}">{name}</text>')
        s.append(f'<text x="{cx+20}" y="{cy+98}" font-family="{SANS}" font-size="18" fill="{MUTED}">{cap}</text>')
    # terminal strip: the real opening-line idea
    s.append(f'<rect x="640" y="344" width="520" height="60" rx="18" fill="{INK}"/>')
    s.append(star(668, 374, 9, GOLD))
    s.append(f'<text x="690" y="381" font-family="{MONO}" font-size="19" fill="#F7F4EE">{t["quota"]}</text>')
    s.append('</svg>')
    return "\n".join(s)


def hero_dark(t):
    W, H = 1200, 460
    NIGHT, PALE = "#1D2140", "#C9C6E0"
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{t["alt_title"]}</title><desc id="d">{t["tag1"]} {t["tag2"]}</desc>',
         f'<rect width="{W}" height="{H}" rx="28" fill="{NIGHT}"/>']
    for (x, y, r) in [(120, 80, 5), (1080, 70, 6), (200, 390, 4), (1010, 400, 5), (1120, 230, 4)]:
        s.append(star(x, y, r, "#FFFFFF", 0.5))
    nodes = [(330, 300), (600, 360), (870, 300)]
    cx, cy = 600, 200
    for (x, y) in nodes:
        s.append(f'<line x1="{cx}" y1="{cy}" x2="{x}" y2="{y}" stroke="{GOLD}" stroke-width="2" stroke-dasharray="3 7" stroke-linecap="round" opacity="0.8"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="40" fill="{GOLD}" opacity="0.18"/>')
    s.append(star(cx, cy, 34, GOLD))
    for (x, y), (name, *_rest) in zip(nodes, t["modes"]):
        s.append(f'<circle cx="{x}" cy="{y}" r="8" fill="{GOLD}"/>')
        s.append(f'<text x="{x}" y="{y+40}" text-anchor="middle" font-family="{SANS}" font-size="24" font-weight="700" fill="#FFFFFF">{name}</text>')
    s.append(f'<text x="600" y="96" text-anchor="middle" font-family="{SANS}" font-size="72" font-weight="800" fill="#FFFFFF" letter-spacing="-1">Roadstar'
             f'<tspan dx="16" font-size="34" fill="{PALE}">引路星</tspan></text>')
    s.append(f'<text x="600" y="136" text-anchor="middle" font-family="{SANS}" font-size="24" fill="{PALE}">{t["tag1"]} {t["tag2"]}</text>')
    s.append('</svg>')
    return "\n".join(s)


def workflow(t):
    W, H = 1200, 400
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{t["wf_title"]}</title>',
         f'<desc id="d">' + " / ".join(" ".join(m) for m in t["modes"]) + f' — {t["say"]}</desc>',
         f'<rect width="{W}" height="{H}" rx="28" fill="{BG}"/>']
    s.append(f'<text x="56" y="72" font-family="{SANS}" font-size="40" font-weight="800" fill="{INK}">{t["wf_title"]}</text>')
    cw, gap, x0, y0, ch = 352, 24, 56, 104, 210
    colors = [GOLD, TEAL, CORAL]
    for i, (name, when, how, out) in enumerate(t["modes"]):
        x = x0 + i * (cw + gap)
        s.append(f'<rect x="{x}" y="{y0}" width="{cw}" height="{ch}" rx="22" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
        s.append(star(x + 40, y0 + 44, 14, colors[i]))
        s.append(f'<text x="{x+66}" y="{y0+54}" font-family="{SANS}" font-size="30" font-weight="800" fill="{INK}">{name}</text>')
        s.append(f'<text x="{x+28}" y="{y0+104}" font-family="{SANS}" font-size="21" fill="{MUTED}">{when}</text>')
        s.append(f'<text x="{x+28}" y="{y0+142}" font-family="{SANS}" font-size="21" font-weight="600" fill="{INK}">{how}</text>')
        s.append(f'<text x="{x+28}" y="{y0+180}" font-family="{SANS}" font-size="21" font-weight="600" fill="{colors[i] if i else "#B07D10"}">{out}</text>')
    s.append(f'<rect x="56" y="336" width="1088" height="40" rx="20" fill="{INK}"/>')
    s.append(f'<text x="600" y="363" text-anchor="middle" font-family="{SANS}" font-size="20" fill="#F7F4EE">{t["say"]}</text>')
    s.append('</svg>')
    return "\n".join(s)


for key, t in T.items():
    suffix = "" if key == "en" else f".{key}"
    (OUT / f"hero{suffix}.svg").write_text(hero(t) + "\n", encoding="utf-8")
    (OUT / f"workflow{suffix}.svg").write_text(workflow(t) + "\n", encoding="utf-8")
(PREV / "hero-dark.svg").write_text(hero_dark(T["en"]) + "\n", encoding="utf-8")
print("ok")
