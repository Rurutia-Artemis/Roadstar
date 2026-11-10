#!/usr/bin/env python3
"""任务书校验：六栏齐了才派得出去（主人 2026-11-03 定）。dex-exec.sh 派活前自动跑；也可手动 `brief-check.py <任务书.md>`。

要查的六栏（按 references/task-brief-template.md 的标题，允许标题后带补充字）：
  目标与做完的样子    必须有一条能判对错的完成线（含「完成线」「做完」「通过」「期望」之一，且不是模板占位）
  涉及模块            至少一个模块名
  不许动什么
  执行环境
  验收命令与期望输出  至少一条命令或期望
  资源上限与止损      要写预计用时和上限（分钟）
型号和强度由 dex-exec 的 --model/--effort 带，不在这里查。

同类方案（主席 2026-11-07 定）：「目标」栏（任务书的「目标与做完的样子」，或 plan 的「1 目标与非目标」里
除「非目标」以外的行）出现整体性说法 新系统 / 新项目 / 新产品 / 新服务 / 大改版 / 重做 / 立项 之一，或「新模块」
且同一目标里还有「系统」「服务」「App」之一时，必须有标题含「同类方案」的一节（11-07 收窄：单独的「新建」
「新增」「新模块」不触发，「新建的测试文件」「新建 quota.py」这类不拦），里面至少 3 条带链接的条目（列表项、表格行或 ### 小标题各算一条）；查不到写「查过：关键词…，无」也放行。
plan 用 `brief-check.py --plan <plan.md>` 查，只查同类方案，不查六栏；无数字目标节时改查同目录 design.md
的「为什么做」「做完的样子」，两者都没有则放行。文件里没有「目标与做完的样子」而有
「<数字> 目标…」一节时自动按 plan 查。dex-exec.sh 派活前对场次目录的 plan.md 也跑一遍。
可选 --class / --est-minutes / --write / --plan-dir：写活检查引用的设计页与钩子点头记录；不传则保持原六栏检查。
--init-design-baseline [--dry-run] 初始化老场次 design-exempt；ROADSTAR_DESIGN_CHECK=0 只跳过设计检查并记账。
退出码：0 合格；2 不合格并列出缺什么。环境变量 BRIEF_CHECK=0 跳过（记一行到 stderr，给真正的急事）。
"""
import argparse
import subprocess
import re
import sys
from pathlib import Path

from design_page import (sections, find, prior_art_problems, approvals, approvals_cmd,
                         requires_design, find_design_page, design_problems, needs_approval, init_baseline)
import baselines
import skiplog

SECTIONS = ['目标与做完的样子', '涉及模块', '不许动什么', '执行环境', '验收命令与期望输出', '资源上限与止损']
PLACEHOLDER = re.compile(r'<[^>\n]{1,40}>|TODO|待填|TBD', re.I)
MIN_CHARS = {'涉及模块': 2, '不许动什么': 2, '执行环境': 2}  # 这三栏一个词就够


def is_plan(secs):
    return not any(k.startswith('目标与做完的样子') for k in secs) and any(re.match(r'^\d+\s*目标', k) for k in secs)


def problems(text, plan=False):
    secs = sections(text)
    if plan or is_plan(secs):
        return prior_art_problems(secs)
    bad = []
    for title in SECTIONS:
        body = find(secs, title)
        if body is None:
            bad.append(f'缺「{title}」一栏')
            continue
        stripped = PLACEHOLDER.sub('', body).strip()
        if len(stripped) < MIN_CHARS.get(title, 6):
            bad.append(f'「{title}」没写内容（只有模板占位）')
            continue
        if title == '目标与做完的样子' and not re.search(r'完成线|做完|通过|期望|算完成|才算', body):
            bad.append('「目标与做完的样子」里没有能判对错的完成线（写明做到什么算完成）')
        if title == '验收命令与期望输出' and not re.search(r'[`$]|npm|swift|pytest|python|curl|xcodebuild|node|期望|应', body):
            bad.append('「验收命令与期望输出」里没有命令或期望输出')
        if title == '资源上限与止损' and not re.search(r'\d+\s*(分钟|min|分)', body):
            bad.append('「资源上限与止损」里没有写分钟数（预计用时和上限）')
    return bad + prior_art_problems(secs)


def check_design(text, brief, plan_dir):
    bases = [brief.parent, plan_dir]
    try:
        run = subprocess.run(['git', '-C', str(plan_dir), 'rev-parse', '--show-toplevel'],
                             capture_output=True, text=True, timeout=10)
        if run.returncode == 0:
            bases.append(Path(run.stdout.strip()))
    except (OSError, subprocess.TimeoutExpired):
        pass
    bases.append(Path.cwd())
    design = find_design_page(text, bases)
    if design is None:
        return ['缺设计页：中活以上的写活先按 references/design-template.md 写一页设计，在任务书里写 `设计页：<路径>`']
    modules = find(sections(text), '涉及模块') or ''
    count = len([m for m in re.split(r'[,，、\n]', modules) if m.strip()])
    bad = design_problems(design, count)
    try:
        design_text = design.read_text(encoding='utf-8')
        if needs_approval(design_text):
            result = approvals(design)
            if not result['ok']:
                reason = result['reason']
                prefix = '' if reason.startswith('缺主人点头记录') else '缺主人点头记录：'
                bad.append(f'{prefix}{reason}。用 '
                           f'`python3 {approvals_cmd()} ask {design}` 生成问题，在选项框里问主人。'
                           '把 ask 输出的 question 原样放进选项框，选项只放「批准」「不批准」。')
            else:
                row = result['record']
                print(f'点头依据：{row.get("design", "")} {row.get("time", "")} '
                      f'tool_use_id={row.get("tool_use_id", "")} 指纹={row.get("fingerprint", "")}',
                      file=sys.stderr)
    except (OSError, UnicodeError):
        pass  # design_problems 已报告读取错误
    return bad


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('brief', nargs='?')
    parser.add_argument('--plan', action='store_true')
    parser.add_argument('--class', dest='cls')
    parser.add_argument('--est-minutes', type=int)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--plan-dir', type=Path)
    parser.add_argument('--init-design-baseline', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if args.init_design_baseline:
        init_baseline(args.dry_run)
        return 0
    if not args.brief or args.dry_run:
        parser.error('需要一份任务书；--dry-run 只用于 --init-design-baseline')
    plan = args.plan
    path = Path(args.brief)
    plan_dir = args.plan_dir or path.parent
    if skiplog.skipped('任务书检查', 'BRIEF_CHECK', plan_dir):
        print('brief-check：BRIEF_CHECK=0，跳过校验（记下：这份任务书没过六栏检查）', file=sys.stderr)
        return 0
    try:
        text = path.read_text(encoding='utf-8')
    except OSError as e:
        print(f'brief-check：读不到任务书 {path}：{e}', file=sys.stderr)
        return 2
    bad = problems(text, plan)
    if plan and not any(re.match(r'^\d+\s*目标', k) for k in sections(text)):
        design = path.parent / 'design.md'
        bad = []
        if design.exists():
            try:
                secs = sections(design.read_text(encoding='utf-8'))
                goals = '\n'.join(find(secs, t) or '' for t in ('为什么做', '做完的样子'))
                bad = ['design.md：' + b for b in prior_art_problems(
                    {'目标': goals, **{k: v for k, v in secs.items() if '同类方案' in k}})]
            except (OSError, UnicodeError) as e:
                bad = [f'design.md：读不到设计页：{e}']
    if not plan and not is_plan(sections(text)) and requires_design(args.cls, args.est_minutes, args.write):
        if skiplog.skipped('设计页检查', 'ROADSTAR_DESIGN_CHECK', plan_dir):
            pass
        elif baselines.listed('design-exempt', plan_dir):
            print('老场次（上线前已有），设计页豁免', file=sys.stderr)
        else:
            bad += check_design(text, path, plan_dir)
    if bad:
        kind = 'plan' if plan or is_plan(sections(text)) else '任务书'
        print(f'{kind}不合格，派不出去：', file=sys.stderr)
        for b in bad:
            print('  - ' + b, file=sys.stderr)
        ref = 'references/task-brief-template.md'
        if kind == 'plan':
            ref = 'references/plan-template.md §3b' if is_plan(sections(text)) else 'references/design-template.md 的同类方案'
        print(f'  按 {ref} 补齐再派；真急可 BRIEF_CHECK=0（会记下）。', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
