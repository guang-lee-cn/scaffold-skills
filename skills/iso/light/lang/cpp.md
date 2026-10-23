# C++ 速查

- **C++17+**，STL 优先——具体替换对照（`string_view`/`optional`/`variant`/`span`/`<algorithm>`/`chrono`）见 [../../references/cpp-idioms.md](../../references/cpp-idioms.md)
- **RAII**：禁止裸 `new/delete`，用 `std::unique_ptr` / `std::shared_ptr`
- **const 正确**：不修改的参数用 `const T&`，不修改成员的方法加 `const`
- **类设计**：头文件 <= 150 行，源文件 <= 250 行，公有方法 <= 9 个（纯数据类型不受限）
- **编译**：`-Wall -Wextra -Werror` 零警告
- **风格**：Google C++ Style Guide
- **测试**：Google Test，命名 `TEST_F(ClassName, Given_When_Then)`
- **内存**：单元测试通过 ASan

## 命名规范（C/C++）

**目的：从命名一眼看出标识符类别（类型/API/变量/宏）。**

| 类别 | 规则 | 示例 | 辨识 |
|---|---|---|---|
| 类型（class/struct/enum/using） | PascalCase，名词 | `DataFactory` `ThreadHandle` | 名词首字母大写 |
| 函数/API（自由函数 + 类方法） | PascalCase，动词 | `CreateThread` `Subscribe` | 动词首字母大写 |
| 局部变量 / 参数 | camelCase | `threadName` `stackBytes` | 小写首字母 |
| 成员变量 | `m_` + camelCase | `m_registry` `m_domains` | `m_` 前缀 |
| 全局 / 静态全局变量 | `G_` + 全大写 | `G_PUBSUB` `G_REGISTRY` | `G_` 前缀 |
| 宏 | 全大写 + 下划线 | `DETSCHED_NONCOPYABLE` | 全大写、无类型 |
| 常量（constexpr/const） | 全大写 + 下划线 | `MSG_ID_STATUS` `CORE_PRIO_START` | 全大写、有类型 |
| 枚举值 | 全大写 + 下划线 | `IDLE` `WORKING` `STOP` | 全大写 |
| 命名空间 | 全小写 | `detsched` `std` | 小写 |
| 文件 | 小写 + 下划线 | `thread_factory.h` | 小写 |
| 目录 | 全小写 | `include/` `src/` | 小写 |

### 细则

1. **类型**：名词；数据 POD 直接命名，行为类以 `Manager/Factory/Cache/Handler/Impl` 等词尾
2. **函数**：动词开头（`Create/Destroy/Get/Set/Subscribe/Publish/Find/Dump`）；bool 查询用 `Is/Has` 开头
3. **枚举**：优先 `enum class`；非 scoped enum 的值泄漏到外层作用域，**值名须全局唯一**
4. **成员变量**：统一 `m_` 前缀（不用尾下划线），与局部变量区分
5. **全局变量**：静态存储期（含文件级 static）统一 `G_` 前缀 + 全大写，与宏/常量区分
6. **常量**：编译期 `constexpr` 全大写；类内静态常量同规则
7. **宏**：全大写；避免与常量重名；库宏带库前缀（如 `DETSCHED_`）
8. **文件/目录**：小写下划线；include 用模块前缀目录（`include/detsched/`）
9. **头文件防护**：`#pragma once`
10. **虚函数**：override 必须标注 `override`
11. **句柄**：类型名 `*_handle`（如 `detmw_handle`），变量用 `h`
12. **回调**：类型 `*_fn` + `void* user_ctx` 传上下文
13. **错误码**：int 返回，0=成功、非 0=失败，统一 errno 风格

