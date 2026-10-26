# skills —— 技能库

本仓库只存**方法**：流程编排、验收面纪律、产出格式、操作型事务清单。实现步骤与判断路径不进技能——理由与判据见 [scaffold/skills/skill-writing-principles.md](../scaffold/skills/skill-writing-principles.md)。

流程、政策、模板、门禁在 [scaffold/](../scaffold/)，那里才是判定性内容的家。

## 入口

先把 [router/](router/SKILL.md) 装上。它回答两件事：当前阶段该用哪个技能；架构师派活时必须把哪五样装进派发包（角色与边界 / 目标 / 验收判据 / 证据落点 / 必装技能）。没有这一层，角色信息只活在对话里，压缩一次就没了。

## 现有技能（12 个）

| 技能 | 管什么 |
|---|---|
| [router/](router/SKILL.md) | 阶段 → 技能路由；派发包五样；角色 → 必备技能表 |
| [iso/](iso/SKILL.md) | 项目从想法到交付：I/S/O 三阶段、重工程与轻原型两轨 |
| [ai-code-review/](ai-code-review/SKILL.md) | 多角色审查流水线：实现 AI + 2 审查 AI + 独立校验 |
| [review/incident-review/](review/incident-review/SKILL.md) | 事故复盘纪律（SRE × 中文复盘三源） |
| [architecture-support-brief/](architecture-support-brief/SKILL.md) | 评审答辩包：结论前置、可独立阅读 |
| [report/](report/SKILL.md) | 研究报告呈现层：可读、可落地、可追溯 |
| [test-naming-and-structure/](test-naming-and-structure/SKILL.md) | 用例命名（GWT）与结构（AA-FCP） |
| [comment-policy/](comment-policy/SKILL.md) | 注释四分类：留契约、迁决策、删复述、删治理 |
| [error-code-classification/](error-code-classification/SKILL.md) | 错误码两面判定：契约面 vs 观测面 |
| [cpp-exemplars/](cpp-exemplars/SKILL.md) | 成熟 C++ 项目真实片段，作编码对照 |
| [notion-diagram/](notion-diagram/SKILL.md) | 文档风格架构图（SVG） |
| [essential-tool-install/](essential-tool-install/SKILL.md) | 关键工具缺失时报给人装，不降级跳过 |

路由数据源：[router/catalog.json](router/catalog.json)，由 `python3 scaffold/skill-lint.py --write` 从各 `SKILL.md` 的 frontmatter 生成，**不要手改**。

## 接入（清单是唯一权威）

1. 编辑 `<项目>/skills/skills.conf`，在 `[common]` 登记技能名，`[project]` 登记项目自有技能
2. `bash scaffold/install-skills.sh --project <项目根>`
3. `... --check` 校验，`... --prune` 清断链，`--worktrees` 一并装进并行工作树，`--user` 装到 `~/.claude/skills`

手工 symlink 视为漂移，`--check` 会报。只登记项目要用的，全量登记等于没登记。

## 改完后自检

```bash
python3 scaffold/skill-lint.py            # frontmatter / catalog 一致性 / 死链 / 触发词冲突
python3 scaffold/skill-lint.py --write    # 重新生成 catalog.json
bash scaffold/install-skills.sh --project <项目根> --check
find ~/.claude/skills -maxdepth 1 -type l ! -exec test -e {} \; -print   # 应为空
```
