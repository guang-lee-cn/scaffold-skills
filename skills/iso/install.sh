#!/usr/bin/env bash
#
# install.sh — 把 iso skill 安装到各 AI 编码平台的技能目录（软链方式，幂等）
#
#   用法:
#     ./install.sh                      # 装到当前项目（默认平台组）
#     ./install.sh --project ~/proj     # 装到指定项目
#     ./install.sh --global             # 装到用户级目录（全部项目可用）
#     ./install.sh --platforms all      # 装到全部已知平台目录
#     ./install.sh --platforms claude-code,agents
#     ./install.sh --dry-run            # 只打印要做什么
#     ./install.sh --uninstall          # 移除本脚本创建的软链
#
# 平台目录对照（✅ = 本机实测过；📄 = 厂商文档记载，未实测）:
#
#   平台             项目级目录                    用户级目录
#   ✅ DSH           .agents/skills/               —
#   ✅ Claude Code   .claude/skills/               ~/.claude/skills/
#   📄 Cursor        .cursor/skills/               —
#   📄 Codex         .codex/skills/                —
#   📄 Gemini CLI    .gemini/skills/               —
#   📄 Antigravity   —                             ~/.gemini/config/skills/
#   📄 Copilot       .github/copilot/skills/       —
#   📄 Cline         .cline/skills/                —
#   📄 Windsurf      .windsurf/skills/             —
#   📄 OpenCode      .opencode/skills/             —
#   📄 Kilo          .kilo/skills/                 —
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PLATFORMS="agents,claude-code"
ALL_PROJECT_PLATFORMS="agents,claude-code,cursor,codex,gemini,copilot,cline,windsurf,opencode,kilo"

MODE="project"
PROJECT="$(pwd)"
PLATFORMS="$DEFAULT_PLATFORMS"
DRY_RUN=0
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project)   PROJECT="$2"; shift 2 ;;
    --global)    MODE="global"; shift ;;
    --platforms) PLATFORMS="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)   sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "未知参数: $1（用 --help 看用法）" >&2; exit 2 ;;
  esac
done

# ── 自检 1：本目录必须真的是一个 skill ──────────────────────────────────────
[ -f "$HERE/SKILL.md" ] || { echo "错误：$HERE 下没有 SKILL.md，不是 skill 目录" >&2; exit 1; }
DIR_NAME="$(basename "$HERE")"
FM_NAME="$(sed -n '/^---$/,/^---$/p' "$HERE/SKILL.md" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//' | tr -d '"'"'"'')"
[ "$FM_NAME" = "$DIR_NAME" ] || {
  echo "错误：frontmatter name='$FM_NAME' 与目录名 '$DIR_NAME' 不一致（Agent Skills 规范要求一致）" >&2; exit 1; }

# ── 目标目录展开 ────────────────────────────────────────────────────────────
project_dir() {
  case "$1" in
    agents)     echo ".agents/skills" ;;
    claude-code) echo ".claude/skills" ;;
    cursor)     echo ".cursor/skills" ;;
    codex)      echo ".codex/skills" ;;
    gemini)     echo ".gemini/skills" ;;
    copilot)    echo ".github/copilot/skills" ;;
    cline)      echo ".cline/skills" ;;
    windsurf)   echo ".windsurf/skills" ;;
    opencode)   echo ".opencode/skills" ;;
    kilo)       echo ".kilo/skills" ;;
    *) return 1 ;;
  esac
}

targets=()
if [ "$MODE" = "global" ]; then
  # 用户级：只装到"该平台确实装了"的目录，不凭空创建平台根目录
  if [ -d "$HOME/.claude" ]; then targets+=("$HOME/.claude/skills")
  else echo "  · 跳过 Claude Code（$HOME/.claude 不存在）"; fi
  if [ -d "$HOME/.gemini" ]; then targets+=("$HOME/.gemini/config/skills")
  else echo "  · 跳过 Antigravity（$HOME/.gemini 不存在）"; fi
else
  [ "$PLATFORMS" = "all" ] && PLATFORMS="$ALL_PROJECT_PLATFORMS"
  IFS=',' read -r -a _p <<< "$PLATFORMS"
  for p in "${_p[@]}"; do
    d="$(project_dir "$p")" || { echo "未知平台: $p" >&2; exit 2; }
    targets+=("$PROJECT/$d")
  done
fi

# ── 执行 ────────────────────────────────────────────────────────────────────
ok=0; skipped=0; removed=0
for dir in "${targets[@]}"; do
  link="$dir/$DIR_NAME"
  if [ "$UNINSTALL" = "1" ]; then
    if [ -L "$link" ]; then
      [ "$DRY_RUN" = "1" ] && { echo "  [dry-run] rm $link"; continue; }
      rm "$link"; echo "  ✗ 已移除 $link"; removed=$((removed+1))
    else
      echo "  · 跳过（不是本脚本建的软链）: $link"; skipped=$((skipped+1))
    fi
    continue
  fi

  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "  ⚠ 跳过：$link 已存在且不是软链（不覆盖真实文件）"; skipped=$((skipped+1)); continue
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "  [dry-run] mkdir -p $dir && ln -sfn $HERE $link"; ok=$((ok+1)); continue
  fi
  mkdir -p "$dir"
  ln -sfn "$HERE" "$link"
  [ -f "$link/SKILL.md" ] || { echo "  ❌ 建立了软链但读不到 SKILL.md: $link" >&2; exit 1; }
  echo "  ✅ $link"; ok=$((ok+1))
done

echo
[ "$UNINSTALL" = "1" ] && echo "移除 $removed 个软链，跳过 $skipped 个" || echo "安装 $ok 个，跳过 $skipped 个"
[ "$DRY_RUN" = "1" ] && echo "（dry-run，未做任何改动）"
echo "源目录: $HERE"
