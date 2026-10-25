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

- 阶段判定不清 → 一次只问一个问题；没人可问时按现有证据选最保守的阶段，并把判断写进开发状态
- 多阶段同时出现 → 拆阶段逐个路由（不并行执行不同阶段 skill）
- 目标 skill 缺失 → 报告缺失，不静默降级

> **外部方法论参照**：`obra/superpowers` 未 vendor，也不在 catalog 内。自研等价物（iso / pj-core / test-naming-and-structure）已有实证，默认就用自研；只借鉴两条方法论——调试按 4-phase（复现 → 根因 → 假设 → 修复，禁 patch-symptom），测试按 RED → GREEN → REFACTOR 纪律。真要正式引入某个外部 skill，先登记 catalog 再改决策表，不做"半引入"。
