# scaffold-skills 飞轮评审（2026-10-25）

评审对象：本仓 `scaffold/`（@ `2d1c820`）　｜　需求方：G　｜　评审人：架构师

评审目的：三个问题要能**机械地**回答，不能靠印象——
① 新项目能否一键布起来？② 布起来之后新 AI 能否一键加载、让 SOP 真的跑起来？③ scaffold + AI + 项目能否形成自我迭代的飞轮，同时 scaffold 自身不熵增？

## 0. 结论

| 需求 | 判定 | 判据 |
|---|---|---|
| ① 一键布设 | **不可用**（会毁数据） | 实跑两次 `bootstrap.sh`，台账/状态/偏离/pj-config 全被模板覆盖 |
| ② 一键加载 | **半可用**（装得上，跑不起来） | `install-skills.sh` 18/18 就绪、`--check` 正确；但项目根没有任何文件告诉新 AI「按哪条主线走」 |
| ③ 回流闭环 | **不存在** | 只有 SOP §11.6 一句人话；本项目 12 门禁、`dirty` 口径、push 前置 QA、追补卡全部未回流，scaffold 仍是 6 门禁 + 无 provenance |

一句话：**装得上，跑不起来，也回不去。** 缺的不是资产（1528 行脚手架 + 40 个技能），是三段接口：

1. 布设产出里没有「入口文件」——AI 打开项目，看不到从这里开始读什么；
2. 装载只覆盖主检出——本项目 13 个 `RunningDDS-wt/*` 并行工作树，**没有一个是带 `.claude/` 的**；
3. 回流靠记忆不靠清单——所以 scaffold 的熵增无法度量，只能靠人察觉。

## 1. 评审方法（可复现）

```bash
# 布设真实性：跑两次
bash scaffold/bootstrap.sh demo-proj /tmp/scaf-probe/demo-proj
echo "MARKER" >> /tmp/scaf-probe/demo-proj/docs/开发交付/问题台账.md
bash scaffold/bootstrap.sh demo-proj /tmp/scaf-probe/demo-proj   # MARKER 消失
# 装载真实性
bash scaffold/install-skills.sh --project /tmp/scaf-probe/demo-proj          # 18/18
bash scaffold/install-skills.sh --project /tmp/scaf-probe/demo-proj --check  # 18/18
python3 scaffold/skill-lint.py                                              # 0 error / 4 warn
# 现网对照：RunningDDS 是 bootstrap 的产物，用它的实际形态反推缺口
```

每条 finding 都带定位，不是通读印象。

## 2. 需求①：一键布设

| # | 级别 | 问题 | 证据 |
|---|---|---|---|
| A1 | P0 | **不幂等，二次执行毁数据**。所有 `cp`/`cat >` 无条件覆盖 | `bootstrap.sh:21`（pj-config）、`:38-40`（三件套）、`:48`（工程流程）；实测 MARKER 行消失、pj-config 复位成占位 |
| A2 | P0 | **无项目根入口文件**。产出全在 `docs/开发交付/` 两层深处，根目录空 | 实跑树：仅 `pj-config.md`、`docs/`、`quality/`、`skills/` |
| A3 | P1 | 不是一键：装技能是「下一步 3)」，且要手工把 `/.claude/skills/` 写进 `.gitignore` | `bootstrap.sh` 末尾 echo；README「入库纪律」是说明文不是动作 |
| A4 | P1 | 索引烤死绝对路径。工程流程.md 里 11 行 `$REPO/scaffold/...` 是生成时展开的字符串 | `bootstrap.sh:48` 之后的 heredoc；scaffold 一移仓，11 行全断且无人报 |
| A5 | P2 | 把 `run_gate.sh.tpl`、`gates.conf.example` 也拷进项目，与产物同名不同义 | 实跑树 `quality/` 下四件 |
| A6 | P2 | 无 scaffold 版本记录，事后无法判断项目生于哪一版规范 | `pj-config` 里没有 commit 行 |
| A7 | **P0** | **采集环开箱即坏**：`run_gate.sh.tpl` 把产物写进 `quality/quality/`，commit 取的是项目**父目录**的仓库；`aggregate_quality.py` 同样路径错位 | `/tmp` 实跑：`gate json -> …/quality/quality/gate-T1.json`，`commit=''`（仓库有 commit）。根因 `DIR/quality` 与 `DIR/../..` 各差一层：脚本装在 `<根>/quality/`，不是 `<根>/` |
| A8 | P1 | 13 个模板只落盘 5 个：任务卡 / QA报告 / Dev交接 / 复盘 / 周总结 / 外部案例库 根本没进项目，项目只能自己发明格式 | `bootstrap.sh` 原 38-45 行只拷三件套 + 两个角色规范 |

修法：`put()` 语义化落盘（存在即保留，`--force` 才覆盖）+ 生成项目根 `CLAUDE.md` + 末尾自动跑装载器 + pj-config 记 `SCAFFOLD_ROOT` 与脚手架 commit + 新增 `check-deploy.sh` 做布设自检（A4 的断链由它兜）。

## 3. 需求②：一键加载

| # | 级别 | 问题 | 证据 |
|---|---|---|---|
| B1 | — | **装载器本身合格**：清单唯一权威、幂等、缺失/冲突返回 2、`--check`/`--prune`/`--dry-run`/`--force` 齐 | 实测 18/18；代码 `install-skills.sh:74-90`（resolve 三类分组） |
| B2 | P0 | 装载只解决「技能在不在」，不解决「按什么顺序做」。SOP 主线、两层门禁、台账终止态、push 单位，全靠人告诉 AI | 与 A2 同源；新 AI 读完 catalog 知道有哪些技能，不知道当前阶段 |
| B3 | P1 | `catalog.json` 只由 `skills/` 生成；`[project]` 组登记的项目自有技能进不了路由 | `skill-lint.py:87-93`（walk 只走 SKILLS） |
| B4 | P1 | **worktree 里无技能**。SOP §1 要求 dev/QA subagent 瞬态拉起，本项目全部在 `RunningDDS-wt/*` 隔离工作树里干活，13 个工作树零 `.claude/` | `ls -d RunningDDS-wt/*/.claude` 全空；当前靠 `~/.claude/skills` 兜底，等于清单失去权威 |

B4 的后果：项目清单以为自己在管技能，实际管不到执行现场。修法：`install-skills.sh --worktrees`（遍历 `git worktree list` 逐个链接），或统一走 `--user` 并在 pj-config 里记明「本项目的执行形态是 worktree ⇒ 必须 user 级装载」。

## 4. 需求③：飞轮与熵增

| # | 级别 | 问题 | 证据 |
|---|---|---|---|
| C1 | P0 | **无回流清单**。SOP §11.6「回灌」没有任何载体，候选只在架构师脑子里，项目一结束就散 | SOP `§11.6`；本仓无 `review/`、无 intake 记录 |
| C2 | P0 | `run_gate.sh.tpl` 无 provenance（只写 commit，无 dirty）。本项目用血换的结论——73 次 run 只有 2 次是证据级——**没有回流**，新项目会原样再踩 | `run_gate.sh.tpl:59` 无 `dirty`；对照 `RunningDDS/quality/run_gate.sh`（319 行，含 dirty/HEAD 校验） |
| C3 | P1 | `gates.conf.example` 自相矛盾：头注释说「POSIX ERE，不支持 `\d`」，示例全用 `\d+`。GNU grep 下 `\d` 未定义 ⇒ 静默取不到值、回落 `exit 0` | 本机 `grep` 是 ugrep 所以能过；`grep -oE 'out of (\d+)'` 在 GNU grep 上不可靠 |
| C4 | P1 | `skill-lint.py` 只扫 `skills/`。**真正会长大的 `scaffold/`（policies/templates/sop）无人检查**：断链、重复正文都不报 | `skill-lint.py:112`（walk(SKILLS)） |
| C5 | P1 | 无触发词冲突检查。19+ 技能里 iso / sdlc / pj-core 都沾「计划·实现」，router 靠人读 description 判路由 | catalog 有 `触发词` 字段但无消费方 |
| C6 | P1 | 无「零引用」统计。SOP §11.4 要求「哪条规则没生效过 → 删掉」，但没有数据源，只能靠记性 | `scaffold/policies/*` 7 个文件，无引用计数工具 |
| C7 | P2 | `aggregate_quality.py` 比现网弱：无逐门 PASS/FAIL 计数、不读 dirty、图表静默截断到 3 条、门禁消失只显示 `-` | 对照 `docs/开发交付/数据飞轮.md` 的口径表 |

## 5. 建议的飞轮形状（三环 + 两个机械闸）

```
环① 采集（已有）  run_gate → gate-<batch>.json → aggregate → trend.md
环② 项目内（已有） 门禁红 → 台账行 → 门禁加固（本项目 19 行、17 闭合）
环③ 回流（缺）     项目 review/ → scaffold 决策（改 / 不改，写理由）
```

环③的机械形态，本文件即是第一份样本：

- `scaffold/review/` = **唯一回流入口**。每个项目结束一个文件，文件名 `<日期>-<项目>-<主题>.md`；
- 文件内每条候选必须回答三问：**换项目还能用吗 / 落在 scaffold 哪个文件 / 不采纳的理由**；
- scaffold 侧的增减只看这张表，不看记忆。

**两个机械闸（防熵增）**，都进 `skill-lint.py`：

1. **零引用闸**：`scaffold/policies/*`、`templates/*` 被其他文件引用的次数为 0 ⇒ 警告。连续两个项目都是 0 ⇒ 删（SOP §11.4 的数据源）；
2. **冲突闸**：catalog 里两个技能共享同一触发词 ⇒ 警告，路由歧义不许悄悄长出来。

另加一条硬纪律（写进 `scaffold/README.md`）：**scaffold 只增「被至少一个项目验证过」的资产**。没跑过的想法留在项目里，不进口。

## 6. SOP 流转的三条改进（通用版需要吸收）

| # | 现状 | 建议 | 出处 |
|---|---|---|---|
| S1 | SOP §4 只说「每卡 push 前代码评审」，没有 push 前置作为**硬条件** | 写死：缺 QA 评审记录的卡不得 push；已误推的，下次 push 前补一次针对**已推 commit** 的评审 | 本项目 I-156（三次未评审即 push） |
| S2 | SOP 无「缺陷已合并且已推」的处置 | 加**追补卡**：不回改历史，开一张只含注释/用例的卡，用变异证明用例对缺陷敏感 | 本项目 EP-02 追补卡 |
| S3 | SOP 未定义「什么样的 run 才算证据」 | 写死：`dirty == 0` 且 commit == HEAD 才是证据级；否则只能当调试记录 | 本项目 I-148（2/73） |

## 7. 本轮修复范围

- P0：A1、A2、A7、B2（与 A2 同源，一个入口文件解决）、C1、C2
- P1：A3、A4、A8、B4、C3、C4、C5、C6
- 立项不动：A5、A6（已在 pj-config 记 SCAFFOLD_ROOT + 版本，剩余部分不动）、B3、C7（记在本文件，下个批次处理）

验收：布设实跑两次不毁数据；新项目根出现入口文件；`check-deploy.sh` 能抓出未填占位与断链索引；`skill-lint.py` 覆盖 `scaffold/` 并报零引用/触发词冲突；`run_gate.sh` 落 `dirty`。

## 8. QA 评审（对 `03276ac` 的独立复核）与处置

评审在 `/tmp` 副本上实跑，不碰仓库。结论是「不建议直接 push」，三条 P1 全部被我独立复现，本轮一并修掉；P2 六条里修四条，P3 修三条，其余记明不做的理由。

### 8.1 已修（本轮 commit）

| 编号 | 现象 | 为什么算缺陷 | 修法 |
|---|---|---|---|
| P1-1 | `while read … done < gates.conf` 的 fd 0 被 `eval "$cmd"` 继承：任何读 stdin 的门禁（`cat`、无参 `grep`、`python3 -`）会**吃掉后面几行配置**，被吃掉的正是可能为红的门禁，整批仍 `rc=0`（复现：3 门只跑 1 门） | 采集环自己制造假绿，与立项目的相反 | `eval "$cmd" </dev/null` |
| P1-2 | 零门禁（空文件 / 只有注释）→ `run_gate` `rc=0`、写 `{"gates":[]}`、被聚合环当证据级；`check-deploy` 也只比字节，给绿灯 | 「门禁没配」被当成「全绿」 | run_gate 解析后 `count==0` → `exit 1` 且不写 json；check-deploy 数非注释行，为 0 报错 |
| P1-3 | `-p|--project) PROJECT="${2:-}"; shift 2` 在 `$#=1` 时 `shift` 失败但不移位 → `while [ $# -gt 0 ]` 死循环、100% CPU、零输出（`timeout 3` 实测 `rc=124`）。`install-skills` 同款（父提交即有） | 漏写参数即挂死，自动化与人工都会踩 | 带值选项先 `[ $# -ge 2 ] \|\| usage 1`；`usage()` 改 here-doc（原先 `sed -n '2,8p'` 把 `set -uo pipefail` 也打进帮助） |
| P2-1 | 末行无换行时 `read` 在 EOF 返回非零，最后一个门禁静默不跑 | 与 P1-1 同类假绿 | `while … read … \|\| [ -n "$name" ]` |
| P2-2 | CRLF 的 gates.conf 全部误判 FAIL（`\r` 留在命令与正则里） | WSL 侧编辑配置即全红，会逼人绕过门禁 | 行级 `%$'\r'` 剥离 |
| P2-3 | 列两侧空白未归一：`\| out of ([0-9]+)` 的前导空格进正则 → 假 FAIL；命令前两个空格 → `tool` 为空报「命令缺失」 | 按表格式对齐写的配置全误红 | 统一 `trim()`；命令自身含 `\|` 的固有限制写进脚本头 |
| P2-5 | 项目已有 CLAUDE.md 时 bootstrap 保留原文件，新入口静默不落盘，`check-deploy` 仍全绿 | 本轮头号目标（AI 入口）在最常见的场景下不生效 | check-deploy 校 `CLAUDE.md` 里是否路由到 `pj-config.md` / `工程流程.md` |
| P2-6 | 只做 `--user` 安装（README/SOP 允许）被判成错误 | 同一脚本 worktree 分支把 user 级当兜底，判据自相矛盾 | 项目级未装但有 `~/.claude/skills` → 警告 |
| P3-a | `skill-lint.rel()` 以 `skills/` 为基，scaffold 里的文件打印成 `../scaffold/x` | 路径错基会误导修复方向 | 非 `skills/` 下的路径改相对仓库根 |
| P3-b | `--check` 也 `mkdir -p $TARGET` | 检查有副作用：会给每棵树建出目录，下一轮判定被自己改变 | `--check`/`--list`/`--dry-run` 不建目录 |
| P3-c | 证据级用 `--untracked-files=no`：树里有未跟踪源码仍算 `dirty: 0` | 那次 run 编的是 commit 里没有的代码 | 计入未跟踪；只排除采集环自己的产物（`gate-*.json`、`.gates.tmp`），否则跑一次就把下一次判脏 |
| P3-d | 聚合环按文件名排序（`b1,b10,b11,b2`）→「最近状态/红转绿」错位；value 含 `\|` 会把表格撑出多余列 | 报告里的结论方向会被排错序影响 | 按（日期, 自然序批次）排序；value 转义 `\|` |
| P3-e | 有 `FOO=1 true` 这类 env 前缀命令时 `tool="${cmd%% *}"` 取到 `FOO=1` → 误报「命令缺失」 | 门禁写法的正常用法被判 FAIL | 跳过前置的 `VAR=val` 再取 tool |
| P3-f | 门禁名里的空白被静默删掉（`my gate` → `mygate`） | 跨批次列名对不上，聚合表把同一门禁当两门 | 含空白即 FAIL，不改写 |

### 8.2 不做（连同理由）

| 编号 | 不做 | 理由 |
|---|---|---|
| P3 | `SKILLS_ROOT` 与脚手架根解耦 | 现在两者都在 `~/code/scaffold-skills`，解耦要先想清楚「技能源与脚手架版本分开」的升级语义，不是一行改动。**但文档必须先说实话**：`pj-config.md` 原先写「只改 SCAFFOLD_ROOT 一行」，实测搬走后技能软链与 `SKILLS_ROOT` 默认都过期——已在 bootstrap 生成的 pj-config 里改成「改这一行足以让规范路径生效，但必须重跑 install-skills 与 check-deploy」 |
| P3 | aggregate 把 `exit 0/exit 1` 当数值画折线 | 无正则的门禁本来就没有可比数值；正确做法是不给它们画线，改画 PASS/FAIL 状态带。属于图表口径调整，与「表格是权威」不冲突，下批做 |
| P3 | 带空格脚手架路径的生成命令未加引号 | 生成文本里是给人读的示例；`bootstrap.sh` 自己处理了空格（已实测）。改成 `"__SCAFFOLD_ROOT__"` 会让复制到 shell 的人多一层引号，收益不明 |

### 8.3 第二轮复核（对 7a3a90b）与处置

第一轮的 P1/P2 复核已闭；第二轮新报了 8 条，其中 2 条被判「push 前必修」。**新-1 是我自己修出来的回归**，值得记下来。

| 编号 | 现象 | 处置 |
|---|---|---|
| 新-1 | `git()` 对 status 输出整体 `.strip()`，丢掉首行首列的状态位空格，再按固定偏移 `l[3:]` 取路径 → `' M quality/gate-r1.json'` 被切成 `'uality/gate-r1.json'`，`own()` 匹配不到，已跟踪的 gate json 一改动就让后续 run 永久判脏 | **已修**：改用 `status --porcelain -z`（NUL 分隔、路径不加引号），解析时按条目走，`R`/`C` 条目多跳一个原路径 |
| 新-2 | user 级兜底只看 `~/.claude/skills` 目录在不在：manifest 写不存在的技能、目录存在但空 → 只警告、rc=0 | **已修**：兜底判据改成 `install-skills.sh --project P --user --check` 真去核对每个技能是否链到位 |
| 新-3 | batch/date 是数字时 `re.split` 抛 `TypeError`，整张表不出 | **已修**：读入即 `str()` |
| 新-4 | 含空格的批次名被 git 加引号，`own()` 失效 → 每次判脏 | **已修**（同新-1，`-z` 不加引号） |
| 新-5 | 只报脏的数量、不报路径，人得自己去翻 | **已修**：点名前 5 个，超出报剩余数 |
| 新-6 | `--check --prune` 向 stderr 喷 `find: No such file or directory` | 不改：`--check` 不该 prune，属于用法错误；噪音无害。若后续有人被误导，再让 `--prune` 与 `--check` 互斥 |
| 新-7 | `FOO="a b" cmd` 的 env 前缀在引号内空格处断开 → 假「命令不存在: a」 | **已修**：按整段赋值剥（支持双引号/单引号/无引号三种） |
| 新-8 | gates.conf 带 UTF-8 BOM，第一个门禁名变成 `<BOM>unit` | **已修**：剥 BOM |
| P2-4 | 我原先判「不做」，理由是「零门禁检查已覆盖」——**这个理由当时是错的**：示例本身有 6 条门禁，`n_gates>0` 直接跳过，旧示例布设的项目完全逃过检测（复核实测 rc=0） | **已修**：判据改为内容——所有门禁命令都还在示例那 6 条里，就等于没换；与 example 字节相同仍单独报。两种判据并存，兼容新旧布设 |
| 遗留 | 删掉 `docs/开发交付/偏离记录.md` 后 check-deploy 仍 0 错误；`CLAUDE.md` 的 `<占位>` 不计待办 | **已修**：偏离记录缺失 → 警告；CLAUDE.md 的 `<…>` → 待办 |

一条过程教训：**修 A 的时候把 B 弄坏了（strip → 偏移）**，且我自己的验证没抓到，因为我的测试里脏行都是 `??`（首列无空格）。测试用例要覆盖「首行就是带状态空的 ` M`」这种形状，不能只覆盖最顺手的一种。后续凡是解析 `git status` 的地方一律用 `-z`，不用人类可读格式。

### 8.4 第三轮复核（对 `c105bf0`）

结论「可以 push」，四条修复逐项复现通过（含我上轮漏掉的「首行带状态空」形状、`R` 重命名、中文+空格路径、`\xff` 文件名）。另外它提了三条**非阻塞**观察，其中两条我认同并按「顺手能修就修」处理：

| 观察 | 处置 |
|---|---|
| `quality/trend.md` 不在 `own()` 白名单：先聚合再跑门禁，下一批就 `dirty≥1` | **已修**：trend.md 与 gate-*.json、.gates.tmp 同列为采集环产物 |
| `status_paths()` 出错返回空列表 → `dirty=0`，等于「取不到状态就当干净」 | **已修**：返回 `None`，`dirty=-1`，并在警告里明说「不能据此判证据级」 |
| `--check --prune` 静默容忍（会喷 find 噪音） | **已修**：两者同时给直接用法错误、`exit 1` |
| CLAUDE.md 的 `<占位>` 按行计数、代码里的 `<T>`/`<br>` 会误报待办 | 不改：只影响待办级、不影响退出码；要准确就得解析 markdown，代价不匹配 |

至此 scaffold 侧三轮评审闭环，可以 push。
