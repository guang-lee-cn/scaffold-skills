# Scaffold（项目脚手架）

人机协作开发基座：**协作 SOP + 质量门禁 + 数据飞轮 + 文档模板**，跨项目通用，5 分钟部署到新项目。

## 组成
| 块 | 内容 |
|---|---|
| quality/ | run_gate.sh.tpl（门禁采集，泛化）+ gates.conf（门禁命令配置）+ aggregate_quality.py（分析环 → trend.md）+ quality/（存储） |
| sop/ | 协作流程通用版（架构师编排 + subagents + G 日终审核 + B 方案 push + 复盘） |
| templates/ | 开发状态.md / 周总结 / QA报告 / Dev交接 / 复盘（三层根因） |
| policies/ | 门禁口径唯一（防假绿）/ 泄漏归属判定 / git 规范（B方案）/ token 纪律 |
| skills/ | 引用公共 skills 仓库（ai-code-review / pj-core / sdlc / router / incident-review / test-naming / error-code / comment-policy / essential-tool-install）+ 写作原则 |

## 5 分钟启用
1. `bash bootstrap.sh <项目名>`（或手动拷贝本目录）
2. 填 `pj-config.md`（仓库/账号/里程碑）
3. 填 `quality/gates.conf`（替换为项目自己的命令，格式见 gates.conf.example）
4. `bash quality/run_gate.sh` → 首个 gate JSON 落盘（飞轮①启动）
5. `python3 quality/aggregate_quality.py` → trend.md（飞轮③启动）
6. 日终：G 按 sop/ 审核清单收尾，次日飞轮转起来

## 演进双轨（公共沉淀 vs 项目特化）
- **项目特有**（本项目独有：项目专属门禁命令、评审维度、sop 细则）→ 产出到**项目根 `skills/` 目录** + docs/开发交付/，不进 Scaffold
- **公共可复用**（跨项目验证有效：新纪律/模板/模式）→ 回流 Scaffold（policies/ / templates/）+ skills 仓库（/home/guang/code/skills）
- 判定：换一个项目还能用 → 回流公共；只有本项目用 → 留项目
- **落点判定**：agent 要自动触发加载的（SKILL.md 结构）→ 项目根 `skills/`；给人读（或人机双读）→ `docs/`（如 docs/开发交付/）
- 项目侧部署时已自动建两个槽位：`skills/` + `docs/开发交付/`（bootstrap.sh）

## 原则
- Scaffold 只装**项目无关**资产；项目特定参数（命令/仓库/里程碑）一律进 pj-config.md + gates.conf
- 门禁唯一口径、先 RUN 再 claim、实证定级（见 policies/）
- skills 仓库独立维护（/home/guang/code/skills），Scaffold 引用不复制
