#!/usr/bin/env python3
"""Generate the three localized Roadstar README hero illustrations."""

import re

from common import BG, CORAL, GOLD, INK, LINE, ROOT, SUFFIXES, TEAL, Drawing

COPY = {
    "zh-CN": (
        "Roadstar 引路星",
        ("Claude 想方案、拆活、验收，", "Codex 写代码。", "换一家模型回头挑错，", "规矩由脚本卡。"),
        "Claude 主会话",
        (("Codex", "写代码"), ("Claude 子代理", "Codex 做不了的"), ("验收", "换会话、换一家")),
        "任务书缺栏派不出去 · 没验收合不进主干",
    ),
    "en": (
        "Roadstar",
        ("Claude plans, splits, verifies,", "Codex writes the code.",
         "Another vendor's model reviews,", "Scripts enforce the rules."),
        "Claude main session",
        (("Codex", "Writes code"), ("Claude subagent", "What Codex can't do"),
         ("Verify", "New session, other vendor")),
        "Brief incomplete: no dispatch · Unverified: no merge",
    ),
    "ja": (
        "Roadstar",
        ("Claude が設計・分割・検収し、", "Codex がコードを書く。",
         "別社のモデルが再点検し、", "ルールはスクリプトが止める。"),
        "Claude メインセッション",
        (("Codex", "コード実装"), ("Claude サブエージェント", "Codex が不得手な作業"), ("検収", "別セッション・別社")),
        "欠けた指示書は渡せない · 未検収は取り込めない",
    ),
}


def skill_version():
    lines = (ROOT / "skill/SKILL.md").read_text(encoding="utf-8").splitlines()
    if lines and lines[0] == "---":
        frontmatter = lines[1:lines.index("---", 1)]
        if "metadata:" in frontmatter:
            for line in frontmatter[frontmatter.index("metadata:") + 1:]:
                if line.strip() and not line.startswith(" "):
                    break
                match = re.fullmatch(r"""  version: *(["']?)([\w.+-]+)\1 *(?:#.*)?""", line)
                if match:
                    return match[2]
    raise ValueError("skill/SKILL.md: missing metadata.version in frontmatter")


def hero(lang, version):
    title, sentences, host, cards, footer = COPY[lang]
    diagram = " → ".join([host, *(" / ".join(card) for card in cards)])
    art = Drawing(463, lang, title, " ".join((*sentences, diagram, footer)))
    art.rect("intro", 28, 30, 490, 356, BG, radius=0)
    art.star(65, 76, 12)
    art.text("intro", f"CLAUDE CODE SKILL · v{version}", 89, 82, 18, mono=True)
    art.text("intro", title, 48, 167, 49 if lang == "zh-CN" else 74, weight=800)
    for sentence, y, size in zip(sentences, (226, 264, 321, 352), (27, 27, 20, 20)):
        weight = 700 if size == 27 else 500
        if lang == "en" and size == 27:
            size = 24
        art.text("intro", sentence, 49, y, size, weight=weight)

    art.rect("host-label", 646, 94, 414, 39, BG, radius=0)
    art.add("circle", cx=853, cy=61, r=30, fill=LINE)
    art.star(853, 61, 26)
    art.text("host-label", host, 853, 121, 24, weight=750, anchor="middle")

    for x, width, badge, tone, (name, detail) in zip(
        (528, 680, 930), (140, 238, 226), ("T1", "T2", "✓"), (TEAL, CORAL, GOLD), cards
    ):
        key = "card-" + badge.replace("✓", "verify")
        middle = x + width / 2
        art.path(f"M853,136 V148 H{middle} V177", dash="3 6")
        art.rect(key, x, 176, width, 132, stroke=LINE)
        art.rect(key + "-badge", x + 14, 191, 52, 32, LINE if tone == TEAL else tone,
                 radius=10, stroke=TEAL if tone == TEAL else None)
        art.text(key + "-badge", badge, x + 40, 213, 17, anchor="middle", mono=True)
        name_size = 17 if lang == "ja" and badge == "T2" else 20
        art.text(key, name, x + 15, 252, name_size, weight=750)
        if lang == "en" and badge == "✓":
            first, second = detail.split(", ", 1)
            art.text(key, first + ",", x + 15, 276, 17, weight=500)
            art.text(key, second, x + 15, 296, 17, weight=500)
        else:
            art.text(key, detail, x + 14, 282, 17, weight=500)

    art.rect("footer", 44, 382, 1112, 50, INK, radius=24)
    art.text("footer", footer, 600, 415, 21, color=BG, weight=700, anchor="middle")
    art.write("hero", lang)


if __name__ == "__main__":
    version = skill_version()
    for language in SUFFIXES:
        hero(language, version)
