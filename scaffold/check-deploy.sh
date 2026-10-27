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
  n_e="$(grep -c '<[^>][^>]*>' "$ENTRY" || true)"
  [ "$n_e" -gt 0 ] && todo "CLAUDE.md 还有 $n_e 个 <占位> 没填"
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
  # 产物落点是 ISO 判「这一阶段有没有产出」的唯一依据：整段缺失 = 没声明 = 下一阶段不许开工。
  # 占位口径与下面 pj-config 的总计数一致：只把「值以 <...> 开头」算未填；
  # 路径模板里的 <日期>/<卡号> 是声明本身的一部分，不算占位。
  if ! grep -q '^产物落点:' "$PJ"; then
    bad "pj-config.md 缺「产物落点」一节（ISO 按它判产出，未声明 = 没产出）"
  else
    sec_pl="$(awk '
      /^产物落点:/ { f=1; next }
      /^[^[:space:]]/ { f=0 }
      f && /: <[^>]*>/ { n++ }
      END { print n+0 }' "$PJ")"
    [ "${sec_pl:-0}" -gt 0 ] && todo "pj-config.md 的产物落点还有 $sec_pl 个 <占位> 没填（没有就写「无」）"
    # 键在、值为空：既不是声明也不是占位，ISO 按「声明了但空着 = 断链」处理，这里先报出来
    sec_empty="$(awk '
      /^产物落点:/ { f=1; next }
      /^[^[:space:]]/ { f=0 }
      f && /^[[:space:]]+[^:#]+:[[:space:]]*$/ { n++ }
      END { print n+0 }' "$PJ")"
    [ "${sec_empty:-0}" -gt 0 ] && todo "pj-config.md 的产物落点有 $sec_empty 个键是空的（写路径，或写「无」）"
  fi
  n="$(awk '
    /^产物落点:/ { f=1; next }
    /^[^[:space:]]/ { f=0 }
    !f && /: <[^>]*>/ { n++ }
    END { print n+0 }' "$PJ")"
  [ "${n:-0}" -gt 0 ] && todo "pj-config.md 还有 $n 个占位没填"
  # 版本漂移：模板只在 bootstrap 时落盘，脚手架前进后项目里的索引可能已过期
  rec="$(sed -n 's/^脚手架版本:[[:space:]]*//p' "$PJ" | head -1)"
  cur="$(git -C "${root:-$REPO}" rev-parse --short HEAD 2>/dev/null || true)"
  if [ -n "$rec" ] && [ -n "$cur" ] && [ "$rec" != "$cur" ]; then
    warn "脚手架已更新（pj-config 记 $rec / 当前 $cur）：规范可能变了，核对差异后按需同步"
  fi
fi

# 3. 索引里的绝对路径（脚手架移动后最先断的就是这些）
for f in "$PROJECT/CLAUDE.md" "$PROJECT/docs/开发交付/工程流程.md"; do
  [ -f "$f" ] || continue
  while IFS= read -r p; do
    [ -e "$p" ] || bad "$(basename "$f") 索引断链 -> $p"
  done < <(grep -oE '`/[^`]+`' "$f" 2>/dev/null | tr -d '`' | sort -u)
done

# 4. 装载产物不入库。问 git 本身，不认字面行：`/.claude/` 这类父目录写法同样有效，
# 按行匹配会把已经生效的规则报成缺陷，警告就被训练成噪声了。
if ! git -C "$PROJECT" check-ignore -q .claude/skills 2>/dev/null; then
  bad ".gitignore 未忽略 .claude/skills（软链含绝对路径，会被提交）"
fi

# 5. 门禁配置
GC="$PROJECT/quality/gates.conf"
if [ ! -f "$GC" ]; then
  bad "缺 quality/gates.conf"
else
  n_gates="$(grep -vcE '^[[:space:]]*(#|$)' "$GC" || true)"
  # 零门禁 = 全链路假绿（run_gate 会 exit 1，这里提前说清是哪份文件）
  [ "${n_gates:-0}" -gt 0 ] || bad "quality/gates.conf 里没有任何门禁（只有注释/空行）"
  if [ -f "$SCAFFOLD/quality/gates.conf.example" ] && cmp -s "$GC" "$SCAFFOLD/quality/gates.conf.example"; then
    bad "quality/gates.conf 还是示例原文（门禁命令没换成本项目的）"
  # 「还是示例」不能只靠与当前 example 字节比较：示例一改，老部署就全逃过检查（本轮实测过）。
  # 再看内容——所有门禁命令都还是示例里那几条，等于没换。口径只有一条，所以与上面是 elif。
  elif [ -f "$SCAFFOLD/quality/gates.conf.example" ] && [ "${n_gates:-0}" -gt 0 ]; then
    ex_cmds="$(grep -vE '^[[:space:]]*(#|$)' "$SCAFFOLD/quality/gates.conf.example" |
      cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    n_same=0; n_all=0
    while IFS='|' read -r nm cm _rest || [ -n "$nm" ]; do
      nm="$(printf '%s' "$nm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      case "$nm" in ''|'#'*) continue;; esac
      n_all=$((n_all+1))
      cm="$(printf '%s' "$cm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      printf '%s\n' "$ex_cmds" | grep -qxF "$cm" && n_same=$((n_same+1))
    done < "$GC"
    if [ "$n_all" -gt 0 ] && [ "$n_same" -eq "$n_all" ]; then
      bad "quality/gates.conf 的命令全部来自示例（没换成本项目的）"
    fi
  fi
fi
[ -f "$PROJECT/quality/run_gate.sh" ] || bad "缺 quality/run_gate.sh"
[ -f "$PROJECT/quality/aggregate_quality.py" ] || bad "缺 quality/aggregate_quality.py（CLAUDE.md 的分析环命令跑不了）"

# 6. 技能清单与装载
CONF="$PROJECT/skills/skills.conf"
if [ ! -f "$CONF" ]; then
  bad "缺 skills/skills.conf（技能清单是唯一权威）"
else
  if ! bash "$SCAFFOLD/install-skills.sh" --project "$PROJECT" --check >/dev/null 2>&1; then
    # user 级安装是合法形态（README/SOP 都允许），与下面 worktree 分支同一判据。
    # 但不能只看目录在不在：目录存在而技能没链上，等于放行一个空目录。
    if bash "$SCAFFOLD/install-skills.sh" --project "$PROJECT" --user --check >/dev/null 2>&1; then
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

# 7b. 角色定义装载（.claude/agents）。清单里没有 [agents] 分组是合法形态：不是每个项目都派子角色，
# 所以这里只在「声明了却装不上」时报警；声明了就等于承认角色定义影响产出，装不上必须挡住。
if grep -q '^\[agents\]' "$CONF" 2>/dev/null; then
  if ! bash "$SCAFFOLD/install-agents.sh" --project "$PROJECT" --check >/dev/null 2>&1; then
    bad "角色定义未装就绪——跑 bash $SCAFFOLD/install-agents.sh --project $PROJECT 看明细"
  fi
  # 与技能同一判据：软链含绝对路径，进了库换台机器就是断链
  if ! git -C "$PROJECT" check-ignore -q .claude/agents 2>/dev/null; then
    bad ".gitignore 未忽略 .claude/agents（角色定义软链含绝对路径，会被提交）"
  fi
fi

# 8. 回流入口与偏离台账
[ -f "$PROJECT/docs/开发交付/回流候选.md" ] || warn "缺 docs/开发交付/回流候选.md（项目 → 脚手架无回路）"
[ -f "$PROJECT/docs/开发交付/偏离记录.md" ] || warn "缺 docs/开发交付/偏离记录.md（偏离无台账，收尾无从回灌）"

# 8b. 进度：卡片状态的唯一落点。只查「卡片」表：「closed 必须有证据」「状态在枚举内」。
# 不查里程碑表——它的列不同，状态又是枚举子集，混查会造出假阳性。
PROG="$PROJECT/docs/开发交付/进度.md"
if [ ! -f "$PROG" ]; then
  bad "缺 docs/开发交付/进度.md（卡片做到哪没有落点，只能靠问人）"
else
  prog_bad="$(awk -F'|' '
    /^## / { in_cards = ($0 ~ /^## 卡片/) ? 1 : 0; next }
    !in_cards || $0 !~ /^\|/ || NF < 7 { next }
    {
      id=$2; st=$5; ev=$6
      gsub(/^[ \t]+|[ \t]+$/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", st); gsub(/^[ \t]+|[ \t]+$/, "", ev)
      if (id == "卡号" || id ~ /^-+$/) next
      if (st != "planned" && st != "open" && st != "fixing" && st != "verifying" && st != "closed" && st != "wontfix")
        { print id " 的状态不在枚举内: [" st "]"; next }
      if (st == "closed" && (ev == "" || ev == "—" || ev == "-"))
        print id " 已 closed 但没有证据（commit / run / 报告路径都算）"
    }' "$PROG")"
  if [ -n "$prog_bad" ]; then
    while IFS= read -r line; do bad "进度.md: $line"; done <<< "$prog_bad"
  fi
fi

# 8c. 常驻链预算：链上文件每轮对话都要读，它们的大小直接决定推理空间。
# 为什么要有这条：CLAUDE.md 写了「规则类文件各自 ≤200 行」，但没有任何执行路径——
# 本项目实测两次超限（台账 301 行 / 299 KB、开发状态 448 行 / 206 KB），直到 G 提才被发现。
# 判据用总字节而不是行数：中文行与英文行差 3 倍，按行数算会被长行逃过去。
# 超限只 warn 不 bad：新项目还没有归档可拆，把它做成错误会让检查从一开始就红。
CHAIN_FILES="CLAUDE.md pj-config.md docs/开发交付/工程流程.md docs/开发交付/进度.md docs/开发交付/开发状态.md docs/开发交付/问题台账.md"
BUDGET_KB="${CHAIN_BUDGET_KB:-150}"
chain_total=0; chain_detail=""
for f in $CHAIN_FILES; do
  [ -f "$PROJECT/$f" ] || continue
  kb=$(( $(wc -c < "$PROJECT/$f") / 1024 ))
  chain_total=$((chain_total + kb))
  # 单文件超过总预算的一半就点名：它一定是主因
  [ "$kb" -gt $((BUDGET_KB / 2)) ] && chain_detail="$chain_detail $(basename "$f")=${kb}KB"
done
if [ "$chain_total" -gt "$BUDGET_KB" ]; then
  warn "常驻链 ${chain_total}KB > 预算 ${BUDGET_KB}KB（超出的应拆到归档，只留当前批与未决）${chain_detail:+；主因：$chain_detail}"
fi
# 拆过却没留索引 = 证据被埋：归档目录里有文件，主文件里就必须能查到往哪找，
# 否则「台账唯一落点」变成了「有人记得就行」。
ADIR="$PROJECT/docs/开发交付/归档"
if [ -d "$ADIR" ] && [ -n "$(ls -A "$ADIR" 2>/dev/null)" ]; then
  if [ -f "$PROJECT/docs/开发交付/开发状态.md" ] && ! grep -q '归档' "$PROJECT/docs/开发交付/开发状态.md"; then
    bad "docs/开发交付/归档/ 里已有文件，但 开发状态.md 没有归档索引（拆出去的东西查不回来）"
  fi
  if [ -f "$PROJECT/docs/开发交付/问题台账.md" ] && ! grep -q '归档' "$PROJECT/docs/开发交付/问题台账.md"; then
    bad "docs/开发交付/归档/ 里已有文件，但 问题台账.md 没有归档索引"
  fi
fi

# 9. 证据链前置：没有仓库 / 没有 commit，run_gate 的 commit 永远为空，一条证据也攒不下
if ! git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  warn "不是 git 仓库：门禁 run 拿不到 commit，只能当调试记录（git init -b main 后做首次提交）"
else
  n_commit="$(git -C "$PROJECT" rev-list --count HEAD 2>/dev/null || echo 0)"
  [ "${n_commit:-0}" -eq 0 ] && warn "仓库还没有任何 commit：门禁 run 的 commit 为空，不是证据级"
fi

# 10. 两个飞轮闸门：批次表 + 提交信息钩子。缺了它们，复盘与提交规范都只剩文档
[ -f "$PROJECT/quality/check-flywheel.sh" ] \
  || bad "缺 quality/check-flywheel.sh：run_gate 的批次前置会静默跳过，飞轮退回靠记性"
[ -f "$PROJECT/quality/commit-lint.sh" ] \
  || warn "缺 quality/commit-lint.sh：提交信息规范没有执行路径"
if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  top="$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ "$top" = "$PROJECT" ]; then
    if [ ! -x "$PROJECT/.git/hooks/commit-msg" ]; then
      warn "未安装 .git/hooks/commit-msg：提交信息检查不会自动跑（重新跑 bootstrap 可装）"
    elif ! grep -q 'commit-lint\.sh' "$PROJECT/.git/hooks/commit-msg" 2>/dev/null; then
      warn ".git/hooks/commit-msg 存在但没调 commit-lint.sh（可能是项目自己的钩子）"
    fi
  fi
fi
if [ -f "$PROG" ]; then
  grep -q '^## 批次' "$PROG" || bad "进度.md 缺「批次」一节：run_gate 的批次前置无表可读，飞轮不会自动转"
fi

echo "---"
echo "项目: $PROJECT"
echo "错误 $errs / 待办 $todos / 警告 $warns"
[ "$errs" -eq 0 ] || exit 2
exit 0
