#!/bin/bash
# Scaffold 一键部署：复制公共资产到新项目 + 生成项目特定占位
# 用法：bash bootstrap.sh <项目名> [目标目录(默认当前目录下 <项目名>/)]
set -e
SCAFFOLD="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"; DEST="${2:-$PWD/$NAME}"
[ -n "$NAME" ] || { echo "用法: bash bootstrap.sh <项目名> [目标目录]"; exit 1; }
mkdir -p "$DEST"
cp -r "$SCAFFOLD"/quality "$SCAFFOLD"/templates "$SCAFFOLD"/policies "$SCAFFOLD"/sop "$DEST"/
cp "$SCAFFOLD"/quality/gates.conf.example "$DEST"/quality/gates.conf
cp "$SCAFFOLD"/quality/run_gate.sh.tpl "$DEST"/quality/run_gate.sh
chmod +x "$DEST"/quality/run_gate.sh

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
项目特有 skills/sop: 项目根 skills/ 目录（本项目独有，公共可复用沉淀回流 Scaffold）
EOF

# 项目特有 skills/sop 落点（公共沉淀回流 Scaffold，见 README 演进双轨）
mkdir -p "$DEST/skills"

# 文档目录骨架
mkdir -p "$DEST/docs/开发交付"
# 复制开发状态模板
[ -f "$SCAFFOLD/templates/开发状态.md.tpl" ] && cp "$SCAFFOLD/templates/开发状态.md.tpl" "$DEST/docs/开发交付/开发状态.md"
echo "=== Scaffold 部署完成: $DEST ==="
echo "下一步: 1) 填 pj-config.md  2) 填 quality/gates.conf  3) bash quality/run_gate.sh 试跑首个批次"
