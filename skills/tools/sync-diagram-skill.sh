#!/usr/bin/env bash
# 同步 notion-diagram skill 到运行副本（豆包 .user_skills 拷贝 / Claude skills symlink）
# 用法: tools/sync-diagram-skill.sh
# 仓库为权威源；运行副本定期同步（改动以仓库为准）
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/notion-diagram"
[ -d "$SRC" ] || { echo "[fail] 未找到 $SRC" >&2; exit 1; }

sync_dir() {  # 优先 rsync（含 --delete 对齐），无则 rm+cp
  if command -v rsync >/dev/null 2>&1; then
    mkdir -p "$2"
    rsync -a --delete "$1/" "$2/"
  else
    rm -rf "$2" && cp -r "$1" "$2"
  fi
}

# 1) 豆包桌面端 .user_skills（Windows 侧，WSL 挂载 /mnt/c）
DOUBAO="/mnt/c/Users/guang/AppData/Local/Doubao/User Data/Default/.doubao/agent_mode/workspace/.user_skills/notion-diagram"
if [ -d "/mnt/c/Users/guang" ]; then
  sync_dir "$SRC" "$DOUBAO"
  echo "[sync] 豆包 .user_skills  <- 仓库 ($(find "$DOUBAO" -type f | wc -l) 文件)"
else
  echo "[skip] 未检测到 /mnt/c 豆包目录，跳过"
fi

# 2) Claude Code 原生 skill（symlink）
if [ -d "$HOME/.claude/skills" ]; then
  ln -sfn "$SRC" "$HOME/.claude/skills/notion-diagram"
  echo "[sync] Claude skills   <- symlink → $SRC"
else
  echo "[skip] 未检测到 ~/.claude/skills，跳过"
fi

echo "[done] 同步完成。改动以 $SRC 为准。"
