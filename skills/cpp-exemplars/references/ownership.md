# 所有权 —— 归还写成控制流，不写成注释

## 出处

abseil/abseil-cpp @ absl/cleanup/cleanup.h（许可证：Apache-2.0，master，2026-10-28 抓取）

## 看什么

1. 先声明自己不是什么：`Cleanup` 明确写「不是接口类型、不是值类型，是控制流构造」，只在一个函数体内使用（`cleanup.h:68-70`）。类型定位先于 API 定下来，后面每个成员都受这一条约束——它不继承、不虚化、不提供句柄语义。
2. 三种结局互斥，且主动动作只能由右值触发：析构执行（`:109-114`）、`Cancel() &&` 撤销（`:98-101`）、`Invoke() &&` 提前执行（`:103-107`）。两个主动动作都要求 `std::move(c)`，所以「提前触发」不可能发生在还要继续用它的地方——这是靠 ref-qualifier 而不是靠约定。
3. 错误用法在编译期就死：`[[nodiscard]]`（`:86`）+ 两条 `static_assert` 拒绝显式模板参数与有返回值的回调（`:87-91`）。契约靠类型系统，不靠文档提醒。

## 不看什么

不要抄 `ABSL_NAMESPACE_BEGIN` 与 `HardeningAssert` 硬化层，也不要同时养 C++11 工厂 `MakeCleanup` 与 C++17 CTAD 两套入口（`:120-131`）——那是为跨标准兼容，新代码定一个标准即可。`Storage` 那层把回调 placement-new 到字符缓冲区，理由写在内部实现里：为了在 `Cancel()` / `Invoke()` 时**立即析构**（`cleanup/internal/cleanup.h:51-53` 的原话是「为避免用 `std::optional` 而本地实现，以便优化」）。普通项目用 `std::optional` 或直接成员就够，不必自己管裸缓冲与 engaged 标志。

## 样例

absl/cleanup/cleanup.h:86-118

```cpp
class [[nodiscard]] Cleanup final {
  static_assert(cleanup_internal::WasDeduced<Arg>(),
                "Explicit template parameters are not supported.");

  static_assert(cleanup_internal::ReturnsVoid<Callback>(),
                "Callbacks that return values are not supported.");

 public:
  Cleanup(Callback callback) : storage_(std::move(callback)) {}  // NOLINT

  Cleanup(Cleanup&& other) = default;

  void Cancel() && {
    absl::base_internal::HardeningAssert(storage_.IsCallbackEngaged());
    storage_.DestroyCallback();
  }

  void Invoke() && {
    absl::base_internal::HardeningAssert(storage_.IsCallbackEngaged());
    storage_.InvokeCallback();
    storage_.DestroyCallback();
  }

  ~Cleanup() {
    if (storage_.IsCallbackEngaged()) {
      storage_.InvokeCallback();
      storage_.DestroyCallback();
    }
  }

 private:
  cleanup_internal::Storage<Callback> storage_;
};
```
