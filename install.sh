#!/usr/bin/env bash
# Roadstar · 引路星 — 一键安装：把 skill 软链到 Claude Code 与 Codex 的发现目录。
# 换电脑后：拷整个 Roadstar 文件夹 → 在本目录跑 ./install.sh → 重开 Claude Code 会话。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {  # link <目标> <软链路径>
  local target="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then echo "跳过 $dest：已存在且不是软链接"; return; fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$target" "$dest"
  echo "已链接  $dest  →  $target"
}

# Claude Code：只安装 skill，不安装子代理
link "$ROOT/skill" "$HOME/.claude/skills/roadstar"

# Codex：~/.agents/skills 是 Codex 的发现目录，~/.codex/skills 是旧入口，两处都链
link "$ROOT/skill" "$HOME/.agents/skills/roadstar"
link "$ROOT/skill" "$HOME/.codex/skills/roadstar"

# 清掉前身 roundtable 的旧软链（指向 RuruAgent/skills/roundtable 的）
for old in "$HOME/.claude/skills/roundtable" "$HOME/.agents/skills/roundtable" "$HOME/.codex/skills/roundtable"; do
  [ -L "$old" ] && { rm "$old"; echo "已清理旧软链  $old"; }
done
echo "完成。重开一个 Claude Code 会话即可（/roadstar，或直接说「开圆桌」「复盘这个项目」「直接调度」）。"
