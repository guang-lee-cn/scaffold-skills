#!/bin/bash
# 统一技能装载器：按项目清单把公共 / 第三方 / 项目自有技能链接到 .claude/skills
# 用法：
#   bash install-skills.sh --project <项目根> [--user] [--check] [--dry-run] [--list] [--prune] [--force]
# 清单：<项目根>/skills/skills.conf（格式见 templates/skills.conf.tpl）
# 源库：$SKILLS_ROOT，默认 ~/code/scaffold-skills/skills
# 退出码：0 全部就绪；1 参数/清单错误；2 有缺失或冲突（--check 同）
set -uo pipefail

SKILLS_ROOT="${SKILLS_ROOT:-$HOME/code/scaffold-skills/skills}"
PROJECT=""
LEVEL="project"
FORCE=0
PRUNE=0
DRY=0
CHECK=0
LIST=0

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--project) PROJECT="${2:-}"; shift 2 ;;
    --user) LEVEL="user"; shift ;;
    --skills-root) SKILLS_ROOT="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --check) CHECK=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
done

[ -n "$PROJECT" ] || { echo "缺 --project <项目根>" >&2; usage 1; }
PROJECT="$(cd "$PROJECT" && pwd)" || { echo "项目目录不存在" >&2; exit 1; }
MANIFEST="$PROJECT/skills/skills.conf"
[ -f "$MANIFEST" ] || {
  echo "缺清单: $MANIFEST" >&2
  echo "参考 scaffold/templates/skills.conf.tpl 创建后重跑" >&2
  exit 1
}

if [ "$LEVEL" = "user" ]; then
  TARGET="$HOME/.claude/skills"
else
  TARGET="$PROJECT/.claude/skills"
fi

# resolve <name> <group> → echo 源目录，失败返回 1
resolve() {
  local name="$1" group="$2" d
  case "$group" in
    project)
      d="$PROJECT/skills/$name"
      [ -f "$d/SKILL.md" ] && { printf '%s\n' "$d"; return 0; }
      ;;
    agent)
      d="$SKILLS_ROOT/agent-skills/skills/$name"
      [ -f "$d/SKILL.md" ] && { printf '%s\n' "$d"; return 0; }
      ;;
    common|*)
      d="$SKILLS_ROOT/$name"
      if [ -f "$d/SKILL.md" ]; then printf '%s\n' "$d"; return 0; fi
      for d in "$SKILLS_ROOT"/*/"$name"; do
        [ -f "$d/SKILL.md" ] && { printf '%s\n' "$d"; return 0; }
      done
      ;;
  esac
  return 1
}

mkdir -p "$TARGET"

group=""
declared=0
linked=0
skipped=0
missing=0
conflict=0

while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -z "$line" ] && continue
  case "$line" in
    \[*\]*)
      group="${line:1:${#line}-2}"
      case "$group" in common|agent|project) ;; *)
        echo "[清单] 未知分组: [$group]" >&2; declared=$((declared+1)); continue ;;
      esac
      continue ;;
  esac
  [ -n "$group" ] || { echo "[清单] 条目 '$line' 不在任何分组下" >&2; declared=$((declared+1)); continue; }

  declared=$((declared+1))
  if ! src="$(resolve "$line" "$group")"; then
    echo "[缺失] $group/$line（源库 $SKILLS_ROOT 无 SKILL.md）"
    missing=$((missing+1))
    continue
  fi
  dst="$TARGET/$line"

  if [ "$LIST" -eq 1 ]; then
    echo "$group/$line -> $src"
    continue
  fi

  if [ -L "$dst" ]; then
    cur="$(readlink "$dst")"
    if [ "$cur" = "$src" ]; then
      echo "[就绪] $line"
      linked=$((linked+1))
      continue
    fi
    if [ "$CHECK" -eq 1 ]; then
      echo "[错链] $line -> $cur（应为 $src）"
      conflict=$((conflict+1))
      continue
    fi
    [ "$DRY" -eq 1 ] && { echo "[重链] $line -> $src"; linked=$((linked+1)); continue; }
    ln -sfn "$src" "$dst"
    echo "[重链] $line -> $src"
    linked=$((linked+1))
    continue
  fi

  if [ -e "$dst" ]; then
    if [ "$FORCE" -eq 1 ] && [ "$DRY" -eq 0 ]; then
      rm -rf "$dst"
      ln -sfn "$src" "$dst"
      echo "[覆盖] $line -> $src"
      linked=$((linked+1))
    else
      echo "[冲突] $dst 已存在且非软链（--force 可覆盖）"
      conflict=$((conflict+1))
    fi
    continue
  fi

  if [ "$CHECK" -eq 1 ]; then
    echo "[未装] $line（应链接到 $src）"
    conflict=$((conflict+1))
    continue
  fi

  if [ "$DRY" -eq 1 ]; then
    echo "[新建] $line -> $src"
  else
    ln -sfn "$src" "$dst"
    echo "[新建] $line -> $src"
  fi
  linked=$((linked+1))
done < "$MANIFEST"

pruned=0
if [ "$PRUNE" -eq 1 ] && [ "$DRY" -eq 0 ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    rm -f "$d"
    echo "[清理] 断链 $(basename "$d")"
    pruned=$((pruned+1))
  done < <(find "$TARGET" -maxdepth 1 -type l ! -exec test -e {} \; -print)
fi

echo "---"
echo "目标: $TARGET"
echo "声明 $declared / 就绪 $linked / 缺失 $missing / 冲突 $conflict / 清理 $pruned"
[ "$missing" -eq 0 ] && [ "$conflict" -eq 0 ] && exit 0
exit 2
