#!/bin/bash
# 角色定义装载器：把脚手架里的 agent 定义链进项目的 .claude/agents
# 用法：
#   bash install-agents.sh --project <项目目录> [--check] [--list] [--force] [--dry-run]
#
# 清单：<项目根>/skills/skills.conf 的 [agents] 分组，一行一个名字（对应 scaffold/agents/<名字>.md）
# 为什么单独一支而不是并进 install-skills.sh：技能链的是目录（要 SKILL.md），角色链的是单文件（要 frontmatter），
# 两者的校验规则不同；合在一起会让 --check 的两类失败混在同一个退出码里。
# 退出码：0 全部就绪；1 参数/清单错误；2 有缺失、错链或冲突（--check 同）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$DIR/agents"
MANIFEST=""
PROJECT=""
CHECK=0
LIST=0
FORCE=0
DRY=0

usage() {
  cat >&2 <<'EOF'
用法：
  bash install-agents.sh --project <项目目录> [--check] [--list] [--force] [--dry-run]

清单：<项目根>/skills/skills.conf 的 [agents] 分组，一行一个名字
退出码：0 全部就绪；1 参数/清单错误；2 有缺失、错链或冲突
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) [ $# -ge 2 ] || { usage; exit 1; }; PROJECT="$2"; shift 2 ;;
    --check)   CHECK=1; shift ;;
    --list)    LIST=1; shift ;;
    --force)   FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

[ -n "$PROJECT" ] || { usage; exit 1; }
[ -d "$PROJECT" ] || { echo "项目目录不存在: $PROJECT" >&2; exit 1; }
MANIFEST="$PROJECT/skills/skills.conf"
TARGET="$PROJECT/.claude/agents"

[ -f "$MANIFEST" ] || { echo "缺清单: $MANIFEST" >&2; exit 1; }
[ -d "$SRC_DIR" ] || { echo "脚手架无 agents 目录: $SRC_DIR" >&2; exit 1; }

declared=0; linked=0; missing=0; conflict=0

# 只读模式不建目录：检查本身不该改变下一轮的判定
if [ "$CHECK" -eq 0 ] && [ "$LIST" -eq 0 ] && [ "$DRY" -eq 0 ]; then
  mkdir -p "$TARGET"
fi

in_agents=0
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -z "$line" ] && continue
  case "$line" in
    \[*\])
      group="${line:1:${#line}-2}"
      [ "$group" = "agents" ] && in_agents=1 || in_agents=0
      continue ;;
  esac
  [ "$in_agents" -eq 1 ] || continue

  declared=$((declared+1))
  src="$SRC_DIR/$line.md"
  if [ ! -f "$src" ]; then
    echo "[缺失] agents/$line（源库 $SRC_DIR 无 $line.md）"
    missing=$((missing+1))
    continue
  fi
  # frontmatter 是唯一必须的结构：没有 name/description/tools 的 agent 会被静默按默认工具放行
  for key in name description tools; do
    head -12 "$src" | grep -q "^$key:" \
      || { echo "[缺失] agents/$line 的 frontmatter 少了 $key:"; missing=$((missing+1)); }
  done

  dst="$TARGET/$line.md"
  [ "$LIST" -eq 1 ] && { echo "agents/$line -> $src"; continue; }

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      echo "[就绪] $line"; linked=$((linked+1)); continue
    fi
    if [ "$CHECK" -eq 1 ]; then
      echo "[错链] $line -> $(readlink "$dst")（应为 $src）"; conflict=$((conflict+1)); continue
    fi
    if [ "$DRY" -eq 1 ]; then
      echo "[重链] $line -> $src"; linked=$((linked+1)); continue
    fi
    ln -sfn "$src" "$dst" && { echo "[重链] $line -> $src"; linked=$((linked+1)); continue; }
    echo "[失败] $line 无法链接到 $dst"; conflict=$((conflict+1)); continue
  fi

  if [ -e "$dst" ]; then
    if [ "$FORCE" -eq 1 ] && [ "$DRY" -eq 0 ] && [ "$CHECK" -eq 0 ]; then
      rm -f "$dst"
      ln -sfn "$src" "$dst" && { echo "[覆盖] $line -> $src"; linked=$((linked+1)); continue; }
    fi
    echo "[冲突] $dst 已存在且非软链（--force 可覆盖）"; conflict=$((conflict+1)); continue
  fi

  if [ "$CHECK" -eq 1 ]; then
    echo "[未装] $line（应链接到 $src）"; conflict=$((conflict+1)); continue
  fi
  [ "$DRY" -eq 1 ] && { echo "[待装] $line -> $src"; linked=$((linked+1)); continue; }
  ln -sfn "$src" "$dst" && { echo "[装入] $line -> $src"; linked=$((linked+1)); continue; }
  echo "[失败] $line 无法链接到 $dst"; conflict=$((conflict+1))
done < "$MANIFEST"

echo "---"
if [ "$declared" -eq 0 ]; then
  echo "清单里没有 [agents] 分组：要么项目不用角色文件，要么清单还没建这一组"
fi
echo "声明 $declared / 就绪 $linked / 缺失 $missing / 冲突 $conflict"
[ "$missing" -eq 0 ] && [ "$conflict" -eq 0 ] && exit 0
exit 2
