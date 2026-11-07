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
除「非目标」以外的行）出现 新建 / 新项目 / 新系统 / 新模块 / 大改版 / 重做 之一时，必须有标题含「同类方案」
的一节，里面至少 3 条带链接的条目（列表项、表格行或 ### 小标题各算一条）；查不到写「查过：关键词…，无」也放行。
plan 用 `brief-check.py --plan <plan.md>` 查，只查同类方案，不查六栏；文件里没有「目标与做完的样子」而有
「<数字> 目标…」一节时自动按 plan 查。dex-exec.sh 派活前对场次目录的 plan.md 也跑一遍。
退出码：0 合格；2 不合格并列出缺什么。环境变量 BRIEF_CHECK=0 跳过（记一行到 stderr，给真正的急事）。
"""
import os
import re
import sys
from pathlib import Path

SECTIONS = ['目标与做完的样子', '涉及模块', '不许动什么', '执行环境', '验收命令与期望输出', '资源上限与止损']
PLACEHOLDER = re.compile(r'<[^>\n]{1,40}>|TODO|待填|TBD', re.I)
MIN_CHARS = {'涉及模块': 2, '不许动什么': 2, '执行环境': 2}  # 这三栏一个词就够
PRIOR_ART_TRIGGER = re.compile(r'新建|新项目|新系统|新模块|大改版|重做')
PRIOR_ART_MIN = 3
PRIOR_ART_HOW = '至少 3 个同类开源项目或产品，每个写它怎么做、我们取什么、不取什么、许可证，附链接；查不到写「查过：关键词…，无」'
REAL_LINK = re.compile(r'https?://[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}')
ITEM_START = re.compile(r'^ ?(?:[-*+]|\d+[.)、])\s+|^\|(?!\s*:?-{2,})|^###\s')
CHECKED_NONE = re.compile(r'查过[:：][^\n]*?\S[^\n]*?[，,；;]\s*无')


def sections(text):
    out, current = {}, None
    for line in text.splitlines():
        m = re.match(r'^##\s+(.+?)\s*$', line)
        if m:
            current = m.group(1).strip()
            out[current] = []
        elif current is not None:
            out[current].append(line)
    return {k: '\n'.join(v).strip() for k, v in out.items()}


def find(secs, title):
    for k, v in secs.items():
        if k.startswith(title):
            return v
    return None


def strip_placeholders(text):
    """去掉 <…> 占位（可跨行、可嵌套），模板说明里的字不算目标或条目。"""
    while True:
        new = re.sub(r'<[^<>]*>', '', text)
        if new == text:
            return new
        text = new


def goal_text(secs):
    for k, v in secs.items():
        if re.match(r'^(?:\d+\s*)?目标', k):
            return '\n'.join(l for l in strip_placeholders(v).splitlines() if '非目标' not in l)
    return ''


def prior_art_items(body):
    items, current = [], None
    for line in body.splitlines():
        if ITEM_START.match(line):
            current = [line]
            items.append(current)
        elif current is not None and line.strip():
            current.append(line)
    return [i for i in items if REAL_LINK.search('\n'.join(i))]


def prior_art_problems(secs):
    m = PRIOR_ART_TRIGGER.search(goal_text(secs))
    if not m:
        return []
    body = next((v for k, v in secs.items() if '同类方案' in k), None)
    if body is None:
        return [f'目标里有「{m.group(0)}」，缺「同类方案」一节：{PRIOR_ART_HOW}']
    body = strip_placeholders(body)
    if CHECKED_NONE.search(body):
        return []
    n = len(prior_art_items(body))
    if n < PRIOR_ART_MIN:
        return [f'目标里有「{m.group(0)}」，「同类方案」只有 {n} 条带链接的条目，要至少 {PRIOR_ART_MIN} 条：{PRIOR_ART_HOW}']
    return []


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


def main():
    args = sys.argv[1:]
    plan = '--plan' in args
    args = [a for a in args if a != '--plan']
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    if os.environ.get('BRIEF_CHECK') == '0':
        print('brief-check：BRIEF_CHECK=0，跳过校验（记下：这份任务书没过六栏检查）', file=sys.stderr)
        return 0
    path = Path(args[0])
    try:
        text = path.read_text(encoding='utf-8')
    except OSError as e:
        print(f'brief-check：读不到任务书 {path}：{e}', file=sys.stderr)
        return 2
    bad = problems(text, plan)
    if bad:
        kind = 'plan' if plan or is_plan(sections(text)) else '任务书'
        print(f'{kind}不合格，派不出去：', file=sys.stderr)
        for b in bad:
            print('  - ' + b, file=sys.stderr)
        ref = 'references/plan-template.md §3b' if kind == 'plan' else 'references/task-brief-template.md'
        print(f'  按 {ref} 补齐再派；真急可 BRIEF_CHECK=0（会记下）。', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
