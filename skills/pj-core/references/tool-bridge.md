# tool-bridge.md · 跨环境文件操作与命令执行纪律（环境无关，G 定案 2026-10-02）

## 0. 环境类型判定（从 pj-config.md §环境类型 读取）

| 类型 | 判定 | 适用 |
|---|---|---|
| `wsl2` | Windows + WSL2 混合 | 当前 fast-dds-rpc 项目 |
| `linux-desktop` | Linux 桌面直连开发 | 换环境时 |
| `ssh-remote` | 本地 agent + SSH 远程开发机 | 换环境时 |

> 新项目接入：pj-config.md 填 `环境类型`，tool-bridge 按分支应用，**通用原则所有环境一致**。

## 1. 通用原则（所有环境）

1. **通道选择**：能直写就直写；失败**换通道**（不反复重试同一失败通道；同一动作失败两次换命令/目录/通道）
2. **编码统一**：UTF-8；验证用**目标系统读取**（防本地显示乱码误判）
3. **命令执行边界**：区分"agent 所在机"与"目标机"——本地 shell 只跑本地命令；目标机命令一律走对应通道（wsl.exe / ssh）
4. **路径规则**：绝对路径；含中文/空格路径经**变量或文件**传递，不经 shell 拼接转码
5. **长操作**：声明时长 + 阶段心跳（workflow.md R1-R2）；>30min 外部等待不轮询（R5）

## 2. 分支 A：ENV=wsl2（Windows + WSL 混合，当前）

背景：文件工具对 `\\wsl.localhost\\Ubuntu\\...`（9P 网络挂载）支持不完整（I/O error / mtime 异常）。

| 操作 | 做法 |
|---|---|
| 编辑/覆盖 WSL 文件 | ❌ 不 UNC 直写 → ✅ 写 Windows Temp → `wsl.exe cp` → WSL 侧处理 |
| 读 WSL 文件 | Read UNC 优先；失败回退 `wsl.exe cat` |
| 搜索 WSL 文件 | Grep UNC 优先；失败回退 `wsl.exe grep` |
| 生成新 WSL 文件 | 写 C:\Temp → cp → WSL 内落地 |

**核心**：UNC 只读、写必桥接（Temp + wsl.exe 通道，100% 稳定）；中文路径经变量传参（wsl.exe 命令行中文转码会静默失败——echo 无输出即怀疑转码）。

## 3. 分支 B：ENV=linux-desktop（Linux 桌面直接开发）

- **无桥接问题**：所有文件操作直接本地路径（Read/Write/Edit/Bash），无需 Temp 中转
- 命令直接本地执行；长任务用 `nohup ... &` / 后台任务管理（桌面会话关闭不杀后台）
- 编码校验：`file -bi` / `iconv -f UTF-8` 复核

## 4. 分支 C：ENV=ssh-remote（本地 agent + SSH 远程开发机）

| 场景 | 做法 |
|---|---|
| 文件传输 | 写远端 = 本地写 Temp → `scp`（单文件）/ `rsync -az`（批量增量）→ 远端落地；读远端 = `scp 远端→本地` 或 `ssh cat` |
| 命令执行 | 远端命令一律 `ssh <host> "cmd"`；批量命令一次传输 heredoc/脚本执行（减少往返）|
| 长任务保活 | `nohup cmd > log 2>&1 &` + 轮询日志；断线恢复用 `tmux`/`screen`（会话分离）|
| 权限 | SSH key 认证；远端 `sudo` 谨慎（非必要不 sudo）；禁止明文口令 |
| 路径 | 远端绝对路径；本地↔远端路径不混用 |
| 编码 | 远端文件 `file -bi` 校验 UTF-8 |

**核心**：SSH 通道是唯一命令入口（不绕行 GUI 远程桌面做文件操作）；传输可断点续传用 rsync。

## 5. 环境切换（pj-config.md 变更即可，L0/L1 其余不动）

1. 改 pj-config.md §环境类型
2. 按本文件对应分支应用纪律
3. 命令基线（command-baseline.md）按环境重录已验证命令
