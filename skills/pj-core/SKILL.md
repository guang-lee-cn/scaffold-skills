---
name: pj-core
description: 通用工程协作流程核心（与工具/项目无关）。任何项目（Fast-DDS RPC / 嵌入式 / 应用软件）的"人机协作开发"流程骨架：Action Plan 门禁、心跳约定、批次管线、Git 提交规范、问题四分类与复盘、价值流、文档模板、WSL 桥接纪律、ISO 三阶段对接、行为约束（Iron Law）。当接替 agent 需要了解"如何与 G 协作、如何推进单元开发、如何归档文档、遵守哪些纪律"时使用。专用项目在其 skills/ 下提供 pj-config.md 与本 skill 对接。
触发词：协作/门禁/日报/复盘/问题/价值流/落盘/提交/归档/纪律/交接/接手/质疑/申诉。
---

# pj-core · 通用工程协作流程（跨项目不变层）

> 设计：**通用/专用分离**——本 skill 只含流程规则与模板骨架（项目无关）；项目特化内容（技术结论/命令/账号/白名单/里程碑）在项目 `skills/pj-config.md` 与项目专用 skill 中。
> 本 skill 可被豆包 / WorkBuddy / Codex / Claude Code 等任意 agent 工具读取（纯 Markdown + 标准脚本，无平台 API 依赖）。

## 0. 使用路由

| 需要 | 读取 |
|---|---|
| 协作流程（门禁/心跳/批次/清单） | `references/workflow.md` |
| Git 提交规范 | `references/commit.md` |
| 问题管理（四分类/L1-L2/复盘） | `references/issues.md` |
| 文档模板（日报/复盘/价值流） | `references/docs-templates.md` |
| 跨环境文件操作/命令执行（wsl2 / linux-desktop / ssh-remote 三分支） | `references/tool-bridge.md` |
| ISO 三阶段对接 | `pj-iso-bridge.md` |
| 协作质疑/申诉（执行角色质疑决策） | `references/dispute-flow.md` |
| 代码注释与设计文档分层（意图不进注释） | `references/code-docs.md` |

## 1. 核心原则（全局适用）

1. **单一问题渐进交互**：一次不同时推进两个以上问题（G 偏好）
2. **简短对话**：简明回答，避免冗长
3. **Action Plan 门禁**：实质操作前先列动作清单 + 操作内容 + 附带信息，G 确认后 agent 接管
4. **事实可追溯**：外部事实附来源；标注 [官方呈现]/[论坛总结]/[自己总结]/[不确认项]
5. **诚实披露**：无法做到时明确说明未完成项/原因/影响，不悄悄降级
6. **风险前置**：网络/权限/大文件等风险提前说明并给替代方案

## 2. 行为约束（Iron Law——措辞级红线）

> 本项目失误实证（日报偷懒 ×2 / 编译假绿 / 先修后记）全部源于**措辞先于证据**——以下为硬红线，违规即返工。

### 2.1 完成/成功声明（verification-before-completion 纪律）

- **无新鲜验证证据不许声称完成**：声称"测试通过"必须有本次运行的 0 失败输出；"构建成功"必须有 exit 0；"修复完成"必须有原症状复测通过；"已推送"必须有 git log 核实
- **禁用措辞**：should / probably / seems / 看起来 / 应该好了 / 应该能跑——一律先 RUN 再 claim
- 常见假绿对照（声明前自查）：

| 声明 | 必须证据 | 不充分 |
|---|---|---|
| 测试通过 | 本次测试命令输出 0 失败 | 上次跑过 / 应该能过 |
| 构建成功 | 构建命令 exit 0 | lint 通过 / 日志看着正常 |
| 修复完成 | 原症状用例复测通过 | 代码改了假设好了 |
| 已推送 | git log / 远端核实 | 本地提交过 |
| 任务完成 | VCS diff 逐项核对 | agent 自称成功 |

### 2.2 接收反馈（反表演式同意）

- 审查/评审反馈：**先实证核验再行动或反驳**——禁 "Great point!" / "你说得对!" / "完全正确!"——用技术验证：读代码/跑命令/查文档
- 反馈不清晰 → 先澄清再实施（部分理解 = 错误实施）
- 反驳要有技术理由（引用代码/测试/文档），不得情绪化

### 2.3 反合理化自查

出现以下任何借口即违规，必须停下重走流程：

| 借口 | 反驳 |
|---|---|
| "太简单不用测试" | 简单也会坏——测试 30 秒 |
| "测试后补一样" | 后补测试必绿——证明不了任何东西 |
| "我已经手动测过" | 手动无记录、无法重跑、易漏边界 |
| "先修再记" | 先修 = 丢失诊断证据（复盘断链） |
| "这次情况特殊" | 没有例外——除非 G 明确豁免 |
| "应该好了" | 证据，不是措辞——RUN 一次 |

## 3. 最小动作集（新项目接入 pj-core）

1. 拷贝本 skill（`pj-core/` 全目录）到团队 skills 根目录（与项目无关，仅一份）
2. 项目侧创建 `skills/pj-config.md`：填项目名/仓库/账号/路径/命令/白名单/里程碑
3. 项目专用 skill（如 `<project>-sop`）引用本 skill 流程规则 + `pj-config.md` 参数
4. 按 `pj-iso-bridge.md` 对接 ISO 三阶段
5. 验证：模拟"拷贝到新项目"，确认定制点只有 `pj-config.md`

## 4. 引用约定

- 专用 skill 中流程规则**不得重复本 skill 内容**，只写 `遵循 pj-core §<节>` 引用
- 项目参数从 `pj-config.md` 取值，不硬编码在 skill 中

## 5. 依赖声明（钩子机制）

- 本 skill 无必装外部依赖（独立完整）
- 调试方法论增强需 `superpowers:systematic-debugging` → **引用钩子**：首次使用时按 vendor/superpowers 指引读取（未 vendor 则 `git submodule update --init vendor/superpowers`（vendor 为 gitlink）或 `git clone https://github.com/obra/superpowers vendor/superpowers`）
- 任务级拆解需 `superpowers:writing-plans`（钩子同上）
- 依赖仅在首次使用时触发下载，落 vendor/ 后不再重复
