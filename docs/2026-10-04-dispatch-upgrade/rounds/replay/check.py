#!/usr/bin/env python3
"""调度回放检查：读 results.json（Workflow 产出），对照 fixtures.json 逐条检查六条性质和两遍一致率。
用法：python3 check.py results.json
results.json 结构：[{"table","scenario","run","rows":[{id,difficulty,executor:{side,model,effort},verifier:{side,model},evidence,reason}],"conflicts":[],"notes":""}]
"""
import json, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
fx = json.load(open(os.path.join(HERE, "fixtures.json")))
res = json.load(open(sys.argv[1]))

CODEX_MODELS = {"gpt-6-astra", "gpt-6.1-sol", "gpt-6-luna", "astra", "sol", "luna", "6.1 sol"}
CLAUDE_MODELS = {"opus", "sonnet", "fable", "haiku", "claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-1"}
BLOCK_CODEX = {"browser_dev", "local_server", "swiftui_build", "network", "system_permission", "real_device"}
ONLY_MAIN = {"outside_workspace", "production"}

def fam(side, model):
    s = (side or "").lower(); m = (model or "").lower()
    if s in ("codex", "dex") or any(k in m for k in ("gpt", "astra", "sol", "luna")): return "codex"
    if s in ("claude", "argo", "main", "subagent") or any(k in m for k in CLAUDE_MODELS): return "claude"
    if s in ("chair", "主席"): return "chair"
    if s in ("pro",): return "pro"
    return s or "?"

fails, passes = [], 0
def check(cond, msg):
    global passes
    if cond: passes += 1
    else: fails.append(msg)

by_key = {}
for r in res:
    t, sc, run = r["table"], r["scenario"], r.get("run", 1)
    by_key[(t, sc, run)] = r
    tasks = {x["id"]: x for x in fx["tables"][t]["tasks"]}
    rows = {x["id"]: x for x in r["rows"]}
    tag = f"{t}/{sc}/r{run}"
    check(set(rows) == set(tasks), f"{tag}: 任务编号不齐，缺 {set(tasks)-set(rows)} 多 {set(rows)-set(tasks)}")
    eligible, to_codex = 0, 0
    for tid, row in rows.items():
        task = tasks.get(tid)
        if not task: continue
        ex, vf = row.get("executor", {}), row.get("verifier", {})
        exf, vff = fam(ex.get("side"), ex.get("model")), fam(vf.get("side"), vf.get("model"))
        needs = set(task.get("needs", []))
        # P6 每行有型号和强度（主席做的除外）
        if exf != "chair":
            check(bool(ex.get("model")) and bool(ex.get("effort")), f"{tag} {tid}: 缺型号或强度 {ex}")
        # P1 执行环境
        if needs & ONLY_MAIN:
            # 真动工作区外那一步只能 Argo 或主席；脚本可由别人写，所以执行方是 Codex/子代理时，验证方必须是 Argo（由它跑真部署）
            exside = (ex.get("side") or "").lower()
            ok_main = exside in ("argo", "main", "chair", "主席")
            ok_hybrid = (vf.get("side") or "").lower() in ("argo", "chair", "主席")
            check(ok_main or ok_hybrid, f"{tag} {tid}: 要写工作区外/生产，派给了 {ex}，真动那一步也没交给 Argo（verifier={vf}）")
        elif needs & BLOCK_CODEX:
            check(exf != "codex", f"{tag} {tid}: 执行环境 {sorted(needs & BLOCK_CODEX)} 不能进 Codex 沙箱，却派给了 {ex}")
        if "browser_verify" in needs and exf == "codex":
            check(vff == "claude", f"{tag} {tid}: Codex 写、却没让 Claude 侧跑浏览器验收（verifier={vf}）")
        # P3 难度
        de = task["difficulty_expected"]
        m = (ex.get("model") or "").lower()
        if de == "难":
            check(not any(k in m for k in ("luna", "sonnet", "haiku")), f"{tag} {tid}: 难任务派给了 {m}")
        if de == "易":
            check(not any(k in m for k in ("astra", "fable")), f"{tag} {tid}: 易任务派给了 {m}")
        # P4 验证方
        if de in ("中", "难") and exf in ("codex", "claude"):
            if sc in ("A_codex_rich", "D_hard_instruction") and exf == "codex" and not task.get("sensitive"):
                # Claude 紧那一列允许 Codex 另一型号验收 Codex 做的活；钱、权限、迁移类除外
                check(vff in ("codex", "claude", "argo", "pro"), f"{tag} {tid}: 验证方缺失（verifier={vf}）")
            elif sc == "B_claude_rich" and exf == "claude":
                check(vff in ("codex", "pro") or "同家" in (r.get("notes", "") + row.get("reason", "")) or "注明" in (r.get("notes", "") + row.get("reason", "")),
                      f"{tag} {tid}: Codex 空时同家验收没注明（verifier={vf}）")
            else:
                check(vff not in ("", "?", "none") and vff != exf, f"{tag} {tid}: 验证方和执行方同家或缺失（exec={exf} verifier={vff}）")
            check(bool(row.get("evidence")), f"{tag} {tid}: 没写证据类型")
        if task.get("sensitive") and exf in ("codex", "claude"):
            text = (r.get("notes", "") + row.get("reason", "") + row.get("verify_method", ""))
            other_side_gone = sc == "B_claude_rich" and exf == "claude"
            ok = (vff not in ("", "?", "none") and vff != exf) or (other_side_gone and (vff in ("pro", "chair") or "主席" in text or "Pro" in text))
            check(ok, f"{tag} {tid}: 钱/权限/迁移类任务同家验收且没走 Pro/主席（exec={exf} verifier={vff}）")
        # P2 统计
        blocked = bool(needs & (BLOCK_CODEX | ONLY_MAIN)) or task.get("visual") or "chair_review" in needs or "chinese_copy" in needs or "foreign_copy" in needs or "calls_models" in needs
        if not blocked and sc in ("A_codex_rich", "B_claude_rich"):
            eligible += 1
            if exf == "codex": to_codex += 1
    if sc == "A_codex_rich" and eligible:
        check(to_codex / eligible >= 0.7, f"{tag}: Codex 多时合格任务只有 {to_codex}/{eligible} 派给 Codex")
    if sc == "B_claude_rich" and eligible:
        check(to_codex == 0, f"{tag}: Codex 空时还有 {to_codex} 件派给 Codex")
    if sc == "D_hard_instruction":
        code_rows = [rows[i] for i in rows if i in tasks and "foreign_copy" not in tasks[i].get("needs", [])]
        check(all(fam(x.get("executor", {}).get("side"), x.get("executor", {}).get("model")) == "claude" and "opus" in (x.get("executor", {}).get("model") or "").lower() for x in code_rows),
              f"{tag}: 硬话「代码一律 Opus」没压过额度")
        check(bool(r.get("conflicts")), f"{tag}: 硬话和额度撞上却没报冲突")

# 一致率：同一 table/scenario 的 run1 与 run2
for (t, sc, run), r in list(by_key.items()):
    if run != 1 or (t, sc, 2) not in by_key: continue
    a = {x["id"]: fam(x["executor"].get("side"), x["executor"].get("model")) for x in r["rows"]}
    b = {x["id"]: fam(x["executor"].get("side"), x["executor"].get("model")) for x in by_key[(t, sc, 2)]["rows"]}
    same = sum(1 for k in a if a.get(k) == b.get(k)); total = max(1, len(a))
    check(same / total >= 0.8, f"{t}/{sc}: 两遍派法一致率 {same}/{total}")
    print(f"一致率 {t}/{sc}: {same}/{total}")

print(f"通过 {passes} 条，失败 {len(fails)} 条")
for f in fails: print(" -", f)
sys.exit(1 if fails else 0)
