# Go 速查

- **gofmt + golint** 标配，提交前 `go vet`
- **error 不忽略**：向上 wrap，用 `fmt.Errorf("xxx: %w", err)`
- **context 贯穿**：IO 操作必须带 context，不传 `context.Background()` 到深层
- **goroutine 必有退出条件**：用 channel 或 context 控制生命周期
- **接口小而精**：1-3 个方法，用 `io.Reader` 那种粒度
- **测试**：`*_test.go`，表格驱动测试优先
- **风格**：Effective Go
