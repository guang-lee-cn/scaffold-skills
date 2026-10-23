# commit.md · Git 提交日志规范（英文版，G 定案）

## 格式

```
[<PROJECT>][<Type>] <Summary>
- 1. <sub-feature>
- 2. <sub-feature>

<context / root-cause / acceptance, optional>
```

## 类型集（冻结枚举，禁止自造词）

| Type | 用途 |
|---|---|
| `Add` | 新功能/新单元 |
| `Fix` | 缺陷修复（附 `I<编号>`） |
| `Refactor` | 结构调整 |
| `Test` | 测试新增/修正 |
| `Docs` | 文档 |
| `Chore` | 构建/CI/杂项 |

## 要点

- 标题 ≤ 72 字符，动词开头（Implement/Fix/Add）
- 子项 `- N.` 前缀
- **Fix 必须带 `I<编号>`**（问题台账可追溯）
- 验证结果（CI/测试计数）可放 body 尾部，保留可审计性
- **不重写历史**（保留与上游合并能力）：规范从下一提交生效，存量 commit 不动

## 提交打包纪律（G 定案 2026-10-20）

- **文档类更新不单独生成提交记录**，避免污染提交区：文档改动随关联代码提交合并（同一语义单元内），或攒批打包提交；
- `[Docs]` 类型仅用于跨阶段收口批次（里程碑/评审收口）或随代码同批时的标注；日常文档更新不单独立提交；
- 禁止 `Co-Authored-By` AI 工具署名（提交纪律规则 3）；未事前批准的提交须先记录偏离再补批准。

## 提交信息可读性纪律（G 定案 2026-10-20）

- **git log 是长期可追溯资产，不是私人笔记**：提交信息须让 G/架构/QA/新接手者不依赖作者上下文也能读懂变更实质；
- **禁黑话**：内部术语/缩写首次出现须有人话展开。反例：`导出接线（ADR-02 合并库交付面）` → 正例：`符号导出：mtcomm 公共 API 加导出宏 + version script 白名单，使合并库 libfastdds.so 对外可链接（ADR-02）`；
- **编号引用边界**：只保留"帮助理解变更"的编号——`Fix` 的 `I<编号>`（缺陷台账，强制可追溯）；**ADR/AR/拍板等文档依据编号不进提交日志**（正文实义描述已表达变更，文档编号会修订致日志引用腐化）——依据记入 worklog/开发状态；
- **审核视角**：提交信息按"陌生人能否 30 秒看懂这次变更"自查；G/架构审核 git log 时发现黑话即打回重写；
- body 只写 what/why（变更实质+动机），不写 how（命令/工具/环境细节 → 工作记录 worklog）。

## 示例

```
[<PROJECT>][Add] Implement H-series high-level call forms
- 1. H1 sync call (call_sync blocking bridge)
- 2. H2 async call (per-call completion handler)
```

```
[<PROJECT>][Fix] Fix reply pairing key mismatch (I40)
- 1. related_sample_identity mis-filled on requester side

Official TODO marks this for v4.0; fixed one line ahead.
```

---
修订：2026-10-20 ① 新增「提交打包纪律」（文档类更新不单独提交，避免污染提交区；禁 AI 署名）；② 新增「提交信息可读性纪律」（禁黑话/30秒可读/body 只写 what-why）；③ 编号引用边界（I 缺陷编号保留 / ADR·AR·拍板文档依据编号移出提交日志，记 worklog）——G 定案，沉淀自 MTComm 项目协作实践。
