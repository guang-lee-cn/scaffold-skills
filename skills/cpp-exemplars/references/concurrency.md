# 并发 —— 锁与它保护的数据是同一个对象

## 出处

facebook/folly @ folly/Synchronized.h（许可证：Apache-2.0，main，2026-10-28 抓取）

## 看什么

1. 锁与数据不可分离：`folly::Synchronized` 把 datum 和 mutex 做成一个对象，datum 只能经 `LockedPtr` 到达（`.rlock()` / `.wlock()`），锁的生命周期就是这个指针的生命周期（`Synchronized.h:622-625`）。没有「先 lock，再自己去取数据」这两个独立步骤，也就没有第二步漏写的机会。
2. 临界区边界写在用法里，不写在注释里：文档明确建议用嵌套作用域括住 `LockedPtr`，让「锁持有多久」在代码结构上直接看得见（`:627-629`）。评审「这把锁的范围」不需要推理，读缩进即可。
3. 回调形态的入口让锁跟着调用栈走：`withLockPtr()` 把 `LockedPtr` 交给回调（`:601-615`），注释说明这样做是为了在回调内部还能 `scopedUnlock()`。锁的作用域由调用边界决定，不由某个局部变量决定。

## 不看什么

不要抄 `SynchronizedBase` 的三份特化（`Shared` / `Upgrade` / `Unique`，`:162` / `:380` / `:504`）与 `LockedPtr` / `WLockedPtr` / `RLockedPtr` 类型族。那是为了让同一套 API 同时支持 shared_mutex 的读写锁与升级锁而做的模板分派；主模板只声明不定义（`:148`），枚举里的 `Unknown` 等级（`:82`）落到它上面就是编译期错误。只有一把 `std::mutex` 的项目，一次分派就够，不必先造类型族。

## 样例

folly/Synchronized.h:622-640

```cpp
/**
 * `folly::Synchronized` pairs a datum with a mutex. The datum can only be
 * reached through a `LockedPtr`, typically acquired via `.rlock()` or
 * `.wlock()`; the mutex is held for the lifetime of the `LockedPtr`.
 *
 * It is recommended to explicitly open a new nested scope when aquiring
 * a `LockedPtr` object, to help visibly delineate the critical section and to
 * ensure that the `LockedPtr` is destroyed as soon as it is no longer needed.
 *
 * @tparam T  The type of datum to be stored.
 * @tparam Mutex  The mutex type that guards the datum. Must be Lockable.
 *
 * @refcode folly/docs/examples/folly/Synchronized.cpp
 */
template <class T, class Mutex = SharedMutex>
struct Synchronized
    : public SynchronizedBase<
          Synchronized<T, Mutex>,
          detail::kSynchronizedMutexLevel<Mutex>> {
```
