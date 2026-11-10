#!/usr/bin/env python3
"""一页设计的解析、派活门槛与只读点头记录；仅依赖标准库。"""
from __future__ import annotations
import json
import os
import re
import subprocess
from pathlib import Path

PRIOR_ART_TRIGGER = re.compile(r'新系统|新项目|新产品|新服务|大改版|重做|立项')
NEW_MODULE = re.compile(r'新模块')
MODULE_SCOPE = re.compile(r'系统|服务|(?<![A-Za-z])app(?![A-Za-z])', re.I)  # 新模块要配上其一才算整体性
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


def prior_art_trigger(goal):
    """返回触发同类方案的词；单独的 新建 / 新增 / 新模块 不算。"""
    m = PRIOR_ART_TRIGGER.search(goal)
    if m:
        return m.group(0)
    m, scope = NEW_MODULE.search(goal), MODULE_SCOPE.search(goal)
    if m and scope:
        return f'{m.group(0)}」+「{scope.group(0)}'
    return None


def prior_art_problems(secs):
    word = prior_art_trigger(goal_text(secs))
    if not word:
        return []
    body = next((v for k, v in secs.items() if '同类方案' in k), None)
    if body is None:
        return [f'目标里有「{word}」，缺「同类方案」一节：{PRIOR_ART_HOW}']
    body = strip_placeholders(body)
    if CHECKED_NONE.search(body):
        return []
    n = len(prior_art_items(body))
    if n < PRIOR_ART_MIN:
        return [f'目标里有「{word}」，「同类方案」只有 {n} 条带链接的条目，要至少 {PRIOR_ART_MIN} 条：{PRIOR_ART_HOW}']
    return []



def requires_design(cls: str | None, est: int | None, write: bool) -> bool:
    if not write or cls in {'取证', '复核', '审方案', '补全'}:
        return False
    if cls is None:
        return est is None or est > 60
    return not (cls in {'批量', '窄回归'} and est is not None and est <= 60)


def find_design_page(brief_text: str, bases: list[Path]) -> Path | None:
    match = re.search(r'^\s*设计页[:：]\s*(`[^`\n]+`|[^\n]+)', brief_text, re.M)
    if not match:
        return None
    target = Path(match.group(1).strip().strip('`')).expanduser()
    candidates = [target] if target.is_absolute() else [base / target for base in bases]
    return next((p.resolve() for p in candidates if p.is_file()), None)


def clean(text):
    return re.sub(r'TODO|待填|TBD', '', strip_placeholders(text), flags=re.I).strip()


def size_of(text: str) -> str | None:
    body = clean(find(sections(text), '大小') or '')
    match = re.match(r'^(中活|大活|新项目)(?=$|[\s，,。；;：:、（(])', body)
    return match.group(1) if match else None


def design_problems(path: Path, module_count: int) -> list[str]:
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeError) as exc:
        return [f'读不到设计页 {path}：{exc}']
    secs, size = sections(text), size_of(text)
    bad = [] if size else ['设计页「大小」没填有效档位（中活 / 大活 / 新项目）']
    required = ['为什么做', '做完的样子', '这次不做什么', '哪种情况技术上跑通也算失败', '只有主人能答的问题']
    if size in {'大活', '新项目'}:
        required += ['两三种做法和选的那种', '小事自己定的清单']
    for title in required:
        if not re.search(r'\w', clean(find(secs, title) or '')):
            bad.append(f'设计页缺「{title}」内容（只有模板占位也算没填）')
    if module_count >= 2:
        body = clean(find(secs, '模块表') or '')
        rows = []
        for line in body.splitlines():
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if not line.lstrip().startswith('|') or len(cells) != 4:
                continue
            if cells[0] == '模块' or all(re.fullmatch(r':?-+:?', c) for c in cells):
                continue
            if all(cells):
                rows.append(cells)
        if len(rows) < 2:
            bad.append('设计页「模块表」至少要两行数据（跨模块任务）')
    goals = '\n'.join(find(secs, t) or '' for t in ('为什么做', '做完的样子'))
    bad += ['设计页：' + b for b in prior_art_problems({'目标': goals, **{k: v for k, v in secs.items() if '同类方案' in k}})]
    return bad


def needs_approval(text: str) -> bool:
    size = size_of(text)
    if size in {'大活', '新项目'}:
        return True
    questions = clean(find(sections(text), '只有主人能答的问题') or '')
    return size == '中活' and bool(questions) and not re.fullmatch(r'无[。．.!！]?|无[，,]\s*因为[\s\S]*', questions)


def approvals_cmd() -> Path:
    return Path(os.environ.get('RURU_APPROVALS_CMD') or
                '~/Documents/RuruCode/RuruAgent/tools/dispatch-gate/approvals.py').expanduser()


def approvals(design: Path) -> dict:
    """只解析写方的核对结果，不在派活端重判批准规则。"""
    command = approvals_cmd()
    failed = {'ok': False, 'record': None, 'reason': '点头核对输出看不懂'}
    if not command.is_file():
        return {**failed, 'reason': f'点头核对命令不在：{command}'}
    try:
        run = subprocess.run(['python3', str(command), 'verify', str(design), '--json'],
                             capture_output=True, text=True, encoding='utf-8', timeout=10)
        result = json.loads(run.stdout)
    except subprocess.TimeoutExpired:
        return {**failed, 'reason': '点头核对超时'}
    except (OSError, UnicodeError, ValueError):
        return failed
    if (not isinstance(result, dict) or not isinstance(result.get('ok'), bool)
            or not isinstance(result.get('reason'), str) or 'record' not in result
            or (result['record'] is not None and not isinstance(result['record'], dict))
            or (result['ok'] and result['record'] is None)):
        return failed
    return result


def git_main(path):
    """登记了 worktree 时取 common dir 的上一级；非 git 保留原目录。"""
    try:
        run = subprocess.run(['git', '-C', str(path), 'rev-parse', '--git-common-dir'],
                             capture_output=True, text=True, timeout=10)
        if run.returncode == 0:
            common = Path(run.stdout.strip())
            return ((path / common) if not common.is_absolute() else common).resolve().parent
    except (OSError, subprocess.TimeoutExpired):
        pass
    return path


def init_baseline(dry_run=False):
    import baselines
    config = Path(os.environ.get('ROADSTAR_CONFIG_DIR') or '~/.config/roadstar').expanduser()
    try:
        projects = (config / 'projects.txt').read_text(encoding='utf-8').splitlines()
    except FileNotFoundError:
        projects = []
    roots = {git_main(Path(p).expanduser().resolve()) / 'docs/roadstar' for p in projects if p.strip()}
    roots.add(Path(os.environ.get('RURUCODE_ROOT') or '~/Documents/RuruCode').expanduser() / 'AI任务/roadstar')
    sessions = {str(p.resolve()) for root in roots for p in root.glob('*/') if p.is_dir()}
    existing = baselines.load('design-exempt')
    added = len(sessions - existing.keys()) if dry_run else baselines.add('design-exempt', sessions)
    print(f'设计页豁免基线{"（dry-run，不写）" if dry_run else ""}：新增 {added} 条，总计 {len(set(existing) | sessions)} 条')
