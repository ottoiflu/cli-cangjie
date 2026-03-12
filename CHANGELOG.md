# CHANGELOG

本文件记录版本变更历史，遵循 [语义化版本 2.0.0](https://semver.org/lang/zh-CN/) 规范。

## [0.2.0] - 2026-03-12

### 新增
- **智能拼写纠错 (Did-You-Mean)**：当用户输入错误的命令或选项时，基于 Levenshtein 编辑距离算法（阈值 0.7）自动推荐最接近的正确选项
  - 支持命令名称纠错：`Unknown command 'lnt'. Did you mean 'lint'?`
  - 支持选项名称纠错：`Unknown option '--confi'. Did you mean '--config'?`
  - 大小写不敏感匹配
- **ANSI 终端样式引擎** (`style.cj`)：内置终端富文本输出
  - 支持加粗、下划线、斜体、暗淡等样式
  - 支持 14 种前景色（标准色 + 亮色）
  - 自动检测 `NO_COLOR` 环境变量，自动退化为纯文本
  - 支持手动开关颜色模式
- **结构化诊断系统** (`diagnostic.cj`)：对标 Rust 编译器 / Clippy 的四级语义化输出
  - `Error`、`Warning`、`Help`、`Note` 四种诊断级别
  - 支持错误上下文定位：显示原始输入并用 `^` 指向错误 token 位置
  - 支持附加提示行 (`hint`)
  - `DiagnosticRenderer` 渲染器统一格式化输出
- **Levenshtein 编辑距离库** (`suggest.cj`)：可复用的字符串相似度算法
  - `levenshteinDistance()` — 精确编辑距离
  - `similarity()` — 归一化相似度 (0.0~1.0)
  - `findSuggestion()` / `findAllSuggestions()` — 候选建议查找

### 变更
- `App.formatError()` 升级为使用诊断系统：错误输出包含结构化标签、上下文定位和帮助提示
- `Parser.resolveFlag()` 在找不到 flag 时自动搜索相似名称并给出建议
- 子命令路由在未匹配时自动执行 Did-You-Mean 检查

### 测试
- 新增 `SuggestTest` (14 用例)：编辑距离、相似度、建议查找
- 新增 `StyleTest` (10 用例)：颜色开关、各样式类型、全色彩测试
- 新增 `DiagnosticTest` (9 用例)：四级诊断渲染、上下文定位、颜色开关
- 新增 `DidYouMeanIntegrationTest` (6 用例)：端到端纠错建议验证
- 测试总数：87 → 126 (新增 39 用例，通过率 100%)

## [0.1.0] - 2026-03-12

### 新增
- 核心路由与基础解析引擎
- 命令树构建 (Command Builder)：多级子命令、别名系统
- Flag/Option/Argument 多形态参数捕获
- 参数强类型转换：Int64、Float64、Bool、String
- `--help`/`--version` 自动注入与生成
- `mockRun()` 内存级测试沙箱
- 87 个测试用例全部通过
