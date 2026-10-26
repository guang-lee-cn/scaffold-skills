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
PROG="$DOCS/进度.md"

# ── 门禁前置：上一批没关门，这一批就没法开工 ─────────────────────────────────
# 为什么放在门禁里而不是写在 SOP 里：全自动流程没有外部触发者，「记得复盘」不可执行；
# 「这一批第一次跑门禁必然失败」才可执行。表不存在或为空 = 还没开始分批次，放行。
#
# 判据分两段，别把「进行中」也拦掉：
#   · 除最后一行外，全部必须「已关闭」——这就是「上一批没关，下一批起不来」；
#   · 最后一行是当前批：`进行中` 放行（批内要跑门禁），`待复盘` 拦下（活干完了，先关批）。
# 早期版本把任何非「已关闭」都算未关，结果是批内第一次跑门禁就红，规则本身不可用。
if [ "$GATE_BATCHES" -eq 1 ]; then
  if [ -f "$PROG" ]; then
    rows="$(awk -F'|' '
      /^## 批次/ {f=1; next}
      /^## /    {f=0}
      f && /^\|/ && $0 !~ /^\|[-|[:space:]]+\|$/ && $2 !~ /批次/ {
        b=$2; s=$5
        gsub(/^[ \t]+|[ \t]+$/, "", b); gsub(/^[ \t]+|[ \t]+$/, "", s)
        print b "\t" s
      }' "$PROG")"
    if [ -n "$rows" ]; then
      total="$(printf '%s\n' "$rows" | grep -c '' || true)"
      i=0
      blocked=0
      while IFS="$(printf '\t')" read -r label state; do
        i=$((i + 1))
        if [ "$i" -lt "$total" ]; then
          if [ "$state" != "已关闭" ]; then
            bad "更早的批次还没关闭：$label（$state）"
            blocked=1
          fi
        else
          case "$state" in
            进行中|已关闭) : ;;
            待复盘)
              bad "最后一批「$label」在待复盘：先把复盘报告写完、批次行改成「已关闭」再跑门禁"
              blocked=1 ;;
            *)
              bad "最后一批「$label」状态无法识别：$state（只允许 进行中/待复盘/已关闭）"
              blocked=1 ;;
          esac
        fi
      done <<EOF
$rows
EOF
      if [ "$blocked" -ne 0 ]; then
        echo "---"; echo "错误 $errs / 待办 $todos"; exit 2
      fi
      echo "[通过] 更早批次均已关闭，当前批「$(printf '%s\n' "$rows" | tail -1 | cut -f1)」状态允许跑门禁"
    else
      echo "[通过] 批次表还没有数据行（首批属正常）"
    fi
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
#
# 路径以批次表为准：同一天可以有两批，两条批次行都写在同一个日期目录里。
# 只按「日期目录/复盘报告.md」找，第二批会拿到第一批的报告——校验照样通过，内容却是别人的。
# 所以先看批次表最后一行的「复盘」列：给了路径就以它为准，给了却不存在就是错，不退回猜测。
RETRO=""; last_state=""; report_error=0
if [ -f "$PROG" ]; then
  last_row="$(awk -F'|' '
    /^## 批次/ {f=1; next}
    /^## /     {f=0}
    f && /^\|/ && $0 !~ /^\|[-|[:space:]]+\|$/ && $2 !~ /批次/ {
      s=$5; r=$6
      gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", r)
      ls=s; lr=r
    }
    END { print (ls == "" ? "" : ls) "\t" (lr == "" ? "" : lr) }' "$PROG")"
  last_state="$(printf '%s' "$last_row" | cut -f1)"
  last_retro="$(printf '%s' "$last_row" | cut -f2)"
  # 复盘列允许写成 `路径`（附注）：取反引号里的路径；没写反引号的裸路径也认。
  retro_rel="$(printf '%s' "$last_retro" | awk -F'`' 'NF > 1 { print $2; exit }')"
  if [ -z "$retro_rel" ]; then
    case "$last_retro" in
      ''|—|-|无|无（*|无\(*) : ;;
      *) retro_rel="$last_retro" ;;
    esac
  fi
  if [ -n "$retro_rel" ]; then
    if [ -f "$DOCS/$retro_rel" ]; then
      RETRO="$DOCS/$retro_rel"
    elif [ -f "$PROJECT/$retro_rel" ]; then
      RETRO="$PROJECT/$retro_rel"
    else
      bad "批次表最后一行的复盘路径不存在：$retro_rel（路径以该列为准，改了文件名就要同步这一列）"
      report_error=1
    fi
  elif [ "$last_state" = "已关闭" ]; then
    bad "最后一批已标「已关闭」，但复盘列没有可点的报告路径——补上该批报告路径（相对 docs/开发交付/）后重跑"
    report_error=1
  elif [ "$last_state" = "待复盘" ]; then
    # 待复盘的含义就是「活干完了，报告还没写完」：这一列的路径是关批的唯一凭据，
    # 空着就会在关批那一刻才发现无凭可依，所以在待复盘阶段就要它。
    bad "最后一批已标「待复盘」，但复盘列没有报告路径——待复盘到已关闭之间唯一要做的事就是填它"
    report_error=1
  fi
fi
if [ -z "$last_state" ]; then
  # 向后兼容：没有批次表（老项目）时才按固定文件名找；命中要说明这是回退，不是权威路径。
  for f in "$BATCH/复盘报告.md" "$BATCH/review/复盘报告.md" "$BATCH/评审/复盘报告.md"; do
    [ -n "$RETRO" ] && break
    [ -f "$f" ] && RETRO="$f"
  done
  [ -n "$RETRO" ] && echo "[提示] 复盘报告以回退路径取到（${RETRO#"$DOCS"/}），进度表的复盘列没填——建议补上权威路径"
fi

if [ "$last_state" = "进行中" ]; then
  # 进行中的批次还没有报告可读：要求它存在等于逼人提前写一份假报告，
  # 或者把上一批的报告复制过来（两者都会让下面的内容校验变成空话）。
  echo "[跳过] 本批（$BATCH）进行中，不要求复盘报告"
elif [ -z "$RETRO" ]; then
  # 上面已按批次表的状态报过「没有路径」，不要再用另一句话说同一件事。
  [ "$report_error" -eq 1 ] || bad "批次 $BATCH 没有复盘报告（模板：docs/开发交付/模板/复盘报告.md）——没有它，规则命中表与退役都是空话"
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
