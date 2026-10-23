#!/bin/bash
# 数据飞轮-采集环（Scaffold 通用门禁）：逐门禁执行 gates.conf → quality/gate-<batch>.json
# 用法：bash run_gate.sh [batch标记]   # 批标记默认 日期-commit-标记
# 依赖：bash + python3 + grep（零外部工具）
# 正则口径：POSIX ERE（如 [0-9]，grep -E 不支持 \d）
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$DIR/gates.conf"
QUALITY="$DIR/quality"
TMP="$DIR/.gates.tmp"
[ -f "$CFG" ] || { echo "缺 gates.conf（参考 gates.conf.example 生成）"; exit 1; }
mkdir -p "$QUALITY"
: > "$TMP"

BATCH="${1:-$(date +%F)-$(git -C "$DIR/../.." rev-parse --short HEAD 2>/dev/null || echo unknown)}"

while IFS='|' read -r name cmd re; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue;; esac
  # 防假绿：命令存在性检查（缺失 = FAIL，不空跑）
  tool="${cmd%% *}"
  if ! command -v "$tool" >/dev/null 2>&1 && ! [ -x "$tool" ]; then
    echo "$name|FAIL|命令缺失: $tool" >> "$TMP"
    echo "[FAIL] $name: 命令缺失 $tool"
    continue
  fi
  out=$(eval "$cmd" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    echo "$name|FAIL|exit $rc" >> "$TMP"
    echo "[FAIL] $name: exit $rc"
  else
    val="exit 0"
    if [ -n "$re" ]; then
      v=$(printf '%s' "$out" | grep -oE "$re" | head -1)
      [ -n "$v" ] && val="$v"
    fi
    echo "$name|PASS|$val" >> "$TMP"
    echo "[PASS] $name: $val"
  fi
done < "$CFG"

python3 - "$BATCH" "$QUALITY" "$TMP" <<'PYEOF'
import json, os, subprocess, sys
batch, quality, tmp = sys.argv[1:4]
commit = ""
try:
    commit = subprocess.run(["git", "-C", os.path.dirname(quality) + "/../..", "rev-parse", "HEAD"],
                            capture_output=True, text=True, timeout=10).stdout.strip()
except Exception:
    pass
gates = []
with open(tmp, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        name, status, val = line.split("|", 2)
        gates.append({"name": name, "status": status, "value": val})
doc = {"batch": batch, "date": os.popen("date +%F").read().strip(), "commit": commit, "gates": gates}
with open(os.path.join(quality, "gate-%s.json" % batch), "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
print("gate json ->", os.path.join(quality, "gate-%s.json" % batch), len(gates), "gates")
PYEOF
rm -f "$TMP"
