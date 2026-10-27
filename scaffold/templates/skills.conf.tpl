# skills.conf —— 项目技能清单（唯一权威）
# 装载：bash scaffold/install-skills.sh --project <项目根>
# 校验：bash scaffold/install-skills.sh --project <项目根> --check
# 说明：
#   [common]  公共技能库（skills 仓库任意一层含 SKILL.md 的目录）
#   [project] 项目自有技能（<项目根>/skills/<name>/SKILL.md）
# 行内 # 之后为注释；空行忽略。只登记本项目要用的，全量登记等于没登记。

[common]
router
iso
ai-code-review
architecture-support-brief
comment-policy
cpp-exemplars
error-code-classification
essential-tool-install
notion-diagram
report
review/incident-review
test-naming-and-structure

[project]
# 项目自有技能，按目录名登记，例如：
# rpc-architect

[agents]
# 角色定义：装载到 <项目根>/.claude/agents/<名字>.md，一行一个，源在 scaffold/agents/<名字>.md
# 装载：bash scaffold/install-agents.sh --project <项目根>
# 校验：bash scaffold/install-agents.sh --project <项目根> --check
# 角色规范正文不写进 agent 文件（双源必分叉），agent 文件只写身份、红线、工具白名单、开工先读哪几份文件、报告模板
qa
dev
