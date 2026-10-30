# 抽象的度 —— 代价要能被调用方看见

## 出处

facebook/folly @ folly/Function.h（许可证：Apache-2.0，main，2026-10-28 抓取）

## 看什么

1. 同一个库给两档，而不是一档通吃：需要拥有时用 `Function`（可能堆分配、不可拷贝），只需要调用时用 `FunctionRef`（两个指针、零分配、引用语义），后者明确写「接受 `FunctionRef` 的函数只应调用它，不应存副本」（`Function.h:1033-1051`）。抽象的第一件事是选档位，不是选有无。
2. 代价暴露出来，而不是吞掉：`heapAllocatedMemory()` 返回 `0` 表示 callable 内联在对象里、没有额外分配（`:906-913`）。调用方可以实测「这次类型擦除值不值」，而不是靠猜或靠 benchmark 才知道。
3. 抽象只承担必要的语义：注释开头就说明它不可拷贝、也不要求被包装对象可拷贝（`:25-26`、`:40-42`）——为了不把拷贝语义强加给调用方，宁可自己放弃拷贝能力。取舍的方向是「少承诺」，不是「多兼容」。
4. 已知缺陷写进头文件：`std::function` 允许 const 引用调用非 const `operator()`，folly 用 Foo / Bar 两段例子把这个坑讲清楚（`:44-49`、`:60-71`），并给出自己的修法（函数类型里带 const 才能 const 调用）。缺陷是接口的一部分，写在接口旁边，而不是写在 issue 里。

## 不看什么

不要抄 `Op::` 枚举 + `exec_` 函数指针表这套手写 vtable（`operator bool` 直接读 `exec_ != nullptr`，`:904`）：它服务的是小对象内联——`heapAllocatedMemory()` 能返回 `0` 正是因为有这块内联缓冲（`:906-909`），代价是每个操作都要额外维护一条分派路径。业务代码里的抽象边界用 `virtual` 或 `std::function` 就够；为省一次堆分配自己搓 vtable，是把库的成本搬进产品。

## 样例

folly/Function.h:1033-1051（借用档：两个指针，零分配）

```cpp
/**
 * @class folly::FunctionRef
 *
 * A reference wrapper for callable objects
 *
 * FunctionRef is similar to std::reference_wrapper, but the template parameter
 * is the function signature type rather than the type of the referenced object.
 * A folly::FunctionRef is cheap to construct as it contains only a pointer to
 * the referenced callable and a pointer to a function which invokes the
 * callable.
 *
 * The user of FunctionRef must be aware of the reference semantics: storing a
 * copy of a FunctionRef is potentially dangerous and should be avoided unless
 * the referenced object definitely outlives the FunctionRef object. Thus any
 * function that accepts a FunctionRef parameter should only use it to invoke
 * the referenced function and not store a copy of it. Knowing that FunctionRef
 * itself has reference semantics, it is generally okay to use it to reference
 * lambdas that capture by reference.
 */
```

folly/Function.h:900-913（拥有档：代价可查）

```cpp
  /**
   * Returns `true` if this `Function` contains a callable, i.e. is
   * non-empty.
   */
  explicit operator bool() const noexcept { return exec_ != nullptr; }

  /**
   * Returns the size of the allocation made to store the callable on the
   * heap. If `0` is returned, there has been no additional memory
   * allocation because the callable is stored within the `Function` object.
   */
  std::size_t heapAllocatedMemory() const noexcept {
    return exec(Op::HEAP, &data_, nullptr);
  }
```
