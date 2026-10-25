#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""数据飞轮-分析环（Scaffold 通用版）：聚合 quality/gate-*.json -> trend.md（表格 + Mermaid 折线）
用法: python3 aggregate_quality.py [--out quality/trend.md] [--charts N]
通用：门禁列名动态（取所有批次 gate 名并集），数值自动提取（覆盖%/计数/errors 等）。
读数口径：只把 git.dirty == 0 且 commit 非空的批次当证据；其余批次在表里标「非证据级」。
"""
import argparse, glob, io, json, os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))
# 脚本可能落在 <项目根>/quality/，也可能被放到别处；两种都认
QUALITY = BASE if os.path.basename(BASE) == "quality" else os.path.join(BASE, "quality")
NUM = re.compile(r"\d+(\.\d+)?")
MAX_CHARTS = 6


def num_of(v):
    m = NUM.search(str(v))
    return float(m.group(0)) if m else None


def provenance(d):
    """返回 (是否证据级, 展示串)。旧格式（顶层 commit、无 dirty）一律不算证据级。"""
    g = d.get("git")
    if isinstance(g, dict):
        commit, dirty = g.get("commit", ""), g.get("dirty", -1)
    else:
        commit, dirty = d.get("commit", ""), -1
    if commit and dirty == 0:
        return True, commit[:8]
    if not commit:
        return False, "无 commit"
    return False, "%s 脏%d" % (commit[:8], dirty) if dirty > 0 else "%s 脏?" % commit[:8]


def load_all():
    rows, names = [], []
    for fp in sorted(glob.glob(os.path.join(QUALITY, "gate-*.json"))):
        try:
            d = json.load(io.open(fp, encoding="utf-8"))
        except Exception:
            continue
        gates = {g["name"]: g for g in d.get("gates", [])}
        for n in gates:
            if n not in names:
                names.append(n)
        level, prov = provenance(d)
        # batch/date 手写或旧工具可能给成数字：一律按字符串比，否则排序时 TypeError 整表不出
        rows.append(dict(batch=str(d.get("batch", os.path.basename(fp)[5:-5])),
                         date=str(d.get("date", "?")), gates=gates,
                         evidence=level, prov=prov))
    # 按文件名排会让 b10 排在 b2 前面，「最近状态/红转绿」随之错位。
    # 先按日期，再按批次名的自然序（数字段当整数比）。
    rows.sort(key=lambda r: (r["date"],
                             [(1, int(t)) if t.isdigit() else (0, t)
                              for t in re.split(r"(\d+)", r["batch"])]))
    return rows, names


def render_md(rows, names, max_charts=MAX_CHARTS):
    L = ["# 门禁趋势（数据飞轮-分析环产出）", "",
         "> 自动生成：`python3 aggregate_quality.py`（输入 quality/gate-*.json）", "",
         "## 明细", "",
         "| 批次 | 日期 | 证据级 | " + " | ".join(names) + " | 门禁 |",
         "|" + "---|" * (len(names) + 4)]
    for r in rows:
        # value 里可能含 |（正则本身/命令片段），不转义会把表格撑出多余列
        cells = [str(r["gates"][n].get("value", "-")).replace("|", "\\|")
                 if n in r["gates"] else "-" for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") != "PASS"]
        L.append("| %s | %s | %s | %s | %s |" % (
            r["batch"], r["date"], r["prov"], " | ".join(cells),
            "**FAIL**" if fail else "OK"))
    L.append("")

    # 逐门汇总：红过几次、当前是否绿——比"看最后一行"可靠
    L += ["## 逐门汇总", "",
          "| 门禁 | 跑过 | 红过 | 最近状态 | 红转绿 |", "|---|---|---|---|---|"]
    for n in names:
        ran = [r for r in rows if n in r["gates"]]
        red = [r for r in ran if r["gates"][n].get("status") != "PASS"]
        seen_red, flipped = False, False
        for r in ran:
            st = r["gates"][n].get("status")
            if st != "PASS":
                seen_red = True
            elif seen_red:
                flipped = True
        last = ran[-1]["gates"][n].get("status", "-") if ran else "-"
        L.append("| %s | %d | %d | %s | %s |" % (n, len(ran), len(red), last,
                                                 "是" if flipped else ("—" if not red else "未转绿")))
    missing = [n for n in names if any(n not in r["gates"] for r in rows)]
    if missing:
        L += ["", "> 有批次缺门禁（列里显示 `-`）：" + "、".join(missing) + "。缺门禁不等于通过。"]

    plotted = 0
    for n in names:
        series = [(r["batch"], num_of(r["gates"].get(n, {}).get("value", ""))) for r in rows]
        series = [(b, v) for b, v in series if v is not None]
        if len(series) < 2:
            continue
        if plotted >= max_charts:
            L += ["", "> 只画前 %d 条数值趋势，其余见明细表。" % max_charts]
            break
        vals = [v for _, v in series]
        lo, hi = min(vals), max(vals)
        pad = max((hi - lo) * 0.2, 1)
        L += ["", "## " + n + " 趋势", "", "```mermaid", "xychart-beta",
              '    title "' + n + ' 趋势"',
              "    x-axis [" + ", ".join('"%s"' % b[:14] for b, _ in series) + "]",
              '    y-axis "%s" %.1f --> %.1f' % (n, lo - pad, hi + pad),
              "    line [" + ", ".join(str(v) for _, v in series) + "]", "```"]
        plotted += 1
    L += ["", "## 读数要点", "",
          "- **证据级**列：`dirty == 0` 且 commit 非空才算；标「脏」的那一批只能当调试记录，不能拿来证明回归",
          "- 数值列下滑/波动 = 门禁回归信号；门禁 FAIL = 当日批次需复盘",
          "- 防假绿：命令缺失/正则未命中会记 FAIL 而非空跑（见 policies/门禁口径唯一.md）"]
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(QUALITY, "trend.md"))
    ap.add_argument("--charts", type=int, default=MAX_CHARTS)
    args = ap.parse_args()
    rows, names = load_all()
    if not rows:
        print("no gate-*.json under", QUALITY)
        sys.exit(1)
    with io.open(args.out, "w", encoding="utf-8") as fh:
        fh.write(render_md(rows, names, args.charts))
    print("批次 | 日期 | 证据级 | " + " | ".join(names) + " | 门禁")
    for r in rows:
        # value 里可能含 |（正则本身/命令片段），不转义会把表格撑出多余列
        cells = [str(r["gates"][n].get("value", "-")).replace("|", "\\|")
                 if n in r["gates"] else "-" for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") != "PASS"]
        print("%s | %s | %s | %s | %s" % (r["batch"][:24], r["date"], r["prov"],
                                          " | ".join(c[:14] for c in cells),
                                          ",".join(fail) if fail else "OK"))
    print("trend.md ->", args.out)


if __name__ == "__main__":
    main()
