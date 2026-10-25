# fmt —— 公开面控制与 const/string_view 纪律

## 出处

fmtlib/fmt @ include/fmt/core.h（许可证：MIT，master，2026-10-25 抓取）

## 看什么

1. 公开面控制：`to_string_view` 三个重载全部关在 `detail` 里，注释明说它不是扩展点；对外只承诺 `basic_string_view`。公开 API 宁可自带 `fmt::basic_string_view` 也不用 `std::string_view`，避免库与调用方 `-std` 不一致时的 ABI 问题（core.h:512 起进入 `FMT_BEGIN_EXPORT` 公开区，514-520 说明自带视图的理由）。
2. const/string_view 纪律：参数一律 `const T&`，返回值一律 `basic_string_view`，全程 `constexpr`。字符指针、类 string 容器、已有视图三种输入归一到一个零拷贝视图，不产生临时 `std::string`。
3. 测试密度：视图契约逐项覆盖——构造、长度、比较、constexpr 各一个独立 TEST（test/core-test.cc:44-118），constexpr 路径即使要 `#if FMT_USE_CONSTEVAL` 也单独测。core.h 对应的 core-test.cc 约 927 行 / 47 个 TEST；新重载没有对应用例，视为没写完。

## 不看什么

不要抄它的兼容层与宏：`FMT_BEGIN_EXPORT` / `FMT_END_EXPORT`、`FMT_BEGIN_NAMESPACE`、`FMT_MODULE`，以及按编译器版本分叉的 `#if` 分支，都是为跨标准、跨工具链兼容服务的。新代码目标明确时直接写普通类与普通命名空间，不需要这套脚手架。

## 样例

include/fmt/core.h:943-967

```cpp
// Constructs fmt::basic_string_view<Char> from types implicitly convertible
// to it, deducing Char. Explicitly convertible types such as the ones returned
// from FMT_STRING are intentionally excluded.
template <typename Char, FMT_ENABLE_IF(is_code_unit<Char>::value)>
constexpr auto to_string_view(const Char* s) -> basic_string_view<Char> {
  return s;
}
template <typename T, FMT_ENABLE_IF(is_std_string_like<T>::value)>
constexpr auto to_string_view(const T& s)
    -> basic_string_view<typename T::value_type> {
  return s;
}
template <typename Char>
constexpr auto to_string_view(basic_string_view<Char> s)
    -> basic_string_view<Char> {
  return s;
}

template <typename T, typename Enable = void>
struct has_to_string_view : std::false_type {};
// detail:: is intentional since to_string_view is not an extension point.
template <typename T>
struct has_to_string_view<
    T, void_t<decltype(detail::to_string_view(std::declval<T>()))>>
    : std::true_type {};
```
