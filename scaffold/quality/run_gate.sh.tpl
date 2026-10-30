#!/bin/bash
# 数据飞轮-采集环（Scaffold 通用门禁）：逐门禁执行 gates.conf → quality/runs/<日期>/<run-id>/
#   每次 run 一个目录：<run-id>/summary.json 汇总；<gate>/gate.json + stdout.log + stderr.log 留单门明细
# 用法：bash quality/run_gate.sh [batch标记] [--allow-dirty] [--allow-open-batches]
#   batch 缺省为 UTC 日期；run-id = <batch>-<UTC 时间戳>Z（例 EP-01-20261027T061500Z）
# 依赖：bash + git(可选) + python3 + grep（零外部工具）
# 正则口径：POSIX ERE，数字写 [0-9]（\d 在 GNU grep 下未定义，会静默取不到值）
# 格式：name|命令|取数正则(可选)；命令自身含 | 会被当成第三列（需要管道就包一层脚本）
# 证据级：git.dirty == 0 且 commit 非空，本次 run 才算证据；否则只能当调试记录
# 脏树在开跑前直接拒绝（exit 2）：跑完再警告等于白跑一趟，而门禁要的是证据不是全绿
# 门禁 exit 77 = 主动跳过（记 SKIP，不算失败）
# 门脚本自己也要有已知全绿的回放样本（历史绿 run 的 stdout.log 回放后仍退出 0 且指标数一致）：
#   它坏了没有别的门能发现；只用坏 run 验证过的解析脚本，会把「脚本静默退出」记成「测试失败」。
# 解析型门脚本在 `set -euo pipefail` 下取数，零命中属正常的必须 `|| true`（policies/constraints-and-criteria.md §2.4）。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <项目根>/quality
ROOT="$(cd "$DIR/.." && pwd)"                          # <项目根>
CFG="$DIR/gates.conf"
QUALITY="$DIR"
TMP="$DIR/.gates.tmp"

usage() {
  cat <<'EOF'
用法：bash quality/run_gate.sh [batch标记] [--allow-dirty] [--allow-open-batches]
  batch 缺省为 UTC 日期；run-id = <batch>-<UTC时间戳>Z
  产物：quality/runs/<日期>/<run-id>/{summary.json, <gate>/{gate.json,stdout.log,stderr.log}}
  --allow-dirty          脏树也开跑（该 run 记 dirty>0，不是证据级）
  --allow-open-batches   上一批未关闭也开跑（新项目接手旧进度表时用）
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done
[ -f "$CFG" ] || { echo "缺 gates.conf（参考 gates.conf.example 生成）"; exit 1; }

# 参数：唯一位置参数是批标记。--allow-dirty 只影响开跑前这一道判树；
# --allow-open-batches 只影响批次表前置（上一批没关也照跑，用于新项目接手旧进度表）
ALLOW_DIRTY=0
ALLOW_OPEN_BATCHES=0
BATCH=""
for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --allow-open-batches) ALLOW_OPEN_BATCHES=1 ;;
    *) [ -z "$BATCH" ] && BATCH="$arg" ;;
  esac
done
[ -n "$BATCH" ] || BATCH="$(date -u +%F)"

# 开跑前判树。例外放采集环自己的产物（runs/ 整个子树、trend.md、.gates.tmp、旧格式 gate-*.json）；
# 取不到 git 状态时（非 git 项目）不拦，由末尾按 commit 空 / dirty=-1 记非证据级。
RELQ="${QUALITY#"$ROOT"/}"
if [ "$ALLOW_DIRTY" -eq 0 ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  relq_re="$(printf '%s' "$RELQ" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
  dirty_list="$(git -C "$ROOT" status --porcelain --untracked-files=normal 2>/dev/null \
    | sed -e 's/^...//' \
    | grep -v -E "^\"?${relq_re}/(\.gates\.tmp|trend\.md|runs(/.*)?|gate-[^\"]*\.json)\"?$" || true)"
  if [ -n "$dirty_list" ]; then
    echo "[STOP] 工作树不干净，拒绝开跑：脏树上的 run 只能当调试记录，而门禁要的是证据"
    printf '%s\n' "$dirty_list" | head -10 | sed 's/^/  /'
    n="$(printf '%s\n' "$dirty_list" | wc -l)"
    [ "$n" -gt 10 ] && echo "  …（共 $n 处）"
    echo "  处理：先提交或收拾这些路径；确要调试，加 --allow-dirty（该 run 记 dirty>0，不能当证据）"
    exit 2
  fi
fi

# 开跑前判批次表：上一批没关闭（复盘没跑），这一批的门禁就不起来。
# 这是飞轮唯一的强制触发点——全自动流程没有外部提醒，「记得复盘」不是可执行规则，
# 「下一批第一次跑门禁必然失败」才是。它只读文件，不跑任何门禁。
if [ "$ALLOW_OPEN_BATCHES" -eq 0 ] && [ -f "$DIR/check-flywheel.sh" ]; then
  if ! bash "$DIR/check-flywheel.sh" --project "$ROOT" --gate-batches; then
    echo "  处理：先关上一批（复盘报告 + 批次指标 + 规则命中表），或加 --allow-open-batches 显式跳过"
    exit 3
  fi
fi

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# 零门禁 ≠ 全绿：配了注释/空文件也 exit 0 的话，聚合环会把它当证据级批次。
# 先数一遍再建 run 目录，避免留下空 run。
cfg_gates=0
while IFS='|' read -r name _ _ || [ -n "$name" ]; do
  name="$(trim "${name%$'\r'}")"
  name="${name#$'\xef\xbb\xbf'}"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue;; esac
  cfg_gates=$((cfg_gates+1))
done < "$CFG"
if [ "$cfg_gates" -eq 0 ]; then
  echo "[FAIL] $CFG 里没有任何门禁（空行与 # 注释不算）：零门禁不等于通过"
  exit 1
fi

# 每次 run 一个目录：quality/runs/<UTC 日期>/<batch>-<UTC 时间戳>Z/
# 同一秒重跑（脚本连续跑、CI 重试）时等到下一秒，保持 run-id 格式不变。
safe_batch="${BATCH//\//_}"
safe_batch="${safe_batch//|/_}"
safe_batch="${safe_batch//[[:space:]]/_}"
[ -n "$safe_batch" ] || safe_batch="$(date -u +%F)"
while :; do
  run_date="$(date -u +%F)"
  run_ts="$(date -u +%Y%m%dT%H%M%SZ)"
  run_id="${safe_batch}-${run_ts}"
  run_dir="$QUALITY/runs/$run_date/$run_id"
  mkdir -p "$QUALITY/runs/$run_date"
  mkdir "$run_dir" 2>/dev/null && break
  sleep 1
done
echo "[RUN] $run_id -> $run_dir"

: > "$TMP"
count=0
fails=0

now_ms() {
  local n
  n="$(date +%s%N 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) echo 0 ;; *) echo $((n / 1000000)) ;; esac
}

# 用 python 写 JSON：命令/原因里可能有引号、反斜杠、中文，printf 拼 JSON 会坏
write_gate_json() {
  python3 - "$@" <<'PYEOF'
import json, sys

path, name, cmd, status, rc, started, dur, reason, val = sys.argv[1:10]
doc = {
    "gate": name,
    "command": cmd,
    "status": status,
    "exit_code": int(rc),
    "started_at": started,
    "duration_ms": int(dur),
    "reason": reason,
    "metrics": {"value": val} if val != "" else {},
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
PYEOF
}

# 末行无换行也要跑（read 在 EOF 处返回非零但变量已填）：否则最后一门禁静默消失
while IFS='|' read -r name cmd re || [ -n "$name" ]; do
  # 行级归一：CRLF 的 \r、列两侧空白（按表格式对齐写的配置不该误红）
  name="$(trim "${name%$'\r'}")"
  cmd="$(trim "${cmd%$'\r'}")"
  re="$(trim "${re%$'\r'}")"
  # Windows 侧编辑器可能写 BOM：不剥掉的话第一个门禁名会变成 <BOM>unit，列名对不上
  name="${name#$'\xef\xbb\xbf'}"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue;; esac
  count=$((count+1))

  # 门禁名不改写：静默把 "my gate" 变成 "mygate" 会让跨批次的列名对不上。
  # 含空白 / 斜杠 / 是 . 或 .. 的名字无法安全当目录，仍记 FAIL，但落在 _gateN/ 下。
  case "$name" in
    *[[:space:]]*|*/*|.|..) gdir="$run_dir/_gate$count"; bad_name=1 ;;
    *) gdir="$run_dir/$name"; bad_name=0 ;;
  esac
  mkdir -p "$gdir"
  : > "$gdir/stdout.log"
  : > "$gdir/stderr.log"
  printf '%s\n' "${gdir#"$run_dir"/}" >> "$TMP"
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ "$bad_name" -eq 1 ]; then
    reason="门禁名含空白、斜杠或为 . / ..，不能当证据目录"
    write_gate_json "$gdir/gate.json" "$name" "$cmd" FAIL 2 "$started" 0 "$reason" ""
    echo "[FAIL] $name: 门禁名含空白、斜杠或为 . / ..（列名会与历史批次对不上）"
    fails=$((fails+1))
    continue
  fi

  # 防假绿：命令存在性检查（缺失 = FAIL，不空跑）；先跳过前置的 VAR=val
  # 值可能带引号且引号内有空格（FOO="a b" cmd），所以按整段赋值剥，不能按第一个空格切
  probe="$cmd"
  while :; do
    next="$(printf '%s' "$probe" | sed -E "s/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|'[^']*'|[^[:space:]]*)[[:space:]]+//")"
    [ "$next" = "$probe" ] && break
    probe="$next"
  done
  tool="${probe%% *}"
  if ! command -v "$tool" >/dev/null 2>&1 && ! [ -x "$tool" ]; then
    write_gate_json "$gdir/gate.json" "$name" "$cmd" FAIL 127 "$started" 0 "命令缺失: $tool" ""
    echo "[FAIL] $name: 命令缺失 $tool"
    fails=$((fails+1))
    continue
  fi

  # </dev/null：不回传循环的 fd 0（配置文件），否则读 stdin 的门禁会吃掉后续配置行
  start_ms="$(now_ms)"
  eval "$cmd" </dev/null >"$gdir/stdout.log" 2>"$gdir/stderr.log"; rc=$?
  end_ms="$(now_ms)"
  dur=$((end_ms - start_ms))
  [ "$dur" -lt 0 ] && dur=0

  if [ "$rc" -eq 77 ]; then
    write_gate_json "$gdir/gate.json" "$name" "$cmd" SKIP "$rc" "$started" "$dur" "exit 77：门禁主动跳过" ""
    echo "[SKIP] $name: exit 77"
    continue
  fi
  if [ "$rc" -ne 0 ]; then
    write_gate_json "$gdir/gate.json" "$name" "$cmd" FAIL "$rc" "$started" "$dur" "命令 exit $rc" ""
    echo "[FAIL] $name: exit $rc"
    fails=$((fails+1))
    continue
  fi

  val=""
  if [ -n "$re" ]; then
    # 防假绿：配了取数正则却匹配不到 = FAIL（指标消失不能当通过）
    val="$(cat "$gdir/stdout.log" "$gdir/stderr.log" | grep -oE "$re" | head -1)"
    if [ -z "$val" ]; then
      write_gate_json "$gdir/gate.json" "$name" "$cmd" FAIL "$rc" "$started" "$dur" "输出未命中取数正则: $re" ""
      echo "[FAIL] $name: 输出里没有 /$re/"
      fails=$((fails+1))
      continue
    fi
  fi
  write_gate_json "$gdir/gate.json" "$name" "$cmd" PASS "$rc" "$started" "$dur" "" "$val"
  if [ -n "$val" ]; then
    echo "[PASS] $name: $val"
  else
    echo "[PASS] $name: exit 0"
  fi
done < "$CFG"

python3 - "$BATCH" "$QUALITY" "$ROOT" "$run_dir" "$TMP" "$run_id" <<'PYEOF'
import json, os, subprocess, sys

batch, quality, root, run_dir, manifest, run_id = sys.argv[1:7]

def git(*args):
    try:
        r = subprocess.run(["git", "-C", root] + list(args),
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""

commit = git("rev-parse", "HEAD")
branch = git("rev-parse", "--abbrev-ref", "HEAD")


def status_paths():
    """-z 而不是默认格式：路径不加引号（含空格/中文不被转义），也不受首列空格被 strip 的影响。
    出错返回 None——取不到状态不能当成「干净」，那是 fail-open。"""
    try:
        r = subprocess.run(["git", "-C", root, "status", "--porcelain", "-z",
                            "--untracked-files=normal"],
                           capture_output=True, timeout=10)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    ents = r.stdout.decode("utf-8", "surrogateescape").split("\0")
    out, i = [], 0
    while i < len(ents):
        e = ents[i]
        i += 1
        if len(e) < 4:
            continue
        out.append(e[3:])
        if e[0] in ("R", "C"):
            i += 1   # 重命名/复制条目后面还跟着原路径
    return out


# 未跟踪文件也算脏：commit 里没有的源码被编进来，这次 run 就不是那个 commit 的证据。
# 例外只有采集环自己的产物：runs/ 整个子树（每次 run 一个目录）、trend.md、.gates.tmp、
# 旧格式 gate-*.json；否则跑一次就把下一次判脏。
qrel = os.path.relpath(quality, root).replace(os.sep, "/")


def own(path):
    p = path.rstrip("/")
    return (p in (qrel + "/.gates.tmp", qrel + "/trend.md", qrel + "/runs")
            or p.startswith(qrel + "/runs/")
            or (p.startswith(qrel + "/gate-") and p.endswith(".json")))


paths = status_paths()
if paths is None:
    dirty, dirty_paths = -1, []        # 取不到状态 ≠ 干净
else:
    dirty_paths = [p for p in paths if not own(p)]
    dirty = -1 if not commit else len(dirty_paths)

gates = []
with open(manifest, encoding="utf-8") as f:
    for line in f:
        rel = line.strip()
        if not rel:
            continue
        with open(os.path.join(run_dir, rel, "gate.json"), encoding="utf-8") as gf:
            g = json.load(gf)
        gates.append({"name": g["gate"], "status": g["status"],
                      "exit_code": g["exit_code"], "duration_ms": g["duration_ms"]})

n_pass = sum(1 for g in gates if g["status"] == "PASS")
n_fail = sum(1 for g in gates if g["status"] == "FAIL")
n_skip = sum(1 for g in gates if g["status"] == "SKIP")
overall = "FAIL" if n_fail else "PASS"

doc = {"run_id": run_id, "batch": batch,
       "git": {"commit": commit, "branch": branch, "dirty": dirty},
       "overall": {"status": overall, "total": len(gates),
                   "pass": n_pass, "fail": n_fail, "skip": n_skip},
       "gates": gates}
path = os.path.join(run_dir, "summary.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
print("summary json ->", path)
print("overall:", overall, "total=%d pass=%d fail=%d skip=%d" % (len(gates), n_pass, n_fail, n_skip))

# 全 SKIP 与全 PASS 是同一行 overall=PASS：stage 未启用时最容易被当成已验收的证据
if n_pass == 0:
    print("[警告] 本次 run 没有一个门禁真正跑过（全部 SKIP）：不能当作通过证据")

if not commit:
    print("[警告] 取不到 commit：本次 run 不是证据级")
elif dirty < 0:
    print("[警告] 取不到工作树状态（git status 失败或超时）：不能据此判证据级，按 dirty=-1 记")
elif dirty != 0:
    # 只报数量等于让人自己去猜哪来的脏：点名前几个，超过就省
    show = dirty_paths[:5]
    more = "" if len(dirty_paths) <= 5 else " …（另有 %d 个）" % (len(dirty_paths) - 5)
    print("[警告] 工作树有 %d 个改动/未跟踪文件（dirty=%d）：本次 run 不是证据级：%s%s"
          % (dirty, dirty, " ".join(show), more))
PYEOF
rc=$?
rm -f "$TMP"
[ $rc -ne 0 ] && exit $rc
[ $fails -ne 0 ] && exit 1
exit 0
