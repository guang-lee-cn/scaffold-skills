#!/bin/bash
# 提交信息检查。规则唯一权威在 scaffold/policies/commit-messages.md，本脚本只执行、不新增规则。
# 用法：bash quality/commit-lint.sh <msg-file>      # 手工跑或给别的脚本调
#       bootstrap 会把它装成 .git/hooks/commit-msg，提交时自动跑
# 退出码：0 通过；1 违规（提交被拒）；2 用法错误
# 可调项（可选，放 quality/commit-lint.conf，KEY=VALUE 一行一个）：
#   MAX_BULLETS=4        正文分条上限，超过说明这个提交在做多件事
#   MAX_BODY_LINES=10    正文（不含 trailer）总行数上限
#   TYPES='feat fix ...' 合法 type 列表
#   CHECK_IDS=1          是否禁内部编号（I-xx / DV-xx）；chore(quality) 归档自动豁免
set -uo pipefail

MSG_FILE="${1:-}"
if ! { [ -n "$MSG_FILE" ] && [ -f "$MSG_FILE" ]; }; then
  echo "用法: bash quality/commit-lint.sh <msg-file>" >&2; exit 2
fi
CONF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/commit-lint.conf"

MAX_BULLETS=4
MAX_BODY_LINES=10
TYPES='feat fix refactor test style chore docs merge'
CHECK_IDS=1
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF"
fi

# 去掉注释行与空行；保留顺序。git 把填写的正文放在注释块之前。
MSG="$(grep -v '^[[:space:]]*#' "$MSG_FILE" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}')"
SUBJECT="$(printf '%s\n' "$MSG" | head -1)"
BODY="$(printf '%s\n' "$MSG" | tail -n +2)"

fail=0
err() { echo "[拒绝] $*" >&2; fail=1; }

# ── 1. 标题 ────────────────────────────────────────────────────────────────
case "$SUBJECT" in
  Merge*|Revert*) : ;;
  *)
    # 字符数而不是字节数：中文标题按可见字数算，72 个汉字已经很长
    n="$(printf '%s' "$SUBJECT" | python3 -c 'import sys; print(len(sys.stdin.read().strip()))' 2>/dev/null || printf '%s' "$SUBJECT" | wc -m)"
    [ "$n" -le 72 ] || err "标题 $n 字符，超过 72"
    type_re="^($(printf '%s' "$TYPES" | tr ' ' '|'))(\([^)]+\))?: [^[:space:]].*"
    printf '%s' "$SUBJECT" | grep -Eq "$type_re" \
      || err "标题不是 <type>(<scope>): <做了什么>；合法 type：$TYPES"
    case "$SUBJECT" in
      *.|*。) err "标题句末不加句号：$SUBJECT" ;;
    esac
    ;;
esac

# ── 2. 正文：总述之后必须分条，短句，条数受控 ──────────────────────────────
case "$SUBJECT" in
  Merge*|Revert*) : ;;
  *)
    [ -n "$(printf '%s' "$BODY" | tr -d '[:space:]')" ] \
      || err "正文为空：标题说「做了什么」，正文说「改了哪几处」"

    bullets="$(printf '%s\n' "$BODY" | grep -cE '^[0-9]+\. ' || true)"
    if [ "$bullets" -gt "$MAX_BULLETS" ]; then
      err "正文 $bullets 条，超过 $MAX_BULLETS 条：分条太多说明这个提交在做多件事，拆成多个提交"
    fi
    # 非分条、非 trailer 的正文行 = 长句或连带背景，要求改成分条
    wrap="$(printf '%s\n' "$BODY" \
      | grep -vE '^[0-9]+\. ' \
      | grep -vE '^[A-Za-z-]+: ' \
      | grep -vE '^[[:space:]]*$' | head -3)"
    [ -z "$wrap" ] || err "正文有非分条行（写成「序号. 一句话」或 <Key>: <value> 的 trailer）：$(printf '%s' "$wrap" | head -1)"

    lines="$(printf '%s\n' "$BODY" | grep -cE '[^[:space:]]' || true)"
    [ "$lines" -le "$MAX_BODY_LINES" ] \
      || err "正文 $lines 行，超过 $MAX_BODY_LINES 行：提交信息不是工作记录"
    ;;
esac

# ── 3. 禁项：署名、生成器、需要解码表的内部编号 ────────────────────────────
# 只匹配署名形态，不匹配裸词：项目入口文件本身就叫 CLAUDE.md，按裸词匹配会把
# 「更新 CLAUDE.md」这类提交判成 AI 署名，被拒的人只能删字或 --no-verify 绕过。
if printf '%s\n' "$MSG" | grep -Eqi 'co-authored-by:|generated with|claude[ -]code|anthropic|🤖'; then
  err "提交信息里出现 AI 署名或生成器标记（本仓禁止）"
fi
# 标题里一律不出现内部代号：标题是给「没有解码表的人」看的第一行。
if printf '%s\n' "$SUBJECT" | grep -Eq '(^|[^A-Za-z0-9])(EP|S[0-9]*[0-9]|I|DV)-?[0-9]+([^A-Za-z0-9]|$)'; then
  err "标题出现内部编号 / 阶段代号：写成这次改动做了什么，代号留给正文 trailer 或台账"
fi
if [ "$CHECK_IDS" -eq 1 ]; then
  case "$SUBJECT" in
    chore\(quality\)*|chore\(repo\)*) : ;;   # 归档类提交：正文允许写 run id / commit
    *)
      if printf '%s\n' "$BODY" | grep -Eq '(^|[^A-Za-z0-9])(I|DV)-[0-9]+'; then
        err "正文出现内部编号（I-xx / DV-xx）：公共仓库没有解码表，读者只能猜"
      fi
      ;;
  esac
fi

# ── 4. 黑话：需要读者额外背景才能解开的词 ──────────────────────────────────
# 隐喻式名词（「收口」「回填」「掉」「假绿」）没法用正则判，只能靠自检：
# 陌生人 30 秒读懂吗？判据写在 policies/commit-messages.md §5，这里不假装能机械判定。

if [ "$fail" -ne 0 ]; then
  echo "---" >&2
  echo "规则：policies/commit-messages.md（格式 / type / 禁项 / 判定三条）" >&2
  exit 1
fi
exit 0
