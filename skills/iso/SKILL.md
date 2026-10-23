---
name: iso
version: 1.0.0
description: >
  引导项目从想法走到代码的分层工作流（Insight → Strategy → Operation），分 Heavy 与 Light 两条轨道。
  Heavy 适用于大中型 C++ 底层工程：强制四层架构、四类架构图、ADR、接口契约、TDD-GWT、上下文隔离；
  Light 适用于原型 / 小工具 / 业务系统：非线性、可跳转、规模自适应、语言无关。
  两条轨道都带阶段门禁、强制文件产出、回滚机制与违规自检。
  触发：开始 ISO、ISO 工作流、分析需求、项目启动、想清楚要做什么、做架构、设计架构、设计接口、拆分子系统、
  实现子系统、写代码、落地开发、集成测试、端到端测试、E2E、准备上线、重构已有项目、改造现有系统、迁移旧系统。
  Trigger phrases: start ISO, ISO workflow, analyze requirements, design architecture,
  define interfaces, split subsystems, implement subsystem, integration test, refactor existing project.
  不适用于：ISO 9001 / ISO 27001 等管理标准认证，ISO 镜像 / 光盘映像文件——这些与"ISO 方法论"无关，遇到时不要加载本技能。
---

# ISO 分层工作流

把"想清楚 → 设计好 → 做出来 → 验到位"拆成有门禁的阶段，每个阶段的产出**落成文件**而不是留在对话里。
它解决的是一个具体问题：**长项目、多会话、多子 agent 时，上下文会丢、阶段会被跳、决策会失去理由。**

## 何时使用

| 用 | 不用 |
|---|---|
| 从零开始的中大型工程（尤其 C++ 底层/嵌入式/多进程多子系统） | 改一行、修个 bug、回答一个问题 |
| 已有系统重构（换通信层、换数据库、架构腐化重来） | 给健康项目加个小功能（直接做即可） |
| 需要完整架构文档与决策记录的交付 | 一次性脚本、临时验证 |
| 多个子系统要并行实现、需要靠契约解耦 | 单人单文件的小改动 |

**触发"重构模式"**：在任何触发词前加"重构"二字（如"重构 + 开始 ISO"）。重构模式在每个阶段正文前插入该阶段的"重构前置"检查，核心区别是**起点不是空白画布，现有系统是最大约束**。

## 第一步：选轨道（不要替用户默认）

**AI 必须先问**："这是重型底层工程，还是轻量项目？" 用户说"轻量/原型/小工具/脚本"就直接进 Light。

| | Heavy | Light |
|---|---|---|
| 适用 | 大中型 C++ 底层工程 | 原型 / 小工具 / 业务系统 |
| 入口 | 本文件 → `iso.md` | 本文件 → `light/CLAUDE.md` |
| 流程 | 线性串行，门禁不可跳 | 非线性，可跳转，规模自适应 |
| 图表 | 4 类强制图 + 五色规范 | 仅业务系统需 1 张架构图 |
| 决策记录 | 至少 3 条 ADR，每条含 ≥2 备选方案对比 | 仅记关键取舍，不限格式 |
| 产出 | 全套 md 强制 | 原型只出代码 |

**不建议混用**：Heavy 的接口契约格式 Light 没定义，混用会断链。

## 阶段 → 文件路由

阶段文件**按需加载，不要一次全读**（渐进披露）。

| 用户说 | 加载 | 门禁通过后必须产出 |
|---|---|---|
| 开始 ISO / 分析需求 / 项目启动 | `iso.md` | `docs/iso-output.md` |
| 做架构 / 设计接口 / 拆分子系统 | `strategy.md` | `design/[项目名]-strategy.md` + `contracts/` |
| 实现子系统 X / 写代码 | `operations/cpp.md` | `docs/design/sub-{name}.md` + 源代码 |
| 集成测试 / E2E / 准备上线 | `operations/integration.md` | `docs/test/integration-plan.md` + `integration-report.md` |
| （Light）任意阶段 | `light/CLAUDE.md` → `discover/design/implement/deliver.md` | 按规模：原型不写文件，工具写 README，系统写 `docs/` |
| 重构项目 | 上述文件各自的"重构前置"章节 | 同左，另加迁移/回退方案 |
| 深度研究 X 的原理 | `../research/technical-research-framework.md` | 研究笔记 |

**主/子 agent 分工**：主 agent 走 `iso.md` → `strategy.md`，产出接口契约与子系统边界后，**并行**拉起子 agent 各自执行 `operations/cpp.md`（每个子 agent 只拿自己子系统的契约）；全部完成后由主 agent 执行 `operations/integration.md`。

## 四条不变量（任何阶段、任何模式都不得违反）

1. **门禁串行**：每个阶段产出 → 用户 `(Y/N)` 确认 → 才进下一阶段。**未经确认不得继续**，也**不得替用户回答**。
2. **产出必须落文件**：门禁通过后写盘，不得只留在聊天记录。上游文件是下游的唯一输入——不写文件就是**断链**。
3. **上下文隔离**：子系统实现阶段**只**允许引用三样东西——该阶段的铁律、本子系统的接口契约、本子系统的设计文档。**禁止引用全局需求描述与全局 ADR**（防止子 agent 被无关信息带偏）。Light 版同理。
4. **决策必须可追溯**：每个关键决策要能回答"解决了什么业务问题"，并留下备选方案与代价。说不出理由的决策 = 未完成的决策。

## 卡住了怎么办

- **回滚**：发现下游与上游假设冲突（如设计推翻战略、实现推翻契约）→ **暂停**，输出"偏差分析"，请求回退到对应阶段修订，而不是就地打补丁。各阶段文件末尾都写了具体的回滚触发条件。
- **ABORT**：`iso.md` 阶段如果问出来"不做也没什么影响"，必须明确告知用户**业务驱动力可能不充分，建议暂停**，而不是继续走流程。
- **契约歧义**：子 agent 不得自行修改接口契约，必须上报主 agent 修订后再下发。

## 常见借口与反驳（出现即违规）

| 常见借口 | 反驳 |
|---|---|
| "需求很明显，跳过 Insight 直接设计" | 跳过的代价在后期以返工支付。ISO 的铁律 1 就是禁止跳阶段。 |
| "先写代码，文档最后补" | 文档是阶段间的**交接面**。补写 = 让下游在错误的输入上工作。 |
| "这条决策显而易见，不用写备选方案" | 没有备选方案的决策无法被复核，也无法在出问题时回滚。至少写 2 个选项。 |
| "子 agent 需要全局背景才能干好" | 那是把上下文污染当效率。契约就是为此设计的边界。 |
| "测试失败但影响不大，先上线" | `integration.md` 铁律 3：失败即阻塞，未定位根因不得进入下一阶段。 |
| "用户没回答，我先按默认往下走" | 门禁未通过就是未通过。可以给建议，不能替用户确认。 |

## 校验：进入下一阶段前自检

- [ ] 本阶段的门禁问题**已得到用户明确的 Y/N**（不是"看起来同意了"）
- [ ] 本阶段要求的文件**已写入磁盘**，且路径与上表一致
- [ ] 上游产出的约束**被显式引用**（而不是凭记忆）
- [ ] `strategy.md`：四类强制图齐全 + 数据流转图用了五色规范 + ≥3 条 ADR（每条 ≥2 备选）+ 基础层/公共设施/关键路径有"自研 vs 开源"专项决策
- [ ] `operations/cpp.md`：测试先于实现 + 命名 `TEST_F(ClassName, Given_When_Then)` + 无裸 `new/delete` + 静态扫描零警告
- [ ] 未用"正交/耦合"**充当结论**，而是给出具体判据（谁会和谁一起改、为什么）
- [ ] 遇到冲突已走回滚流程，而不是就地打补丁

## 文件地图

```
iso/
├── SKILL.md                 ← 本文件（入口与路由）
├── STARTHERE.md             ← 给人看的上手指南
├── QUICKREF.txt             ← 触发词速查表
├── iso.md                   ← Heavy: 战略洞察（Insight/Strategy/Operation）
├── strategy.md              ← Heavy: 架构设计 + 接口契约 + 迭代计划
├── operations/
│   ├── cpp.md               ← Heavy: C++ 子系统实现（TDD-GWT）
│   └── integration.md       ← Heavy: 集成测试与交付
├── references/
│   ├── thinking.md          ← 构造性阶梯法则（跨阶段推理方法）
│   ├── diagram-spec.md      ← 架构图格式规范（分层/五色/Mermaid 规避规则）
│   ├── oss-adoption.md      ← 基础层选型手册（自研 vs 开源 vs 复用）
│   ├── quality-gates.md     ← 质量门禁协议（能力契约 / 四态判定 / 降级记账）
│   └── cpp-idioms.md        ← C++ 语言设施对照（STL 替代 / 模板 / 注释 / 单一职责）
├── light/                   ← Light 全套（discover → design → implement → deliver + lang/ 速查卡）
└── install.sh               ← 多平台安装脚本
```

## 依赖声明（钩子机制）

- 本 skill 无必装外部依赖（独立完整）
- 任务级拆解（多步骤实现计划）需 `superpowers:writing-plans` → **引用钩子**：首次使用时按 vendor/superpowers 指引读取（未 vendor 则 `git submodule update --init vendor/superpowers`（vendor 为 gitlink）或 `git clone https://github.com/obra/superpowers vendor/superpowers`）
- TDD 流程纪律需 `superpowers:test-driven-development`（钩子同上）
