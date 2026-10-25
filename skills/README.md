# skills —— AI 工作流技能仓库

## 当前结构（2026-10-03 重组织）

| 目录 | 层 | 说明 |
|---|---|---|
| [pj-core/](pj-core/) | 通用层 | 协作流程核心：Action Plan 门禁/行为约束（Iron Law）/问题四分类/复盘九段式/价值流/文档模板/WSL 桥接（**纯 Markdown 跨 agent 工具可用**） |
| [iso/](iso/) | 通用层 | Heavy+Light ISO 工作流（历史接入方式见下） |
| [ai-code-review/](ai-code-review/) | 通用层 | AI 多角色代码审查流水线（实现 AI + 2+ 审查 AI + 校验 Oracle + 工具审查 + 状态机） |
| [router/](router/) | 通用层 | L0 阶段路由（确定性 catalog 路由——参考 SWEStash skill-router 模式） |
| [sdlc/](sdlc/) | 通用层 | SDLC 分阶段卡片（A 架构 / S 规范 / 复核 / 决策记录） |
| [architecture-support-brief/](architecture-support-brief/) | 通用层 | 架构支撑包（不是架构主文档） |
| [agent-skills/](agent-skills/) | 第三方 | Addy Osmani 工程技能包（ad- 前缀，接入方式见下） |
| [research/](research/) | 历史 | 深度研究框架（复制粘贴到任意大模型） |
| [review/](review/) | 通用层 | incident-review 事故复盘纪律 |
| [ros2/](ros2/) | 通用层 | ros2-amr-debug 调试纪律 |

单技能目录（各有 `SKILL.md`）：`test-naming-and-structure/`、`comment-policy/`、`error-code-classification/`、`essential-tool-install/`、`notion-diagram/`。

### 新项目接入（装载器，不再手工 symlink）

1. `git clone git@github.com:guang-lee-cn/scaffold-skills.git`（或复用本地 `/home/guang/code/scaffold-skills`）
2. 项目用 scaffold 初始化后，编辑 `<项目>/skills/skills.conf`：按 `[common]` / `[agent]` / `[project]` 登记
3. `bash /home/guang/code/scaffold-skills/scaffold/install-skills.sh --project <项目根>`
4. 校验：`... --check`；清理漂移：`... --prune`
5. 项目参数仍写 `pj-config.md`，技能清单只写名字

三类技能一个入口：公共（本仓库）、第三方（`agent-skills/`）、项目自有（`<项目>/skills/`）。**清单是唯一权威**——手工 symlink 视为漂移，由 `--check` 报出。

本仓库位置移动后，重跑装载器即可；不再需要逐条重接。

三种接入 Claude 上下文的方式（原生 skill / CLAUDE.md 触发词 / 斜杠命令 + subagent persona）。装载器只负责原生 skill；命令与 persona 见下方 agent-skills 安装段。

## 目录与接入方式

| 组 | 内容 | 接入方式 | 触发 |
|----|------|---------|------|
| [ros2/](ros2/) | ros2-amr-debug 调试纪律 | **原生 skill**：symlink 到 `~/.claude/skills/` | `/ros2-amr-debug` 或 description 自动匹配 |
| [review/](review/) | incident-review 事故复盘纪律 | **原生 skill**：symlink 到 `~/.claude/skills/` | `/incident-review` 或触发词"复盘一下""写 postmortem"等 |
| [iso/](iso/) | Heavy + Light 两套 ISO 工作流模板 | **原生 skill**：symlink 到 `~/.claude/skills/` 与 `<项目>/.agents/skills/`（`iso/install.sh` 一键装，覆盖 10 个平台目录） | "开始 ISO""做架构""实现子系统""集成测试"（重构项目加"重构"二字） |
| [agent-skills/](agent-skills/) | 第三方工程技能包（Addy Osmani，25 技能 + 7 checklist，MIT）；**全部加 `ad-` 前缀** | **原生 skill + 命令**：symlink 到 `~/.claude/skills/ad-*`；命令 9 个、persona 4 个装到 `~/.claude/commands`、`~/.claude/agents` | `/ad-spec` `/ad-plan` `/ad-build` `/ad-test` `/ad-review` `/ad-ship` `/ad-constraints` `/ad-code-simplify` `/ad-webperf` |
| [research/](research/) | 深度研究框架 + 八问快研 | **无自动接入**：设计为复制粘贴到任意大模型 | 见 [quick-decision-research.md](research/quick-decision-research.md) 内嵌指令块 |

### 原生 skill（ros2 / review）

标准 Claude Code skill 结构：`<组>/<skill-name>/SKILL.md`（YAML frontmatter 带 name + description）。
优先用装载器登记到项目清单；确需用户级安装时：

```bash
bash /home/guang/code/scaffold-skills/scaffold/install-skills.sh --project <项目根> --user
```

手工 symlink 仅作兜底（随后应补进清单，否则 `--check` 会报漂移）。

多环境（网页 AI / 其他 IDE）加载见 [ros2/QUICKSTART.md](ros2/QUICKSTART.md)。

### CLAUDE.md 触发词（iso）

iso/ 不是原生 skill，靠 `/home/guang/CLAUDE.md` 的「ISO 工作流」一节指示 Claude 加载对应文件：

- "开始 ISO" → [iso/iso.md](iso/iso.md)（轻量模式 → [iso/light/](iso/light/)）
- "做架构" → [iso/strategy.md](iso/strategy.md)
- "实现子系统" → [iso/operations/cpp.md](iso/operations/cpp.md)
- "集成测试" → [iso/operations/integration.md](iso/operations/integration.md)

入口导读：[iso/STARTHERE.md](iso/STARTHERE.md)，速查：[iso/QUICKREF.txt](iso/QUICKREF.txt)。

### 第三方技能包（agent-skills/）

[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)（Addy Osmani，MIT）的镜像：25 个按开发生命周期组织的工程技能 + 7 个 checklist。

**⚠️ 与上游最大的差异：全包统一加 `ad-` 前缀**（Addy Osmani 首两字母 + 连字符）。原因：这个包的入口名极其通用——`spec`、`plan`、`build`、`test`、`review`、`ship`——极易与 harness 内置技能或本地技能撞名；`review` 已经实际撞上 Claude Code 内置的同名技能。**下划线不能用**：上游校验器强制 `/^[a-z0-9]+(-[a-z0-9]+)*$/`。

- **真身**：`agent-skills/`——上游 tarball + 下面的脚本化转换，**不再是逐字节原样**
- **技能**：25 条 symlink → `~/.claude/skills/ad-<name>`；目录名与 frontmatter `name:` 都已加前缀
- **checklist**：`~/.claude/references` symlink 到 `agent-skills/references`（技能正文用 `../../references/*.md`，从 `~/.claude/skills/ad-<name>/` 上溯两级正好落这里）
- **命令 9 个 + persona 4 个**：`~/.claude/commands/ad-*.md`、`~/.claude/agents/ad-*.md`（`ad-ship`、`ad-webperf` 靠 `subagent_type` 匹配 persona 的 `name` 字段，所以 persona 必须一起装）

**四处差异**（1、2 在真身内，3、4 在安装层）——**更新时会丢**，必须按「重新安装」重做：

| # | 差异 | 处数 | 原因 |
|---|------|------|------|
| 1 | 全包 `ad-` 前缀：技能目录 + `name:`、命令文件名、persona 文件名 + `name:`，以及正文里对这些名字的引用 | 38 项重命名 + 325 处引用 | 见上。**正文引用必须一起改**，否则正文里的 `/review` 会指向内置技能 |
| 2 | 校验器豁免表对前缀不敏感（`scripts/lib/skill-lint.js` 引入 `exemptKey`） | 2 处调用 | `SECTION_EXEMPT_SKILLS` 按技能名硬编码，改名后 `ad-idea-refine`/`ad-using-agent-skills` 会误报 7 个 section error |
| 3 | 剥掉 `agent-skills:` 命名空间前缀 | 命令+persona 共 12 处 | 那是**插件安装**的写法；个人技能安装下技能名是裸名，不剥则引用不到 |
| 4 | `references/*.md` 改绝对路径 | 2 处 | 相对路径会落到 `~/.claude/commands/references/`。**不能建软链**——`commands/` 的子目录会被当命令命名空间，凭空多出 7 个 `/references:xxx` |

**未加前缀的部分（有意保留上游原文）**：`README.md`、`docs/`、`AGENTS.md`、`evals/`、`scripts/` 其余部分，以及其它 harness 的入口 `commands/`（Antigravity）与 `.gemini/commands/`——我们只装 `.claude/` 那一套。

**重新安装（覆盖更新上游后执行）**

```bash
M=/home/guang/code/scaffold-skills/skills/agent-skills
OLD=$(ls "$M/skills")        # 转换前先记旧名，用于清理旧软链

# 1) 取上游（git clone 在本机易超时，用 tarball 更稳）
curl -sL -o /tmp/as.tar.gz https://codeload.github.com/addyosmani/agent-skills/tar.gz/refs/heads/main
rm -rf /tmp/as && mkdir /tmp/as && tar xzf /tmp/as.tar.gz -C /tmp/as
rm -rf "$M" && cp -r /tmp/as/agent-skills-main "$M"

# 2) 差异 1 + 2：加前缀 + 校验器豁免修复（幂等；脚本就在本仓库 tools/prefix-ad.py）
python3 /home/guang/code/scaffold-skills/skills/tools/prefix-ad.py "$M" --apply
(cd "$M" && node scripts/validate-skills.js | tail -1)   # 必须 PASSED，0 error 0 warning

# 3) 技能 + checklist 软链（先清旧名）
for n in $OLD; do [ -L ~/.claude/skills/$n ] && rm -f ~/.claude/skills/$n; done
for d in "$M"/skills/*; do ln -sfn "$d" ~/.claude/skills/$(basename "$d"); done
ln -sfn "$M/references" ~/.claude/references

# 4) 差异 3 + 4：命令与 persona（先清空，保证可重复执行）
mkdir -p ~/.claude/commands ~/.claude/agents
rm -f ~/.claude/commands/*.md ~/.claude/agents/*.md
for f in "$M"/.claude/commands/*.md; do sed 's/agent-skills://g' "$f" > ~/.claude/commands/$(basename "$f"); done
for f in "$M"/agents/*.md;          do sed 's/agent-skills://g' "$f" > ~/.claude/agents/$(basename "$f"); done
R="$M/references"
sed -i "s#references/orchestration-patterns.md#$R/orchestration-patterns.md#g" ~/.claude/commands/*.md ~/.claude/agents/*.md
sed -i "s#references/performance-checklist.md#$R/performance-checklist.md#g"   ~/.claude/commands/*.md ~/.claude/agents/*.md
```

> **判据**：第 2 步的校验器必须输出 `0 error(s), 0 warning(s) — PASSED`。它同时检查「`name` 是否等于目录名」和「跨技能引用是否死链」，是改名正确性最好的证明。脚本产物与真身曾用 `diff -r` 比对确认逐文件一致，且重复执行不产生 `ad-ad-`。

> 深度学习侧（DSH，即 DSH Web GUI）另有一份**真实拷贝**在 `ai-job-search/.agents/skills/`，同样带 `ad-` 前缀，且每个 `SKILL.md` 加了 `enabled: false`——否则该仓库的 `/scrape` 会把 25 个工程技能当招聘门户反复判 broken。那是副本、与本仓库无关，更新需另行重做。

## 自检（改仓库结构/搬目录后必跑）

```bash
# 1. 清单与链接一致（项目级）
bash /home/guang/code/scaffold-skills/scaffold/install-skills.sh --project <项目根> --check

# 2. 用户级无悬空 symlink
find ~/.claude/skills -maxdepth 1 -type l ! -exec test -e {} \; -print   # 输出应为空

# 3. CLAUDE.md 与 settings.json 无死路径
grep -rn "code/prompt" /home/guang/CLAUDE.md ~/.claude/settings.json  # 输出应为空
```

```bash
# 3. agent-skills 前缀与差异是否还在（丢差异的信号）
ls ~/.claude/skills   | grep -c '^ad-'   # 25
ls ~/.claude/commands | grep -c '^ad-'   # 9
ls ~/.claude/agents   | grep -c '^ad-'   # 4
grep -rl "agent-skills:" ~/.claude/commands ~/.claude/agents | wc -l    # 0
(cd /home/guang/code/scaffold-skills/skills/agent-skills && node scripts/validate-skills.js | tail -1)   # PASSED
```

```bash
# 4. iso skill（原生 skill 接线）
ls ~/.claude/skills/iso/SKILL.md          # 应存在
bash -n /home/guang/code/scaffold-skills/skills/iso/install.sh && echo "install.sh 语法 OK"
```

终极验证：新开会话，系统提示的可用 skills 列表里应出现 ros2-amr-debug 和 incident-review；说"开始 ISO"应能加载 iso/ 模板。

## 修改纪律

见 [iso/CLAUDE.md](iso/CLAUDE.md)「本项目开发约定」：小步执行、提交前公示、测试先行。
