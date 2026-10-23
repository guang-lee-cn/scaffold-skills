---
name: test-naming-and-structure
description: 测试用例命名与结构规范。编写/评审测试时判定：用例名是否行为语义（GWT）、内部变量/helper 是否领域语义化、流程是否该抽函数（AA-FCP）、断言放哪。触发词：测试命名/用例命名/GWT/AA-FCP/Rule of Three/测试结构/helper/活文档。
---

# 测试用例命名与结构

## 术语对齐

中间件/库的"业务" = **框架外部可观察行为本身**。"业务化"命名 = 领域语义化：以外部行为命名（"未 ready 的请求必须回 UNSUPPORTED"），不是产品业务语言、更不是实现细节语言。命名基准 = 项目术语表（ubiquitous language）。

## 用例名（底线，单元/集成一视同仁）

GWT 三段式（Given-When-Then），以领域行为表达。

## 内部命名（integration 行为验证类用例）

流程按"场景叙述"组织；helper/变量按术语表命名（`owned_participant`/`late_reply`/`overloaded_server`）。

三限定：
1. 适用范围 = 行为验证类；设施验证类（交付性/平台/工具判据）保持技术命名。
2. **should 级不进门禁**——风格规范非缺陷判据，审核按"建议"标注。
3. **增量应用不一次性大重命名**——存量顺手改，不搞大规模 churn（git blame 污染）。

## 单元测试内部豁免

替身/注入（fake_clock/mock channel/畸形输入）本身是技术构造，强行业务化造作；豁免仅限**内部**命名，用例名仍须 GWT 行为语义。

## 流程 function 化（AA-FCP 边界）

| 边界 | 处置 | 理由 |
|---|---|---|
| Arrange（Given） | 复合构造（≥3 步）抽 `make_*`/`given_*` helper | 消除样板；Rule of Three 触发（≥3 用例重复才抽）；一行构造不抽（加跳转无收益） |
| Act（When） | 内联在 TEST 体内 | 触发行为被抽走后读用例需跨函数拼装"发生了什么"，活文档受损 |
| Assert（Then） | **红线：不进 helper** | 断言包进 helper：失败定位差、验证意图模糊（ad-test-engineer 反模式） |

附加规则：helper 无状态、输入全参数化（测试间不共享可变状态，隔离红线）；当前零重复不预先抽（YAGNI），用例上量后按需出现。
