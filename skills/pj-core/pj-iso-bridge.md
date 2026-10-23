# pj-iso-bridge.md · ISO 三阶段对接（通用）

> 对接 G 的 ISO 规范（iso skill：同 skills 根时 `../iso/iso.md`；分离部署时路径见项目 `pj-config.md` 通用层路径），适用于 Heavy 轨道（底层工程）。

## 流程

**Insight → Strategy → Operation 回填门禁**：每阶段产出 → 对话 Y/N 确认 → 才进下阶段。

| 阶段 | 产出 | 门禁 |
|---|---|---|
| Insight | 摸底/调研/选型（insight.md 活文档） | 事实核验 + G 确认 |
| Strategy | 方案/架构/契约（`[项目名]-strategy.md` 活文档） | 方案评审（ADR ≥3，每条 ≥2 备选）|
| Operation | 实现纪律（operations.md 活文档）+ 契约 vN | 本地验证 + 远端 CI + G 验收 |

## 强制产出（固定名活文档）

- `<项目>/docs/iso/insight.md`、`[项目名]-strategy.md`、`operations.md`（固定名不加日期戳，修订记版本节）
- `<项目>/docs/contracts/`（契约 vN：接口/语义/版本）
- ADR ≥3（每条 ≥2 备选方案）

## 实现纪律（operations）

- TDD-GWT（`TEST_F(ClassName, Given_When_Then)`）
- 无裸 new/delete、静态扫描零警告、实现类 final + 析构两族（接口族 protected、值类型族 public virtual）
- 上下文隔离：实现阶段只引本子系统契约+设计文档；外部参考收敛为图谱/ADR
- 回滚：冲突→偏差分析→回退修订，不就地打补丁
- 发布回退策略：制品先回退止血→main 回退上一绿提交、故障留 dev 供根因→可快速定位走 hotfix 前向修复→限时无法定位才进一步回退

## 适配层纪律（契约扩展）

- 契约面（官方/对外接口）零改动，扩展走适配层（基类+继承或窄接口组合）
- 接口管理第一优先级=**高内聚低耦合**；物理约束（≤9 方法/≤5 成员）= 设计评审触发点而非硬上限
