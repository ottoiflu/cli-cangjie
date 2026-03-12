# Cangjie CLI Framework

一个使用仓颉编程语言开发的现代化命令行（CLI）框架，帮助开发者快速构建具有极致用户体验的 CLI 工具。

对标 Rust Clippy 的诊断体验，遵循 [clig.dev](https://clig.dev/)、GNU 及 Unix 实用工具规范。

---

## 特性概览

| 特性类别       | 内容                                                                                |
| -------------- | ----------------------------------------------------------------------------------- |
| **命令树构建** | 无限深度子命令、别名系统、命令分组、Builder 流式 API                                |
| **参数解析**   | 短/长选项、布尔开关、变长位置参数、Pass-Through (`--`)、值分隔符                    |
| **强类型系统** | Int64/Float64/Bool/String 内置转换器、枚举值约束 (Choices)、自定义验证器            |
| **配置管道**   | 四级优先级：CLI > 环境变量 > 配置文件 > 默认值                                      |
| **诊断系统**   | Clippy 风格的 Error/Warning/Help/Note 四级诊断、视觉化错误定位、N-Best Did-You-Mean |
| **生命周期**   | PersistentPreRun → PreRun → Middleware → Action → PostRun → PersistentPostRun       |
| **交互组件**   | Spinner、ProgressBar、Confirm、Select、MultiSelect                                  |
| **测试套件**   | mockRun 沙箱、IO 独立捕获、InputMock 交互模拟、Golden Files 快照测试                |
| **工程化**     | Shell 补全 (Bash/Zsh/Fish)、弃用系统、信号处理、错误聚合                            |

## 快速开始

```cangjie
import cli.*

main() {
    let app = App("my-tool")
        .description("A modern CLI tool built with Cangjie CLI Framework")
        .version("1.0.0")
        .command(
            Command("greet")
                .description("Greet someone")
                .flag(Flag("name").short(r'n').description("Name to greet").required(true))
                .action({ ctx =>
                    let name = ctx.getFlagOrDefault("name", "World")
                    println("Hello, ${name}!")
                    0
                })
        )

    let result = app.mockRun(Array<String>(Process.arguments))
    Process.exit(result.exitCode)
}
```

## 核心 API

### 命令构建

```cangjie
let app = App("tool")
    .description("My CLI tool")
    .version("1.0.0")
    .envPrefix("MYAPP")                  // 环境变量前缀
    .configFile("tool.toml")             // 配置文件名
    .globalFlag(Flag("verbose").short(r'v').action(SetTrue))  // 全局标志
    .command(
        Command("serve")
            .description("Start the server")
            .subcommandGroup("Server Commands")
            .flag(Flag("port").short(r'p').valueType(Int64Type).defaultValue("8080"))
            .flag(Flag("host").envVar("BIND_HOST").defaultValue("0.0.0.0"))
            .action({ ctx =>
                let port = ctx.getFlagOrDefault("port", "8080")
                let host = ctx.getFlagOrDefault("host", "0.0.0.0")
                println("Listening on ${host}:${port}")
                0
            })
    )
```

### Flag 约束

```cangjie
// 互斥标志
Flag("json").action(SetTrue).conflictsWith("plain")

// 依赖标志
Flag("output-format").requires("output")

// 枚举值约束
Flag("format").choices(["text", "json", "yaml"])

// 值分隔符
Flag("filter").delimiter(r',')    // --filter a,b,c → ["a", "b", "c"]

// 自定义验证器
Flag("port").valueType(Int64Type).validator({ v => Int64.tryParse(v).map({ n => n > 0 && n < 65536 }).getOrDefault(false) }, "must be 1-65535")
```

### 生命周期 & 中间件

```cangjie
app.persistentPreRun({ ctx => println("Before every command") })
   .use({ ctx, next =>
       let start = DateTime.now()
       let code = next()
       let elapsed = DateTime.now() - start
       println("Took ${elapsed}ms")
       code
   })
```

### 测试 API

```cangjie
@Test
func testGreet() {
    let app = App("tool").command(greetCmd)
    let result = app.mockRun(["greet", "--name", "Alice"])
    @Expect(result.exitCode, 0)
}

@Test
func testDidYouMean() {
    let app = App("tool").command(greetCmd)
    let result = app.mockRun(["gret"])
    @Expect(result.stderr.contains("Did you mean 'greet'?"), true)
}
```

## 配置管道

四级优先级覆盖模型：

```
CLI 显式参数 > 环境变量 > 配置文件 > 代码默认值
```

配置文件格式（兼容 TOML 子集）：

```toml
# tool.toml
host = "localhost"
port = 8080
verbose = true
```

环境变量自动映射：`envPrefix("APP")` + `--db-host` → `APP_DB_HOST`

## 诊断输出

框架自动生成 Clippy 风格的诊断信息：

```
error: Unknown option '--confi'. Did you mean '--config'?
  |
  | tool --confi value
  |      ^^^^^^^^
  |
  = help: For more information, try '--help'.
```

多错误聚合报告：

```
error: Required flag '--host' was not provided.
error: Required flag '--port' was not provided.
error: Found 2 errors

For more information, try '--help'.
```

## 项目结构

```
src/
  app.cj          # 应用入口、mockRun 沙箱、帮助生成
  command.cj       # 命令树构建器
  flag.cj          # Flag/Option 定义
  argument.cj      # 位置参数定义
  parser.cj        # 核心解析引擎（二阶段: parseOnly + finalize）
  context.cj       # 执行上下文、依赖注入
  types.cj         # 值类型枚举与转换器
  errors.cj        # 异常体系（含 AggregateException）
  diagnostic.cj    # 诊断系统（Error/Warning/Help/Note）
  suggest.cj       # Levenshtein 编辑距离、Did-You-Mean
  style.cj         # ANSI 终端样式引擎
  config.cj        # 配置文件加载与解析
  input.cj         # InputMock、Prompt 交互
  widget.cj        # 交互组件（Spinner/ProgressBar/Confirm/Select）
  snapshot.cj      # Golden Files 快照测试引擎
  advanced.cj      # 高级特性（补全、弃用、版本信息、输出格式）
  test/            # 测试套件（378+ 用例）
example/           # 示例应用
docs/              # 测试报告与文档
```

## 开发与测试

```bash
# 构建
cjpm build

# 运行全部测试
cjpm test

# 当前测试覆盖
# TOTAL: 378, PASSED: 378, SKIPPED: 0, ERROR: 0, FAILED: 0
```

## 版本历史

详见 [CHANGELOG.md](CHANGELOG.md)

| 版本    | 主要特性                       |
| ------- | ------------------------------ |
| v0.1.0  | 核心路由与基础解析引擎         |
| v0.2.0  | 诊断系统与 Clippy 级别用户体验 |
| v0.3.0  | 配置合并流与生命周期抽象       |
| v0.4.0  | 测试套件增强与快照测试         |
| v0.5.0  | 交互式组件集                   |
| v0.6.0  | Flag 约束与高级验证            |
| v0.7.0  | 配置文件管道                   |
| v0.8.0  | Shell 补全与高级特性           |
| v0.9.0  | 增强型 Flag 值域与帮助系统     |
| v0.10.0 | 健壮性与工程化增强             |
| v1.0.0  | 项目结构优化与示例应用         |

## 许可证

本项目采用 Apache-2.0 许可证。详见 [LICENSE](LICENSE)。

## 贡献

欢迎贡献！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。
