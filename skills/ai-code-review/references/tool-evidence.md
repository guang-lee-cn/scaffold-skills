# 工具审查规范（证据归档）

## 静态
```bash
cppcheck --version                              # 版本归档
cppcheck --enable=warning,portability --std=c++14 --error-exitcode=1 <dir> 2> raw.txt
# 原始输出归档（含版本+命令+suppress 清单——空文件=0 警告的正常形态）
```

## 动态
```bash
# ASan
cmake -B build-asan -G Ninja -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DEPROSIMA_BUILD_TESTS=ON \
  -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer" -DCMAKE_C_FLAGS="..."
# TSan（注意）
cmake -B build-tsan -G Ninja ... -DCMAKE_CXX_FLAGS="-fsanitize=thread -fno-omit-frame-pointer"
setarch x86_64 -R <test-bin>   # WSL2 必需：TSan unexpected memory mapping 规避（per-command——不改系统）
```

## 已知坑（环境类——E 台账）
| 坑 | 表现 | 处理 |
|---|---|---|
| TSan WSL2 映射失败 | FATAL: unexpected memory mapping | setarch -R（per-command）|
| TSan 全量构建失败 | blackbox 测试发现阶段失败 | 部分构建（只编译审查目标——lib + 测试子集）|
| asan 并行度异常 | -j1 异常 | 查 resource-jobs 探测（flag/ccache 影响）|

## 证据归档纪律
- 原始输出（非摘要）落 review-artifacts/（含版本/命令/suppress）
- 关键代码实证落报告（file:line 原文引用）
- 工具盲区标注（如 data race=TSan 可见/ASan 不可见——cppcheck 不查动态）
