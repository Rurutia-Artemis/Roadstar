#!/usr/bin/env python3
"""圆桌 · 把 Dex 的 JSON 审稿渲染成可读文本（贴给主席、抄进账本）。
用法：render-review.py <rN-dex-review.json> [--round N] [--from Dex]
"""
import json, sys

SEV = {"blocking": "阻塞", "should": "建议", "nit": "小意见"}
ST = {"ok": "ok", "weak": "弱", "missing": "缺"}
VD = {"resolved": "已解决", "still_open": "仍开放", "escalate": "交主席"}

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(2)
    path = args[0]; rnd = ""; who = "Dex"
    if "--round" in args: rnd = args[args.index("--round") + 1]
    if "--from" in args: who = args[args.index("--from") + 1]
    d = json.load(open(path))
    out = []
    head = f"{who}：第 {rnd} 轮审稿" if rnd else f"{who}：审稿"
    out.append(f"## {head} · {d['verdict']}")
    bad = [c for c in d.get("checklist", []) if c["status"] != "ok"]
    if bad:
        out.append("\n清单未过项：")
        for c in bad:
            out.append(f"- {c['item']}（{ST.get(c['status'], c['status'])}）：{c['note']}")
    else:
        out.append("\n清单：全部 ok")
    issues = d.get("new_issues", [])
    if issues:
        out.append("\n新议题：")
        for i, it in enumerate(issues, 1):
            scope = "" if it.get("scope", "in") == "in" else "【范围外→停车场】"
            out.append(f"- {i}. [{SEV.get(it['severity'], it['severity'])}]{scope} {it['title']}")
            out.append(f"  - 证据：{it['evidence']}")
            out.append(f"  - 改法：{it['suggestion']}")
    else:
        out.append("\n新议题：无")
    ov = d.get("open_issue_verdicts", [])
    if ov:
        out.append("\n对开放议题的判定：")
        for v in ov:
            out.append(f"- {v['id']}：{VD.get(v['verdict'], v['verdict'])}。{v['reason']}")
    if d.get("alternative", "").strip():
        out.append(f"\n替代方案：{d['alternative'].strip()}")
    if d.get("reply_to_chair", "").strip():
        out.append(f"\n答主席：{d['reply_to_chair'].strip()}")
    qs = d.get("questions_for_chair", [])
    if qs:
        out.append("\n问主席：")
        for q in qs:
            out.append(f"- {q}")
    print("\n".join(out))

if __name__ == "__main__":
    main()
