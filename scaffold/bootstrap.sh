#!/bin/bash
# Scaffold 一键部署：生成项目骨架 + 落项目特定占位
# 用法：bash bootstrap.sh <项目名> [目标目录(默认当前目录下 <项目名>/)]
# 原则：公共流程与规范不在项目里复制副本，只留一份并在项目里放索引
set -e
SCAFFOLD="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCAFFOLD/.." && pwd)"
NAME="$1"; DEST="${2:-$PWD/$NAME}"
[ -n "$NAME" ] || { echo "用法: bash bootstrap.sh <项目名> [目标目录]"; exit 1; }
mkdir -p "$DEST"

# 质量飞轮：只有这部分必须落在项目里（含项目自己的门禁命令与历史数据）
cp -r "$SCAFFOLD"/quality "$DEST"/
cp "$SCAFFOLD"/quality/gates.conf.example "$DEST"/quality/gates.conf
cp "$SCAFFOLD"/quality/run_gate.sh.tpl "$DEST"/quality/run_gate.sh
chmod +x "$DEST"/quality/run_gate.sh

mkdir -p "$DEST/docs/开发交付"

# 生成 pj-config 占位（项目特定参数唯一落点）
cat > "$DEST"/pj-config.md <<EOF
# pj-config（新项目唯一参数落点）
项目名: $NAME
仓库: <git remote>
分支/基线: <branch>
账号/身份: <no-identity-不提交>
里程碑: <M0-M7 占位>
门禁: 见 quality/gates.conf
文档: docs/开发交付/（开发状态.md 唯一接口，架构师唯一写者）
项目特有 skills: 项目根 skills/（本项目独有；公共可复用的回流 scaffold-skills）
EOF

# 项目技能清单（唯一权威）
mkdir -p "$DEST/skills"
cp "$SCAFFOLD/templates/skills.conf.tpl" "$DEST/skills/skills.conf"

# 台账骨架
cp "$SCAFFOLD/templates/问题台账.md.tpl" "$DEST/docs/开发交付/问题台账.md"
cp "$SCAFFOLD/templates/偏离记录.md.tpl" "$DEST/docs/开发交付/偏离记录.md"
cp "$SCAFFOLD/templates/开发状态.md.tpl" "$DEST/docs/开发交付/开发状态.md"

# 角色规范骨架：只含职责/边界/红线/自检，编码与流程靠引用
mkdir -p "$DEST/docs/开发交付/角色规范"
cp "$SCAFFOLD/templates/角色规范-Dev.tpl" "$DEST/docs/开发交付/角色规范/Dev.md"
cp "$SCAFFOLD/templates/角色规范-QA.tpl" "$DEST/docs/开发交付/角色规范/QA.md"

# 流程索引：指向唯一源，不复制正文
cat > "$DEST"/docs/开发交付/工程流程.md <<EOF
# 工程流程 —— $NAME

> 通用流程与规范不在本项目复制，唯一源见下表。本文件只写本项目特有的增删，差异记进 \`偏离记录.md\`。

| 内容 | 唯一源 |
|---|---|
| 协作流程（执行形态 / 角色 / 门禁 / 复审） | \`$REPO/scaffold/sop/协作流程-通用版.md\` |
| 方案评审门禁 | \`$REPO/scaffold/policies/方案评审门禁.md\` |
| Git 规范（粒度 / push 单位 / 编号） | \`$REPO/scaffold/policies/git规范.md\` |
| 门禁口径（防假绿） | \`$REPO/scaffold/policies/门禁口径唯一.md\` |
| 泄漏归属判定 | \`$REPO/scaffold/policies/泄漏归属判定.md\` |
| Token 纪律 | \`$REPO/scaffold/policies/token纪律.md\` |
| 调研先行与外部案例库 | \`$REPO/scaffold/policies/调研先行.md\` |
| 规范该写什么（约束/判据/手段）与 DoD 四块 | \`$REPO/scaffold/policies/约束与判据.md\` |
| 角色规范骨架（Dev / QA） | \`$REPO/scaffold/templates/角色规范-Dev.tpl\`、\`角色规范-QA.tpl\` |
| 提交信息格式 | \`$REPO/skills/pj-core/references/commit.md\` |
| 技能写作原则 | \`$REPO/scaffold/skills/skill-writing-principles.md\` |

## 本项目特有

- 门禁命令：\`quality/gates.conf\`
- 里程碑与仓库：\`pj-config.md\`
- 项目自有技能：\`skills/skills.conf\` 的 \`[project]\` 段
EOF

echo "=== Scaffold 部署完成: $DEST ==="
echo "下一步:"
echo "  1) 填 pj-config.md"
echo "  2) 填 quality/gates.conf"
echo "  3) 按 skills/skills.conf 登记技能，然后 bash $SCAFFOLD/install-skills.sh --project $DEST"
echo "  4) bash quality/run_gate.sh 试跑首个批次"
