# Git 规范（B 方案：日终逐条审核统一 push）

- 白天：本地 commit（不 push），公示提交信息定稿（commit message 一字不改）
- 日终：G 逐条审核提交 log（可插入修改：push 前窗口 rebase reword/edit/drop + 连带调整）
- push 后：只追加新 commit，不改历史
- 熔断红线：force push / 删除 / 回滚操作 → 停住等 G
- 提交信息：人可读，含「做了什么+验证证据」；**禁一切编号黑话**——台账编号（J-xx/RWF/TG/ADR 等）无背景即噪音，须自解释或省略（"修复 Pending 重复登记误取调用方状态"优于"修复 J-47"）
- **禁协作元信息进提交信息**："产物移出版本库/工作区不再变脏/QA 取阅"类治理说明不进 commit message——治理事实只落 .gitignore / 脚本头部 / README
- 文档类更新：不单独生成提交记录，与代码提交合并或攒批
