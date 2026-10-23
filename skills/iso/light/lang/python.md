# Python 速查

- **类型注解**：所有函数签名加 type hints，`mypy` 检查
- **虚拟环境**：`uv` 或 `venv`，`pyproject.toml` 管理依赖
- **异常**：明确捕获具体异常类型，不用裸 `except:`
- **资源**：用 `with` 上下文管理器，不用裸 `open()` / `close()`
- **测试**：`pytest`，命名 `test_<模块>_<场景>`
- **风格**：`ruff` 格式化 + lint，Black 兼容
- **日志**：`logging` 模块，不用 `print()` 调试
