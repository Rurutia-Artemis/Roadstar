#!/usr/bin/env python3
"""Generate the script gates and two-vendor lineup in three languages."""

from common import BG, CARD, CORAL, GOLD, INK, LINE, MUTED, SUFFIXES, TEAL, Drawing

GATES = {
    "zh-CN": (
        ("派活前", "任务书缺一栏，派不出去"),
        ("合并时", "没有验收记录，合不进主干"),
        ("收尾时", "还有没收完的，不算做完"),
    ),
    "en": (
        ("Before dispatch", "Brief missing a field: no dispatch"),
        ("At merge", "No verification record, no merge to main"),
        ("At wrap-up", "Loose ends mean not done"),
    ),
    "ja": (
        ("割り当て前", "指示書に項目抜け：割り当て不可"),
        ("マージ時", "検収記録なし：メインにマージ不可"),
        ("仕上げ時", "残作業があれば完了にならない"),
    ),
}

LINEUP = {
    "zh-CN": (
        "Claude 这边", "Codex 这边", "换一家验收",
        ("任务书、拍板", "验收、补位", "取证、批量", "出错才升级", "写代码", "难活、审方案"),
        "额度用到零才停",
    ),
    "en": (
        "Claude side", "Codex side", "Cross-vendor verify",
        ("Briefs, decisions", "Verify, cover gaps", "Evidence, bulk jobs", "Escalate only on error",
         "Writes code", "Hard tasks, plan review"),
        "Stop only at zero quota",
    ),
    "ja": (
        "Claude 側", "Codex 側", "別社で検収",
        ("指示書・最終判断", "検収・代役", "事実確認・一括処理", "ミス時だけ Opus へ",
         "コード実装", "難題・設計レビュー"),
        "クォータが 0 になるまで止めない",
    ),
}


def gates(lang):
    scripts = ("brief-check.py", "guard.py", "cleanup.py --check")
    rows = GATES[lang]
    desc = " / ".join(f"{when}: {script} — {result}" for (when, result), script in zip(rows, scripts))
    art = Drawing(331, lang, " · ".join(when for when, _ in rows), desc)
    for index, ((when, result), script) in enumerate(zip(rows, scripts)):
        y = 35 + index * 90
        when_id, script_id, result_id = (f"{column}-{index}" for column in ("when", "script", "result"))
        art.rect(when_id, 44, y, 234, 80, CARD, stroke=LINE)
        art.star(70, y + 40, 10, (CORAL, GOLD, TEAL)[index])
        art.text(when_id, when, 92, y + 48, 19, weight=750)
        art.rect(script_id, 290, y, 276, 80, INK)
        art.text(script_id, script, 428, y + 47, 20, color=BG, mono=True, anchor="middle")
        art.rect(result_id, 578, y, 578, 80, CARD, stroke=LINE)
        if lang == "en" and index == 1:
            record, outcome = result.split(", ", 1)
            art.text(result_id, record + ",", 605, y + 35, 24, weight=700)
            art.text(result_id, outcome, 605, y + 64, 24, weight=700)
        else:
            art.text(result_id, result, 605, y + 48, 24, weight=700)
    art.write("gates", lang)


def lineup(lang):
    claude, codex, verify, roles, footer = LINEUP[lang]
    names = ("Fable", "Sonnet", "Haiku", "Opus", "Sol", "Astra")
    desc = " / ".join([*(f"{name}: {role}" for name, role in zip(names, roles)), verify, footer])
    art = Drawing(461, lang, f"{claude} · {codex}", desc)

    for key, x, head, tone in (("claude", 44, claude, CORAL), ("codex", 735, codex, TEAL)):
        art.rect(key, x, 30, 421, 46, BG, radius=0)
        art.star(x + 16, 53, 12, tone)
        art.text(key, head, x + 38, 62, 26, weight=800)

    for index, (name, role) in enumerate(zip(names[:4], roles[:4])):
        y = 85 + index * 72
        key = f"claude-{index}"
        art.rect(key, 44, y, 421, 62, BG if name == "Opus" else CARD,
                 radius=16, stroke=MUTED if name == "Opus" else LINE, dash="6 5" if name == "Opus" else None)
        art.text(key, name, 66, y + 39, 24, weight=800)
        art.text(key, role, 173, y + 39, 19, weight=500)

    art.rect("sol", 735, 85, 421, 204, CARD, stroke=LINE)
    art.rect("sol-accent", 757, 108, 44, 6, TEAL, radius=3)
    art.text("sol", names[4], 757, 194, 70, weight=800)
    art.text("sol", roles[4], 758, 248, 32, weight=750)
    art.rect("astra", 735, 301, 421, 62, CARD, radius=16, stroke=LINE)
    art.text("astra", names[5], 757, 340, 24, weight=800)
    art.text("astra", roles[5], 861, 340, 19, weight=500)

    art.rect("verify", 478, 160, 244, 56, BG, radius=0)
    art.text("verify", verify, 600, 193, 18, weight=800, anchor="middle")
    art.path("M508,235 H692 M518,225 L508,235 518,245 M682,225 L692,235 682,245", width=3)
    art.star(600, 235, 9)

    art.rect("footer", 44, 382, 1112, 50, INK, radius=24)
    art.text("footer", footer, 600, 415, 21, color=BG, weight=700, anchor="middle")
    art.write("lineup", lang)


if __name__ == "__main__":
    for language in SUFFIXES:
        gates(language)
        lineup(language)
