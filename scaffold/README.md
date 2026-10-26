# Scaffold（项目脚手架）

人机协作开发基座：**协作 SOP + 质量门禁 + 数据飞轮 + 文档模板**，跨项目通用，一条命令布设。

## 组成
| 块 | 内容 |
|---|---|
| bootstrap.sh | 一键布设（幂等：已存在的项目文件一律保留，`--force` 才覆盖） |
| check-deploy.sh | 布设自检：入口文件 / 索引断链 / 占位未填 / 门禁未配 / 技能未装 / 工作树无技能 |
| quality/ | run_gate.sh.tpl（采集环，落 git.dirty 判定证据级）+ gates.conf（门禁命令）+ aggregate_quality.py（分析环 → trend.md） |
| sop/ | 协作流程通用版（执行形态 + 两层门禁 + push 前置条件 + 缺陷/偏离 + 项目结束复审） |
| templates/ | CLAUDE.md（AI 入口）/ 回流候选 / 开发状态 / 问题台账 / 偏离记录 / 外部案例库 / 周总结 / QA报告 / Dev交接 / 复盘 / 任务卡 / 角色规范 |
| policies/ | 门禁口径唯一（防假绿）/ 泄漏归属判定 / git 规范 / 方案评审门禁 / 调研先行 / token 纪律 / 约束与判据 |
| review/ | **回流入口**：每个项目结束时一份 `<日期>-<项目>-<主题>.md`，是 scaffold 增删的唯一依据 |
| skills/ | 技能写作原则；安装由 `install-skills.sh` 统一执行 |
| install-skills.sh | 统一装载器：按 `<项目>/skills/skills.conf` 链接公共 / 第三方 / 项目自有技能，`--worktrees` 覆盖并行工作树 |
| skill-lint.py | 自检（frontmatter / catalog ↔ 目录 / 断链 / 重复 / 零引用 / 触发词冲突）+ `--write` 生成 catalog |

## 一条命令布设

```bash
bash scaffold/bootstrap.sh <项目名> [目标目录]      # 骨架 + 装技能 + 自检
bash scaffold/check-deploy.sh --project <项目根>    # 随时随地复查布设是否还成立
```

布设产出（新 AI 从这里开始读）：

```
CLAUDE.md                        ← 入口：读什么、按什么主线走、五条硬约束、命令
pj-config.md                     ← 项目参数唯一落点（含 SCAFFOLD_ROOT / 脚手架版本）
docs/开发交付/
  工程流程.md                   ← 唯一施工口径索引（细则指向 scaffold，不复制）
  开发状态.md / 问题台账.md / 偏离记录.md / 回流候选.md
  角色规范/{Dev,QA}.md  模板/  外部案例库.md
quality/                         ← run_gate.sh + gates.conf + gate-*.json + trend.md
skills/skills.conf               ← 技能清单（唯一权威）
```

之后只剩两件事要人填：`pj-config.md` 的占位、`quality/gates.conf` 的命令。`check-deploy.sh` 会把没填的列成待办，把断了索引列成错误。

## 数据飞轮（三环）
```
采集  quality/run_gate.sh → gate-<batch>.json（含 git.commit / branch / dirty）
分析  python3 quality/aggregate_quality.py → trend.md（明细 + 逐门汇总 + 折线）
回流  docs/开发交付/回流候选.md →（项目结束）→ scaffold/review/<日期>-…md → 改 scaffold
```

**证据级只有一个口径**：`git.dirty == 0` 且 commit 非空。脏树上的 run 只能当调试记录。配了取数正则却匹配不到输出 = FAIL（指标消失不等于通过）。

## 技能装载（统一入口）

两类技能，一个清单，一个装载器：

| 分组 | 源 | 管理方式 |
|---|---|---|
| `[common]` | skills 仓库任意一层含 `SKILL.md` 的目录 | 公共迭代，项目只登记 |
| `[project]` | `<项目>/skills/<name>/SKILL.md` | 项目自己迭代，清单登记后统一装载 |

```bash
bash scaffold/install-skills.sh --project <项目根>              # 装载/重链
bash scaffold/install-skills.sh --project <项目根> --check      # 校验清单与链接
bash scaffold/install-skills.sh --project <项目根> --worktrees  # 并行工作树一并装载
bash scaffold/install-skills.sh --project <项目根> --prune      # 清理断链
bash scaffold/install-skills.sh --project <项目根> --user       # 装到 ~/.claude/skills
```

默认装到 `<项目>/.claude/skills`。`--force` 覆盖同名实体目录；`--dry-run` 只打印。缺失源或冲突返回 2，不静默跳过。

**并行执行形态必看**：SOP §1 要求 subagent 在隔离工作树里干活，而 `.claude/` 不会随工作树生成。只在主检出装过 = 执行现场没有技能。用 `--worktrees` 或 `--user`。

入库纪律：`skills/skills.conf` 入库，`.claude/skills/` 不入库（装载产物，含绝对路径）。bootstrap 会自动写 `.gitignore`。

## 演进：谁能进来，谁必须出去

**入口只有一个**：`docs/开发交付/回流候选.md`（项目侧随手记）→ `scaffold/review/`（项目结束裁决）。
判定只有一句：**换一个项目还能用吗？**

- 能 → 进 scaffold，落点写清（policies / templates / sop / quality / skills）
- 不能 → 留项目 `skills/` 或 `docs/`，不占这张表
- 只增**被至少一个项目验证过**的资产；没跑过的想法留在项目里

**抗熵的两道机械闸**（`skill-lint.py`，零成本，每次都跑）：

1. **零引用闸**：`policies/`、`templates/`、`sop/` 里没有任何文件指向的条目 → 警告。两个项目都没用就删（SOP §11.4 的数据源）
2. **冲突闸**：两个技能共享同一触发词 → 警告。路由歧义要显式，不许悄悄长出来

## 原则
- Scaffold 只装**项目无关**资产；项目特定参数（命令/仓库/里程碑/阈值）一律进 pj-config.md + gates.conf
- 门禁唯一口径、先 RUN 再 claim、实证定级（见 policies/）
- 技能本体只有本仓 `../skills/` 一份；Scaffold 只提供装载器，不在项目里复制技能内容
- 装载与布设都是幂等的：清单是唯一权威，手工 symlink 一律视为待清理的漂移
- 流程与规范同理：`bootstrap.sh` 在项目里只生成 `docs/开发交付/工程流程.md` 索引，不复制 policies / sop 正文
- 规范正文改了，项目不用重跑 bootstrap —— 项目里存的是索引，只有 `check-deploy.sh` 需要复查
