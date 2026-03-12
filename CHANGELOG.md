# CHANGELOG

本文件记录版本变更历史，遵循 [语义化版本 2.0.0](https://semver.org/lang/zh-CN/) 规范。

## [0.4.0] - 2026-03-12

### 新增
- **Golden Files 快照测试引擎** (`snapshot.cj`)：对标 Rust Clippy 的 `.stderr` 比对方案
  - `Snapshot.compare(name, actual)` — 与磁盘 `.golden` 文件比对
  - `Snapshot.update(name, actual)` — bless 模式更新快照
  - 首次运行自动创建 golden 文件
  - 不匹配时生成 `.golden.new` 文件和行级 diff 描述
  - 支持自定义快照目录
- **交互式输入模拟** (`input.cj`)：预设 stdin 输入流用于测试 Prompt 交互
  - `InputMock` — 输入队列管理：`addLine()`、`addLines()`、`readLine()`、`reset()`
  - `Prompt` — 交互式输入辅助：`ask()`、`askOrDefault()`、`confirm()`、`select()`
  - 支持在 `mockRun` action 中使用 Prompt 进行自动化交互测试

### 测试
- 新增 `SnapshotTest` (9 用例)：创建/比对/更新/diff/Help 稳定性/错误稳定性/UI 回退检测
- 新增 `InputMockTest` (5 用例)：读取/EOF/状态/重置/批量
- 新增 `PromptTest` (9 用例)：文本/默认值/确认/选择/Action 集成
- 测试总数：146 → 169 (新增 23 用例，通过率 100%)

## [0.3.0] - 2026-03-12

### 新增
- **生命周期钩子系统**：命令执行前后的精细控制
  - `persistentPreRun` / `persistentPostRun`：App 级钩子，跨所有子命令传播
  - `preRun` / `postRun`：命令级钩子，仅在匹配命令上触发
  - 执行顺序保证：PersistentPreRun → PreRun → Action → PostRun → PersistentPostRun
- **中间件链 (Middleware)**：可组合的请求处理管道
  - App 全局中间件：`app.use({ ctx, next => ... })`
  - 命令级中间件：`command.use({ ctx, next => ... })`
  - 支持短路机制：中间件不调用 `next()` 即可阻断后续执行
  - 多层中间件按注册顺序依次执行
- **环境变量配置合并**：三级优先级 CLI > ENV > Default
  - 显式映射：`Flag("host").envVar("DB_HOST")` 绑定特定环境变量
  - 自动前缀：`app.envPrefix("MYAPP")` → flag `db-host` 自动绑定 `MYAPP_DB_HOST`
  - 显式映射优先于自动前缀
- **Context 依赖注入**：中间件与 action 间的数据传递
  - `ctx.setValue(key, value)` / `ctx.getValue(key)` / `ctx.hasValue(key)`
  - 中间件写入的值可在后续中间件和 action 中读取

### 变更
- `Context._values` 存储类型从 `Any` 简化为 `String`，提供更安全的类型操作
- `App.mockRun()` 执行流程重构：解析 → 环境变量合并 → 生命周期钩子 → 中间件链 → Action

### 测试
- 新增 `LifecycleTest` (6 用例)：钩子执行顺序、Persistent 传播、无钩子兼容
- 新增 `MiddlewareTest` (5 用例)：全局/本地中间件、链式调用、短路、钩子协作
- 新增 `EnvVarTest` (5 用例)：显式映射、自动前缀、优先级链、缺省回退
- 新增 `ContextValueTest` (4 用例)：存取、覆盖、存在性、中间件传递
- 测试总数：126 → 146 (新增 20 用例，通过率 100%)

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
