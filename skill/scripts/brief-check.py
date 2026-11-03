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
退出码：0 合格；2 不合格并列出缺什么。环境变量 BRIEF_CHECK=0 跳过（记一行到 stderr，给真正的急事）。
"""
import os
import re
import sys
from pathlib import Path

SECTIONS = ['目标与做完的样子', '涉及模块', '不许动什么', '执行环境', '验收命令与期望输出', '资源上限与止损']
PLACEHOLDER = re.compile(r'<[^>\n]{1,40}>|TODO|待填|TBD', re.I)
MIN_CHARS = {'涉及模块': 2, '不许动什么': 2, '执行环境': 2}  # 这三栏一个词就够


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


def problems(text):
    secs = sections(text)
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
    return bad


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    if os.environ.get('BRIEF_CHECK') == '0':
        print('brief-check：BRIEF_CHECK=0，跳过校验（记下：这份任务书没过六栏检查）', file=sys.stderr)
        return 0
    path = Path(sys.argv[1])
    try:
        text = path.read_text(encoding='utf-8')
    except OSError as e:
        print(f'brief-check：读不到任务书 {path}：{e}', file=sys.stderr)
        return 2
    bad = problems(text)
    if bad:
        print('任务书不合格，派不出去：', file=sys.stderr)
        for b in bad:
            print('  - ' + b, file=sys.stderr)
        print('  按 references/task-brief-template.md 补齐再派；真急可 BRIEF_CHECK=0（会记下）。', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
