# abseil —— 基础类型设计与强类型

## 出处

abseil/abseil-cpp @ absl/types/span.h（许可证：Apache-2.0，master，2026-10-25 抓取）

## 看什么

1. 隐式转换只向只读开放：`Span<const T>` 可以从 const 容器隐式构造，`Span<T>` 只能显式构造（`explicit Span(V& v)`）。const 正确性由类型系统强制，调用点拿不到意外的可变别名。
2. 生命周期写进签名：每个指针/容器构造参数都带 `ABSL_ATTRIBUTE_LIFETIME_BOUND`，编译器能对"span 比被引用对象活得久"报警。契约不靠注释，靠类型标注。
3. 不拥有、不复制：构造只取 `data()` + `size()`，数组特化 `Span(T(&)[N])` 保留编译期长度。同一项目的错误分层采用值/错误互斥的 `StatusOr`：默认构造是 `explicit`，避免 `return {}` 被误读成空值（absl/status/statusor.h:228-233）；`Status` 对外只给 `code()` 与 `message()` 视图（absl/status/status.h:534-556）。

## 不看什么

不要抄它的内部实现脚手架：`ABSL_NAMESPACE_BEGIN` 宏、`EnableIfConvertibleFrom` / `EnableIfValueIsConst` 这串 SFINAE 别名，以及 `internal_statusor` 用多个私有基类拼出的构造/赋值分派。它们是为 ABI 兼容和极端泛型支持服务的；业务类型用 `explicit` + `const` + 一条清晰的不变量就够了。

## 样例

absl/types/span.h:221-248

```cpp
  constexpr Span() noexcept : Span(nullptr, 0) {}
  constexpr Span(pointer array ABSL_ATTRIBUTE_LIFETIME_BOUND,
                 size_type length) noexcept
      : ptr_(array), len_(length) {}

  // Implicit conversion constructors
  template <size_t N>
  constexpr Span(T(  // NOLINT(google-explicit-constructor)
      &a ABSL_ATTRIBUTE_LIFETIME_BOUND)[N]) noexcept
      : Span(a, N) {}

  // Explicit reference constructor for a mutable `Span<T>` type. Can be
  // replaced with MakeSpan() to infer the type parameter.
  template <typename V, typename = EnableIfConvertibleFrom<V>,
            typename = EnableIfValueIsMutable<V>,
            typename = span_internal::EnableIfNotIsView<V>>
  explicit Span(
      V& v
          ABSL_ATTRIBUTE_LIFETIME_BOUND) noexcept  // NOLINT(runtime/references)
      : Span(span_internal::GetData(v), v.size()) {}

  // Implicit reference constructor for a read-only `Span<const T>` type
  template <typename V, typename = EnableIfConvertibleFrom<V>,
            typename = EnableIfValueIsConst<V>,
            typename = span_internal::EnableIfNotIsView<V>>
  // NOLINTNEXTLINE(google-explicit-constructor)
  constexpr Span(const V& v ABSL_ATTRIBUTE_LIFETIME_BOUND) noexcept
      : Span(span_internal::GetData(v), v.size()) {}
```
