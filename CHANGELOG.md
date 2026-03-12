# CHANGELOG

本文件记录版本变更历史，遵循 [语义化版本 2.0.0](https://semver.org/lang/zh-CN/) 规范。

## [0.10.0] - 2026-03-12

### 新增
- **信号处理 (Signal Handling)**：框架级 `SignalHandler` 抽象，支持 SIGINT(130)/SIGTERM(143) 信号模拟与退出码。`simulateSignal()` 用于 mockRun 测试，生命周期检查点自动检测中断
- **错误聚合 (Error Aggregation)**：`AggregateException` 收集多个验证错误（必填、约束、组）后统一报告。摘要格式 "Found X errors and Y warnings"
- **Env 类型自动协变**：环境变量值根据 Flag 的 `valueType` 自动执行类型转换（Int64/Bool/Float64），转换失败时生成包含环境变量名和目标 Flag 的友好诊断

### 变更
- `Parser.finalize()` 重构为错误聚合模式：内部使用 `collectRequiredFlagErrors`/`collectFlagConstraintErrors`/`collectFlagGroupErrors` 收集所有验证错误
- `App.applyEnvVars()` 新增类型协变：调用 `coerceEnvValue()` 根据 Flag 类型转换环境变量值
- `App.mockRunWithConfig()` 新增 `AggregateException` 处理分支，格式化多错误输出

### 测试
- 新增 `SignalHandlerTest` (6)、`ErrorAggregationTest` (5)、`EnvAutoMappingTest` (4)、`EnvTypeCoercionTest` (6)、`Phase10IntegrationTest` (5)
- 测试总数：352 → 378 (新增 26 用例，通过率 100%)

## [0.9.0] - 2026-03-12

### 新增
- **枚举值约束 (Choices)**：Flag 支持 `.choices(["text", "json", "markdown"])` 限定可选值集合，非法值时自动生成诊断报错并列出可选项，支持 Did-You-Mean 建议。对标 clap 的 `PossibleValue` / `value_parser`
- **值分隔符 (Value Delimiters)**：支持 `.delimiter(r',')` 自动按分隔符拆分 `--filter a,b,c` 为多值数组。对标 clap 的 `use_value_delimiter`
- **Pass-Through 参数**：`--` 后的参数通过 `ctx.getPassthroughArgs()` 直接访问，支持 `tool lint -- -W clippy::all` 模式。对标 Clippy 的 `cargo clippy [ARGS] -- [CLIPPY_ARGS]`
- **帮助文档增强**：支持 `.example(name, desc)` 添加 Examples 段落、`.afterHelp(text)` / `.beforeHelp(text)` 自定义帮助首尾。对标 clap 的 `after_help` / `before_help`
- **终端宽度自适应**：`.helpWidth(n)` 控制帮助文档折行宽度，默认 80 列。遵循 clig.dev 规范
- **N-Best 智能建议**：Did-You-Mean 增强为返回最多 3 条候选建议，按相似度排序。命令、Flag、Choices 均支持多候选
- **子命令分组显示**：`.subcommandGroup(name)` 支持帮助文档中按组分类显示子命令。对标 clap 的 `subcommand_help_heading`

### 变更
- `generateHelp()` 重写：支持分组渲染、choices 显示 (`<text|json|markdown>`)、Examples 段落、beforeHelp/afterHelp、终端宽度折行
- `Parser.resolveFlag()` 和子命令路由升级为 N-Best 建议（使用 `findAllSuggestions()`）
- `handleFlagValue`/`handleFlagNoEquals`/`handleShortFlagSingle` 新增 delimiter 拆分和 choices 校验

### 测试
- 新增 `ChoicesValidationTest` (5)、`ValueDelimiterTest` (5)、`PassThroughArgsTest` (4)、`HelpExamplesTest` (4)、`TerminalWidthTest` (2)、`SubcommandGroupTest` (3)、`NBestSuggestionTest` (4)、`Phase9IntegrationTest` (5)
- 测试总数：320 → 352 (新增 32 用例，通过率 100%)

## [0.8.0] - 2026-03-12

### 新增
- **Shell 补全脚本生成** (`CompletionGenerator`)：支持 Bash/Zsh/Fish 三种 Shell 的自动补全脚本生成。对标 clap_complete 的补全生成能力
- **输出格式模式** (`OutputFormatter`)：支持 `text` / `json` 输出格式切换，内置 JSON 转义和键值对渲染
- **丰富版本信息** (`VersionInfo`)：版本输出支持构建元数据（commit hash、commit date、build date、compiler）。对标 `rustc_tools_util` 的 `VersionInfo` 设计
- **标志/命令弃用系统** (`DeprecationInfo`)：支持 `.deprecated(reason, replacement)` 标记，使用时自动输出 Warning 级别迁移提示。对标 Clippy config 的 `#[conf_deprecated]` 机制
- **全局标志传播** (`globalFlag`)：App 级 Flag 自动传播至所有子命令（递归），避免重复声明

### 测试
- 新增 `BashCompletionTest` (5)、`ZshCompletionTest` (4)、`FishCompletionTest` (6)、`ShellTypeParsingTest` (1)、`OutputFormatTest` (6)、`VersionInfoTest` (9)、`DeprecationInfoTest` (4)、`DeprecatedFlagTest` (3)、`DeprecatedCommandTest` (2)、`GlobalFlagPropagationTest` (6)、`Phase8IntegrationTest` (5)
- 测试总数：269 → 320 (新增 51 用例，通过率 100%)

## [0.7.0] - 2026-03-12

### 新增
- **配置文件加载** (`ConfigLoader`)：支持 `key = value` 格式配置文件解析（兼容 TOML 子集），支持注释、引号字符串、布尔值、Section 头部
- **配置文件发现**：支持从 CWD 向上遍历查找配置文件，支持 `CONFIG_PATH` 环境变量覆盖。对标 Clippy 的 `clippy.toml` 查找逻辑
- **四级优先级管道**：CLI 显式参数 > 环境变量 > 配置文件 > 代码默认值。新增 `parseOnly`/`finalize` 分离流程确保优先级正确
- **配置错误报告**：解析失败时提供行号定位与 Did-You-Mean 建议。对标 Clippy 的 `ConfError` + `edit_distance` 字段纠错
- **Key 归一化**：连字符/下划线自动互换匹配（如 `db_host` 匹配 `db-host`）
- **`mockRunWithConfig`**：新增带配置文件内容注入的测试沙箱 API。无需磁盘文件即可端到端测试配置流

### 测试
- 新增 `ConfigParserTest` (8)、`ConfigErrorTest` (6)、`ConfigDiscoveryTest` (2)、`ConfigKeyNormalizationTest` (1)、`ConfigPriorityPipelineTest` (6)、`ConfigErrorIntegrationTest` (3)、`ParentDirTest` (4)
- 测试总数：239 → 269 (新增 30 用例，通过率 100%)

## [0.6.0] - 2026-03-12

### 新增
- **Flag 互斥约束** (`conflictsWith`)：运行时检测冲突的显式标志并生成诊断报错。对标 clap 的 `conflicts_with`
- **Flag 依赖声明** (`requires`)：指定 Flag 前置依赖，缺少时生成友好提示
- **自定义验证器** (`validator((String) -> Bool, message)`)：框架层拦截不合法值。对标 Clippy clippy_dev 的 `lint_name()` 校验器
- **隐藏标志与命令** (`hidden()`)：从 Help 输出中隐藏但仍可正常使用。对标 clap 的 `hide = true`
- **标志组验证**：`requireGroup(name, members)` (至少选一)、`mutuallyExclusiveGroup(name, members)` (最多选一)
- **显式 Flag 追踪**：Context 新增 `markExplicit()`/`isExplicit()` 区分用户输入与默认值

### 测试
- 新增 `ConflictsTest` (4 用例)、`RequiresTest` (4)、`ValidatorTest` (5)、`HiddenTest` (4)、`FlagGroupTest` (5)、`ConstraintIntegrationTest` (3)
- 测试总数：214 → 239 (新增 25 用例，通过率 100%)

## [0.5.0] - 2026-03-12

### 新增
- **交互式终端组件** (`widget.cj`)：丰富的 TUI 交互组件集
  - `Spinner` — 加载指示器：4 种动画样式 (Dots/Line/Arrow/Simple)，tick/finish/reset 状态管理
  - `ProgressBar` — 进度条：可配置宽度、填充字符、百分比/计数显示、前缀文本
  - `Confirm` — 确认组件：y/n 交互，支持默认值，与 InputMock 集成
  - `Select` — 单选组件：数字索引和文本匹配两种选择方式，支持默认选项
  - `MultiSelect` — 多选组件：逗号分隔数字输入，自动跳过无效序号

### 测试
- 新增 `SpinnerTest` (10 用例)：4 种样式帧循环、状态管理、render 输出
- 新增 `ProgressBarTest` (11 用例)：进度控制、百分比计算、render 格式、边界值
- 新增 `ConfirmWidgetTest` (7 用例)：y/n 输入、默认值、EOF、render 提示
- 新增 `SelectWidgetTest` (7 用例)：数字/文本选择、默认选项、无效输入
- 新增 `MultiSelectWidgetTest` (6 用例)：单选/多选、空格处理、无效跳过
- 新增 `WidgetIntegrationTest` (4 用例)：组件在 mockRun 端到端集成
- 测试总数：169 → 214 (新增 45 用例，通过率 100%)

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
