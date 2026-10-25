#!/bin/bash
# 布设自检：验证一个由 bootstrap.sh 生成的项目，现在还能不能按 SOP 跑起来
# 用法：bash check-deploy.sh --project <项目根>
# 判据：错误 = 跑不起来（断链 / 缺入口 / 门禁未配置 / 技能装不上）；待办 = 占位没填；警告 = 能跑但有风险
# 退出码：0 无错误；2 有错误
set -uo pipefail
SCAFFOLD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCAFFOLD/.." && pwd)"
usage() {
  cat >&2 <<'EOF'
用法：bash check-deploy.sh --project <项目根>
  -p, --project <项目根>   必填
退出码：0 无错误；2 有错误；1 参数错误
EOF
  exit "${1:-0}"
}

PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--project)
      # 缺值必须显式报错：`shift 2` 在 $#=1 时失败但不移位，会 100% CPU 死循环
      [ $# -ge 2 ] || usage 1
      PROJECT="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
done
[ -n "$PROJECT" ] || { echo "缺 --project <项目根>" >&2; usage 1; }
PROJECT="$(cd "$PROJECT" && pwd)" || exit 1

errs=0; todos=0; warns=0
bad()  { echo "[错误] $*"; errs=$((errs+1)); }
todo() { echo "[待办] $*"; todos=$((todos+1)); }
warn() { echo "[警告] $*"; warns=$((warns+1)); }

# 1. AI 入口
ENTRY="$PROJECT/CLAUDE.md"
if [ ! -f "$ENTRY" ]; then
  bad "缺项目入口 CLAUDE.md（新 AI 无从下手）——重跑 bootstrap.sh 或从 templates/CLAUDE.md.tpl 补"
else
  for ref in pj-config.md docs/开发交付/工程流程.md docs/开发交付/开发状态.md docs/开发交付/问题台账.md; do
    [ -f "$PROJECT/$ref" ] || bad "CLAUDE.md 指向的 $ref 不存在"
  done
  # 存在不等于生效：项目原有 CLAUDE.md 会被 bootstrap 保留，入口也就没落盘
  for key in pj-config.md 工程流程.md; do
    grep -qF "$key" "$ENTRY" || bad "CLAUDE.md 没有路由到 $key（多半是项目原有文件被保留，入口没写入）"
  done
fi

# 2. 脚手架锚点
PJ="$PROJECT/pj-config.md"
if [ ! -f "$PJ" ]; then
  bad "缺 pj-config.md"
else
  root="$(sed -n 's/^SCAFFOLD_ROOT:[[:space:]]*//p' "$PJ" | head -1)"
  if [ -z "$root" ]; then
    bad "pj-config.md 无 SCAFFOLD_ROOT（脚手架移动后无法定位规范）"
  elif [ ! -f "$root/scaffold/sop/协作流程-通用版.md" ]; then
    bad "SCAFFOLD_ROOT=$root 下找不到 scaffold/sop/协作流程-通用版.md"
  elif [ "$root" != "$REPO" ]; then
    warn "SCAFFOLD_ROOT=$root，但当前脚手架在 $REPO（两处不一致，择一改）"
  fi
  n="$(grep -c ': <[^>]*>' "$PJ" || true)"
  [ "$n" -gt 0 ] && todo "pj-config.md 还有 $n 个占位没填"
fi

# 3. 索引里的绝对路径（脚手架移动后最先断的就是这些）
for f in "$PROJECT/CLAUDE.md" "$PROJECT/docs/开发交付/工程流程.md"; do
  [ -f "$f" ] || continue
  while IFS= read -r p; do
    [ -e "$p" ] || bad "$(basename "$f") 索引断链 -> $p"
  done < <(grep -oE '`/[^`]+`' "$f" 2>/dev/null | tr -d '`' | sort -u)
done

# 4. 装载产物不入库
if ! grep -qx '/.claude/skills/' "$PROJECT/.gitignore" 2>/dev/null; then
  bad ".gitignore 缺 /.claude/skills/（软链含绝对路径，会被提交）"
fi

# 5. 门禁配置
GC="$PROJECT/quality/gates.conf"
if [ ! -f "$GC" ]; then
  bad "缺 quality/gates.conf"
else
  if [ -f "$SCAFFOLD/quality/gates.conf.example" ] && cmp -s "$GC" "$SCAFFOLD/quality/gates.conf.example"; then
    bad "quality/gates.conf 还是示例原文（门禁命令没换成本项目的）"
  fi
  n_gates="$(grep -vcE '^[[:space:]]*(#|$)' "$GC" || true)"
  # 零门禁 = 全链路假绿（run_gate 会 exit 1，这里提前说清是哪份文件）
  [ "${n_gates:-0}" -gt 0 ] || bad "quality/gates.conf 里没有任何门禁（只有注释/空行）"
fi
[ -f "$PROJECT/quality/run_gate.sh" ] || bad "缺 quality/run_gate.sh"
[ -f "$PROJECT/quality/aggregate_quality.py" ] || bad "缺 quality/aggregate_quality.py（CLAUDE.md 的分析环命令跑不了）"

# 6. 技能清单与装载
CONF="$PROJECT/skills/skills.conf"
if [ ! -f "$CONF" ]; then
  bad "缺 skills/skills.conf（技能清单是唯一权威）"
else
  if ! bash "$SCAFFOLD/install-skills.sh" --project "$PROJECT" --check >/dev/null 2>&1; then
    # user 级安装是合法形态（README/SOP 都允许），与下面 worktree 分支保持同一判据
    if [ -d "$HOME/.claude/skills" ]; then
      warn "项目级技能未装，当前靠 user 级 ~/.claude/skills 兜底（清单对项目不生效）"
    else
      bad "技能装载未就绪——跑 install-skills.sh --project $PROJECT 看明细"
    fi
  fi
  # 7. 并行执行形态：worktree 里必须也有技能
  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    wts="$(git -C "$PROJECT" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')"
    n_wt="$(printf '%s\n' "$wts" | grep -c . || true)"
    if [ "${n_wt:-0}" -gt 1 ]; then
      naked=""
      while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        [ -d "$wt/.claude/skills" ] || naked="$naked $wt"
      done <<< "$wts"
      if [ -n "$naked" ]; then
        if [ -d "$HOME/.claude/skills" ]; then
          warn "有 $n_wt 个 worktree，其中这些没有 .claude/skills：$naked（当前靠 user 级安装兜底，清单对工作树无效）"
        else
          bad "worktree 无技能且无 user 级安装：$naked（执行期 subagent 拿不到技能）"
        fi
      fi
    fi
  fi
fi

# 8. 回流入口
[ -f "$PROJECT/docs/开发交付/回流候选.md" ] || warn "缺 docs/开发交付/回流候选.md（项目 → 脚手架无回路）"

echo "---"
echo "项目: $PROJECT"
echo "错误 $errs / 待办 $todos / 警告 $warns"
[ "$errs" -eq 0 ] || exit 2
exit 0
