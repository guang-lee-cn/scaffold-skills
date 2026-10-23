# vendor/ 子模块恢复信息（删除前置记录，保证可逆）

> 记录时间：2026-10-17　操作：删除 `vendor/superpowers` 子模块（第三方镜像，非自研）
> 目的：仓库瘦身（约 3.7 MB / 229 文件），第三方内容改为**按需下载**，不进版本库。

## 恢复命令（二选一，等价）

```bash
# A. 若有 .gitmodules（旧式，已随删除移除）
git submodule update --init vendor/superpowers

# B. 直接用记录的上游地址与 commit（推荐，不依赖 .gitmodules）
git clone https://github.com/obra/superpowers.git vendor/superpowers
git -C vendor/superpowers checkout 8ca22dba9a94f28898bbce59f2537ff4d87c747d
```

## 钉住的信息

| 项 | 值 |
|---|---|
| 路径 | `vendor/superpowers` |
| 上游 URL | `git@github.com:obra/superpowers.git`（HTTPS 等价：`https://github.com/obra/superpowers.git`） |
| Gitlink SHA（删除时） | `8ca22dba9a94f28898bbce59f2537ff4d87c747d` |
| 删除前内部是否有本地改动 | **无**（`git -C vendor/superpowers status --porcelain` = 0 行） |
| 删除前内部是否含非 superpowers 内容 | **无**（`ls vendor/` 仅 `superpowers`） |

## 被 4 条 catalog 依赖引用的技能（删除后仍可路由，走下载钩子）

| catalog 条目 | 上游技能路径 |
|---|---|
| `superpowers:test-driven-development` | `skills/test-driven-development/SKILL.md` |
| `superpowers:systematic-debugging` | `skills/systematic-debugging/SKILL.md` |
| `superpowers:writing-plans` | `skills/writing-plans/SKILL.md` |
| `superpowers:verification-before-completion` | `skills/verification-before-completion/SKILL.md` |

> 引用方式：先执行上方恢复命令把仓库拉到本地，再按 `vendor/superpowers/<上游技能路径>` 读取。
> catalog.json 中这 4 条已改为「按需下载」依赖，不再假定子模块已 checkout。

## 反例

- ❌ 未记录 SHA 就删子模块 ⇒ 无法恢复到同一版本，属不可逆丢失
- ❌ 删除前不检查 submodule 内部 status ⇒ 可能丢失未推送的本地改造
