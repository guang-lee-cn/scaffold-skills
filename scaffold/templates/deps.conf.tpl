# 工具依赖清单（可选；没有这一份就跳过检查）
#
# 一行一个工具，字段用 | 分隔：
#   名字 | 验证命令 | 来源 | 定位提示 | 必需性
#
# 来源只有三种，决定「先在哪找」和「缺了怎么补」：
#   system   宿主提供。只查 PATH（不加项目路径），缺了给包管理器命令
#   project  项目 / SDK 自带。先把 <项目根>/<定位提示> 放到 PATH 最前再查；
#            自带副本不存在、却在系统 PATH 上找到了，判「来源不符」——
#            版本错配比缺失更难查，所以不让它静默通过
#   any      两者都行。先查自带，再查系统，输出里记下命中哪一种
#
# 定位提示：
#   system  -> 包名，写成 <包管理器>:<包名>，如 apt:cppcheck（支持 apt / dnf / brew）
#   project -> 相对项目根的目录，如 third_party/llvm/bin
#   any     -> 同 project；没有自带就留空
#
# 必需性：required（缺失即错误，检查退出 2）/ optional（缺失只告警）。留空按 required。
#
# 这份清单只做三件事：声明、解析、上报。不下载、不安装——
# 缺工具时把精确命令交给人执行，脚手架不动宿主。门禁脚本里的 need()
# 仍然保留作运行时兜底：清单会漂移，闸门不能指望清单。
#
# 示例（取消注释，改成项目自己的）：
# ccache|ccache --version|system|apt:ccache|required
# clang-tidy|clang-tidy --version|project|third_party/llvm/bin|required
# python3|python3 -V|any||required
# valgrind|valgrind --version|system|apt:valgrind|optional
