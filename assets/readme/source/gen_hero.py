#!/usr/bin/env python3
"""Generate the three localized Roadstar README hero illustrations."""

import math
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
         "Another vendor's model hunts for errors.", "Scripts enforce the rules."),
        "Claude main session",
        (("Codex", "Writes code"), ("Claude subagent", "What Codex can't do"),
         ("Verify", "New session, other vendor")),
        "Brief missing a field: no dispatch · Unverified: no merge",
    ),
    "ja": (
        "Roadstar",
        ("Claude が設計・分割・検収し、", "Codex がコードを書く。",
         "別社のモデルが誤りを探し、", "ルール違反はスクリプトが止める。"),
        "Claude メインセッション",
        (("Codex", "コード実装"), ("Claude サブエージェント", "Codex にできない作業"), ("検収", "別セッション・別社")),
        "指示書に項目抜け：割り当て不可 · 未検収：マージ不可",
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


def wrap_intro_subtitle(sentence, size, available_width):
    def estimated_width(line):
        # Match the SVG checker's estimates for ASCII and full-width glyphs.
        return size * sum(0.6 if char.isascii() else 1 for char in line)

    if estimated_width(sentence) <= available_width:
        return [sentence]

    lines = []
    line = ""
    # Keep ASCII words together; unspaced CJK copy can break between glyphs.
    for token in re.findall(r"[!-~]+|.", sentence):
        candidate = line + token
        if line and estimated_width(candidate.rstrip()) > available_width:
            lines.append(line.rstrip())
            line = token
        else:
            line = candidate
    return [*lines, line.rstrip()]


def hero(lang, version):
    title, sentences, host, cards, footer = COPY[lang]
    diagram = " → ".join([host, *(" / ".join(card) for card in cards)])
    subtitles = [(detail,) for _, detail in cards]
    if lang == "en":
        first, second = subtitles[-1][0].split(", ", 1)
        subtitles[-1] = (first + ",", second)

    card_lefts = (528, 680, 930)
    card_top, card_height = 176, 132
    subtitle_baseline, subtitle_size, subtitle_bottom_padding = 282, 17, 12
    line_height = subtitle_size * 1.35
    last_baseline = subtitle_baseline + line_height * (max(map(len, subtitles)) - 1)
    extra_height = max(0, math.ceil(last_baseline + subtitle_bottom_padding) - (card_top + card_height))
    art = Drawing(463 + extra_height, lang, title, " ".join((*sentences, diagram, footer)))
    art.rect("intro", 28, 30, 490, 356, BG, radius=0)
    art.star(65, 76, 12)
    art.text("intro", f"CLAUDE CODE SKILL · v{version}", 89, 82, 18, mono=True)
    art.text("intro", title, 48, 167, 49 if lang == "zh-CN" else 74, weight=800)
    intro_x = 49
    for sentence, y in zip(sentences[:2], (226, 264)):
        art.text("intro", sentence, intro_x, y, 24 if lang == "en" else 27, weight=700)

    # The first diagram card starts half its 2-unit stroke before its x coordinate.
    intro_width = min(card_lefts) - 1 - intro_x - 40
    intro_size = 18 if lang == "en" else 20
    intro_lines = [
        line for sentence in sentences[2:]
        for line in wrap_intro_subtitle(sentence, intro_size, intro_width)
    ]
    intro_line_height = intro_size * 1.35 if len(intro_lines) > len(sentences[2:]) else 31
    for index, line in enumerate(intro_lines):
        art.text("intro", line, intro_x, 321 + index * intro_line_height, intro_size, weight=500)

    art.rect("host-label", 646, 94, 414, 39, BG, radius=0)
    art.add("circle", cx=853, cy=61, r=30, fill=LINE)
    art.star(853, 61, 26)
    art.text("host-label", host, 853, 121, 24, weight=750, anchor="middle")

    for x, width, badge, tone, (name, _), lines in zip(
        card_lefts, (140, 238, 226), ("T1", "T2", "✓"), (TEAL, CORAL, GOLD), cards, subtitles
    ):
        key = "card-" + badge.replace("✓", "verify")
        middle = x + width / 2
        art.path(f"M853,136 V148 H{middle} V177", dash="3 6")
        art.rect(key, x, card_top, width, card_height + extra_height, stroke=LINE)
        art.rect(key + "-badge", x + 14, 191, 52, 32, LINE if tone == TEAL else tone,
                 radius=10, stroke=TEAL if tone == TEAL else None)
        art.text(key + "-badge", badge, x + 40, 213, 17, anchor="middle", mono=True)
        name_size = 17 if lang == "ja" and badge == "T2" else 20
        art.text(key, name, x + 15, 252, name_size, weight=750)
        subtitle_x = x + (15 if len(lines) > 1 else 14)
        y = subtitle_baseline
        for line in lines:
            art.text(key, line, subtitle_x, y, subtitle_size, weight=500)
            y += line_height

    art.rect("footer", 44, 382 + extra_height, 1112, 50, INK, radius=24)
    art.text("footer", footer, 600, 415 + extra_height, 21, color=BG, weight=700, anchor="middle")
    art.write("hero", lang)


if __name__ == "__main__":
    version = skill_version()
    for language in SUFFIXES:
        hero(language, version)
