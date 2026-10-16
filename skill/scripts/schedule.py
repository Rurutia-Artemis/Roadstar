#!/usr/bin/env python3
"""Turn a split table into a schedule: per-task estimate, finish time, totals (standard library only).

Input is the plan §10 table or the minutes table (markdown) or ``--tasks``
JSON.  Each task becomes five segments: Argo writes the brief → the lane
executes → the reviewer reads → Argo accepts → Argo merges.  Argo is one
serial lane; Codex and Claude lanes have per-strategy parallel caps; a family
whose weekly window is empty cannot start before its reset.  Output is the
seven-column table with four total lines (markdown) or ``--json``.
"""

import argparse
from datetime import datetime, timedelta
import importlib.util
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rs_tasks as rs  # noqa: E402


MAX_ROWS = 8
STRATEGY_LABEL = {"auto": "自动分配", "quality": "质量优先", "thrift": "省着用", "rush": "赶时间"}
CONFIDENCE_RANK = {"高": 3, "中": 2, "低": 1}


class Lane:
    def __init__(self, name, capacity):
        self.name, self.capacity, self.busy = name, capacity, []

    def earliest(self, ready, minutes):
        if self.capacity is None:
            return ready
        candidates = sorted({ready} | {end for _, end, _ in self.busy if end > ready})
        for start in candidates:
            end = start + timedelta(minutes=minutes)
            if self.fits(start, end):
                return start
        return candidates[-1]

    def fits(self, start, end):
        points = sorted({start} | {s for s, _, _ in self.busy if start <= s < end})
        for point in points:
            active = sum(1 for s, e, _ in self.busy if s <= point < e)
            if active >= self.capacity:
                return False
        return True

    def book(self, start, minutes, label):
        end = start + timedelta(minutes=minutes)
        self.busy.append((start, end, label))
        return end


def topological(tasks):
    ids = {task["id"] for task in tasks}
    remaining = {task["id"]: [dep for dep in task["deps"] if dep in ids] for task in tasks}
    unknown = sorted({dep for task in tasks for dep in task["deps"] if dep not in ids})
    order, done = [], set()
    while remaining:
        ready = [task for task in tasks if task["id"] in remaining and all(dep in done for dep in remaining[task["id"]])]
        if not ready:
            cycle = sorted(remaining)
            raise ValueError("依赖成环：" + "、".join(cycle))
        task = ready[0]
        order.append(task)
        done.add(task["id"])
        del remaining[task["id"]]
    return order, unknown


def family_lane(family, lanes):
    return lanes.get(family) or lanes["external"]


def schedule(tasks, start, strategy_spec, defaults, local, probe, strategy):
    lanes = {"argo": Lane("argo", 1), "codex": Lane("codex", strategy_spec["parallel"]["codex"]),
             "claude": Lane("claude", strategy_spec["parallel"]["claude"]), "chair": Lane("chair", None),
             "external": Lane("external", None)}
    gates, notes = {}, []
    for family, side_key, used_key in (("codex", "codex", "weekly"), ("claude", "claude", "seven_day")):
        side = (probe or {}).get(side_key) or {}
        window = side.get(used_key)
        if side.get("tier") == "空" and window:
            reset = rs.parse_iso(window["resets_at"])
            if reset > start:
                gates[family] = reset
                notes.append(f"{'Codex' if family == 'codex' else 'Claude'} 本周已空，这边的线排在 {rs.fmt_jst(reset, True)} 重置之后")
        elif side.get("source") == "none" and family == "claude":
            notes.append("Claude 读不到，按紧处理")
    argo = defaults["argo_minutes"]
    review_minutes_default = rs.estimate_minutes("复核", "sonnet", "medium", defaults, local)[0]
    order, unknown = topological(tasks)
    if unknown:
        notes.append("依赖里有表外编号：" + "、".join(unknown) + "，当作已完成")
    finish, rows = {}, []
    for task in order:
        model, effort, family = task["model"], task["effort"], rs.family_of(task["model"])
        family = family if family in lanes else "external"
        if family in ("codex", "claude") and not effort:
            effort = "high" if model in ("gpt-6.1-sol", "gpt-6-astra") else "medium"
        if task["est_minutes"]:
            exec_minutes, source, confidence = task["est_minutes"], "表里给的", "中"
        elif family in ("codex", "claude"):
            exec_minutes, source, confidence = rs.estimate_minutes(task["class"], model, effort, defaults, local)
        elif family == "argo":
            exec_minutes, source, confidence = rs.estimate_minutes(task["class"], "fable", "high", defaults, local)
        else:
            exec_minutes, source, confidence = 0, "外部，不计时", "低"
        exec_minutes = int(round(exec_minutes))
        deps_done = [finish[dep] for dep in task["deps"] if dep in finish]
        ready = max([start] + deps_done)
        because = None
        if deps_done and max(deps_done) == ready and ready > start:
            because = max(task["deps"], key=lambda dep: finish.get(dep, start))
        # 1 Argo writes the brief (external lanes still need a brief).
        brief_start = lanes["argo"].earliest(ready, argo["brief"])
        brief_end = lanes["argo"].book(brief_start, argo["brief"], f"{task['id']} 任务书")
        # 2 execution
        exec_ready = max(brief_end, gates.get(family, start))
        lane = family_lane(family, lanes)
        exec_start = lane.earliest(exec_ready, exec_minutes) if exec_minutes else exec_ready
        if exec_start > exec_ready:
            # The lane was full: the task whose line ended at exec_start freed the slot.
            ids = {t["id"] for t in tasks}
            freed = [label.split()[0] for s, e, label in lane.busy if e == exec_start and label.split()[0] in ids]
            if freed:
                because = freed[0]
        exec_end = lane.book(exec_start, exec_minutes, task["id"]) if exec_minutes else exec_start
        # 3 review
        reviewer = task.get("reviewer")
        review_family = rs.family_of(reviewer)
        if review_family in ("codex", "claude"):
            minutes = int(round(review_minutes_default))
            review_lane = lanes[review_family]
            review_start = review_lane.earliest(max(exec_end, gates.get(review_family, start)), minutes)
            review_end = review_lane.book(review_start, minutes, f"{task['id']} 复核")
        elif review_family == "argo" or reviewer is None:
            review_end = exec_end  # Argo re-runs during acceptance
        else:
            review_end = exec_end  # chair nod: not counted
        # 4 acceptance, 5 merge (Argo)
        accept_start = lanes["argo"].earliest(review_end, argo["accept"])
        accept_end = lanes["argo"].book(accept_start, argo["accept"], f"{task['id']} 验收")
        merge_start = lanes["argo"].earliest(accept_end, argo["merge"])
        merge_end = lanes["argo"].book(merge_start, argo["merge"], f"{task['id']} 合并")
        finish[task["id"]] = merge_end
        rows.append({
            "id": task["id"], "name": task["name"], "class": task["class"], "family": family,
            "executor": rs.executor_label(model, effort) if family in ("codex", "claude", "argo") else (task["executor_text"] or rs.executor_label(model)),
            "effort": effort, "model": model, "reason": task.get("reason") or "",
            "est_minutes": exec_minutes, "est_text": rs.fmt_minutes(exec_minutes) if exec_minutes else "外部",
            "est_source": source, "confidence": confidence,
            "reviewer": task.get("reviewer_text") or ("我复跑" if reviewer is None else rs.executor_label(reviewer)),
            "deps": task["deps"], "deps_text": " ".join(dep.lstrip("T") for dep in task["deps"]) or "无",
            "start": exec_start.isoformat(timespec="minutes"), "finish": merge_end.isoformat(timespec="minutes"),
            "finish_jst": rs.fmt_jst(merge_end), "finish_date_jst": rs.fmt_jst(merge_end, True),
            "waits_for_reset": family in gates, "because": because,
        })
    lane_minutes = sum(row["est_minutes"] for row in rows) + sum(
        int(round(review_minutes_default)) for task in tasks if rs.family_of(task.get("reviewer")) in ("codex", "claude"))
    argo_minutes = sum(int((end - s).total_seconds() // 60) for s, end, _ in lanes["argo"].busy)
    end_time = max(finish.values()) if finish else start
    # critical path: walk back from the last finished task along "because" links
    last = max(finish, key=finish.get) if finish else None
    path = []
    by_id = {row["id"]: row for row in rows}
    while last:
        path.append(last)
        last = by_id[last]["because"]
    path.reverse()
    parallel = {family: max((sum(1 for s, e, _ in lanes[family].busy if s <= point < e)
                             for point in {s for s, _, _ in lanes[family].busy}), default=0) for family in ("codex", "claude")}
    confidence = min((row["confidence"] for row in rows if row["est_minutes"]), key=CONFIDENCE_RANK.get, default="低")
    return {
        "strategy": strategy, "strategy_label": STRATEGY_LABEL[strategy],
        "start": start.isoformat(timespec="minutes"), "start_jst": rs.fmt_jst(start, True),
        "rows": rows, "critical_path": path,
        "lane_minutes": lane_minutes, "lane_text": rs.fmt_minutes(lane_minutes),
        "argo_minutes": argo_minutes, "argo_text": rs.fmt_minutes(argo_minutes),
        "parallel": parallel, "finish": end_time.isoformat(timespec="minutes"),
        "finish_jst": rs.fmt_jst(end_time), "finish_date_jst": rs.fmt_jst(end_time, True),
        "total_minutes": int((end_time - start).total_seconds() // 60), "total_text": rs.fmt_minutes((end_time - start).total_seconds() / 60),
        "confidence": confidence, "notes": notes, "gates": {k: v.isoformat(timespec="minutes") for k, v in gates.items()},
    }


def quota_line(tasks, strategy, probe, defaults, local, estimate_json):
    """Use quota-estimate.py's plan_cost for the 额度 line when a probe is given."""
    if estimate_json and estimate_json.get("plan"):
        totals = estimate_json["plan"]["totals"]
        return "；".join(totals[key]["text"] for key in ("codex", "claude") if key in totals and totals[key]["units"]) or "无"
    if not probe:
        return "没给探针读数，开工前再跑一次面板"
    spec = importlib.util.spec_from_file_location("quota_estimate", Path(__file__).resolve().parent / "quota-estimate.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    providers = rs.load_providers()
    now = datetime.now(rs.UTC)
    estimates = {key: module.side_estimate(key, probe.get(key) or {}, providers, local, defaults, now) for key in ("claude", "codex")}
    cost = module.plan_cost(tasks, strategy, providers, defaults, local, estimates)
    parts = [cost["totals"][key]["text"] for key in ("codex", "claude") if cost["totals"][key]["units"]]
    for family, index in cost["shortfall"].items():
        parts.append(f"第 {index} 件起 {'Codex' if family == 'codex' else 'Claude'} 会过 90%，到时按策略降级或刷重置卡")
    return "；".join(parts) or "无"


def render(result, quota_text, title):
    rows = result["rows"]
    head = f"拆分表（{result['strategy_label']}"
    if result["notes"]:
        head += "；" + "；".join(result["notes"])
    sources = sorted({r["est_source"] for r in rows if r["est_minutes"]})
    head += f"；预估按{'、'.join(sources) if sources else '默认值表'}，置信度{result['confidence']}）"
    lines = [head] if not title else [f"{title}", head]
    header = ["#", "事", "给谁 · 强度", "为什么", "预估", "预计完成", "审查人", "依赖"]
    table = [header]
    shown = rows[:MAX_ROWS]
    for index, row in enumerate(shown, 1):
        table.append([str(index), row["name"], row["executor"], row["reason"] or "—", row["est_text"],
                      row["finish_jst"] + ("（重置后）" if row["waits_for_reset"] else ""), row["reviewer"], row["deps_text"]])
    widths = [min(max(rs.display_width(r[i]) for r in table), 26 if i in (1, 3) else 40) for i in range(len(header))]
    for r in table:
        cells = []
        for i, cell in enumerate(r):
            text = cell
            while rs.display_width(text) > widths[i]:
                text = text[:-1]
            cells.append(rs.pad(text, widths[i]))
        lines.append(" " + "  ".join(cells).rstrip())
    rest = rows[MAX_ROWS:]
    if rest:
        groups = {}
        for row in rest:
            groups.setdefault((row["class"], row["executor"]), []).append(row)
        for (klass, executor), group in groups.items():
            like = next((i for i, r in enumerate(shown, 1) if r["class"] == klass and r["executor"] == executor), None)
            last = max(group, key=lambda r: r["finish"])
            lines.append(f" 另 {len(group)} 件{klass}（{executor}）{'，同第 ' + str(like) + ' 件的配置' if like else ''}，预计 {last['finish_jst']} 前陆续完成")
    lines.append("─" * 72)
    path = " → ".join(p.lstrip("T") for p in result["critical_path"]) if result["critical_path"] else "无"
    codex_n, claude_n = result["parallel"]["codex"], result["parallel"]["claude"]
    par = "、".join(f"{n} 条 {name} 线" for n, name in ((codex_n, "Codex"), (claude_n, "Claude")) if n) or "无并行线"
    lines.append(f" 线上工时合计 {result['lane_text']}（含复核）；我这边任务书、验收、合并共 {result['argo_text']}；并行 {par}；关键路径 {path}")
    lines.append(f" 预计全部完工 {result['finish_date_jst']} JST（从你说开工 {result['start_jst']} 起算，等你点头的时间不算）")
    lines.append(f" 额度：{quota_text}")
    lines.append(" 开工就按表派，改哪条说一声。")
    return "\n".join(lines)


def parse_start(value):
    if not value:
        return datetime.now(rs.UTC).replace(second=0, microsecond=0)
    if len(value) <= 5 and ":" in value:
        hour, minute = value.split(":")
        local = datetime.now(rs.JST).replace(hour=int(hour), minute=int(minute), second=0, microsecond=0)
        return local.astimezone(rs.UTC)
    return rs.parse_iso(value)


def main(argv=None):
    parser = argparse.ArgumentParser(description="把拆分表排成带预估和完工时刻的排活表")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--plan", type=Path, help="含拆分表的 plan.md 或纪要")
    source.add_argument("--tasks", type=Path, help="任务 JSON：[{id, name, class, executor, reviewer, deps, est}]")
    parser.add_argument("--start", help="开工时刻，ISO 或 HH:MM（JST）；默认现在")
    parser.add_argument("--strategy", choices=sorted(STRATEGY_LABEL), default="auto")
    parser.add_argument("--probe", type=Path, help="quota-status.py --json 输出，用来判额度窗口")
    parser.add_argument("--estimate", type=Path, help="quota-estimate.py --plan 的输出，用它的额度行")
    parser.add_argument("--defaults", type=Path)
    parser.add_argument("--estimates", type=Path, help="本机校准表")
    parser.add_argument("--strategies", type=Path)
    parser.add_argument("--parallel-codex", type=int)
    parser.add_argument("--parallel-claude", type=int)
    parser.add_argument("--title", default="")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.plan:
            tasks = rs.parse_tasks_markdown(args.plan.read_text(encoding="utf-8"))
        else:
            raw = json.loads(args.tasks.read_text(encoding="utf-8"))
            tasks = [rs.task_from_cells(str(item.get("id", f"T{i}")), item["name"], item.get("class", ""), item.get("executor", ""),
                                        str(item.get("cap", "") or ""), item.get("reviewer", ""),
                                        " ".join(item.get("deps", [])) if isinstance(item.get("deps"), list) else str(item.get("deps", "") or ""),
                                        str(item.get("est", "") or ""), item.get("reason", ""), item.get("module", ""))
                     for i, item in enumerate(raw, 1)]
        defaults = rs.load_defaults(args.defaults)
        strategies = rs.load_strategies(args.strategies)
        probe = json.loads(args.probe.read_text(encoding="utf-8")) if args.probe else None
        estimate_json = json.loads(args.estimate.read_text(encoding="utf-8")) if args.estimate else None
        start = parse_start(args.start)
    except (OSError, ValueError, KeyError) as error:
        print(f"输入有问题：{error}", file=sys.stderr)
        return 2
    if not tasks:
        print("没找到拆分表：表头要有「任务」或「事」和「执行方」或「给谁」", file=sys.stderr)
        return 2
    local = rs.load_local_estimates(args.estimates)
    spec = json.loads(json.dumps(strategies["strategies"][args.strategy]))
    if args.parallel_codex:
        spec["parallel"]["codex"] = args.parallel_codex
    if args.parallel_claude:
        spec["parallel"]["claude"] = args.parallel_claude
    try:
        result = schedule(tasks, start, spec, defaults, local, probe, args.strategy)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2
    quota_text = quota_line(tasks, args.strategy, probe, defaults, local, estimate_json)
    result["quota_text"] = quota_text
    result["markdown"] = render(result, quota_text, args.title)
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(result["markdown"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
