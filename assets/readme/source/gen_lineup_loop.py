#!/usr/bin/env python3
"""Roadstar README: model lineup (two vendors, six models) + escalation/learning loop, in en / zh-CN / ja.
Usage: gen_lineup_loop.py <assets/readme dir>. Same palette and star motif as the hero."""
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans', 'Noto Sans CJK SC', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
BG, CARD, INK, MUTED, LINE = "#F7F4EE", "#FFFFFF", "#2B2A3D", "#8A8798", "#E4DED3"
GOLD, GOLD_D, CORAL, CORAL_D, TEAL, TEAL_D = "#F2B544", "#9A6B0C", "#E07A5F", "#B9583F", "#3E9C9E", "#2E7C7E"


def star(cx, cy, r, fill):
    return (f'<path d="M{cx},{cy-r} Q{cx},{cy} {cx+r},{cy} Q{cx},{cy} {cx},{cy+r} '
            f'Q{cx},{cy} {cx-r},{cy} Q{cx},{cy} {cx},{cy-r} Z" fill="{fill}"/>')


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def lineup(t):
    W, H = 1200, 640
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{esc(t["title"])}</title>',
         f'<desc id="d">{esc(" / ".join(n + " " + r for n, r, _ in t["claude"] + t["codex"]))}</desc>',
         f'<rect width="{W}" height="{H}" rx="28" fill="{BG}"/>',
         f'<text x="48" y="74" font-family="{SANS}" font-size="40" font-weight="800" fill="{INK}">{esc(t["title"])}</text>']
    cols = [(48, 640, t["claude_head"], CORAL, CORAL_D, t["claude"]), (720, 432, t["codex_head"], TEAL, TEAL_D, t["codex"])]
    for x, w, head, c, dark, rows in cols:
        s.append(star(x + 14, 122, 12, c))
        s.append(f'<text x="{x+36}" y="130" font-family="{SANS}" font-size="24" font-weight="700" fill="{dark}">{esc(head)}</text>')
        for i, (name, role, price) in enumerate(rows):
            y = 152 + i * 100
            s.append(f'<rect x="{x}" y="{y}" width="{w}" height="88" rx="20" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
            s.append(f'<text x="{x+24}" y="{y+38}" font-family="{SANS}" font-size="27" font-weight="800" fill="{INK}">{esc(name)}</text>')
            s.append(f'<text x="{x+w-24}" y="{y+37}" text-anchor="end" font-family="{MONO}" font-size="19" fill="{dark}">{esc(price)}</text>')
            s.append(f'<text x="{x+24}" y="{y+70}" font-family="{SANS}" font-size="20" fill="{MUTED}">{esc(role)}</text>')
    # escalation cue on the Claude column, codex note under its two rows
    s.append(f'<rect x="48" y="560" width="640" height="48" rx="24" fill="{INK}"/>')
    s.append(f'<text x="368" y="591" text-anchor="middle" font-family="{SANS}" font-size="20" fill="#F7F4EE">{esc(t["up"])}</text>')
    for j, line in enumerate(t["codex_note"]):
        s.append(f'<text x="720" y="{396 + j*30}" font-family="{SANS}" font-size="20" fill="{INK}">{esc(line)}</text>')
    s.append(f'<text x="720" y="{396 + len(t["codex_note"])*30 + 24}" font-family="{SANS}" font-size="18" fill="{MUTED}">{esc(t["price_note"][0])}</text>')
    if len(t["price_note"]) > 1:
        s.append(f'<text x="720" y="{396 + len(t["codex_note"])*30 + 50}" font-family="{SANS}" font-size="18" fill="{MUTED}">{esc(t["price_note"][1])}</text>')
    s.append('</svg>')
    return "\n".join(s) + "\n"


def loop(t):
    W, H = 1200, 380
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">',
         f'<title id="t">{esc(t["loop_title"])}</title>',
         f'<desc id="d">{esc(" → ".join(" ".join(c) for c in t["steps"]) + " · " + t["loop_back"])}</desc>',
         f'<rect width="{W}" height="{H}" rx="28" fill="{BG}"/>',
         f'<text x="40" y="66" font-family="{SANS}" font-size="38" font-weight="800" fill="{INK}">{esc(t["loop_title"])}</text>']
    cw, gap, x0, y0, ch = 204, 30, 40, 96, 176
    colors = [(GOLD, GOLD_D), (TEAL, TEAL_D), (CORAL, CORAL_D), (CORAL, CORAL_D), (TEAL, TEAL_D)]
    for i, (head, l1, l2) in enumerate(t["steps"]):
        x = x0 + i * (cw + gap)
        c, dark = colors[i]
        s.append(f'<rect x="{x}" y="{y0}" width="{cw}" height="{ch}" rx="22" fill="{CARD}" stroke="{LINE}" stroke-width="2"/>')
        s.append(f'<text x="{x+22}" y="{y0+40}" font-family="{MONO}" font-size="20" fill="{dark}">{i+1:02d}</text>')
        s.append(star(x + cw - 32, y0 + 34, 11, c))
        s.append(f'<text x="{x+22}" y="{y0+82}" font-family="{SANS}" font-size="25" font-weight="800" fill="{INK}">{esc(head)}</text>')
        s.append(f'<text x="{x+22}" y="{y0+122}" font-family="{SANS}" font-size="19" fill="{MUTED}">{esc(l1)}</text>')
        s.append(f'<text x="{x+22}" y="{y0+150}" font-family="{SANS}" font-size="19" fill="{MUTED}">{esc(l2)}</text>')
        if i < 4:
            ax = x + cw + 6
            s.append(f'<path d="M{ax},{y0+ch/2} l18,0 m-7,-7 l7,7 l-7,7" stroke="{GOLD}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    # loop back bar
    s.append(f'<path d="M{x0 + 4*(cw+gap) + cw/2},{y0+ch+4} v20 H{x0 + cw/2} v-20" stroke="{GOLD}" stroke-width="3" fill="none" stroke-dasharray="4 7" stroke-linecap="round"/>')
    s.append(f'<rect x="{x0+40}" y="{y0+ch+30}" width="{W - 2*x0 - 80}" height="48" rx="24" fill="{INK}"/>')
    s.append(f'<text x="{W/2}" y="{y0+ch+61}" text-anchor="middle" font-family="{SANS}" font-size="20" fill="#F7F4EE">{esc(t["loop_back"])}</text>')
    s.append('</svg>')
    return "\n".join(s) + "\n"


T = {
    "zh-CN": dict(
        title="两家六个型号，按活分工",
        claude_head="Claude · 四层", codex_head="Codex · 两层",
        claude=[("Fable 5.1", "主会话做判断；卡死时查根因", "$10 / $50"),
                ("Opus 5.5", "难活、根因诊断、画样张", "$4 / $20"),
                ("Sonnet 5.5", "跨家复核，规格清楚的实现", "$2 / $10"),
                ("Haiku 5.5", "取证、批量，常驻", "$0.10 / $0.50")],
        codex=[("Astra", "难活、审方案", "基准"), ("6.1 Sol", "常规实现", "约 1/5")],
        up="↑ 碰壁就停，做完的收下，剩下的交上一层补全",
        codex_note=["Codex 只有两层，", "最便宜和最难的活", "由 Claude 这边补齐。"],
        price_note=["价格：API 每百万 token", "输入 / 输出，美元，只比贵贱"],
        loop_title="碰壁就停，越用越准",
        steps=[("起步", "经验表里", "最便宜的那层"), ("写进度", "每试一次", "记一行"),
               ("碰壁就停", "连败三次、空转", "或用掉九成"), ("升级补全", "做完的收下", "剩下交高一级"),
               ("记战绩", "类别、型号", "结果、额度差")],
        loop_back="样本满 5 次：完成率 ≥ 90% 降到更便宜的层，< 60% 升一层，主席点头才改表",
    ),
    "en": dict(
        title="Six models, each on the work it does best",
        claude_head="Claude · four tiers", codex_head="Codex · two tiers",
        claude=[("Fable 5.1", "Main session; root causes when stuck", "$10 / $50"),
                ("Opus 5.5", "Hard tasks, root causes, mockups", "$4 / $20"),
                ("Sonnet 5.5", "Cross-vendor review, spec'd builds", "$2 / $10"),
                ("Haiku 5.5", "Lookups and batch work, always on", "$0.10 / $0.50")],
        codex=[("Astra", "Hard tasks, plan review", "baseline"), ("6.1 Sol", "Routine implementation", "~1/5")],
        up="↑ Stuck? Stop, keep what passed, hand the rest up",
        codex_note=["Codex has two tiers.", "Claude covers the cheapest", "and the hardest work."],
        price_note=["Prices: API $ per 1M tokens,", "input / output, for comparison"],
        loop_title="Stop at the wall, learn every run",
        steps=[("Start", "cheapest tier", "with a record"), ("Log", "one line per", "check attempt"),
               ("Stop", "3 fails, idle,", "or 90% of time"), ("Escalate", "keep what passed,", "send the rest up"),
               ("Record", "class, model,", "result, quota")],
        loop_back="After 5 samples: ≥ 90% done moves a class down a tier, < 60% moves it up. You approve each change.",
    ),
    "ja": dict(
        title="六つのモデルを、得意な仕事に",
        claude_head="Claude · 4 層", codex_head="Codex · 2 層",
        claude=[("Fable 5.1", "メイン会話の判断、行き詰まりの原因究明", "$10 / $50"),
                ("Opus 5.5", "難しい実装、原因究明、見本づくり", "$4 / $20"),
                ("Sonnet 5.5", "他社モデルの検証、仕様が明確な実装", "$2 / $10"),
                ("Haiku 5.5", "調査と一括作業を常に担当", "$0.10 / $0.50")],
        codex=[("Astra", "難しい実装と計画レビュー", "基準"), ("6.1 Sol", "通常の実装", "約 1/5")],
        up="↑ 壁に当たったら止め、済んだ分は残して残りを上へ",
        codex_note=["Codex は 2 層だけ。", "一番安い仕事と一番難しい仕事は", "Claude 側が受け持つ。"],
        price_note=["価格は API の 100 万トークンあたり", "入力 / 出力（米ドル）、比較用"],
        loop_title="壁で止め、使うほど賢く",
        steps=[("起点", "実績のある", "一番安い層"), ("進捗を記録", "試すたびに", "1 行ずつ"),
               ("壁で止める", "3 連敗、空転、", "時間の 9 割"), ("上位で補完", "済んだ分は残し", "残りを一つ上へ"),
               ("実績を記録", "種類とモデル", "結果と消費枠")],
        loop_back="5 件たまったら、完了率 90% 以上なら安い層へ、60% 未満なら一つ上へ。表の変更は本人が承認",
    ),
}

for lang, t in T.items():
    sfx = "" if lang == "en" else f".{lang}"
    (OUT / f"lineup{sfx}.svg").write_text(lineup(t), encoding="utf-8")
    (OUT / f"loop{sfx}.svg").write_text(loop(t), encoding="utf-8")
print("ok")
