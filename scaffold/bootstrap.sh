#!/bin/bash
# Scaffold 一键部署：骨架 + 占位 + 技能装载 + 自检
# 用法：bash bootstrap.sh <项目名> [目标目录] [--force] [--no-skills] [--no-git]
# 原则：公共流程与规范不在项目里复制副本，只留一份并在项目里放索引
# 幂等：已存在的项目文件一律保留（重跑不会覆盖台账/状态/配置）；--force 才用模板覆盖
# 工作区：目标不在任何仓库内时自动 git init -b main（--no-git 跳过）；不代做首次提交
set -euo pipefail
SCAFFOLD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCAFFOLD/.." && pwd)"
NAME=""; DEST=""; FORCE=0; WITH_SKILLS=1; WITH_GIT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --no-skills) WITH_SKILLS=0; shift ;;
    --no-git) WITH_GIT=0; shift ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "未知参数: $1" >&2; exit 1 ;;
    *) if [ -z "$NAME" ]; then NAME="$1"; else DEST="$1"; fi; shift ;;
  esac
done
[ -n "$NAME" ] || { echo "用法: bash bootstrap.sh <项目名> [目标目录] [--force] [--no-skills] [--no-git]"; exit 1; }
DEST="${DEST:-$PWD/$NAME}"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
SCAFFOLD_REV="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
written=0; kept=0

# 工作区。先判「目标在不在某个仓库里」：rev-parse 会向上找，光看 --git-dir 会把外层仓库当成自己的。
# 不做首次提交：提交是本项目第一次变更，留给用户/架构师，命令打在末尾的下一步里。
if [ "$WITH_GIT" -eq 1 ]; then
  top="$(git -C "$DEST" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$top" ]; then
    git -C "$DEST" init -q -b main
    echo "[写入] git 仓库（分支 main）"
  elif [ "$top" != "$DEST" ]; then
    echo "[保留] 已在仓库 $top 内，跳过 git init"
  fi
fi
BRANCH="$(git -C "$DEST" symbolic-ref --short HEAD 2>/dev/null || echo '<branch>')"

put() {  # put <源文件> <目标> [x]
  local src="$1" dst="$2" mode="${3:-}"
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    echo "[保留] ${dst#"$DEST"/}"; kept=$((kept+1)); return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  if [ "$mode" = "x" ]; then chmod +x "$dst"; fi
  echo "[写入] ${dst#"$DEST"/}"; written=$((written+1))
}

gen() {  # gen <目标>  —— 内容从 stdin 读；存在即保留（先吃掉 stdin）
  local dst="$1"
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    cat >/dev/null; echo "[保留] ${dst#"$DEST"/}"; kept=$((kept+1)); return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cat > "$dst"
  echo "[写入] ${dst#"$DEST"/}"; written=$((written+1))
}

# ── 质量飞轮：唯一必须落在项目里的部分（含项目自己的门禁命令与历史数据）
put "$SCAFFOLD/quality/run_gate.sh.tpl"     "$DEST/quality/run_gate.sh" x
put "$SCAFFOLD/quality/aggregate_quality.py" "$DEST/quality/aggregate_quality.py" x
put "$SCAFFOLD/quality/gates.conf.example"  "$DEST/quality/gates.conf"

# ── 项目参数唯一落点
gen "$DEST/pj-config.md" <<EOF
# pj-config（新项目唯一参数落点）

> 由 bootstrap 生成。脚手架位置变动时，改 \`SCAFFOLD_ROOT\` 这一行**足以**让规范路径继续生效，
> 但已装载的技能是绝对路径软链、\`install-skills.sh\` 的源库默认也写死在 \$HOME 下：
> 搬完必须重跑一次 \`install-skills.sh\`（以及 \`--worktrees\`），再跑 \`check-deploy.sh\` 确认。

项目名: $NAME
仓库: <git remote>
分支/基线: $BRANCH
账号/身份: <no-identity-不提交>
里程碑: <M0-M7 占位>
SCAFFOLD_ROOT: $REPO
脚手架版本: $SCAFFOLD_REV
门禁: 见 quality/gates.conf
文档: docs/开发交付/（开发状态.md 唯一接口，架构师唯一写者）
项目特有 skills: 项目根 skills/（本项目独有；公共可复用的走 回流候选.md）
执行形态: <单检出 | git worktree 并行（需 install-skills.sh --worktrees）>
环境类型: <wsl2 | linux-desktop | ssh-remote>（决定 tool-bridge.md 走哪条分支）
EOF

# pj-config 保留（重跑）时只刷新版本行：这一行是布设快照，不是项目内容。
# 不刷新的话 check-deploy 的「脚手架已更新」警告会永久挂着，警告就被训练成噪声。
PJ_FILE="$DEST/pj-config.md"
if grep -q '^脚手架版本:' "$PJ_FILE"; then
  sed "s|^脚手架版本:.*|脚手架版本: $SCAFFOLD_REV|" "$PJ_FILE" > "$PJ_FILE.tmp" \
    && mv "$PJ_FILE.tmp" "$PJ_FILE"
fi

# ── 项目技能清单（唯一权威）
put "$SCAFFOLD/templates/skills.conf.tpl" "$DEST/skills/skills.conf"

# ── 台账 / 状态 / 偏离 / 回流候选
put "$SCAFFOLD/templates/问题台账.md.tpl"   "$DEST/docs/开发交付/问题台账.md"
put "$SCAFFOLD/templates/偏离记录.md.tpl"   "$DEST/docs/开发交付/偏离记录.md"
put "$SCAFFOLD/templates/开发状态.md.tpl"   "$DEST/docs/开发交付/开发状态.md"
sed -e "s#__PROJECT__#$NAME#g" "$SCAFFOLD/templates/回流候选.md.tpl" \
  | gen "$DEST/docs/开发交付/回流候选.md"

# ── 角色规范骨架：只含职责/边界/红线/自检，编码与流程靠引用
put "$SCAFFOLD/templates/角色规范-Dev.tpl" "$DEST/docs/开发交付/角色规范/Dev.md"
put "$SCAFFOLD/templates/角色规范-QA.tpl"  "$DEST/docs/开发交付/角色规范/QA.md"

# ── 运作模板（不落盘的项目会自己发明第八种格式）：只给骨架，填不填随项目
put "$SCAFFOLD/templates/任务卡.tpl"       "$DEST/docs/开发交付/模板/任务卡.md"
put "$SCAFFOLD/templates/QA评审报告.tpl"   "$DEST/docs/开发交付/模板/QA评审报告.md"
put "$SCAFFOLD/templates/Dev交接.tpl"      "$DEST/docs/开发交付/模板/Dev交接.md"
put "$SCAFFOLD/templates/复盘报告.tpl"     "$DEST/docs/开发交付/模板/复盘报告.md"
put "$SCAFFOLD/templates/架构师周总结.tpl" "$DEST/docs/开发交付/模板/架构师周总结.md"
put "$SCAFFOLD/templates/外部案例库.md.tpl" "$DEST/docs/开发交付/外部案例库.md"

# ── AI 入口：项目根 CLAUDE.md（新 AI 唯一入口，不复制规范正文）
sed -e "s#__PROJECT__#$NAME#g" -e "s#__SCAFFOLD_ROOT__#$REPO#g" \
  "$SCAFFOLD/templates/CLAUDE.md.tpl" | gen "$DEST/CLAUDE.md"

# ── 流程索引：指向唯一源，不复制正文
gen "$DEST/docs/开发交付/工程流程.md" <<EOF
# 工程流程 —— $NAME

> 通用流程与规范不在本项目复制，唯一源见下表。本文件只写本项目特有的增删，差异记进 \`偏离记录.md\`。
> 脚手架位置以 \`pj-config.md\` 的 \`SCAFFOLD_ROOT\` 为准（当前：\`$REPO\`）。下面路径是生成时的快照，移动后跑 \`check-deploy.sh\` 会报。

| 内容 | 唯一源 |
|---|---|
| 最高准则（四条，约束一切 SOP 与技能） | \`$REPO/scaffold/policies/最高准则.md\` |
| 协作流程（执行形态 / 角色 / 门禁 / 复审） | \`$REPO/scaffold/sop/协作流程-通用版.md\` |
| 方案评审门禁 | \`$REPO/scaffold/policies/方案评审门禁.md\` |
| Git 规范（粒度 / 放行 / 历史） | \`$REPO/scaffold/policies/git规范.md\` |
| 门禁口径（防假绿） | \`$REPO/scaffold/policies/门禁口径唯一.md\` |
| 泄漏归属判定 | \`$REPO/scaffold/policies/泄漏归属判定.md\` |
| Token 纪律 | \`$REPO/scaffold/policies/token纪律.md\` |
| 调研先行与外部案例库 | \`$REPO/scaffold/policies/调研先行.md\` |
| 跨环境文件操作与命令执行（wsl2 / 本地 / 远程） | \`$REPO/scaffold/policies/tool-bridge.md\` |
| 规范该写什么（约束/判据/手段）、DoD 四块、规则的准入与退役 | \`$REPO/scaffold/policies/约束与判据.md\` |
| 角色规范骨架（Dev / QA） | \`$REPO/scaffold/templates/角色规范-Dev.tpl\`、\`角色规范-QA.tpl\` |
| 提交信息格式 | \`$REPO/scaffold/policies/commit信息.md\` |
| 技能写作原则 | \`$REPO/scaffold/skills/skill-writing-principles.md\` |

## 本项目特有

- 门禁命令：\`quality/gates.conf\`
- 里程碑与仓库：\`pj-config.md\`
- 项目自有技能：\`skills/skills.conf\` 的 \`[project]\` 段
- 回流候选：\`回流候选.md\`（项目 → 脚手架的唯一入口）
EOF

# ── 装载产物不入库
GI="$DEST/.gitignore"
if [ ! -f "$GI" ]; then
  printf '/.claude/skills/\n' > "$GI"; echo "[写入] .gitignore"; written=$((written+1))
elif ! grep -qx '/.claude/skills/' "$GI"; then
  printf '\n/.claude/skills/\n' >> "$GI"; echo "[追加] .gitignore: /.claude/skills/"; written=$((written+1))
fi

# ── 首批工作目录：计划 / 日志 / 交接 / 评审各就各位，省得每个角色自己发明路径
BATCH_DATE="$(date +%F)"
for sub in 计划 日志 交接 评审; do
  mkdir -p "$DEST/docs/开发交付/$BATCH_DATE/$sub"
done
echo "[写入] docs/开发交付/$BATCH_DATE/{计划,日志,交接,评审}"

echo "=== Scaffold 布设：$DEST（写入 $written / 保留 $kept）==="

if [ "$WITH_SKILLS" -eq 1 ]; then
  echo "--- 装载技能 ---"
  bash "$SCAFFOLD/install-skills.sh" --project "$DEST" || echo "[警告] 技能未全部就绪，按上面提示补清单后重跑 --no-skills 那条命令"
fi

echo "--- 布设自检 ---"
bash "$SCAFFOLD/check-deploy.sh" --project "$DEST" || true

echo "下一步:"
echo "  1) 填 pj-config.md 的 <占位>"
echo "  2) 填 quality/gates.conf（换成本项目真实命令；示例是 C++ 口径）"
if [ "$WITH_GIT" -eq 1 ]; then
  echo "  3) git add -A && git commit -m 'chore(scaffold): bootstrap' —— 门禁只认有 commit 的干净树"
  echo "  4) bash quality/run_gate.sh <batch标记> 试跑首个批次"
  echo "  5) 让 AI 从项目根 CLAUDE.md 开始读"
else
  echo "  3) bash quality/run_gate.sh <batch标记> 试跑首个批次（非 git 项目：run 只能当调试记录）"
  echo "  4) 让 AI 从项目根 CLAUDE.md 开始读"
fi
