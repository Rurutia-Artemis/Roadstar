#!/usr/bin/env python3
"""Generate the 1.14 / 2.0 comparison and seven-step workflow in three languages."""

from common import BG, CARD, CORAL, GOLD, INK, LINE, MUTED, SUFFIXES, TEAL, Drawing

CHANGES = {
    "zh-CN": (
        ("触发", "点名才跑", "默认就走"),
        ("规矩", "写在正文里", "脚本拦三处"),
        ("正文", "224 行", "54 行"),
        ("开工前", "开场面板和策略一问", "一页设计"),
        ("探讨", "默认三轮", "两家各出一轮"),
    ),
    "en": (
        ("Trigger", "Runs only when named", "Runs by default"),
        ("Rules", "Rules in the text", "Scripts block at 3 points"),
        ("Body", "224 lines", "54 lines"),
        ("Before work", "Dashboard and strategy prompt", "One-page design"),
        ("Discussion", "Three rounds by default", "One round from each vendor"),
    ),
    "ja": (
        ("起動", "明示呼び出し時のみ", "既定で動く"),
        ("ルール", "本文に書く", "スクリプトが3か所で止める"),
        ("本文", "224 行", "54 行"),
        ("着手前", "開始パネルと戦略の確認", "1 ページ設計"),
        ("検討", "通常は3ラウンド", "両社が1ラウンドずつ"),
    ),
}

WORKFLOW = {
    "zh-CN": (
        (("一页设计",), ("判难度",), ("六栏任务书",), ("派活",), ("换会话验收",), ("收尾",), ("对账",)),
        (("Claude 主会话",), ("Codex 或子代理",), ("另一家模型",)),
    ),
    "en": (
        (("One-page", "design"), ("Size the", "job"), ("Six-field", "brief"), ("Dispatch",),
         ("Verify in a", "new session"), ("Wrap up",), ("Reconcile",)),
        (("Claude main session",), ("Codex or", "subagent"), ("Other vendor's", "model")),
    ),
    "ja": (
        (("1 ページ設計",), ("難易度の判定",), ("6 項目の指示書",), ("割り当て",),
         ("別セッションで検収",), ("仕上げ",), ("照合",)),
        (("Claude メインセッション",), ("Codex かサブエージェント",), ("別社のモデル",)),
    ),
}


def changes(lang):
    rows = CHANGES[lang]
    desc = " / ".join(f"{label}: {before} → {after}" for label, before, after in rows)
    header_top, top, gap = 34, 111, 9
    row_heights = (58, 58, 98, 58, 58)
    last_row_bottom = top + sum(row_heights) + gap * (len(rows) - 1)
    # The last row's 2-unit stroke extends one unit beyond its rect.
    art = Drawing(last_row_bottom + 1 + header_top, lang, "1.14 → 2.0", desc)
    art.rect("before", 228, header_top, 429, 66, LINE)
    art.rect("after", 718, header_top, 438, 66, GOLD)
    art.text("before", "1.14", 254, 79, 34, weight=800, mono=True)
    art.text("after", "2.0", 744, 79, 34, weight=800, mono=True)
    art.star(1121, 67, 13, INK)

    for index, ((label, before, after), height) in enumerate(zip(rows, row_heights)):
        body = index == 2
        center = top + height / 2
        art.rect(f"label-{index}", 34, top, 184, height, BG, radius=0)
        art.rect(f"before-{index}", 228, top, 429, height, LINE, radius=15)
        art.rect(f"after-{index}", 718, top, 438, height, CARD, radius=15, stroke=LINE)
        art.text(f"label-{index}", label, 49, center + 7, 21, weight=700)
        art.path(f"M670,{center} H705 m-8,-7 l8,7 -8,7", color=TEAL)
        size = 57 if body else 22
        baseline = center + (19 if body else 8)
        art.text(f"before-{index}", before, 254, baseline, size, weight=750 if body else 500)
        art.text(f"after-{index}", after, 744, baseline, size, weight=800 if body else 700)
        top += height + gap

    art.write("changes", lang)


def workflow(lang):
    steps, owners = WORKFLOW[lang]
    desc = " → ".join(" ".join(lines) for lines in steps)
    art = Drawing(330, lang, desc, " / ".join(" ".join(lines) for lines in owners))
    widths = (144, 136, 147, 166, 194, 122, 123)
    gap = 12
    lefts = [48 + sum(widths[:index]) + gap * index for index in range(len(widths))]
    centers = [x + width / 2 for x, width in zip(lefts, widths)]

    for index, (lines, x, width, cx) in enumerate(zip(steps, lefts, widths, centers)):
        key = f"step-{index}"
        verify = index == 4
        accent = verify or index == 0
        art.rect(key, x, 38, width, 128, INK if verify else CARD, stroke=None if verify else LINE)
        art.rect(f"number-{index}", x + 13, 52, 42, 34, GOLD if accent else LINE,
                 radius=10, stroke=None if accent else TEAL)
        art.text(f"number-{index}", str(index), x + 34, 76, 21, weight=800, anchor="middle", mono=True)
        if verify:
            art.star(x + width - 26, 69, 11)
        if index < len(steps) - 1:
            right = x + width
            art.path(f"M{right + 2},106 H{right + 9} m-3,-4 l4,4 -4,4", color=MUTED, width=1.6)
        size = 17 if lang == "ja" and index in (2, 4) else 18
        for offset, line in enumerate(lines):
            y = (120 if len(lines) == 2 else 133) + 25 * offset
            art.text(key, line, cx, y, size, weight=750, color=BG if verify else INK, anchor="middle")

    for first, last, lines, fill in (
        (0, 2, owners[0], LINE), (3, 3, owners[1], LINE),
        (4, 4, owners[2], GOLD), (5, 6, owners[0], LINE),
    ):
        if lang == "ja" and first == 3:
            # Break after the particle without inserting a space in the source text.
            prefix, particle, rest = lines[0].partition("か")
            lines = (prefix + particle, rest)
        x = lefts[first]
        width = lefts[last] + widths[last] - x
        key = f"owner-{first}"
        art.rect(key, x, 181, width, 56, fill, radius=14)
        for offset, line in enumerate(lines):
            y = (205 if len(lines) == 2 else 215) + 20 * offset
            art.text(key, line, x + width / 2, y, 17, anchor="middle")

    for index, script, width in ((2, "brief-check.py", 172), (4, "guard.py", 110), (5, "cleanup.py --check", 203)):
        cx = centers[index]
        key = f"gate-{index}"
        art.path(f"M{cx},240 V257", color=CORAL, width=2)
        art.rect(key, cx - width / 2, 259, width, 39, INK, radius=19)
        art.text(key, script, cx, 284, 16, color=BG, anchor="middle", mono=True)

    art.write("workflow", lang)


if __name__ == "__main__":
    for language in SUFFIXES:
        changes(language)
        workflow(language)
