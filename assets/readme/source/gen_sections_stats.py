#!/usr/bin/env python3
"""Roadstar README: section banners + stat strip (en / zh-CN / ja). Same palette and star motif as the hero."""
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans', 'Noto Sans CJK SC', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
BG, CARD, INK, MUTED, LINE = "#F7F4EE", "#FFFFFF", "#2B2A3D", "#8A8798", "#E4DED3"
# color roles: why = gold, proof/benefit = teal, limits = coral, install/reference = ink
ROLE = {"why": ("#F2B544", "#9A6B0C"), "proof": ("#3E9C9E", "#2E7C7E"), "limit": ("#E07A5F", "#B9583F"), "ref": ("#2B2A3D", "#2B2A3D")}


def star(cx, cy, r, fill):
    return (f'<path d="M{cx},{cy-r} Q{cx},{cy} {cx+r},{cy} Q{cx},{cy} {cx},{cy+r} '
            f'Q{cx},{cy} {cx-r},{cy} Q{cx},{cy} {cx},{cy-r} Z" fill="{fill}"/>')


def banner(num, title, sub, role):
    c, dark = ROLE[role]
    return "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 1200 160" role="img" aria-labelledby="t d">',
        f'<title id="t">{num} {title}</title><desc id="d">{sub}</desc>',
        f'<rect width="1200" height="160" rx="24" fill="{BG}"/>',
        f'<circle cx="78" cy="80" r="42" fill="{c}" opacity="0.16"/>',
        star(78, 80, 32, c),
        f'<text x="142" y="56" font-family="{MONO}" font-size="22" letter-spacing="2" fill="{dark}">{num}</text>',
        f'<text x="198" y="56" font-family="{SANS}" font-size="22" fill="{MUTED}">{sub}</text>',
        f'<text x="138" y="120" font-family="{SANS}" font-size="56" font-weight="800" fill="{INK}">{title}</text>',
        f'<rect x="142" y="136" width="120" height="7" rx="3.5" fill="{c}"/>',
        '</svg>', ""])


def stats(items, title, desc):
    pad, gap = 32, 20
    w = (1200 - 2 * pad - 2 * gap) // 3
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 1200 220" role="img" aria-labelledby="t d">',
         f'<title id="t">{title}</title><desc id="d">{desc}</desc>',
         f'<rect width="1200" height="220" rx="28" fill="{BG}"/>']
    for i, (num, unit, cap, role) in enumerate(items):
        c, dark = ROLE[role]
        x = pad + i * (w + gap)
        s.append(f'<rect x="{x}" y="28" width="{w}" height="164" rx="22" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
        s.append(star(x + w - 40, 64, 13, c))
        s.append(f'<text x="{x+28}" y="110" font-family="{SANS}" font-size="64" font-weight="800" fill="{dark}" letter-spacing="-1">{num}'
                 f'<tspan dx="10" font-size="28" font-weight="700" fill="{INK}" letter-spacing="0">{unit}</tspan></text>')
        s.append(f'<text x="{x+28}" y="158" font-family="{SANS}" font-size="20" fill="{MUTED}">{cap}</text>')
    s += ['</svg>', ""]
    return "\n".join(s)


SECTIONS = {
    "zh-CN": [("01", "它解决了我三个问题", "两边订阅 · 方案挑错 · 派活验收", "why"),
              ("02", "我最满意的几个地方", "额度自己看 · 换型号验收 · 止损 · 规矩", "proof"),
              ("03", "不是特别方便的地方", "要装 Codex 命令行 · 单家模式还没实跑", "limit"),
              ("04", "安装", "把仓库地址丢给 AI 就行", "ref")],
    "en": [("01", "Used for real", "17 runs · 244 Codex sessions · 31 rules", "proof"),
           ("02", "What it fixes", "two subscriptions · a second model · less babysitting", "why"),
           ("03", "Install", "or hand this URL to your AI", "ref")],
    "ja": [("01", "実際に使った記録", "17 回 · Codex 244 回 · ルール 31", "proof"),
           ("02", "何が楽になるか", "サブスク二つ · もう一社の目 · 割り振りと確認", "why"),
           ("03", "インストール", "URL を AI に渡すだけでも OK", "ref")],
}
STATS = {
    "zh-CN": ([("17", "场", "10-04 以来，四个项目", "why"), ("244", "次", "Codex：Sol 130 / Astra 114", "proof"),
               ("31", "条规矩", "每条来自一次真出事", "limit")],
              "真跑过的数字", "10 月 4 日以来四个项目 17 场，Codex 会话 244 次（Sol 130、Astra 114），规矩 31 条。"),
    "en": ([("17", "runs", "since Oct 4, four projects", "why"), ("244", "sessions", "Codex: 130 Sol / 114 Astra", "proof"),
            ("31", "rules", "each from a real failure", "limit")],
           "Numbers from real use", "17 runs across four projects since 2026-10-04, 244 Codex sessions (130 Sol, 114 Astra), 31 rules."),
    "ja": ([("17", "回", "10-04 以降・4 プロジェクト", "why"), ("244", "回", "Codex：Sol 130／Astra 114", "proof"),
            ("31", "ルール", "どれも実際の失敗から", "limit")],
           "実際に使った数字", "2026-10-04 以降 4 プロジェクトで 17 回、Codex セッション 244 回（Sol 130、Astra 114）、ルール 31。"),
}

for lang, secs in SECTIONS.items():
    sfx = "" if lang == "en" else f".{lang}"
    for i, (num, title, sub, role) in enumerate(secs, 1):
        (OUT / f"section-{i}{sfx}.svg").write_text(banner(num, title, sub, role), encoding="utf-8")
    items, title, desc = STATS[lang]
    (OUT / f"stats{sfx}.svg").write_text(stats(items, title, desc), encoding="utf-8")
print("ok")
