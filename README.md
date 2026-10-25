# scaffold-skills

人机协作开发的公共资产库：一套**项目脚手架**（`scaffold/`）+ 一套 **AI Agent 技能库**（`skills/`）。两块都可以单独拿去用，按需部署到具体项目。

| 目录 | 作用 |
|---|---|
| [`scaffold/`](scaffold/README.md) | 项目无关的协作基座：协作 SOP、质量门禁采集与分析、文档模板、纪律类 policies；`bootstrap.sh` 5 分钟部署到新项目 |
| [`skills/`](skills/README.md) | AI 工作流技能库：可被 Claude Code 等 agent 直接加载的 `SKILL.md` 资产（SDLC、代码审查、事故复盘、研究、架构图等） |

## 目录结构

```text
scaffold-skills/
├── scaffold/                       # 项目脚手架（项目无关资产）
│   ├── bootstrap.sh                # 一键部署到新项目（只落骨架，不复制规范正文）
│   ├── install-skills.sh           # 技能装载器（按项目清单软链到 .claude/skills）
│   ├── skill-lint.py               # 技能库自检 + catalog 生成
│   ├── policies/                   # 门禁口径 / 泄漏归属 / git 规范 / 方案评审门禁 / 调研先行 / token 纪律
│   ├── quality/                    # run_gate.sh.tpl 门禁采集 + gates.conf.example + aggregate_quality.py 趋势分析
│   ├── sop/协作流程-通用版.md       # 执行形态 + 两层门禁 + 缺陷/偏离 + 项目结束复审
│   ├── templates/                  # 开发状态 / 问题台账 / 偏离记录 / 外部案例库 / QA 报告 / Dev 交接 / 复盘
│   └── skills/                     # skill 写作原则（供项目侧 skills/ 引用）
└── skills/                         # 技能库（唯一源）
    ├── sdlc/                       # SDLC 阶段工作流（R/S/A/I/V/D/P）
    ├── iso/                        # Heavy + Light ISO 工作流（install.sh 一键装）
    ├── pj-core/                    # 协作流程核心：Action Plan 门禁 / Iron Law / 复盘九段式
    ├── ai-code-review/             # 多角色代码审查流水线
    ├── router/                     # L0 阶段路由（catalog.json 确定性路由）
    ├── review/  ros2/              # 事故复盘纪律 / ROS2 AMR 调试纪律
    ├── research/                   # 深度研究框架 + 八问快研
    ├── notion-diagram/             # Notion 风多色分区架构图（SVG design token + 模板 + 渲染自检）
    ├── test-naming-and-structure/  # 测试命名与结构约束
    ├── comment-policy/             # 注释策略
    ├── error-code-classification/  # 错误码分类
    ├── essential-tool-install/     # 常用工具安装指引
    ├── agent-skills/               # 第三方：Addy Osmani agent-skills（MIT，统一 ad- 前缀）
    └── tools/                      # 辅助脚本（skill 同步、前缀批处理）
```

## 快速开始

**项目脚手架**（在新项目里）：

```bash
bash scaffold/bootstrap.sh <项目名>
```

然后填 `pj-config.md`（仓库/账号/里程碑）和 `quality/gates.conf`（项目自己的门禁命令），跑 `bash quality/run_gate.sh` 落第一个 gate JSON，再用 `python3 quality/aggregate_quality.py` 生成 `trend.md`。完整步骤见 [scaffold/README.md](scaffold/README.md)。

**技能库**：标准 skill 目录 `<组>/<skill-name>/SKILL.md`。装载走清单，不手工 symlink：

```bash
bash scaffold/install-skills.sh --project <项目根>            # 按 <项目根>/skills/skills.conf 装载
bash scaffold/install-skills.sh --project <项目根> --check    # 校验（清单 vs 实际链接）
python3 scaffold/skill-lint.py                               # 技能库自检（frontmatter / catalog / 断链 / 重复）
python3 scaffold/skill-lint.py --write                       # 重新生成 router/catalog.json
```

三种接入方式（原生 skill / 触发词 / 斜杠命令 + subagent）见 [skills/README.md](skills/README.md)。

## 演进原则

- **单一源**：技能本体只有 `skills/` 一份，流程规范只有 `scaffold/` 一份。项目里不放副本，只放清单与索引（`bootstrap.sh` 生成的 `docs/开发交付/工程流程.md` 就是索引，指向本仓路径）
- `scaffold/` 只装**项目无关**资产；项目特定参数（命令、仓库、里程碑）一律进 `pj-config.md` + `gates.conf`
- 门禁口径唯一、先 RUN 再 claim、实证定级（见 `scaffold/policies/`）
- 换一个项目还能用的 → 回流本仓库；只有本项目用的 → 留在项目内
- 与规范不一致但决定照做的 → 记进项目的偏离记录，项目结束复审时逐条裁决

## 第三方与许可

- 本仓库自有内容采用 MIT 协议，见 [LICENSE](LICENSE)
- `skills/agent-skills/` 为 [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) 的副本（MIT，© 2025 Addy Osmani），原 `LICENSE` 与归属信息保留在该目录内，技能名统一加 `ad-` 前缀以避免冲突
- 其余目录为自有资产

原独立技能仓库 `guang-lee-cn/skills` 已于 2026-10-25 并入本仓 `skills/`，此后只维护本仓一份。
