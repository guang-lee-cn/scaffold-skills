# __PROJECT__ —— AI 入口

> 本文件只做路由，不写规范正文。规范唯一源在脚手架（`__SCAFFOLD_ROOT__`），项目参数唯一源在 `pj-config.md`。
> 由 `bootstrap.sh` 生成；项目特有内容写在下面的「本项目补充」段，不要改上面的路由。

## 一、开工前按序读这一条链

1. `pj-config.md` —— 仓库 / 分支 / 里程碑 / 账号身份 / `SCAFFOLD_ROOT`
2. `docs/开发交付/工程流程.md` —— **本项目的唯一施工口径**（主线、两层门禁、角色边界、push 条件）
3. `docs/开发交付/进度.md` —— 卡片做到哪了、下一步是什么（一屏；**问「现在做到哪」之前先读它**）
4. `docs/开发交付/开发状态.md` —— 当前批次与最新裁决（架构师唯一写者；不重复卡片状态）
5. `docs/开发交付/问题台账.md` —— 全部缺陷与终止态

不确定该用哪个技能时，先读 `__SCAFFOLD_ROOT__/skills/router/SKILL.md`，再按名调用。

> **常驻预算**：这条链是每轮对话都要占的上下文，所以只放「去哪读」与不可协商项，不放规范正文。链上的规则类文件各自控制在 200 行内；超出的拆到 `docs/开发交付/` 的专题文件，链上留指针。新增内容优先加指针，不加正文——链变长直接挤压模型的推理空间。

## 二、主线（细则见工程流程 §2）

方案 → 台账行 → 独立评审 → 架构师裁决 → 派卡 → 小步实现 → commit → QA/架构师验收 → 集成 → 按卡 push

## 三、不可协商的五条

- 缺陷先入台账拿编号，再修；终止态只有 `closed` / `wontfix`，没有第三种
- 缺 QA 评审记录的卡不得 push；已误推的，下次 push 前补一次针对**已推 commit** 的评审
- 门禁结果只认 `quality/gate-*.json`，且 `git.dirty == 0` 才是证据级
- 与规范不一致的做法记一条偏离（`偏离记录.md`），不口头绕过
- 结论先写验证方法；只看一段数据不下根因结论

## 四、命令

```bash
bash quality/run_gate.sh [batch标记]        # 采集环，配置在同目录 gates.conf
python3 quality/aggregate_quality.py        # 分析环 → quality/trend.md
bash __SCAFFOLD_ROOT__/scaffold/check-deploy.sh --project .   # 布设自检（断链/占位/技能）
bash __SCAFFOLD_ROOT__/scaffold/install-skills.sh --project . --check   # 技能清单校验
```

执行形态是 git worktree 时（并行 dev / QA 各占一棵树），必须用 `--worktrees` 或 `--user` 装载，否则工作树里没有技能。

## 五、项目结束时

把「换一个项目还能用」的东西写进 `docs/开发交付/回流候选.md`，一条一行，写清落在脚手架哪个文件；不采则写理由。这是脚手架自我迭代的唯一入口。

## 六、本项目补充

- 架构文档：<路径>
- 门禁门数与时序：<如 12 门 / S0..S5 分阶段>
- 其他：<无>
