# 返回值 —— 闭集分档，借码必须写明，自我撤销由实现兜住

## 出处

- nginx/nginx @ `src/core/ngx_core.h`（BSD-2-Clause，master，2026-10-28 抓取）。七个码的**语义不在头文件里**，在官方 Development guide 的 *Common return codes* 一节。
- redis/redis @ `src/ae.h`、`src/ae.c`（RSALv2 / SSPLv1 / AGPLv3 三选一，unstable，2026-10-28 抓取）。该许可不在本库白名单内，**只作描述，不贴片段**。

## 看什么

1. 闭集先分四档，而不是「成功 / 失败」两档。七个码实际分成：成功终态（`NGX_OK`、`NGX_DONE`）、可重试（`NGX_AGAIN`）、**非错误的拒绝**（`NGX_DECLINED`，指南原话 "This is never an error"）、资源不可用（`NGX_BUSY`）、失败（`NGX_ERROR`、`NGX_ABORT`）。最值钱的是 `DECLINED`：「因为没启用所以不走」被明文排除在错误之外，调用方不必把它翻译成失败，也就不会把一次正常的路由决策记成故障。
2. 可以借码，但必须在使用处写明它此刻表示什么。指南在 `ngx_peer_connection_t::get` 一节把 `NGX_BUSY` 展开为「当前没有可用上游」，并列三种成因（组为空、全在 failed 状态、全被占用）。同一个码在不同上下文承载不同含义是允许的，代价是**每一处借用的地方都要重新定义一次**。
3. 回调的返回值就是下一次调度的参数。`aeTimeProc` 返回 `int`（`ae.h:47`），实现里非 `AE_NOMORE` 就当作「再过这么多毫秒叫我」，`AE_NOMORE` 表示取消（`ae.c:339-343`）。一个返回值同时承担「结果」与「下次何时」，省掉回调里再判断一次要不要 `aeDeleteTimeEvent` 的分支。
4. 允许回调自杀，就必须由实现兜住。正因为可以返回 `AE_NOMORE` 取消自己，`aeTimeEvent` 才有 `refcount` 字段（`ae.h:68-69` 注释直说「防止递归定时器调用中被释放」），实现里 `refcount++/--` 把回调整个包住（`ae.c:334-336`）。「回调里能不能删掉自己」这类问题，答案必须是实现保证，不能是调用约定。

## 不看什么

1. 不学 nginx 把契约放代码外。`ngx_core.h` 注释密度 3%、`ngx_module.h` 1%，七个码的定义处**一行注释都没有**：读得到码值，读不到「`NGX_DONE` 到底算成功还是失败」。redis 的 12%–16%（陷阱处给长注）才是可迁移的密度。
2. 不学用同值魔数兼作控制指令。`AE_NOMORE` 与 `AE_DELETED_EVENT_ID` 都是 `-1`（`ae.h:37-38`），靠出现在哪一行来区分。C++ 里 `std::optional` 或独立枚举能直接消掉这层歧义。
3. 不学「所有函数共用一个整型返回码」。`ngx_int_t` 的代价不是类型不安全，而是**返回类型不告诉你这个函数属于哪个码子集**，调用方只能靠记忆或读实现。C++ 用 `Status` + `enum class` 可以把子集写进签名。

## 样例

nginx/nginx `src/core/ngx_core.h:39-45`（BSD-2-Clause）。闭集本身就这么七行，一个注释都没有——这正是「闭集必须配一份外部语义表」的反面证据：

```c
#define  NGX_OK          0
#define  NGX_ERROR      -1
#define  NGX_AGAIN      -2
#define  NGX_BUSY       -3
#define  NGX_DONE       -4
#define  NGX_DECLINED   -5
#define  NGX_ABORT      -6
```

redis 对应的两处片段（`ae.h:37-38` 的两个 `-1` 魔数、`ae.c:334-343` 的 `refcount++/refcount--` 包住回调）因许可证原因不转录，特征已在上面第 3、4 条与本栏第 2 条写明，按「出处」路径与行号可自行核对。
