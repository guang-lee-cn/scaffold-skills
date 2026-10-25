#!/bin/bash
# 数据飞轮-采集环（Scaffold 通用门禁）：逐门禁执行 gates.conf → quality/gate-<batch>.json
# 用法：bash quality/run_gate.sh [batch标记]   # 批标记默认 日期-commit
# 依赖：bash + git(可选) + python3 + grep（零外部工具）
# 正则口径：POSIX ERE，数字写 [0-9]（\d 在 GNU grep 下未定义，会静默取不到值）
# 格式：name|命令|取数正则(可选)；命令自身含 | 会被当成第三列（需要管道就包一层脚本）
# 证据级：git.dirty == 0 且 commit 非空，本次 run 才算证据；否则只能当调试记录
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <项目根>/quality
ROOT="$(cd "$DIR/.." && pwd)"                          # <项目根>
CFG="$DIR/gates.conf"
QUALITY="$DIR"
TMP="$DIR/.gates.tmp"
[ -f "$CFG" ] || { echo "缺 gates.conf（参考 gates.conf.example 生成）"; exit 1; }
mkdir -p "$QUALITY"
: > "$TMP"

BATCH="${1:-$(date +%F)-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
count=0
fails=0

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# 末行无换行也要跑（read 在 EOF 处返回非零但变量已填）：否则最后一门禁静默消失
while IFS='|' read -r name cmd re || [ -n "$name" ]; do
  # 行级归一：CRLF 的 \r、列两侧空白（按表格式对齐写的配置不该误红）
  name="$(trim "${name%$'\r'}")"
  cmd="$(trim "${cmd%$'\r'}")"
  re="$(trim "${re%$'\r'}")"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue;; esac
  count=$((count+1))
  # 门禁名不改写：静默把 "my gate" 变成 "mygate" 会让跨批次的列名对不上
  if printf '%s' "$name" | grep -q '[[:space:]]'; then
    echo "$name|FAIL|门禁名含空白" >> "$TMP"
    echo "[FAIL] $name: 门禁名含空白（列名会与历史批次对不上）"
    fails=$((fails+1))
    continue
  fi
  # 防假绿：命令存在性检查（缺失 = FAIL，不空跑）；先跳过前置的 VAR=val
  probe="$cmd"
  while [[ "$probe" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]] ]]; do
    probe="$(trim "${probe#*[[:space:]]}")"
  done
  tool="${probe%% *}"
  if ! command -v "$tool" >/dev/null 2>&1 && ! [ -x "$tool" ]; then
    echo "$name|FAIL|命令缺失: $tool" >> "$TMP"
    echo "[FAIL] $name: 命令缺失 $tool"
    fails=$((fails+1))
    continue
  fi
  # </dev/null：不回传循环的 fd 0（配置文件），否则读 stdin 的门禁会吃掉后续配置行
  out=$(eval "$cmd" </dev/null 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    echo "$name|FAIL|exit $rc" >> "$TMP"
    echo "[FAIL] $name: exit $rc"
    fails=$((fails+1))
    continue
  fi
  val="exit 0"
  if [ -n "$re" ]; then
    # 防假绿：配了取数正则却匹配不到 = FAIL（指标消失不能当通过）
    v=$(printf '%s' "$out" | grep -oE "$re" | head -1)
    if [ -z "$v" ]; then
      echo "$name|FAIL|正则未命中: $re" >> "$TMP"
      echo "[FAIL] $name: 输出里没有 /$re/"
      fails=$((fails+1))
      continue
    fi
    val="$v"
  fi
  echo "$name|PASS|$val" >> "$TMP"
  echo "[PASS] $name: $val"
done < "$CFG"

# 零门禁 ≠ 全绿：配了注释/空文件也 exit 0 的话，聚合环会把它当证据级批次
if [ "$count" -eq 0 ]; then
  echo "[FAIL] $CFG 里没有任何门禁（空行与 # 注释不算）：零门禁不等于通过"
  rm -f "$TMP"
  exit 1
fi

python3 - "$BATCH" "$QUALITY" "$ROOT" "$TMP" <<'PYEOF'
import json, os, subprocess, sys

batch, quality, root, tmp = sys.argv[1:5]

def git(*args):
    try:
        r = subprocess.run(["git", "-C", root] + list(args),
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""

commit = git("rev-parse", "HEAD")
branch = git("rev-parse", "--abbrev-ref", "HEAD")
status = git("status", "--porcelain", "--untracked-files=normal")

# 未跟踪文件也算脏：commit 里没有的源码被编进来，这次 run 就不是那个 commit 的证据。
# 例外只有采集环自己的产物（gate-*.json / .gates.tmp），否则跑一次就把下一次判脏。
qrel = os.path.relpath(quality, root).replace(os.sep, "/")


def own(path):
    return (path == qrel + "/.gates.tmp"
            or (path.startswith(qrel + "/gate-") and path.endswith(".json")))


dirty = -1 if not commit else len([l for l in status.splitlines()
                                   if l.strip() and not own(l[3:])])

gates = []
with open(tmp, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        gname, gstat, gval = line.split("|", 2)
        gates.append({"name": gname, "status": gstat, "value": gval})

date = subprocess.run(["date", "+%F"], capture_output=True, text=True).stdout.strip()
doc = {"batch": batch, "date": date,
       "git": {"commit": commit, "branch": branch, "dirty": dirty},
       "gates": gates}
path = os.path.join(quality, "gate-%s.json" % batch)
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
print("gate json ->", path, len(gates), "gates")

if not commit:
    print("[警告] 取不到 commit：本次 run 不是证据级")
elif dirty != 0:
    print("[警告] 工作树有 %d 个改动/未跟踪文件（dirty=%d）：本次 run 不是证据级" % (dirty, dirty))
PYEOF
rc=$?
rm -f "$TMP"
[ $rc -ne 0 ] && exit $rc
[ $fails -ne 0 ] && exit 1
exit 0
