#!/bin/bash
# 统一技能装载器：按项目清单把公共 / 第三方 / 项目自有技能链接到 .claude/skills
# 用法：
#   bash install-skills.sh --project <项目根> [--user] [--worktrees] [--check] [--dry-run] [--list] [--prune] [--force]
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
WORKTREES=0

usage() {
  cat >&2 <<'EOF'
用法：
  bash install-skills.sh --project <项目根> [--user] [--worktrees] [--check] [--dry-run] [--list] [--prune] [--force]
  --skills-root <dir>   覆盖源库（默认 $SKILLS_ROOT 或 ~/code/scaffold-skills/skills）
  --user               装到 ~/.claude/skills（并行工作树的兜底）
  --worktrees          同时装进该项目的每棵 git worktree
清单：<项目根>/skills/skills.conf（格式见 templates/skills.conf.tpl）
退出码：0 全部就绪；1 参数/清单错误；2 有缺失或冲突（--check 同）
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    # 带值的选项一律先验 $#：`shift 2` 在 $#=1 时失败但不移位，会 100% CPU 死循环
    -p|--project)
      [ $# -ge 2 ] || usage 1
      PROJECT="$2"; shift 2 ;;
    --user) LEVEL="user"; shift ;;
    --worktrees) WORKTREES=1; shift ;;
    --skills-root)
      [ $# -ge 2 ] || usage 1
      SKILLS_ROOT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --check) CHECK=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
done

# --check 是只读的，--prune 会删断链：两者同时给是用法错误，不静默容忍
if [ "$CHECK" -eq 1 ] && [ "$PRUNE" -eq 1 ]; then
  echo "--check 与 --prune 不能同时给（检查不该有副作用）" >&2
  usage 1
fi

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

# link_all：把清单里的技能链进 $TARGET（$TARGET 由调用方设置）
link_all() {
  local group="" raw line src dst cur
  # --check/--list/--dry-run 都是只读的：连目录都不该建，否则「检查」会顺手改变下一轮的判定
  if [ "$CHECK" -eq 0 ] && [ "$LIST" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    mkdir -p "$TARGET"
  fi
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

  if [ "$PRUNE" -eq 1 ] && [ "$DRY" -eq 0 ]; then
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      rm -f "$d"
      echo "[清理] 断链 $(basename "$d")"
      pruned=$((pruned+1))
    done < <(find "$TARGET" -maxdepth 1 -type l ! -exec test -e {} \; -print)
  fi
}

declared=0; linked=0; skipped=0; missing=0; conflict=0; pruned=0
link_all
echo "---"
echo "目标: $TARGET"
echo "声明 $declared / 就绪 $linked / 缺失 $missing / 冲突 $conflict / 清理 $pruned"

# 并行执行形态：SOP §1 要求 subagent 在隔离工作树里干活，工作树里没有 .claude 就等于清单失效
if [ "$WORKTREES" -eq 1 ] && [ "$LEVEL" = "project" ]; then
  if ! git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "[警告] 不是 git 仓库，--worktrees 无意义"
  else
    wt_declared=0; wt_linked=0; wt_missing=0; wt_conflict=0
    while IFS= read -r wt; do
      [ -n "$wt" ] || continue
      [ "$wt" = "$PROJECT" ] && continue
      [ -d "$wt" ] || continue
      echo "--- worktree: $wt"
      TARGET="$wt/.claude/skills"
      d0=$declared; l0=$linked; m0=$missing; c0=$conflict
      link_all
      wt_declared=$((wt_declared + declared - d0))
      wt_linked=$((wt_linked + linked - l0))
      wt_missing=$((wt_missing + missing - m0))
      wt_conflict=$((wt_conflict + conflict - c0))
      echo "  声明 $((declared - d0)) / 就绪 $((linked - l0)) / 缺失 $((missing - m0)) / 冲突 $((conflict - c0))"
    done < <(git -C "$PROJECT" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    echo "---"
    echo "worktree 合计: 声明 $wt_declared / 就绪 $wt_linked / 缺失 $wt_missing / 冲突 $wt_conflict"
  fi
fi

[ "$missing" -eq 0 ] && [ "$conflict" -eq 0 ] && exit 0
exit 2
