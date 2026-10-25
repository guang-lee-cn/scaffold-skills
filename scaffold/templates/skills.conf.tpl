# skills.conf —— 项目技能清单（唯一权威）
# 装载：bash scaffold/install-skills.sh --project <项目根>
# 校验：bash scaffold/install-skills.sh --project <项目根> --check
# 说明：
#   [common]  公共技能库（skills 仓库任意一层含 SKILL.md 的目录）
#   [agent]   第三方 agent-skills（ad- 前缀）
#   [project] 项目自有技能（<项目根>/skills/<name>/SKILL.md）
# 行内 # 之后为注释；空行忽略。

[common]
iso
pj-core
router
sdlc
ai-code-review
architecture-support-brief
test-naming-and-structure
comment-policy
error-code-classification
essential-tool-install
notion-diagram

[agent]
ad-documentation-and-adrs
ad-planning-and-task-breakdown
ad-test-driven-development
ad-code-review-and-quality
ad-incremental-implementation
ad-source-driven-development
ad-spec-driven-development

[project]
# 项目自有技能，按目录名登记，例如：
# rpc-architect
