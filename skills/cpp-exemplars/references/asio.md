# asio —— 异步接口面与生命周期

## 出处

chriskohlhoff/asio @ include/asio/basic_socket.hpp（许可证：BSL-1.0，master，2026-10-25 抓取）

## 看什么

1. handler 语义写进契约：`close()` 的注释明确承诺——任何在途 send/receive/connect 操作立即取消，并以 `asio::error::operation_aborted` 完成。调用方据此区分"我的取消"和"真错误"，不必自己追踪每个 pending handler。
2. 关闭顺序：优雅关闭要先 `shutdown()` 再 `close()`，注释直接点明这是可移植行为。终止连接与释放描述符是两步，不是一步。
3. 接口面成对出现：抛异常版 `close()`（basic_socket.hpp:509-514）与 `close(asio::error_code&)` 版（540-544）并存。后者在"函数报错但描述符仍已关闭"时把错误交回调用方，错误路径的契约同样明确，不因不抛异常而含糊。

## 不看什么

不要抄它的兼容层：`ASIO_SYNC_OP_VOID_RETURN(ec)` 这类为无异常构建和旧接口保留的返回宏，`ASIO_NO_DEPRECATED` 分叉（io_context.hpp:479-511），以及 Boost.Asio 与 standalone Asio 的双形态维护（仓库根的 boostify.pl、boost_asio.manifest）。新接口用普通 `void` / `error_code` 返回即可，不必养两套签名。

## 样例

include/asio/basic_socket.hpp:516-544

```cpp
  /// Close the socket.
  /**
   * This function is used to close the socket. Any asynchronous send, receive
   * or connect operations will be cancelled immediately, and will complete
   * with the asio::error::operation_aborted error.
   *
   * @param ec Set to indicate what error occurred, if any. Note that, even if
   * the function indicates an error, the underlying descriptor is closed.
   *
   * @par Example
   * @code
   * asio::ip::tcp::socket socket(my_context);
   * ...
   * asio::error_code ec;
   * socket.close(ec);
   * if (ec)
   * {
   *   // An error occurred.
   * }
   * @endcode
   *
   * @note For portable behaviour with respect to graceful closure of a
   * connected socket, call shutdown() before closing the socket.
   */
  ASIO_SYNC_OP_VOID close(asio::error_code& ec)
  {
    impl_.get_service().close(impl_.get_implementation(), ec);
    ASIO_SYNC_OP_VOID_RETURN(ec);
  }
```
