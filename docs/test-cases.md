# 仓颉 CLI 框架 — Phase 1 测试用例说明

## 1. 概述

Phase 1（核心路由与基础解析引擎）共计 **65** 个测试用例，覆盖框架的 7 个核心模块。测试使用仓颉标准库 `std.unittest` 框架，所有用例均通过 `cjpm test` 一键运行。

## 2. 测试文件结构

| 序号 | 测试文件                  | 测试类                   | 用例数 | 对应源码          |
| ---- | ------------------------- | ------------------------ | ------ | ----------------- |
| 1    | `src/command_test.cj`     | `CommandBuilderTest`     | 6      | `src/command.cj`  |
| 2    | `src/flag_test.cj`        | `FlagDefinitionTest`     | 4      | `src/flag.cj`     |
| 3    | `src/argument_test.cj`    | `ArgumentDefinitionTest` | 3      | `src/argument.cj` |
| 4    | `src/types_test.cj`       | `TypeConversionTest`     | 10     | `src/types.cj`    |
| 5    | `src/context_test.cj`     | `ContextTest`            | 6      | `src/context.cj`  |
| 6    | `src/parser_test.cj`      | `ParserTest`             | 20     | `src/parser.cj`   |
| 7    | `src/integration_test.cj` | `AppIntegrationTest`     | 16     | `src/app.cj`      |

## 3. 各模块测试用例详解

### 3.1 命令树构建测试 (`CommandBuilderTest`) — 6 例

1. **testBasicCommandCreation**
   - 验证 `Command` 基础元数据设置（名称、描述、版本、作者），确保 Builder 链式调用正确赋值。

2. **testSubcommandRegistration**
   - 向根命令注册两个子命令 `lint` 和 `fmt`，验证子命令列表大小和名称正确性。

3. **testDeepNestedSubcommands**
   - 构建三级嵌套命令树 `tool → cloud → server → start`，逐层验证子命令链路完整。

4. **testCommandAliases**
   - 为 `install` 命令添加别名 `i` 和 `add`，验证别名列表正确存储。

5. **testFindSubcommandByName**
   - 通过名称查找子命令，验证 `Some` 匹配和 `None` 未匹配两种路径。

6. **testFindSubcommandByAlias**
   - 通过别名 `i` 查找 `install` 子命令，验证别名索引功能。

### 3.2 Flag 定义测试 (`FlagDefinitionTest`) — 4 例

1. **testBasicFlag**
   - 验证 Flag 的长名、短名、描述、默认值以及 `isBoolFlag == false` 等属性。

2. **testBoolFlag**
   - 使用 `.asBool()` 创建布尔开关 Flag，验证 `isBoolFlag == true` 且默认值自动设为 `"false"`。

3. **testFlagWithTypeAndRequired**
   - 设置 Flag 类型为 `Int64Type` 且标记为必填，验证 `isRequired()` 返回 `true`。

4. **testFlagMatches**
   - 为 Flag 设置长名 `output`、短名 `o` 和别名 `out`，验证 `matches()` 方法对三者均返回 `true`，对无关名称返回 `false`。

### 3.3 Argument 定义测试 (`ArgumentDefinitionTest`) — 3 例

1. **testBasicArgument**
   - 验证位置参数的名称、描述、必填属性和 `isVariadic == false` 默认值。

2. **testVariadicArgument**
   - 创建变长参数并设置 `minCount(1)` / `maxCount(10)`，验证变长标志和数量阈值。

3. **testTypedArgument**
   - 为参数指定 `Int64Type` 类型和默认值 `"5"`，验证类型化参数定义。

### 3.4 类型转换测试 (`TypeConversionTest`) — 10 例

1. **testValidInt**
   - 验证 `isValidInt()` 对正常整数字符串（正数、负数、带 `+` 号、零）返回 `true`。

2. **testInvalidInt**
   - 验证 `isValidInt()` 对空串、字母、浮点数、孤立负号返回 `false`。

3. **testValidFloat**
   - 验证 `isValidFloat()` 对标准浮点数、负浮点、纯整数、`0.0` 返回 `true`。

4. **testInvalidFloat**
   - 验证 `isValidFloat()` 对空串、字母、多小数点格式返回 `false`。

5. **testBoolConversion**
   - 验证 `normalizeBool()` 将 `true/false/yes/no/1/0` 统一标准化为 `"true"` 或 `"false"`。

6. **testBoolConversionError**
   - 输入非法布尔值 `"maybe"`，验证抛出 `TypeConversionException` 且消息包含 `"Cannot convert"`。

7. **testValidateAndConvertString**
   - 验证 `validateAndConvert()` 对 `StringType` 类型直接透传字符串值。

8. **testValidateAndConvertInt**
   - 验证 `validateAndConvert()` 对 `Int64Type` 类型正常通过校验。

9. **testValidateAndConvertIntError**
   - 输入 `"abc"` 作为 `Int64Type`，验证抛出 `TypeConversionException`。

10. **testSimpleIntParse**
    - 验证 `parseSimpleInt()` 对正数、负数、零的实际数值解析正确性。

### 3.5 Context 测试 (`ContextTest`) — 6 例

1. **testFlagStorage**
   - 向 Context 存入两个 Flag 值，验证已存 Flag 返回 `Some`，不存在的 Flag 返回 `None`。

2. **testBoolFlagHelper**
   - 验证 `getBoolFlag()` 对 `"true"` 返回 `true`，`"false"` 返回 `false`，缺失 Flag 返回 `false`。

3. **testGetFlagOrDefault**
   - 验证 `getFlagOrDefault()` 有值时返回实际值，无值时返回指定默认值。

4. **testArguments**
   - 向 Context 添加两个位置参数，验证 `argumentCount()`、按索引获取、越界返回 `None`。

5. **testCommandPath**
   - 依次压入三级命令路径 `tool → cloud → deploy`，验证 `getCommandPathStr()` 拼接结果。

6. **testInt64FlagHelper**
   - 验证 `getInt64Flag()` 将字符串 Flag 值正确转换为 `Int64` 类型。

### 3.6 解析引擎测试 (`ParserTest`) — 20 例

1. **testParseLongFlag** — 解析 `--verbose` 和 `--config app.toml`，验证布尔开关和值 Flag。
2. **testParseLongFlagWithEquals** — 解析 `--config=app.toml`，验证等号赋值语法。
3. **testParseShortFlag** — 解析 `-v` 和 `-c app.toml`，验证短选项。
4. **testSubcommandRouting** — 解析 `lint --fix`，验证子命令路由至 `lint`。
5. **testDeepSubcommandRouting** — 解析 `cloud server start --port 8080`，验证三级子命令路由和命令路径。
6. **testPositionalArguments** — 解析两个位置参数，验证按序捕获。
7. **testVariadicArguments** — 解析三个变长参数，验证全部捕获。
8. **testDoubleDashSeparator** — `--verbose -- --not-a-flag file.txt`，验证 `--` 后所有内容作为位置参数。
9. **testDefaultValues** — 不传参时验证 Flag 默认值自动填充。
10. **testRequiredFlagMissing** — 缺失必填 Flag `--output`，验证抛出 `ValidationException`。
11. **testRequiredArgumentMissing** — 缺失必填位置参数，验证抛出 `ValidationException`。
12. **testUnknownLongFlag** — 传入未定义的 `--unknown`，验证抛出 `ParseException`。
13. **testUnknownShortFlag** — 传入未定义的 `-x`，验证抛出 `ParseException`。
14. **testFlagMissingValue** — `--output` 未跟值，验证抛出 `ParseException` 并提示 `"requires a value"`。
15. **testTypedFlagInt64** — `--port 8080` 正确解析为 Int64 类型值。
16. **testTypedFlagInt64Error** — `--port abc` 类型校验失败，抛出 `TypeConversionException`。
17. **testTypedFlagBool** — `--debug yes` 自动标准化为 `"true"`。
18. **testSubcommandWithAlias** — 通过别名 `i` 路由到 `install` 子命令。
19. **testMixedFlagsAndArgs** — 混合传入位置参数和选项，验证各部分正确分离。
20. **testVariadicMinCountViolation** — 变长参数数量不满足 `minCount(2)`，抛出 `ValidationException`。

### 3.7 App 集成测试 (`AppIntegrationTest`) — 16 例

1. **testAppBuilder** — 验证 App 级 Builder 方法正确委托至根 Command。
2. **testMockRunHelp** — `--help` 返回 exitCode=0，stderr 包含 `Usage:` / `Commands:` 及子命令列表。
3. **testMockRunHelpShort** — `-h` 等效 `--help`。
4. **testMockRunVersion** — `--version` 返回 exitCode=0，stdout 包含应用名和版本号。
5. **testMockRunVersionShort** — `-V` 等效 `--version`。
6. **testMockRunSubcommandHelp** — `lint --help` 显示子命令级帮助，包含描述和 Flag 列表。
7. **testMockRunWithAction** — 子命令 `greet` 绑定 Action 执行后返回 exitCode=0。
8. **testMockRunParseError** — 传入未知选项 `--unknown-flag`，exitCode=2 且 stderr 包含 `"error:"`。
9. **testMockRunRequiredFlagError** — 缺失必填 Flag，exitCode=2 且 stderr 提示具体 Flag 名称。
10. **testMockRunTypedFlagError** — 类型校验失败（`--port not-a-number`），exitCode=2。
11. **testMockRunComplexScenario** — 综合场景：别名子命令 + 必填 Flag + Int64 类型 Flag + 位置参数 + 全局 Flag，验证 Action 接收到正确的解析结果。
12. **testMockRunSubcommandByAlias** — 通过别名 `i` 调用 `install` 子命令。
13. **testHelpContainsOptions** — 帮助输出包含 Options 节及 Flag 的短名/长名/默认值。
14. **testHelpContainsArguments** — 帮助输出包含 Arguments 节及参数名称。
15. **testNoActionShowsHelp** — 无 Action 且无参数时自动显示帮助信息。
16. **testDoubleDashInMockRun** — 通过 mockRun 验证 `--` 分隔符在集成级别正确工作。

## 4. 测试覆盖矩阵

| 核心能力             | 正向测试 | 异常/边界测试 | 集成测试 |
| -------------------- | -------- | ------------- | -------- |
| 命令树 & 子命令路由  | ✅        | ✅             | ✅        |
| 命令/Flag 别名       | ✅        | —             | ✅        |
| 长选项 (`--flag`)    | ✅        | ✅             | ✅        |
| 短选项 (`-f`)        | ✅        | ✅             | ✅        |
| 等号赋值 (`--k=v`)   | ✅        | —             | —        |
| 布尔开关             | ✅        | —             | ✅        |
| 位置参数 (定长)      | ✅        | ✅             | ✅        |
| 位置参数 (变长)      | ✅        | ✅             | —        |
| `--` 分隔符          | ✅        | —             | ✅        |
| 默认值填充           | ✅        | —             | —        |
| 必填校验             | —        | ✅             | ✅        |
| 强类型转换 (Int64)   | ✅        | ✅             | ✅        |
| 强类型转换 (Float64) | ✅        | ✅             | —        |
| 强类型转换 (Bool)    | ✅        | ✅             | —        |
| Help 自动生成        | —        | —             | ✅        |
| Version 自动生成     | —        | —             | ✅        |
| 错误格式化 & 退出码  | —        | —             | ✅        |
| mockRun 沙箱         | —        | —             | ✅        |

## 5. 运行方式

```bash
cjpm test
```

所有测试通过 `cjpm test` 一键执行，无需额外配置。测试文件位于 `src/` 目录下，以 `_test.cj` 后缀命名，由 cjpm 自动发现。
