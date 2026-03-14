# Cangjie CLI Framework — API 参考文档

> 版本：v1.1.0 (M12) · 包名：`cli` · 工具链：cjc 1.0.5 + cjpm

本文档列出框架全部公开 API，按模块分组，方便检索。

---

## 目录

- [类型别名](#类型别名)
- [App — 应用入口](#app--应用入口)
- [Command — 命令定义](#command--命令定义)
- [Flag — 选项定义](#flag--选项定义)
- [Argument — 位置参数](#argument--位置参数)
- [Context — 运行时上下文](#context--运行时上下文)
- [Parser — 解析引擎](#parser--解析引擎)
- [类型与枚举](#类型与枚举)
- [异常体系](#异常体系)
- [诊断系统](#诊断系统)
- [终端样式](#终端样式)
- [拼写建议](#拼写建议)
- [本地化](#本地化)
- [配置管道](#配置管道)
- [输入与交互](#输入与交互)
- [交互组件](#交互组件)
- [高级功能](#高级功能)
- [Shell 补全](#shell-补全)
- [快照测试](#快照测试)
- [示例构建器](#示例构建器)

---

## 类型别名

```cangjie
public type ActionHandler  = (Context) -> Int64
public type HookHandler    = (Context) -> Unit
public type Middleware      = (Context, () -> Int64) -> Int64
```

| 别名            | 用途                                           |
| --------------- | ---------------------------------------------- |
| `ActionHandler` | 命令的主执行逻辑，返回退出码                   |
| `HookHandler`   | 生命周期钩子（PreRun / PostRun 等）            |
| `Middleware`    | 中间件，接收上下文与 `next` 闭包，可短路或包装 |

---

## App — 应用入口

> 源码：`src/app.cj`

### 构造

```cangjie
public init(name: String)
```

### 构建器方法（返回 `This`）

| 方法                            | 说明                                           |
| ------------------------------- | ---------------------------------------------- |
| `description(desc)`             | 设置应用描述                                   |
| `version(ver)`                  | 设置版本号                                     |
| `author(auth)`                  | 设置作者                                       |
| `command(subCmd)`               | 添加子命令                                     |
| `commands(subs)`                | 批量添加子命令                                 |
| `flag(f)`                       | 添加根级别 Flag                                |
| `flags(fs)`                     | 批量添加 Flag                                  |
| `argument(arg)`                 | 添加位置参数                                   |
| `arguments(args)`               | 批量添加位置参数                               |
| `action(handler)`               | 设置根命令的执行逻辑                           |
| `envPrefix(prefix)`             | 设置环境变量前缀（如 `"APP"` → `APP_DB_HOST`） |
| `use(mw)`                       | 注册全局中间件                                 |
| `configLoader(loader)`          | 注入配置加载器                                 |
| `configFile(name)`              | 设置配置文件名                                 |
| `configPathEnvVar(envVarName)`  | 通过环境变量指定配置文件路径                   |
| `versionInfo(info)`             | 注入富版本信息                                 |
| `helpWidth(width)`              | 设置帮助文本折行宽度                           |
| `globalFlag(f)`                 | 添加全局 Flag（子命令继承）                    |
| `globalFlags(fs)`               | 批量添加全局 Flag                              |
| `signalHandler(handler)`        | 注册信号处理器                                 |
| `locale(l)`                     | 注入 Locale 实现                               |
| `subcommandRequired(r!: Bool)`  | 强制必须指定子命令（默认 `true`）              |
| `argRequiredElseHelp(r!: Bool)` | 无参数时自动打印帮助（默认 `true`）            |
| `persistentPreRun(hook)`        | 全局前置钩子                                   |
| `persistentPostRun(hook)`       | 全局后置钩子                                   |

### 执行方法

| 方法                                      | 签名                            | 说明                                  |
| ----------------------------------------- | ------------------------------- | ------------------------------------- |
| `run()`                                   | `() -> Int64`                   | 从 `Process.arguments` 读取参数并执行 |
| `run(args)`                               | `(Array<String>) -> Int64`      | 指定参数数组执行                      |
| `mockRun(args)`                           | `(Array<String>) -> TestResult` | 沙箱执行，捕获 stdout/stderr/exitCode |
| `mockRunWithConfig(args, configContent!)` | 见签名                          | 沙箱执行，注入配置文件内容            |

### 辅助方法

| 方法                        | 说明                   |
| --------------------------- | ---------------------- |
| `getRootCommand()`          | 获取根 `Command` 实例  |
| `getSignalHandler()`        | 获取信号处理器         |
| `generateHelp(cmd)`         | 为指定命令生成帮助文本 |
| `generateCompletion(shell)` | 生成 Shell 补全脚本    |

### 关联类型

#### SignalType

```cangjie
public enum SignalType {
    | SIGINT    // Ctrl+C (exit 130)
    | SIGTERM   // kill (exit 143)
}
```

#### SignalHandler

| 方法                  | 说明               |
| --------------------- | ------------------ |
| `onSignal(callback)`  | 注册信号回调       |
| `simulateSignal(sig)` | 模拟信号（测试用） |
| `isInterrupted()`     | 是否已收到信号     |
| `getSignalType()`     | 获取信号类型       |
| `getExitCode()`       | 获取对应退出码     |
| `reset()`             | 重置状态           |

#### TestResult

```cangjie
public class TestResult {
    public let exitCode: Int64
    public let stdout: String
    public let stderr: String
}
```

---

## Command — 命令定义

> 源码：`src/command.cj`

### 构造

```cangjie
public init(name: String)
```

### 构建器方法（返回 `This`）

| 方法                                          | 说明                   |
| --------------------------------------------- | ---------------------- |
| `description(desc)`                           | 简短描述               |
| `longAbout(text)`                             | `--help` 长描述        |
| `version(ver)`                                | 命令版本               |
| `author(auth)`                                | 作者                   |
| `alias(a)` / `aliases(arr)`                   | 别名                   |
| `command(subCmd)` / `commands(subs)`          | 子命令                 |
| `flag(f)` / `flags(fs)`                       | Flag                   |
| `argument(arg)` / `arguments(args)`           | 位置参数               |
| `action(handler)`                             | 执行逻辑               |
| `persistentPreRun(hook)`                      | 持久前置钩子           |
| `preRun(hook)`                                | 命令前置钩子           |
| `postRun(hook)`                               | 命令后置钩子           |
| `persistentPostRun(hook)`                     | 持久后置钩子           |
| `use(mw)`                                     | 中间件                 |
| `hidden(h!)`                                  | 隐藏命令               |
| `deprecated(reason, replacement!)`            | 标记弃用               |
| `deprecatedSince(reason, replacement, since)` | 带版本的弃用           |
| `example(name, desc)`                         | 示例说明               |
| `afterHelp(text)` / `beforeHelp(text)`        | 帮助文本追加/前置      |
| `subcommandGroup(g)`                          | 子命令分组名           |
| `subcommandRequired(r!)`                      | 强制必须指定子命令     |
| `argRequiredElseHelp(r!)`                     | 无参数时自动打印帮助   |
| `requireGroup(name, members)`                 | 至少使用一个 Flag 的组 |
| `mutuallyExclusiveGroup(name, members)`       | 互斥 Flag 组           |

### 查询方法

| 方法                      | 返回                          | 说明                   |
| ------------------------- | ----------------------------- | ---------------------- |
| `getName()`               | `String`                      | 命令名                 |
| `getDescription()`        | `Option<String>`              | 描述                   |
| `getSubcommands()`        | `ArrayList<Command>`          | 子命令列表             |
| `getSubcommandMap()`      | `HashMap<String, Command>`    | 子命令映射（含别名）   |
| `getFlags()`              | `ArrayList<Flag>`             | Flag 列表              |
| `getArguments()`          | `ArrayList<Argument>`         | 位置参数列表           |
| `getAction()`             | `Option<ActionHandler>`       | 执行逻辑               |
| `isHidden()`              | `Bool`                        | 是否隐藏               |
| `isDeprecated()`          | `Bool`                        | 是否弃用               |
| `isSubcommandRequired()`  | `Bool`                        | 子命令是否必需         |
| `isArgRequiredElseHelp()` | `Bool`                        | 无参时是否打印帮助     |
| `getLongAbout()`          | `Option<String>`              | 长描述                 |
| `getExamples()`           | `ArrayList<(String, String)>` | 示例列表               |
| `findSubcommand(name)`    | `Option<Command>`             | 按名称/别名查找子命令  |
| `findFlag(name)`          | `Option<Flag>`                | 按长名/别名查找 Flag   |
| `findFlagByShort(c)`      | `Option<Flag>`                | 按短名查找 Flag        |
| `allCommandNames()`       | `ArrayList<String>`           | 所有子命令名（含别名） |
| `allFlagNames()`          | `ArrayList<String>`           | 所有 Flag 名（含别名） |

---

## Flag — 选项定义

> 源码：`src/flag.cj`

### 构造

```cangjie
public init(longName: String)
```

### 构建器方法（返回 `This`）

| 方法                                          | 说明                                                                |
| --------------------------------------------- | ------------------------------------------------------------------- |
| `short(s: Rune)`                              | 短名（如 `r'v'`）                                                   |
| `description(d)`                              | 简短描述                                                            |
| `longHelp(text)`                              | `--help` 长描述                                                     |
| `group(g)`                                    | 分组名                                                              |
| `required(r)`                                 | 是否必需                                                            |
| `defaultValue(v)`                             | 默认值                                                              |
| `valueType(t: ValueType)`                     | 值类型（`StringType`/`Int64Type`/`Float64Type`/`BoolType`）         |
| `action(a: FlagAction)`                       | 动作类型（`Set`/`SetTrue`/`SetFalse`/`Append`/`Count`/`Terminate`） |
| `asBool()`                                    | 快捷设置为 `SetTrue` + `BoolType`                                   |
| `envVar(e)`                                   | 绑定环境变量                                                        |
| `alias(a)`                                    | 别名                                                                |
| `conflictsWith(flagName)`                     | 互斥 Flag                                                           |
| `requires(flagName)`                          | 依赖 Flag                                                           |
| `hidden(h!)`                                  | 隐藏                                                                |
| `validator(fn, message!)`                     | 自定义验证器                                                        |
| `deprecated(reason, replacement!)`            | 弃用                                                                |
| `deprecatedSince(reason, replacement, since)` | 带版本弃用                                                          |
| `choices(values: Array<String>)`              | 枚举值约束                                                          |
| `delimiter(d: Rune)`                          | 值分隔符（如 `r','`）                                               |
| `valueName(name)`                             | 自定义值占位名（帮助文本中显示）                                    |
| `valueHint(hint: ValueHint)`                  | 值类型提示（Shell 补全用）                                          |
| `allowHyphenValues(allow!)`                   | 允许以 `-` 开头的值                                                 |

### 查询方法

| 方法                     | 返回                | 说明                 |
| ------------------------ | ------------------- | -------------------- |
| `getLongName()`          | `String`            | 长名                 |
| `getShortName()`         | `Option<Rune>`      | 短名                 |
| `getDescription()`       | `Option<String>`    | 描述                 |
| `getLongHelp()`          | `Option<String>`    | 长帮助               |
| `getGroup()`             | `String`            | 分组                 |
| `isRequired()`           | `Bool`              | 是否必需             |
| `getDefaultValue()`      | `Option<String>`    | 默认值               |
| `getValueType()`         | `ValueType`         | 值类型               |
| `getAction()`            | `FlagAction`        | 动作类型             |
| `getEnvVar()`            | `Option<String>`    | 环境变量             |
| `getAliases()`           | `ArrayList<String>` | 别名列表             |
| `getConflicts()`         | `ArrayList<String>` | 互斥列表             |
| `getRequires()`          | `ArrayList<String>` | 依赖列表             |
| `isHidden()`             | `Bool`              | 是否隐藏             |
| `getChoices()`           | `ArrayList<String>` | 枚举值列表           |
| `hasChoices()`           | `Bool`              | 是否有枚举约束       |
| `getDelimiter()`         | `Option<Rune>`      | 分隔符               |
| `getValueName()`         | `Option<String>`    | 自定义值名           |
| `getValueHint()`         | `ValueHint`         | 值提示               |
| `getAllowHyphenValues()` | `Bool`              | 是否允许连字符值     |
| `getValuePlaceholder()`  | `String`            | 帮助文本中的占位显示 |
| `isBoolFlag()`           | `Bool`              | 是否为布尔开关       |
| `isCount()`              | `Bool`              | 是否为计数器         |
| `isTerminate()`          | `Bool`              | 是否为终止动作       |
| `matches(name)`          | `Bool`              | 长名/别名匹配        |
| `matchesShort(c)`        | `Bool`              | 短名匹配             |

---

## Argument — 位置参数

> 源码：`src/argument.cj`

### 构造

```cangjie
public init(name: String)
```

### 构建器方法（返回 `This`）

| 方法                          | 说明     |
| ----------------------------- | -------- |
| `description(d)`              | 描述     |
| `required(r)`                 | 是否必需 |
| `defaultValue(v)`             | 默认值   |
| `valueType(t)`                | 值类型   |
| `variadic(v)`                 | 变长参数 |
| `minCount(n)` / `maxCount(n)` | 数量约束 |

### 查询方法

| 方法                              | 返回             |
| --------------------------------- | ---------------- |
| `getName()`                       | `String`         |
| `getDescription()`                | `Option<String>` |
| `isRequired()`                    | `Bool`           |
| `getDefaultValue()`               | `Option<String>` |
| `getValueType()`                  | `ValueType`      |
| `isVariadic()`                    | `Bool`           |
| `getMinCount()` / `getMaxCount()` | `Int64`          |

---

## Context — 运行时上下文

> 源码：`src/context.cj`

### Flag 操作

| 方法                                 | 说明                                   |
| ------------------------------------ | -------------------------------------- |
| `setFlag(name, value)`               | 设值                                   |
| `appendFlag(name, value)`            | 追加值（`Append` 模式）                |
| `getFlag(name)`                      | 获取单值 `Option<String>`              |
| `getFlagAll(name)`                   | 获取所有值 `Option<ArrayList<String>>` |
| `getFlagOrDefault(name, defaultVal)` | 获取值或默认                           |
| `get<T>(name)`                       | 泛型获取（需 `Parsable<T>`）           |
| `getAll<T>(name)`                    | 泛型获取所有值                         |
| `getString(name)`                    | 获取字符串                             |
| `getBoolFlag(name)`                  | 获取布尔值                             |
| `getInt64Flag(name)`                 | 获取 Int64                             |
| `hasFlag(name)`                      | 是否存在                               |

### 位置参数

| 方法                 | 说明                         |
| -------------------- | ---------------------------- |
| `addArgument(value)` | 添加位置参数                 |
| `getArgument(index)` | 按索引获取 `Option<String>`  |
| `getArguments()`     | 获取全部 `ArrayList<String>` |
| `argumentCount()`    | 数量                         |

### 命令路径

| 方法                    | 说明                                     |
| ----------------------- | ---------------------------------------- |
| `pushCommandPath(name)` | 推入命令路径                             |
| `getCommandPathStr()`   | 获取路径字符串（如 `"app cloud start"`） |

### 自定义值存储（DI）

| 方法                   | 说明                  |
| ---------------------- | --------------------- |
| `setValue(key, value)` | 存储自定义值          |
| `getValue(key)`        | 读取 `Option<String>` |
| `hasValue(key)`        | 是否存在              |

### 显式标记

| 方法                 | 说明                 |
| -------------------- | -------------------- |
| `markExplicit(name)` | 标记 Flag 为显式设置 |
| `isExplicit(name)`   | 是否为显式设置       |
| `hasAnyExplicit()`   | 是否有任何显式 Flag  |

### Pass-Through 参数

| 方法                     | 说明               |
| ------------------------ | ------------------ |
| `addPassthroughArg(arg)` | 添加 `--` 后的参数 |
| `getPassthroughArgs()`   | 获取全部           |
| `hasPassthroughArgs()`   | 是否存在           |

### 工具函数

```cangjie
public func parseSimpleInt(s: String): Int64
```

---

## Parser — 解析引擎

> 源码：`src/parser.cj`

| 方法                                                 | 说明                                                             |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| `parse(rootCmd, rawArgs)`                            | 完整解析（路由 + 验证 + 配置合并），返回 `(Command, Context)`    |
| `parseOnly(rootCmd, rawArgs)`                        | 仅解析（不做验证），返回 `(Command, Context, ArrayList<String>)` |
| `finalize(rootCmd, matchedCmd, ctx, positionalArgs)` | 后期验证（类型转换、约束检查、参数赋值）                         |

---

## 类型与枚举

> 源码：`src/types.cj`

### ValueType

```cangjie
public enum ValueType {
    | StringType | Int64Type | Float64Type | BoolType
}
```

### FlagAction

```cangjie
public enum FlagAction {
    | Set                       // 默认赋值
    | SetTrue                   // 布尔开启
    | SetFalse                  // 布尔关闭
    | Append                    // 追加多值
    | Count                     // 出现次数计数（如 -vvv → 3）
    | Terminate(() -> String)   // 终止回调（--help / --version）
}
```

### ValueHint

```cangjie
public enum ValueHint {
    | Default      // 无特殊提示
    | AnyPath      // 任意路径
    | FilePath     // 文件路径
    | DirPath      // 目录路径
    | CommandName  // 命令名
    | Username     // 用户名
    | Hostname     // 主机名
    | Url          // URL
    | EmailAddress // 邮箱地址
}
```

### 工具函数

| 函数                                  | 说明                                  |
| ------------------------------------- | ------------------------------------- |
| `isValidInt(s)`                       | 验证整数格式                          |
| `isValidFloat(s)`                     | 验证浮点格式                          |
| `normalizeBool(s)`                    | 规范化布尔值（`"yes"` → `"true"` 等） |
| `validateAndConvert(raw, targetType)` | 类型验证与转换                        |

---

## 异常体系

> 源码：`src/errors.cj`

```
Exception
└── CliException              # CLI 框架基类
    ├── ParseException        # 解析错误（exit 2）
    ├── TypeConversionException  # 类型转换错误
    ├── ValidationException   # 验证错误
    ├── TerminateException    # 终止（--help / --version 触发）
    └── AggregateException    # 聚合错误（多错误批量报告）
```

### AggregateException

| 方法                              | 说明             |
| --------------------------------- | ---------------- |
| `getErrors()`                     | 获取所有错误消息 |
| `getWarnings()`                   | 获取所有警告消息 |
| `errorCount()` / `warningCount()` | 数量统计         |

---

## 诊断系统

> 源码：`src/diagnostic.cj`

### DiagnosticLevel

```cangjie
public enum DiagnosticLevel { Note | Help | Warning | Error }
```

### Diagnostic 构建

```cangjie
let d = Diagnostic(Error, "Unknown option '--confi'")
    .hint("Did you mean '--config'?")
    .context("tool --confi value")
    .position(5)
```

### DiagnosticRenderer

```cangjie
let renderer = DiagnosticRenderer()       // 或传入自定义 StyleEngine
let output = renderer.render(d)           // 渲染单条
let output = renderer.renderAll(diags)    // 批量渲染
```

### 快捷构造函数

| 函数               | 等价                       |
| ------------------ | -------------------------- |
| `errorDiag(msg)`   | `Diagnostic(Error, msg)`   |
| `warningDiag(msg)` | `Diagnostic(Warning, msg)` |
| `helpDiag(msg)`    | `Diagnostic(Help, msg)`    |
| `noteDiag(msg)`    | `Diagnostic(Note, msg)`    |

---

## 终端样式

> 源码：`src/style.cj`

### Color 枚举

```cangjie
Red | Green | Yellow | Blue | Magenta | Cyan | White
BrightRed | BrightGreen | BrightYellow | BrightBlue | BrightMagenta | BrightCyan | BrightWhite
```

### StyleEngine

| 方法                 | 说明                     |
| -------------------- | ------------------------ |
| `init()`             | 自动检测 `NO_COLOR` 环境 |
| `init(colorEnabled)` | 手动指定                 |
| `isColorEnabled()`   | 是否启用颜色             |
| `bold(text)`         | 粗体                     |
| `underline(text)`    | 下划线                   |
| `italic(text)`       | 斜体                     |
| `dim(text)`          | 暗淡                     |
| `color(text, c)`     | 着色                     |
| `boldColor(text, c)` | 粗体 + 着色              |

---

## 拼写建议

> 源码：`src/suggest.cj`

| 函数                                                        | 说明                         |
| ----------------------------------------------------------- | ---------------------------- |
| `levenshteinDistance(a, b)`                                 | Damerau-Levenshtein 编辑距离 |
| `similarity(a, b)`                                          | 相似度（0.0 ~ 1.0）          |
| `findSuggestion(input, candidates)`                         | 查找最佳建议（阈值 0.7）     |
| `findSuggestionWithThreshold(input, candidates, threshold)` | 自定义阈值                   |
| `findAllSuggestions(input, candidates, threshold)`          | 所有超过阈值的建议           |

---

## 本地化

> 源码：`src/locale.cj`

### Locale 接口

提供 60+ 方法，覆盖所有用户可见文本。所有方法均有英文默认实现，仅需覆盖需要翻译的方法。

| 类别          | 方法数 | 示例                                                                |
| ------------- | ------ | ------------------------------------------------------------------- |
| 诊断标签      | 4      | `labelError()` → `"error"`                                          |
| 帮助文档      | 11     | `helpUsagePrefix()` → `"Usage: "`                                   |
| 命令/选项错误 | 9      | `errUnknownCommand(name)`                                           |
| 值校验        | 4      | `errInvalidChoiceValue(value, flag, choices)`                       |
| 约束错误      | 5      | `errFlagConflict(flag, conflict)`, `errSubcommandRequired(cmdName)` |
| 位置参数      | 3      | `errArgRequired(name)`                                              |
| 类型转换      | 3      | `errTypeBool(value)`                                                |
| 错误聚合      | 4      | `summaryErrors(count)`                                              |
| 配置文件      | 5      | `cfgExpectedFormat()`                                               |
| 弃用警告      | 4      | `deprecatedWarning(itemType, itemName)`                             |
| 信号处理      | 1      | `signalTerminated(sigName)`                                         |
| 交互组件      | 3      | `widgetConfirmYes()`                                                |

### Messages 单例

```cangjie
Messages.setLocale(ChineseLocale())   // 全局注入
Messages.locale().labelError()         // 获取当前 Locale
Messages.reset()                       // 恢复默认
```

---

## 配置管道

> 源码：`src/config.cj`

### ConfigLoader

| 方法                                              | 说明                   |
| ------------------------------------------------- | ---------------------- |
| `configFileName(name)` / `configFileNames(names)` | 配置文件名             |
| `configPathEnvVar(envVarName)`                    | 通过环境变量指定路径   |
| `knownKey(key)` / `knownKeys(keys)`               | 已知配置键             |
| `knownKeysFromFlags(flags)`                       | 从 Flag 列表提取已知键 |
| `discover(startDir!)`                             | 向上查找配置文件       |
| `parse(content, filePath!)`                       | 解析配置内容           |
| `load(startDir!)`                                 | 发现 + 解析            |
| `applyToContext(data, ctx)`                       | 应用到 Context         |

### 优先级覆盖模型

```
CLI 显式参数 > 环境变量 > 配置文件 > 代码默认值
```

### ConfigError / ConfigException

错误携带文件路径、行号、行内容，支持 Did-You-Mean 建议。

---

## 输入与交互

> 源码：`src/input.cj`

### InputMock（测试用）

```cangjie
let mock = InputMock()
    .addLine("yes")
    .addLines(["alice", "42"])
mock.readLine()           // Option<String>
mock.hasMore()            // Bool
mock.consumed()           // 已消费行数
```

### Prompt

```cangjie
let prompt = Prompt(mock)     // 或 Prompt() 用真实 stdin
prompt.ask("Name?")           // Option<String>
prompt.askOrDefault("Name?", "World")
prompt.confirm("Continue?")   // Bool
prompt.select("Choose:", ["A", "B", "C"])
```

---

## 交互组件

> 源码：`src/widget.cj`

### Spinner

```cangjie
let s = Spinner(style: Dots).message("Loading...")
s.tick()
s.render()       // 当前帧
s.finish(message: "Done!")
```

### ProgressBar

```cangjie
let bar = ProgressBar(100)
    .width(40).prefix("Downloading")
bar.advance()
bar.set(50)
bar.render()     // "[████████░░░░░░░░░░░░] 50%"
```

### Confirm / Select / MultiSelect

```cangjie
Confirm("Continue?").defaultValue(true).run(mock)
Select("Choose:").options(["A", "B"]).run(mock)
MultiSelect("Pick:").options(["X", "Y", "Z"]).run(mock)
```

---

## 高级功能

> 源码：`src/advanced.cj`

### OutputFormatter

```cangjie
let entries = ArrayList<(String, String)>()
OutputFormatter.toJson(entries)
OutputFormatter.toText(entries, separator: ": ")
OutputFormatter.format(entries, Json)
```

### VersionInfo

```cangjie
VersionInfo()
    .name("tool").version("1.0.0")
    .commitHash("abc1234").buildDate("2025-01-01")
    .shortString()    // "tool 1.0.0"
    .verboseString()  // 完整多行输出
```

### DeprecationInfo

```cangjie
DeprecationInfo("Removed in v2", "use-other", "v1.5.0")
    .formatWarning("flag", "--old-flag")
```

---

## Shell 补全

> 源码：`src/completion.cj`

### ShellType

```cangjie
public enum ShellType { Bash | Zsh | Fish }
public func parseShellType(s: String): Option<ShellType>
```

### CompletionGenerator

```cangjie
let script = CompletionGenerator.generate(app.getRootCommand(), Zsh)
```

生成的脚本支持：
- 子命令补全
- Flag 长名/短名补全
- `ValueHint` 映射（`FilePath` → Zsh `_files` / Fish `-F`，`DirPath` → Zsh `_directories` 等）
- `Count` 类型 Flag 标记为可重复
- `choices()` 值补全

---

## 快照测试

> 源码：`src/snapshot.cj`

```cangjie
let snap = Snapshot(snapshotDir: "src/test/snapshots")
let result = snap.compare("test-name", actualOutput)
// result.matched / result.diff
snap.update("test-name", newBaseline)
```

---

## 示例构建器

> 源码：`src/example.cj`

```cangjie
let demoApp = buildExampleApp()  // 返回完整示例 App
```

---

## 退出码约定

| 退出码 | 含义            |
| ------ | --------------- |
| `0`    | 成功            |
| `1`    | 应用逻辑错误    |
| `2`    | 解析/使用错误   |
| `130`  | SIGINT (Ctrl+C) |
| `143`  | SIGTERM         |
