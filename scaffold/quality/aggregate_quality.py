#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""数据飞轮-分析环（Scaffold 通用版）：聚合 quality/gate-*.json -> trend.md（表格 + Mermaid 折线）
用法: python3 aggregate_quality.py [--out quality/trend.md]
通用：门禁列名动态（取所有批次 gate 名并集），数值自动提取（覆盖%/计数/errors 等）。
"""
import argparse, glob, io, json, os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))
QUALITY = os.path.join(BASE, "quality")
NUM = re.compile(r"\d+(\.\d+)?")

def num_of(v):
    m = NUM.search(str(v))
    return float(m.group(0)) if m else None

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
        rows.append(dict(batch=d.get("batch", os.path.basename(fp)[5:-5]),
                         date=d.get("date", "?"), gates=gates))
    return rows, names

def render_md(rows, names):
    L = ["# 门禁趋势（数据飞轮-分析环产出）", "",
         "> 自动生成：`python3 aggregate_quality.py`（输入 quality/gate-*.json）", "",
         "## 明细", "",
         "| 批次 | 日期 | " + " | ".join(names) + " | 门禁 |",
         "|" + "---|" * (len(names) + 3)]
    for r in rows:
        cells = [r["gates"].get(n, {}).get("value", "-") if n in r["gates"] else "-" for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") != "PASS"]
        L.append("| " + r["batch"] + " | " + r["date"] + " | " + " | ".join(cells) + " | " + ("**FAIL**" if fail else "OK") + " |")
    L.append("")
    plotted = 0
    for n in names:
        series = [(r["batch"], num_of(r["gates"].get(n, {}).get("value", ""))) for r in rows]
        series = [(b, v) for b, v in series if v is not None]
        if len(series) < 2 or plotted >= 3:
            continue
        vals = [v for _, v in series]
        lo, hi = min(vals), max(vals)
        pad = max((hi - lo) * 0.2, 1)
        L += ["## " + n + " 趋势", "", "```mermaid", "xychart-beta",
              '    title "' + n + ' 趋势"',
              "    x-axis [" + ", ".join('"%s"' % b[:14] for b, _ in series) + "]",
              '    y-axis "%s" %.1f --> %.1f' % (n, lo - pad, hi + pad),
              "    line [" + ", ".join(str(v) for _, v in series) + "]", "```", ""]
        plotted += 1
    L += ["## 读数要点", "",
          "- 数值列下滑/波动 = 门禁回归信号；门禁 FAIL = 当日批次需复盘",
          "- 防假绿：命令缺失/未运行会记 FAIL 而非空跑（见 policies/门禁口径唯一.md）"]
    return "\n".join(L)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(QUALITY, "trend.md"))
    args = ap.parse_args()
    rows, names = load_all()
    if not rows:
        print("no gate-*.json under", QUALITY); sys.exit(1)
    io.open(args.out, "w", encoding="utf-8").write(render_md(rows, names))
    print("批次 | 日期 | " + " | ".join(names) + " | 门禁")
    for r in rows:
        cells = [r["gates"].get(n, {}).get("value", "-") if n in r["gates"] else "-" for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") != "PASS"]
        print(r["batch"][:24] + " | " + r["date"] + " | " + " | ".join(c[:14] for c in cells) + " | " + (",".join(fail) if fail else "OK"))
    print("trend.md ->", args.out)

if __name__ == "__main__":
    main()
