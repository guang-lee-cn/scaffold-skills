# Scaffold（项目脚手架）

人机协作开发基座：**协作 SOP + 质量门禁 + 数据飞轮 + 文档模板**，跨项目通用，5 分钟部署到新项目。

## 组成
| 块 | 内容 |
|---|---|
| quality/ | run_gate.sh.tpl（门禁采集，泛化）+ gates.conf（门禁命令配置）+ aggregate_quality.py（分析环 → trend.md）+ quality/（存储） |
| sop/ | 协作流程通用版（执行形态 + 两层门禁 + 缺陷/偏离 + 项目结束复审） |
| templates/ | 开发状态.md / 问题台账 / 偏离记录 / 外部案例库 / 周总结 / QA报告 / Dev交接 / 复盘（三层根因） |
| policies/ | 门禁口径唯一（防假绿）/ 泄漏归属判定 / git 规范 / 方案评审门禁 / 调研先行 / token 纪律 |
| skills/ | 技能写作原则；安装由 `install-skills.sh` 统一执行 |
| install-skills.sh | 统一装载器：按 `<项目>/skills/skills.conf` 链接公共 / 第三方 / 项目自有技能到 `.claude/skills` |
| skill-lint.py | 技能库自检（frontmatter / catalog ↔ 目录 / 断链 / 重复）+ `--write` 生成 catalog |
| templates/skills.conf.tpl | 项目技能清单模板（三类分组，项目唯一权威） |

## 5 分钟启用
1. `bash bootstrap.sh <项目名>`（或手动拷贝本目录）
2. 填 `pj-config.md`（仓库/账号/里程碑）
3. 填 `quality/gates.conf`（替换为项目自己的命令，格式见 gates.conf.example）
4. 按 `skills/skills.conf` 登记技能，执行 `bash <scaffold>/install-skills.sh --project <项目根>`
5. `bash quality/run_gate.sh` → 首个 gate JSON 落盘（飞轮①启动）
6. `python3 quality/aggregate_quality.py` → trend.md（飞轮③启动）
7. 自检：`python3 <scaffold>/skill-lint.py`；项目结束时按 `sop/` §11 与 G 做一轮复审

## 技能装载（统一入口）

三类技能，一个清单，一个装载器：

| 分组 | 源 | 管理方式 |
|---|---|---|
| `[common]` | skills 仓库任意一层含 `SKILL.md` 的目录 | 公共迭代，项目只登记 |
| `[agent]` | `agent-skills/skills/ad-*` | 第三方包，项目只登记 |
| `[project]` | `<项目>/skills/<name>/SKILL.md` | 项目自己迭代，清单登记后统一装载 |

```bash
bash scaffold/install-skills.sh --project <项目根>            # 装载/重链
bash scaffold/install-skills.sh --project <项目根> --check    # 校验清单与链接
bash scaffold/install-skills.sh --project <项目根> --prune    # 清理断链
bash scaffold/install-skills.sh --project <项目根> --user     # 装到 ~/.claude/skills
```

默认装到 `<项目>/.claude/skills`。`--force` 覆盖同名实体目录；`--dry-run` 只打印。缺失源或冲突返回 2，不静默跳过。

入库纪律：`skills/skills.conf` 入库，`.claude/skills/` 不入库（装载产物，含绝对路径）。项目 `.gitignore` 加：

```
/.claude/skills/
```

## 演进双轨（公共沉淀 vs 项目特化）
- **项目特有**（本项目独有：项目专属门禁命令、评审维度、sop 细则）→ 产出到**项目根 `skills/` 目录** + docs/开发交付/，不进 Scaffold
- **公共可复用**（跨项目验证有效：新纪律/模板/模式）→ 回流 Scaffold（policies/ / templates/）或本仓 skills/
- 判定：换一个项目还能用 → 回流公共；只有本项目用 → 留项目
- **落点判定**：agent 要自动触发加载的（SKILL.md 结构）→ 项目根 `skills/`；给人读（或人机双读）→ `docs/`（如 docs/开发交付/）
- 项目侧部署时已自动建两个槽位：`skills/` + `docs/开发交付/`（bootstrap.sh）

## 原则
- Scaffold 只装**项目无关**资产；项目特定参数（命令/仓库/里程碑）一律进 pj-config.md + gates.conf
- 门禁唯一口径、先 RUN 再 claim、实证定级（见 policies/）
- 技能本体只有本仓 `../skills/` 一份；Scaffold 只提供装载器，不在项目里复制技能内容
- 装载是幂等的：清单是唯一权威，手工 symlink 一律视为待清理的漂移
- 流程与规范同理：`bootstrap.sh` 在项目里只生成 `docs/开发交付/工程流程.md` 索引，不复制 policies / sop 正文
