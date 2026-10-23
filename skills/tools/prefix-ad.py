#!/usr/bin/env python3
"""给 agent-skills 镜像加 ad- 前缀（作者 Addy Osmani 首两字母 + 连字符）。

    python3 prefix-ad.py <agent-skills 根目录> [--apply]

做两件事：
  1. 名称加前缀：技能目录 + frontmatter name、命令文件名、persona 文件名 + name 字段，
     以及正文里对这些名字的引用（技能名 / persona 名 / /命令 引用）。
  2. 校验器豁免修复：SECTION_EXEMPT_SKILLS 按技能名硬编码，改名后
     ad-idea-refine / ad-using-agent-skills 会误报 section error，故引入前缀不敏感的查表。

默认 dry-run 只报告。--apply 才写盘。**幂等**：已带 ad- 前缀的名字会被跳过，
重复执行不会产生 ad-ad-。
"""
import re
import sys
import pathlib

root = pathlib.Path(sys.argv[1]).resolve()
apply = '--apply' in sys.argv
PREFIX = 'ad-'


def unprefixed(names):
    """跳过已加前缀的，保证幂等。"""
    return [n for n in names if not n.startswith(PREFIX)]


skill_dirs = sorted([d for d in (root / 'skills').iterdir() if d.is_dir()])
command_files = sorted((root / '.claude' / 'commands').glob('*.md'))
agent_files = sorted((root / 'agents').glob('*.md'))

skills = unprefixed([d.name for d in skill_dirs])
commands = unprefixed([p.stem for p in command_files])
agents = unprefixed([p.stem for p in agent_files])

content_files = (
    sorted((root / 'skills').glob('*/SKILL.md'))
    + command_files
    + agent_files
    + sorted((root / 'references').glob('*.md'))
)

# 技能名 / persona：两侧都不能是单词字符或连字符
def name_re(n):
    return re.compile(rf'(?<![\w-]){re.escape(n)}(?![\w-])')


# 命令：斜杠前不能是路径字符（挡住 tasks/plan.md）；名字后不能是 . 或 /（挡住 test.ts）
def cmd_re(c):
    return re.compile(rf'(?<![\w./-])/{re.escape(c)}(?![\w./-])')


cmd_hits = []
counts = {'skill': 0, 'cmd': 0, 'agent': 0}
changed = []

for f in content_files:
    text = orig = f.read_text(encoding='utf-8')
    for n in skills:
        text, k = name_re(n).subn(PREFIX + n, text)
        counts['skill'] += k
    for p in agents:
        text, k = name_re(p).subn(PREFIX + p, text)
        counts['agent'] += k
    for c in commands:
        for m in cmd_re(c).finditer(text):
            line = text[:m.start()].count('\n') + 1
            cmd_hits.append((f.relative_to(root), line, c,
                             text.splitlines()[line - 1].strip()[:110]))
        text, k = cmd_re(c).subn('/' + PREFIX + c, text)
        counts['cmd'] += k
    if text != orig:
        changed.append(f.relative_to(root))
        if apply:
            f.write_text(text, encoding='utf-8')

renames = []
for d in skill_dirs:
    if d.name.startswith(PREFIX):
        continue
    renames.append((d, d.parent / (PREFIX + d.name)))
for p in command_files + agent_files:
    if p.stem.startswith(PREFIX):
        continue
    renames.append((p, p.parent / (PREFIX + p.name)))
if apply:
    for old, new in renames:
        if new.exists():
            sys.exit(f"目标已存在，中止：{new}")
        old.rename(new)


def patch_validator(r):
    f = r / 'scripts' / 'lib' / 'skill-lint.js'
    if not f.is_file():
        return 'not-found'
    t = f.read_text(encoding='utf-8')
    if 'exemptKey' in t:
        return 'already'
    marker = "// Regex patterns that indicate an explicit cross-skill reference."
    if marker not in t:
        return 'marker-missing'
    helper = (
        "// Local vendor note: this mirror installs every skill under an `ad-` prefix\n"
        "// (see the repo README, section 第三方技能包), so exemption lookups tolerate\n"
        "// that prefix instead of hardcoding the renamed keys twice.\n"
        "const exemptKey = (name) =>\n"
        "  (Object.hasOwn(SECTION_EXEMPT_SKILLS, name) ? name : name.replace(/^ad-/, ''));\n\n"
    )
    t = t.replace(marker, helper + marker, 1)
    usage = "Object.hasOwn(SECTION_EXEMPT_SKILLS, dirName)"
    if t.count(usage) != 2:
        return f'unexpected-usage-count:{t.count(usage)}'
    t = t.replace(usage, "Object.hasOwn(SECTION_EXEMPT_SKILLS, exemptKey(dirName))")
    if apply:
        f.write_text(t, encoding='utf-8')
    return 'patched'


print(f"根目录: {root}")
print(f"模式: {'APPLY' if apply else 'DRY-RUN'}")
print(f"内容改写: 技能名 {counts['skill']} / persona {counts['agent']} / 命令 {counts['cmd']} 处")
print(f"改动文件: {len(changed)} 个 / 重命名: {len(renames)} 项")
print(f"校验器豁免修复: {patch_validator(root)}")
if cmd_hits:
    print("\n=== 命令替换点（逐条核对，防止误伤路径）===")
    for rel, line, c, ctx in cmd_hits:
        print(f"  {rel}:{line}  /{c}  →  {ctx}")
