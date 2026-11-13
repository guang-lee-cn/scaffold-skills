#!/bin/bash
# 模板资产自检：清单 coverage + 部署可复现
# 用法：bash check-assets.sh
#       bash check-assets.sh --selftest   # 在临时项目真跑一次 bootstrap，逐条断言目标文件存在
# 判据：模板目录下每个 *.tpl 都登记在 templates.manifest，源存在、目标不重复；
#       --selftest 还要所有目标文件在新项目里真的落盘。
# 退出码：0 无错误；2 有错误；1 参数错误
#
# 为什么需要：手写 put 列表漏过两个模板，而 skill-lint 的零引用检查抓不到——
# 两个模板已被策略引用，所以「零引用」是干净的；漏的是「引用 ≠ 部署」。
set -uo pipefail
SCAFFOLD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCAFFOLD/.." && pwd)"
MANIFEST="$SCAFFOLD/templates/templates.manifest"
SELFTEST=0
case "${1:-}" in
  --selftest) SELFTEST=1 ;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  '') ;;
  *) echo "未知参数: $1" >&2; exit 1 ;;
esac

errs=0; n=0
bad() { echo "[错误] $*"; errs=$((errs+1)); }

[ -f "$MANIFEST" ] || { echo "[错误] 缺 templates/templates.manifest" >&2; exit 2; }

declared=""; declared_dsts=""
while IFS='|' read -r src dst mode || [ -n "$src" ]; do
  src="$(printf '%s' "$src" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  dst="$(printf '%s' "$dst" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  mode="$(printf '%s' "$mode" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$src" in ''|'#'*) continue ;; esac
  n=$((n+1))
  declared="$declared$src"$'\n'
  [ -f "$SCAFFOLD/templates/$src" ] || bad "清单源不存在：$src"
  case "$dst" in ''|/*) bad "目标路径必须是非空相对路径：$src -> [$dst]" ;; esac
  case "$mode" in put|gen:project|gen:claude) ;; *) bad "模式非法：$src -> [$mode]" ;; esac
  # 目标重复：两行写同一个文件，后一行会静默覆盖前一行
  if printf '%s\n' "$declared_dsts" | grep -qxF "$dst"; then
    bad "目标路径重复：$dst"
  fi
  declared_dsts="$declared_dsts$dst"$'\n'
done < "$MANIFEST"

# 反向覆盖：templates 下的每个 *.tpl 都必须被清单认领
while IFS= read -r f; do
  rel="$(basename "$f")"
  if ! printf '%s' "$declared" | grep -qxF "$rel"; then
    bad "模板未登记：templates/$rel（新增模板必须写进 templates.manifest）"
  fi
done < <(find "$SCAFFOLD/templates" -maxdepth 1 -type f -name '*.tpl' | sort)

echo "清单: $n 条；模板目录: $(find "$SCAFFOLD/templates" -maxdepth 1 -type f -name '*.tpl' | wc -l) 个"

if [ "$SELFTEST" -eq 1 ] && [ "$errs" -eq 0 ]; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  bash "$SCAFFOLD/bootstrap.sh" SelftestProj "$T/proj" --no-skills --no-git \
    > "$T/bootstrap.log" 2>&1 || { bad "--selftest: bootstrap 失败（日志 $T/bootstrap.log）"; cat "$T/bootstrap.log" >&2; }
  while IFS='|' read -r src dst mode || [ -n "$src" ]; do
    src="$(printf '%s' "$src" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    dst="$(printf '%s' "$dst" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$src" in ''|'#'*) continue ;; esac
    [ -f "$T/proj/$dst" ] || bad "--selftest: 新项目缺 $dst（清单要求它落盘）"
  done < "$MANIFEST"
  [ "$errs" -eq 0 ] && echo "[自检通过] 新项目逐条落盘（$n 个目标）"
fi

echo "---"
echo "错误 $errs"
[ "$errs" -eq 0 ] || exit 2
exit 0
