# agent-skills 适用性评估（针对 dts-framework / ros2_amr_framework）

> 对象：[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) 的 25 个技能（本仓库内已统一加 `ad-` 前缀）
> 方法：对 25 个 `SKILL.md` 正文做**词边界匹配**的生态词扫描 + 人工判读
> 位置说明：本文放在 `agent-skills/` 的**上一级**，因为 README 的重新安装流程第 1 步是
> `rm -rf "$M" && cp -r ...`，**放在镜像目录内的自建文件会在下次更新时被静默删除**。

## 一句话结论

25 个技能里 **0 个含 C++ / CMake / GoogleTest / ROS2 / DDS 语境**——这套东西是写给 **Web / JS / 服务端**技术栈的。
但是它们是**流程技能**（步骤 + 验证门 + 反合理化表），**流程语言无关，偏的是示例与工具命令**。
所以：**可以用，但要预期把示例和命令整体换掉。**

## 扫描证据（词边界匹配，已排除子串误命中）

| 词 | 出现次数 | 词 | 出现次数 |
|---|---|---|---|
| `c++` / `cpp` | **0** | `cmake` / `makefile` | **0** / 1 |
| `gtest` / `ctest` | **0** | `gcc` / `clang` | **0** |
| `ros` / `dds` | **0** | `posix` / `pthread` / `futex` / `epoll` | **0** |
| `malloc` / `mutex` / `valgrind` / `asan` | **0** | `shared memory` / `lock-free` | **0** |

**⚠️ 不要用不带词边界的计数**——本次扫描踩过的坑，记录下来免得重复：

| 假命中 | 真相 |
|---|---|
| `ros×18`（doubt-driven-development） | 来自 "ac**ros**s"、"err**ors**" |
| `elf×5` | 来自 "s**elf**" |
| `dds×4` | 来自 "a**dds**" |
| `slam` | 来自销售文案 "grand-**slam** offer" |
| `thread` / `kernel` / `embedded` | 分别指**对话线程** / **知识内核** / **嵌入式提示**，不是系统编程 |

即：**先看命中的是哪个词、出现在什么语境，再下判断**；标量评分和裸计数都会骗人。

## A 档 · 直接可用（几乎不含 Web 语境）

| 技能 | 行数 | 对你的具体价值 |
|---|---|---|
| `ad-doubt-driven-development` | 243 | **唯一零 Web 词的实质技能**。对抗式复查每个非平凡决策——"抄了 SHM 的返回值、没抄它的语义"正是它要拦的那类决策 |
| `ad-planning-and-task-breakdown` | 257 | 零 Web 词，纯任务分解与验收标准 |
| `ad-using-agent-skills` | 192 | 零 Web 词：技能路由 |
| `ad-idea-refine` | 178 | 零 Web 词：需求发散/收敛 |
| `ad-code-review-and-quality` | 396 | 五轴评审、变更约 100 行、Nit/Optional/FYI 分级——语言无关 |
| `ad-code-simplification` | 331 | Chesterton's Fence、Rule of 500 |
| `ad-git-workflow-and-versioning` | 355 | trunk-based、原子提交、提交即存档点 |
| `ad-debugging-and-error-recovery` | 300 | 复现→定位→缩小→修复→护栏。**dts 的 OOM 事故就是这个流程的现成范例**（但示例是 npm/browser） |
| `ad-documentation-and-adrs` | 288 | ADR 模板 → `TransportInterface` 这类决策正该写 ADR，也是面试素材 |

## B 档 · 流程可用，工具链整体替换

| 技能 | Web 词 | 怎么改 |
|---|---|---|
| `ad-source-driven-development` | 26（react×15） | ⭐ **最该用的一个**：实现决策以官方文档为准、引用来源、标注未验证。**OOM 根因就是没核对 FastDDS 里那个返回值的语义**。换成 cppreference / FastDDS / ROS2 官方文档 |
| `ad-constraint-driven-development` | 24（npm×8、lighthouse×6） | ⭐ 质量门写成 `CONSTRAINTS.md`，**防 agent 把检查改绿**（删测试、加抑制、调低阈值）。文中工具 Semgrep/gitleaks/osv-scanner/Stryker → 映射到 clang-tidy / cppcheck / gitleaks / CTest。你有 78.8% 覆盖率 + CI，正对症 |
| `ad-test-driven-development` | 31（typescript×10、browser×7） | 红绿重构、测试金字塔 80/15/5、DAMP、Beyonce Rule 可迁移；**但 `references/testing-patterns.md` 整份是 Jest/RTL/Playwright**（技能自己写了 "principles transfer, syntax is JS/TS-specific"）→ 换成 GoogleTest + gcov + ctest |
| `ad-ci-cd-and-automation` | 37（**npm×24**、playwright×4、vercel×3） | Shift Left / 质量门 / 失败反馈可用；workflow 示例要按 CMake + colcon + ctest 重写 |
| `ad-api-and-interface-design` | 15（typescript×13） | Hyrum's Law、One-Version Rule、错误语义、边界校验 → **正对 `TransportInterface` 的契约问题** |
| `ad-observability-and-instrumentation` | 9 | 结构化日志/RED 指标/症状告警偏服务端；C++ 系统软件要补 **perf/ftrace、日志开销与采样率** |
| `ad-security-and-hardening` | 24（typescript×12、html×4） | OWASP Top 10 是 Web 的；可用的是密钥管理、依赖审计、边界校验 |
| `ad-spec-driven-development` | 5 | 几乎中立，直接可用（写规格再动手） |
| `ad-interview-me` | 2 | 一次一问挖真实需求 |
| `ad-incremental-implementation` | 3 | 薄切片可用；feature flag 那部分对中间件不适用 |
| `ad-deprecation-and-migration` | 2 | expand/contract 的 DB 迁移不适用；C++ API 演进（给 `TransportInterface` 加接口）可迁移 |
| `ad-shipping-and-launch` | 9 | 中间件库没有"上线"；AMR **上机器人**时才用（分级发布/回滚） |
| `ad-context-engineering` | 16（graphql×5） | rules 文件/MCP/上下文打包；用 Claude Code 时有点用，内容偏 Web 栈 |

## C 档 · 别装

| 技能 | 为什么 |
|---|---|
| `ad-browser-testing-with-devtools` | `browser×28`，还依赖 Chrome DevTools MCP |
| `ad-frontend-ui-engineering` | Web UI（React/CSS/Storybook） |
| `ad-performance-optimization` | ⚠️ **名字最骗人**：内容是 `bundle×9`、`lighthouse×4`、**Core Web Vitals**。950 raw/s 瓶颈链、perf 火焰图、valgrind 它**一个字都没有** |

## 两个项目的最小集

**dts-framework（C++17 中间件）**

1. `ad-source-driven-development` —— 治"没核对 FastDDS 语义"这个已发生的坑
2. `ad-constraint-driven-development` —— 用 `CONSTRAINTS.md` + 你的 clang-tidy/cppcheck/gcov/CI 防检查被改绿
3. `ad-test-driven-development` —— 配 GoogleTest/ctest（替换 JS 示例）
4. `ad-doubt-driven-development` —— 零 Web 词，对抗式复查非平凡决策
5. `ad-documentation-and-adrs` —— ADR 记录 `TransportInterface` 这类决策
6. `ad-api-and-interface-design` —— contract-first → 接口契约

**ros2_amr_framework（ROS2 / AMR）**

1. `ad-debugging-and-error-recovery` —— 仿真联调阶段的定位纪律
2. `ad-test-driven-development` —— A*/EKF/Pure Pursuit/DBSCAN 的确定性单测（假时钟、假地图、假输入）
3. `ad-incremental-implementation` —— 四层链路薄切片推进
4. `ad-code-review-and-quality` —— 合并前五轴评审
5. `ad-planning-and-task-breakdown` —— 把"引入成熟开源实现"拆成可验证任务

## 跨库去重（重要）

这套里的 **code review / TDD / git 工作流 / 文档 / 最小变更**，与 `~/skills/agency-agents/` 里那些 agent（`engineering-code-reviewer`、`engineering-git-workflow-master` 等）是**同一件事**。

**只选一边。建议选本套**（agent-skills）——成体系、带验证门、有反合理化表；agency-agents 那边只挑它**独有**的角度（AI 代码安全审计、代码漂移考古、事件指挥），见 `~/skills/agency-agents-index.md`。

## 怎么调用

- **DSH（Web GUI）**：直接点名，例如「用 `ad-source-driven-development` 帮我核对这段 FastDDS 用法」
- **Claude Code**：`/ad-spec` `/ad-plan` `/ad-build` `/ad-test` `/ad-review` `/ad-ship` `/ad-constraints` `/ad-code-simplify` `/ad-webperf`
- 也可按 description 自动触发（技能名与描述都在 `~/.claude/skills/ad-*`）
