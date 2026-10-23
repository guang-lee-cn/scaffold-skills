---
name: router
description: L0 技能路由调度。当需要决定"当前阶段该用哪个 skill"、接手项目、切换工作阶段、多 skill 协作编排时使用。触发词：路由/调度/该用什么skill/阶段决策/接手项目/编排。本 skill 是纯决策薄件——读 catalog 后按阶段决策表调用目标 skill。
---

# L0 Router · 阶段路由决策表（v0.2）

> 设计：确定性路由（参考 SWEStash skill-router 模式——不依赖 description 概率触发）。catalog.json = 全量技能目录（唯一数据源）；决策表 = 阶段→skill 映射；AI 按名调用目标 skill。
> 豆包化：无 hooks/skillOverrides——本文件即决策依据，AI 读到后按表路由。

## 1. 使用方式（3 步）

1. 读 `catalog.json`（全量技能目录——名称/职责/触发词/依赖）
2. 判定当前工作阶段（见决策表"判定"列）
3. 按表调用目标 skill（先读其 SKILL.md 再执行）

> **两轴定位**：先判**阶段**（本表）→ 再看**来源**（自研 / `vendor/`）与**领域**（`domains/`）。
> 三轴交叉处才是一个具体技能入口。

## 2. 阶段 → skill 决策表

| 阶段 | 判定（用户说了什么） | 主 skill | 辅助/记录 |
|---|---|---|---|
| **规范对齐** | 对齐标准规范/核义务/查 `shall`/合规点/规范与方案比对 | **sdlc/S**（S1 身份 → S2 架构 → S3 shall 清单 → S4 工作包 → S5 差异矩阵） | pj-core（证据分级） |
| 启动/需求 | 项目启动/分析需求/想清楚要做什么 | iso（Insight） | pj-core（协作协议） |
| 架构 | 做架构/设计接口/拆子系统/选型 | iso（Strategy） | — |
| 计划 | 多步骤任务/拆分计划 | **iso（Insight/Strategy 拆解）** | pj-core（协作协议） |
| 实现 | 写代码/子系统实现 | iso（operations/cpp）+ **test-naming-and-structure（TDD/GWT 用例规范）** | pj-core（单元记录） |
| 集成 | 集成测试/E2E/准备上线 | iso（operations/integration） | — |
| 调试 | 故障/异常/复现/死锁/泄漏 | **pj-core issues（九段式记录 + Oracle）** | — |
| 审查 | 代码审查/对弈复核/审查收口 | ai-code-review | pj-core（问题台账） |
| 完成/合并 | 声称完成/提交/合并/发布 | pj-core（行为约束 + 完成验证） | pj-core（提交纪律双通道） |
| 复盘 | 复盘/问题归档/改进措施 | pj-core issues（九段式） | — |
| 记录 | 落盘/日报/单元记录 | pj-core（record） | — |
| 交接 | 接手项目/换环境/换 agent | pj-core + 项目 README + pj-config.md | — |

## 3. 依赖钩子

- 所有目标 skill 均为按需加载：先读目标 SKILL.md → 缺失时按该 skill 的依赖声明下载
- 本 router 不 vendor 任何目标 skill 内容（薄件原则）

## 4. 路由纪律

- 阶段判定不清 → 问 G（单一问题渐进，一次一个问题）
- 多阶段同时出现 → 拆阶段逐个路由（不并行执行不同阶段 skill）
- 目标 skill 缺失 → 报告缺失 + 给出下载钩子，不静默降级

> **可选 vendor 标注（2026-10-22 收敛期）**：`superpowers:*`（writing-plans / TDD / systematic-debugging / verification-before-completion / finishing-a-development-branch）保留在 catalog 为**可选 vendor（默认未启用）**——如启用按需下载 obra/superpowers 对应子集并登记 catalog 后替换本表对应主列；**决策表默认引自研等价物**（iso / pj-core / test-naming-and-structure），避免双重体系选择负担。

> **有效性评估（2026-10-22，证据：obra/superpowers 公开结构 + 本仓自研 skill 实战实证）——分场景判定，非二选一**：
> | 等价物对 | 自研（本项目实证） | superpowers（外部经典） | 判定 |
> |---|---|---|---|
> | 调试 | pj-core issues 九段式（记录+Oracle，MTComm 实战） | systematic-debugging 4-phase（复现→根因→假设→修复，防 patch-symptom） | **借鉴 4-phase 方法论**（补自研短板），九段式记录保留 |
> | TDD | test-naming + gtest 门禁（39/39、覆盖 98.6% 实证） | 强制 RED→GREEN→REFACTOR，禁 code-before-tests | 约束等效且自研已实证 → **借鉴 RED-GREEN 纪律表述**，体系保持 |
> | 计划 | 里程碑+指令 DoD（团队节奏，300-600 行/批） | writing-plans 原子任务化（2-5 分钟，单 agent 长跑） | 场景不同 → 保持自研 |
> | 完成验证 | pj-core 门禁套件+双通道评审+G 批准 | verification-before-completion | 自研更完整（含评审/门禁）→ 保持 |
> **结论**：自研体系与 SOP/门禁/四角色深度绑定且已实证，保持为默认；superpowers 作**方法论参照源**，仅裁用 systematic-debugging 4-phase 与 TDD RED-GREEN 纪律（轻量思想借鉴，不整体引入——符合"轻量按需裁用"原则）。
