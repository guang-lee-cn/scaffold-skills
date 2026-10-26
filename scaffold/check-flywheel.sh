#!/bin/bash
# 飞轮自检：批次关闭时问三个问题——复盘写了吗、规则命中表填了吗、回流候选裁决了吗
# 用法：bash check-flywheel.sh --project <项目根> [--batch <日期目录>]
#       bash check-flywheel.sh --project <项目根> --gate-batches   # 门禁前置：上一批没关就不许开下一批
# 判据：错误 = 飞轮这轮没转（下一轮脚手架不会变好）；待办 = 有零命中规则等着退役
# 退出码：0 无错误；2 有错误；1 参数错误
set -uo pipefail
PROJECT=""; BATCH=""; GATE_BATCHES=0
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--project) [ $# -ge 2 ] || { usage >&2; exit 1; }
                  PROJECT="$2"; shift 2 ;;
    -b|--batch)   [ $# -ge 2 ] || { usage >&2; exit 1; }
                  BATCH="$2"; shift 2 ;;
    --gate-batches) GATE_BATCHES=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done
[ -n "$PROJECT" ] || { echo "缺 --project <项目根>" >&2; exit 1; }
PROJECT="$(cd "$PROJECT" && pwd)" || exit 1

errs=0; todos=0
bad()  { echo "[错误] $*"; errs=$((errs+1)); }
todo() { echo "[待办] $*"; todos=$((todos+1)); }

DOCS="$PROJECT/docs/开发交付"

# ── 门禁前置：批次表里还有没关闭的批次，就不许开下一批 ───────────────────────
# 为什么放在门禁里而不是写在 SOP 里：全自动流程没有外部触发者，「记得复盘」不可执行；
# 「下一批第一次跑门禁必然失败」才可执行。表不存在或为空 = 还没开始分批次，放行。
if [ "$GATE_BATCHES" -eq 1 ]; then
  PROG="$DOCS/进度.md"
  if [ -f "$PROG" ]; then
    open_rows="$(awk -F'|' '
      /^## 批次/ {f=1; next}
      /^## /    {f=0}
      f && /^\|/ && $0 !~ /^\|[-|[:space:]]+\|$/ && $2 !~ /批次/ {
        s=$5; gsub(/^[ \t]+|[ \t]+$/, "", s)
        if (s != "已关闭") { b=$2; gsub(/^[ \t]+|[ \t]+$/, "", b); print b " (" s ")" }
      }' "$PROG")"
    if [ -n "$open_rows" ]; then
      bad "批次未关闭就开新批：$(printf '%s' "$open_rows" | tr '\n' ' ')"
      bad "先跑完当前批的关批仪式（复盘报告 + 批次指标 + 规则命中表 + check-flywheel.sh 退出 0），把批次行改成「已关闭」"
      echo "---"; echo "错误 $errs / 待办 $todos"; exit 2
    fi
    echo "[通过] 批次表无未关闭批次"
  else
    todo "没有进度.md 的批次表，跳过批次门禁（新项目首批属正常）"
  fi
  exit 0
fi

# 批次目录：显式指定 > 最新的 20xx-xx-xx 目录
if [ -z "$BATCH" ]; then
  BATCH="$(find "$DOCS" -maxdepth 1 -type d -name '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' 2>/dev/null | sort | tail -1)"
fi
[ -n "$BATCH" ] || { bad "找不到批次目录（$DOCS 下没有 20xx-xx-xx）"; echo "---"; echo "错误 $errs / 待办 $todos"; exit 2; }

# 1. 复盘报告：批末必须有一份，且规则命中表填了
RETRO=""
for f in "$BATCH/复盘报告.md" "$BATCH/review/复盘报告.md" "$BATCH/评审/复盘报告.md"; do
  [ -f "$f" ] && RETRO="$f" && break
done
if [ -z "$RETRO" ]; then
  bad "批次 $BATCH 没有复盘报告（模板：docs/开发交付/模板/复盘报告.md）——没有它，规则命中表与退役都是空话"
else
  if ! grep -q '^## 规则命中表' "$RETRO"; then
    bad "$(basename "$RETRO") 缺「规则命中表」一节：不知道哪条规则这轮真的挡过东西"
  else
    # 命中表里的数据行：至少一行，且不能整表都是占位
    rows="$(awk '/^## 规则命中表/{f=1;next} /^## /{f=0}
                 f && /^\|/ && $0 !~ /^\|[-|[:space:]]+\|$/ && !/规则（文件/' "$RETRO")"
    if [ -z "$rows" ]; then
      bad "$(basename "$RETRO") 的规则命中表是空的"
    elif printf '%s\n' "$rows" | grep -q '<'; then
      bad "$(basename "$RETRO") 的规则命中表还有 <占位> 没填"
    else
      # 2. 零命中规则的退役提醒：连续两批才删，这里只点名，不替人决定
      zero="$(printf '%s\n' "$rows" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); if ($3 == "否") {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}}')"
      [ -n "$zero" ] && todo "本批零命中的规则（连续两批零命中即删除或降为样本）：$(printf '%s' "$zero" | tr '\n' ' ')"
    fi
  fi
  grep -q '<占位>' "$RETRO" && todo "$(basename "$RETRO") 仍有 <占位>（如仅示例处可忽略）"

  # 4. 批次指标：没有可比数字，改进只能凭印象，飞轮等于没转
  if ! grep -q '^## 批次指标' "$RETRO"; then
    bad "$(basename "$RETRO") 缺「批次指标」一节（逃逸率 / 假绿 / 变异覆盖 / 规则命中 / 返工）"
  else
    metrics_bad="$(awk '/^## 批次指标/{f=1;next} /^## /{f=0} f && /^\|/' "$RETRO" |
      grep -v '指标 *| *本批' | grep -v '^|-' )"
    if printf '%s\n' "$metrics_bad" | grep -q '<'; then
      bad "$(basename "$RETRO") 的批次指标还有占位没填"
    fi
  fi
fi

# 3. 回流候选：这轮有没有新候选、有没有裁决。没有候选是合法结论，但必须写过
FLY="$DOCS/回流候选.md"
if [ ! -f "$FLY" ]; then
  bad "缺 docs/开发交付/回流候选.md（项目 → 脚手架无回路，飞轮不转）"
else
  if grep -q '^| *R-[0-9]' "$FLY"; then
    # 示例行（候选列以「例：」开头）不算候选：模板自带的示例不该让每批都报错。
    # 裁决列取「最后一个非空字段」：表格行以 | 结尾时 $NF 恒为空，直接用 $NF 会全判未裁决。
    undisposed="$(awk -F'|' '/^\| *R-[0-9]/ {
        cand=$3; gsub(/^[ \t]+|[ \t]+$/, "", cand)
        if (cand ~ /^例：/) next
        disp=""
        for (i=NF; i>=2; i--) { v=$i; gsub(/^[ \t]+|[ \t]+$/, "", v); if (v != "") { disp=v; break } }
        if (disp == "" || disp ~ /^<.*>$/) print $2 }' "$FLY")"
    [ -n "$undisposed" ] && bad "回流候选有未裁决行：$(printf '%s' "$undisposed" | tr '\n' ' ')"
  else
    todo "回流候选还没有任何 R-xx 行——本项目至今没往回灌过东西？确认后在这一批写明"
  fi
fi

echo "---"
echo "批次: $BATCH"
echo "错误 $errs / 待办 $todos"
[ "$errs" -eq 0 ] || exit 2
exit 0
