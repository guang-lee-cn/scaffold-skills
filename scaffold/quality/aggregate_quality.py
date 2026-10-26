#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""数据飞轮-分析环（Scaffold 通用版）：聚合 quality/runs/*/*/summary.json -> trend.md
兼容旧格式 quality/gate-*.json，老项目的历史批次不丢。
新布局每次 run 一个目录：quality/runs/<日期>/<run-id>/{summary.json, <gate>/gate.json, ...}
输出：明细表 + 逐门状态/耗时表 + Mermaid 耗时趋势，能一眼看出哪门红了、耗时是否退化。
用法: python3 aggregate_quality.py [--out quality/trend.md] [--charts N]
读数口径：只把 git.dirty == 0 且 commit 非空的 run 当证据；其余 run 在表里标「非证据级」。
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


def natural(s):
    return [(1, int(t)) if t.isdigit() else (0, t) for t in re.split(r"(\d+)", s)]


def load_all():
    rows = []
    # 新格式：一次 run 一个 summary.json
    for fp in glob.glob(os.path.join(QUALITY, "runs", "*", "*", "summary.json")):
        try:
            d = json.load(io.open(fp, encoding="utf-8"))
        except Exception:
            continue
        run_dir = os.path.dirname(fp)
        date = os.path.basename(os.path.dirname(run_dir))
        run_id = str(d.get("run_id") or os.path.basename(run_dir))
        gates = {}
        for g in d.get("gates", []):
            n = g.get("name")
            if not n:
                continue
            gates[n] = {"status": g.get("status", "?"),
                        "exit_code": g.get("exit_code"),
                        "duration_ms": g.get("duration_ms")}
        level, prov = provenance(d)
        rows.append(dict(run=run_id, batch=str(d.get("batch", run_id)), date=date,
                         gates=gates, evidence=level, prov=prov, source="run"))
    # 旧格式：平铺 gate-<batch>.json（只有 value，没有 duration_ms）
    for fp in glob.glob(os.path.join(QUALITY, "gate-*.json")):
        try:
            d = json.load(io.open(fp, encoding="utf-8"))
        except Exception:
            continue
        gates = {}
        for g in d.get("gates", []):
            n = g.get("name")
            if not n:
                continue
            item = {"status": g.get("status", "?"), "exit_code": None,
                    "duration_ms": None}
            if g.get("value") is not None:
                item["value"] = g.get("value")
            gates[n] = item
        level, prov = provenance(d)
        batch = str(d.get("batch", os.path.basename(fp)[5:-5]))
        rows.append(dict(run=batch, batch=batch, date=str(d.get("date", "?")),
                         gates=gates, evidence=level, prov=prov, source="legacy"))
    # 按日期，再按 run 名的自然序（数字段当整数比），否则 b10 会排在 b2 前面
    rows.sort(key=lambda r: (r["date"], natural(r["run"])))
    names = []
    for r in rows:
        for n in r["gates"]:
            if n not in names:
                names.append(n)
    return rows, names


def cell(g):
    """单门单元格：状态 + 耗时；旧格式有 value 时附上，FAIL 加粗。"""
    if not g:
        return "-"
    st = g.get("status", "?")
    dur = g.get("duration_ms")
    if dur is None:
        val = g.get("value")
        txt = st if val is None else "%s(%s)" % (st, val)
    else:
        txt = "%s/%sms" % (st, dur)
    return "**%s**" % txt if st == "FAIL" else txt


def dur_change(series):
    """最近一次相对上一次的耗时变化；明显变慢（>20% 且 >50ms）标成退化。"""
    if len(series) < 2:
        return "—"
    latest, prev = series[-1], series[-2]
    if prev <= 0:
        return "—"
    pct = (latest - prev) * 100.0 / prev
    if pct > 20 and (latest - prev) > 50:
        return "**↑ %.1f%% 退化**" % pct
    if pct < -20:
        return "↓ %.1f%%" % abs(pct)
    return "%+.1f%%" % pct


def render_md(rows, names, max_charts=MAX_CHARTS):
    L = ["# 门禁趋势（数据飞轮-分析环产出）", "",
         "> 自动生成：`python3 aggregate_quality.py`"
         "（输入 `quality/runs/*/*/summary.json`，兼容旧 `quality/gate-*.json`）", "",
         "## 明细（每次 run）", "",
         "| run | 批次 | 日期 | 证据级 | " + " | ".join(names) + " | 红门 |",
         "|" + "---|" * (len(names) + 5)]
    for r in rows:
        # 单元格内容可能含 |（旧格式 value/正则），不转义会把表格撑出多余列
        cells = [cell(r["gates"].get(n)).replace("|", "\\|") for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") == "FAIL"]
        L.append("| %s | %s | %s | %s | %s | %s |" % (
            r["run"], r["batch"], r["date"], r["prov"], " | ".join(cells),
            "**" + ", ".join(fail) + "**" if fail else "OK"))
    L.append("")

    # 逐门一行：最近状态 / 最近耗时 / 耗时变化 / 最近 commit——红线与耗时退化都能直接扫到
    L += ["## 逐门状态与耗时", "",
          "| 门禁 | 跑过 | 红过 | 最近状态 | 最近 duration_ms | 上次 duration_ms | 耗时变化 | 最近 commit |",
          "|---|---|---|---|---|---|---|---|"]
    for n in names:
        ran = [r for r in rows if n in r["gates"]]
        red = [r for r in ran if r["gates"][n].get("status") == "FAIL"]
        last = ran[-1] if ran else None
        last_g = last["gates"][n] if last else {}
        series = [r["gates"][n].get("duration_ms") for r in ran
                  if r["gates"][n].get("duration_ms") is not None]
        L.append("| %s | %d | %d | %s | %s | %s | %s | %s |" % (
            n, len(ran), len(red), last_g.get("status", "-"),
            series[-1] if series else "-",
            series[-2] if len(series) >= 2 else "-",
            dur_change(series),
            last["prov"] if last else "-"))
    missing = [n for n in names if any(n not in r["gates"] for r in rows)]
    if missing:
        L += ["", "> 有 run 缺门禁（列里显示 `-`）：" + "、".join(missing) + "。缺门禁不等于通过。"]

    # 耗时趋势：只画有 >=2 个耗时的门禁（旧格式没有耗时，自动跳过）
    plottable = []
    for n in names:
        series = [(r["run"], r["gates"][n].get("duration_ms")) for r in rows
                  if n in r["gates"] and r["gates"][n].get("duration_ms") is not None]
        if len(series) >= 2:
            plottable.append((n, series))
    if plottable:
        L += ["", "## 门禁耗时趋势", ""]
        for i, (n, series) in enumerate(plottable):
            if i >= max_charts:
                L += ["> 只画前 %d 条耗时趋势，其余见逐门表。" % max_charts]
                break
            vals = [v for _, v in series]
            lo, hi = min(vals), max(vals)
            pad = max((hi - lo) * 0.2, 1)
            L += ["### " + n + " 耗时", "", "```mermaid", "xychart-beta",
                  '    title "%s 耗时(ms)"' % n,
                  "    x-axis [" + ", ".join('"%s"' % b[:20] for b, _ in series) + "]",
                  '    y-axis "duration_ms" %.1f --> %.1f' % (lo - pad, hi + pad),
                  "    line [" + ", ".join(str(v) for v in vals) + "]", "```", ""]

    if L and L[-1] != "":
        L.append("")
    L += ["## 读数要点", "",
          "- **证据级**列：`summary.json.git.dirty == 0` 且 commit 非空才算；标「脏」的 run 只能当调试记录",
          "- **红门**：任一 `status == FAIL`；`SKIP`（exit 77）不算红，但要在复盘里写明为什么跳过",
          "- **耗时变化**：最近一次相对上一次；↑ 超 20% 且多 50ms 标「退化」，看趋势图确认是否持续",
          "- 防假绿：命令缺失/正则未命中会记 FAIL 而非空跑（见 policies/门禁口径唯一.md）"]
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(QUALITY, "trend.md"))
    ap.add_argument("--charts", type=int, default=MAX_CHARTS)
    args = ap.parse_args()
    rows, names = load_all()
    if not rows:
        print("no quality/runs/*/*/summary.json or quality/gate-*.json under", QUALITY)
        sys.exit(1)
    with io.open(args.out, "w", encoding="utf-8") as fh:
        fh.write(render_md(rows, names, args.charts))
    print("run | 日期 | 证据级 | " + " | ".join(names) + " | 红门")
    for r in rows:
        cells = [cell(r["gates"].get(n)).replace("|", "\\|") for n in names]
        fail = [n for n in names if r["gates"].get(n, {}).get("status") == "FAIL"]
        print("%s | %s | %s | %s | %s" % (r["run"][:24], r["date"], r["prov"],
                                          " | ".join(c[:20] for c in cells),
                                          ",".join(fail) if fail else "OK"))
    print("trend.md ->", args.out)


if __name__ == "__main__":
    main()
