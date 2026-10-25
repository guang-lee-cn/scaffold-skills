#!/usr/bin/env python3
"""技能库自检 / catalog 生成。

用法：
    python3 scaffold/skill-lint.py           # 只检查，有错退出 1
    python3 scaffold/skill-lint.py --write   # 重新生成 skills/router/catalog.json

检查项：
    1. frontmatter：--- 包裹，含 name / description，description 单行且含「触发词：」
    2. catalog ↔ 目录一致：每个含 SKILL.md 的目录都在 catalog 里，反之亦然
    3. 相对链接可解析
    4. 内容完全相同的重复文件（警告）

不做的事：不校验措辞、不校验技能内容质量——那些靠评审。
"""
import hashlib
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS = os.path.join(REPO, "skills")
CATALOG = os.path.join(SKILLS, "router", "catalog.json")
SKIP_DIRS = {".git", "node_modules", "vendor"}


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for f in sorted(filenames):
            yield os.path.join(dirpath, f)


def parse_frontmatter(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fm = {}
    last_key = None
    folded = False
    for line in lines[1:]:
        if line.strip() == "---":
            return fm
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            last_key = m.group(1)
            value = m.group(2).strip()
            folded = value in (">", "|", ">-", "|-")
            fm[last_key] = "" if folded else value
        elif last_key and line.strip():
            # 续行：多行标量；折叠块（>）按空格展平成一行
            fm[last_key] = f"{fm[last_key]} {line.strip()}".strip()
    return None


def skill_dirs():
    out = []
    for path in walk(SKILLS):
        if os.path.basename(path) == "SKILL.md":
            out.append(os.path.dirname(path))
    return out


def rel(path):
    return os.path.relpath(path, SKILLS).replace(os.sep, "/")


def entry_for(dir_path):
    fm = parse_frontmatter(os.path.join(dir_path, "SKILL.md")) or {}
    name = fm.get("name") or os.path.basename(dir_path)
    desc = fm.get("description", "")
    parts = re.split(r"触发词：|触发：|Trigger phrases[:：]", desc, maxsplit=1)
    body = parts[0]
    trig = parts[1].rstrip("。. ") if len(parts) > 1 else ""
    third_party = rel(dir_path).startswith("agent-skills/")
    entry = {
        "name": name,
        "layer": "第三方" if third_party else "通用",
        "路径": rel(dir_path),
        "职责": body.strip().rstrip("。"),
        "触发词": trig,
    }
    return entry


def build_catalog():
    entries = [entry_for(d) for d in skill_dirs()]
    entries.sort(key=lambda e: (e["layer"] != "通用", e["name"]))
    return {
        "version": "0.3",
        "说明": "L0 Router 数据源，由 scaffold/skill-lint.py --write 生成，不要手改。"
                "本表与 skills/ 下所有含 SKILL.md 的目录一一对应；未登记 = 未启用。",
        "catalog": entries,
    }


def check_frontmatter():
    """返回 (errors, warnings)。

    硬错只有一类：frontmatter 缺失 / 缺 name / 缺 description——这会让技能装不上。
    其余（触发词、长度）只影响路由命中率，算警告，不拦。
    """
    errs, warns = [], []
    for d in skill_dirs():
        p = os.path.join(d, "SKILL.md")
        fm = parse_frontmatter(p)
        if fm is None:
            errs.append(f"{rel(p)}: frontmatter 缺失或未闭合")
            continue
        for key in ("name", "description"):
            if not fm.get(key):
                errs.append(f"{rel(p)}: frontmatter 缺 {key}")
        if rel(p).startswith("agent-skills/"):
            # 第三方包不改内容：只要求能被解析出 name / description
            continue
        desc = fm.get("description", "")
        if "触发" not in desc:
            warns.append(f"{rel(p)}: description 无触发词，只能按名调用")
        if len(desc) > 400:
            warns.append(f"{rel(p)}: description {len(desc)} 字，占用上下文偏多")
    return errs, warns


def check_catalog():
    errs = []
    expected = {e["name"]: e for e in (entry_for(d) for d in skill_dirs())}
    try:
        with open(CATALOG, encoding="utf-8") as fh:
            actual = {e["name"] for e in json.load(fh).get("catalog", [])}
    except FileNotFoundError:
        return [f"{rel(CATALOG)}: 不存在，先跑 --write"]
    except json.JSONDecodeError as exc:
        return [f"{rel(CATALOG)}: JSON 解析失败 {exc}"]
    for name in sorted(expected.keys() - actual):
        errs.append(f"catalog 缺条目: {name}（目录存在但未登记）")
    for name in sorted(actual - expected.keys()):
        errs.append(f"catalog 多条目: {name}（无对应 SKILL.md 目录）")
    return errs


LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def check_links():
    errs = []
    for path in walk(SKILLS):
        if not path.endswith(".md"):
            continue
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for target in LINK_RE.findall(text):
            target = target.split("#", 1)[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                errs.append(f"{rel(path)}: 断链 -> {target}")
    return errs


def find_duplicates():
    seen = {}
    warns = []
    for path in walk(SKILLS):
        if not path.endswith(".md"):
            continue
        with open(path, "rb") as fh:
            digest = hashlib.sha256(fh.read()).hexdigest()
        if digest in seen:
            warns.append(f"重复文件: {rel(path)} 与 {rel(seen[digest])}")
        else:
            seen[digest] = path
    return warns


def main():
    if "--write" in sys.argv:
        data = build_catalog()
        os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
        with open(CATALOG, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"已生成 {rel(CATALOG)}：{len(data['catalog'])} 条")
        return 0

    fm_errs, fm_warns = check_frontmatter()
    errs = fm_errs + check_catalog() + check_links()
    warns = fm_warns + find_duplicates()
    for w in warns:
        print(f"[警告] {w}")
    for e in errs:
        print(f"[错误] {e}")
    print(f"--- 技能 {len(skill_dirs())} 个 / 错误 {len(errs)} / 警告 {len(warns)}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
