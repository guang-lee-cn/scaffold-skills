# ros2 快速启动指导

> 目标：**任何 AI 环境**（Claude Code / ZCode / Cursor / Codex / 网页 ChatGPT 等）一键加载本目录技能，
> 让 AI 按纪律调试 ROS2/AMR 项目，而不是自由发挥。
> 技能仓库位置：`/home/guang/code/scaffold-skills/skills/ros2/`

## 目录结构

```
ros2/
├── QUICKSTART.md              ← 本文件（多环境启动指导）
└── ros2-amr-debug/
    └── SKILL.md               ← 核心：AI 协同调试纪律（证据分级/分层修复/红旗清单）
```

---

## 一、通用启动指令（复制粘贴即用，所有 AI 环境通吃）

### 方式 U1：粘贴引导词（网页 AI / 任何聊天框，最低成本）

把下面这段贴到对话开头：

```text
你将作为 ROS2/AMR 调试代理工作。必须先读取并严格遵守以下技能文件中的全部纪律：
/home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug/SKILL.md
（无文件读取能力时，我会把文件内容粘贴给你）
核心要求：结论必须标证据等级（铁证/推断/继承）；修改必须遵守责任分层；
每次改动写六元组日志；禁止为通过仿真环境而硬编码大脑代码。
```

若 AI 无法读本地文件，用方式 U2。

### 方式 U2：内联注入（无文件系统的 AI，一行命令生成粘贴包）

在 WSL 终端执行，把输出整段复制给 AI：

```bash
cat /home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug/SKILL.md | sed 's/^/    /'
```

### 方式 U3：项目级注入（推荐，对该项目所有 AI 会话永久生效）

把技能引用写进项目说明文件，Claude Code / Codex / 大多数 agent 都会自动读取：

```bash
cd /home/guang/code/ros2_ws/src/ros2_amr_framework
cat >> AGENTS.md <<'EOF'

## AI 调试纪律（强制）
调试任何问题前，先读取并遵守：
/home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug/SKILL.md
（CLAUDE.md 同步此条；无读取能力的环境由用户粘贴）
EOF
cp AGENTS.md CLAUDE.md 2>/dev/null || true
```

---

## 二、分环境专属启动

### Claude Code / ZCode（技能目录方式，可自动触发）

```bash
# 全局安装（所有项目可用）
mkdir -p ~/.claude/skills
ln -sfn /home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug ~/.claude/skills/ros2-amr-debug

# 或仅当前项目安装
cd /home/guang/code/ros2_ws/src/ros2_amr_framework
mkdir -p .claude/skills
ln -sfn /home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug .claude/skills/ros2-amr-debug
```

装完后新开会话即可自动触发；也可显式调用 `/ros2-amr-debug`。
**验证**：问 AI「你现在遵守什么调试纪律？」应能复述证据分级与责任分层规则。

### Cursor

```bash
cd /home/guang/code/ros2_ws/src/ros2_amr_framework
mkdir -p .cursor
cat > .cursor/rules/ros2-debug.mdc <<'EOF'
---
description: ROS2/AMR 调试纪律
alwaysApply: true
---
@/home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug/SKILL.md
EOF
```

或在对话中输入 `@/home/guang/code/scaffold-skills/skills/ros2/ros2-amr-debug/SKILL.md` 直接引用。

### Codex CLI / 其它读 AGENTS.md 的 agent

见方式 U3（AGENTS.md 已覆盖）。

### 网页 ChatGPT / DeepSeek / Gemini 等

方式 U2 生成粘贴包，作为对话第一条消息发送。

---

## 三、新会话自检清单（30 秒确认 AI 已就位）

1. 问：「你的结论分级有哪几级？」→ 应答：铁证/推断/继承
2. 问：「仿真传感器伪影该改哪层？」→ 应答：仿真资产层，禁止改大脑
3. 问：「改代码前必须先给什么？」→ 应答：可证伪预测 + 回滚方法

三问全对 → 开始工作；任一答错 → 重新注入技能文件。

## 四、技能演进规则

- 技能内容修改直接编辑 `SKILL.md`（软链/引用方式下所有环境同步生效）
- 每次实战中沉淀的新纪律（新坑、新工具、新红旗）→ 追加到 SKILL.md 对应章节并注明日期
- 新技能按 `ros2/<skill-name>/SKILL.md` 结构扩展，并在本文件登记启动方式
