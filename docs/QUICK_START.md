# Cangjie CLI Framework — 快速开始

> 版本：v1.1.0 (M12) · 工具链：cjc 1.0.5 + cjpm

---

## 目录

- [安装](#安装)
- [创建第一个 CLI 应用](#创建第一个-cli-应用)
- [子命令](#子命令)
- [Flag 与选项](#flag-与选项)
- [位置参数](#位置参数)
- [生命周期与中间件](#生命周期与中间件)
- [配置文件集成](#配置文件集成)
- [约束与验证](#约束与验证)
- [交互组件](#交互组件)
- [Shell 补全](#shell-补全)
- [测试](#测试)
- [国际化](#国际化)
- [完整示例](#完整示例)

---

## 安装

### 前置条件

- 仓颉编译器 cjc 1.0.5+
- 仓颉包管理器 cjpm

### 添加依赖

在项目的 `cjpm.toml` 中添加：

```toml
[dependencies]
  cli = { path = "/path/to/cli" }
```

然后在代码中引入：

```cangjie
import cli.*
```

---

## 创建第一个 CLI 应用

```cangjie
import cli.*

main(): Int64 {
    let app = App("hello")
        .description("A simple greeting tool")
        .version("1.0.0")
        .flag(
            Flag("name").short(r'n')
                .description("Name to greet")
                .defaultValue("World")
        )
        .action({ ctx =>
            let name = ctx.getFlagOrDefault("name", "World")
            println("Hello, ${name}!")
            0
        })

    app.run()
}
```

运行效果：

```bash
$ hello
Hello, World!

$ hello --name Alice
Hello, Alice!

$ hello -n Bob
Hello, Bob!

$ hello --help
A simple greeting tool

Usage: hello [OPTIONS]

Options:
  -n, --name <VALUE>  Name to greet [default: World]
  -h, --help          Print help
  -V, --version       Print version

$ hello --version
hello 1.0.0
```

`-h` / `--help` 和 `-V` / `--version` 由框架自动注入。

---

## 子命令

```cangjie
let app = App("tool")
    .description("My DevOps toolkit")
    .version("1.0.0")
    .command(
        Command("serve")
            .alias("s")                           // 别名
            .description("Start development server")
            .flag(Flag("port").short(r'p').valueType(Int64Type).defaultValue("8080"))
            .action({ ctx =>
                println("Listening on port ${ctx.getFlagOrDefault("port", "8080")}")
                0
            })
    )
    .command(
        Command("deploy")
            .alias("d")
            .description("Deploy to production")
            .subcommandRequired()                  // 必须指定子命令
            .command(
                Command("staging")
                    .description("Deploy to staging")
                    .action({ _ => println("Deployed to staging!"); 0 })
            )
            .command(
                Command("production")
                    .description("Deploy to production")
                    .action({ _ => println("Deployed to production!"); 0 })
            )
    )
```

```bash
$ tool serve --port 3000
Listening on port 3000

$ tool s -p 3000            # 使用别名
Listening on port 3000

$ tool deploy               # 未指定子命令 → 报错
error: 'deploy' requires a subcommand.
```

---

## Flag 与选项

### 基本类型

```cangjie
Flag("port").valueType(Int64Type)           // 整数
Flag("threshold").valueType(Float64Type)    // 浮点
Flag("verbose").asBool()                     // 布尔开关
Flag("name")                                 // 字符串（默认）
```

### 动作类型

```cangjie
// 默认赋值（Set），接受一个值
Flag("output").action(Set)

// 布尔开关
Flag("verbose").action(SetTrue)

// 追加多值
Flag("filter").action(Append)                // --filter a --filter b → ["a", "b"]

// 出现次数计数
Flag("verbose").short(r'v').action(Count)   // -vvv → 3
```

### 枚举值约束

```cangjie
Flag("format").choices(["text", "json", "yaml"])
// --format xml → error: Invalid value 'xml' for '--format'. Valid choices: text, json, yaml
```

### 值分隔符

```cangjie
Flag("tags").delimiter(r',')
// --tags a,b,c → ["a", "b", "c"]
```

### 环境变量绑定

```cangjie
Flag("host").envVar("BIND_HOST").defaultValue("localhost")
// BIND_HOST=0.0.0.0 tool serve → host = "0.0.0.0"
```

帮助文本自动显示绑定关系：

```
--host <VALUE>  Bind address [env: BIND_HOST] [default: localhost]
```

### 自定义值占位名与补全提示

```cangjie
Flag("config")
    .valueName("FILE")                // 帮助文本显示 --config <FILE>
    .valueHint(FilePath)              // Shell 补全时提供文件补全
```

### Count 计数（分级日志示例）

```cangjie
let app = App("tool")
    .flag(Flag("verbose").short(r'v').action(Count))
    .action({ ctx =>
        let level = match (ctx.getInt64Flag("verbose")) {
            case Some(n) => n
            case None => 0
        }
        match (level) {
            case 0 => println("ERROR only")
            case 1 => println("INFO level")
            case 2 => println("DEBUG level")
            case _ => println("TRACE level")
        }
        0
    })
```

```bash
$ tool              # level=0 → ERROR only
$ tool -v           # level=1 → INFO level
$ tool -vv          # level=2 → DEBUG level
$ tool -vvv         # level=3 → TRACE level
$ tool -v -v -v     # 等价于 -vvv
```

---

## 位置参数

```cangjie
Command("greet")
    .argument(
        Argument("name")
            .description("Person to greet")
            .required(true)
    )
    .argument(
        Argument("files")
            .description("Input files")
            .variadic(true)
            .minCount(1)
    )
    .action({ ctx =>
        let name = match (ctx.getArgument(0)) { case Some(n) => n; case None => "" }
        let files = ctx.getArguments()
        // ...
        0
    })
```

### Pass-Through 参数

`--` 之后的所有 token 不被解析，直接传递：

```cangjie
// tool lint ./src -- --strict --max-warnings 10
let extraArgs = ctx.getPassthroughArgs()   // ["--strict", "--max-warnings", "10"]
```

---

## 生命周期与中间件

### 生命周期钩子

```cangjie
let app = App("tool")
    .persistentPreRun({ ctx =>
        // 全局前置：初始化日志、加载全局配置
        println("[init] Loading configuration...")
    })
    .persistentPostRun({ ctx =>
        // 全局后置：清理资源
        println("[cleanup] Done.")
    })
    .command(
        Command("serve")
            .preRun({ ctx =>
                println("[serve] Validating config...")
            })
            .action({ ctx => println("Server running"); 0 })
            .postRun({ ctx =>
                println("[serve] Cleanup...")
            })
    )
```

### 中间件（洋葱模型）

```cangjie
app.use({ ctx, next =>
    println("→ Before")
    let code = next()    // 调用下一层
    println("← After (exit: ${code})")
    code
})
```

多个中间件按注册顺序嵌套，形成洋葱模型。不调用 `next()` 即可短路整个链。

---

## 配置文件集成

```cangjie
let app = App("tool")
    .envPrefix("MYAPP")              // 环境变量前缀
    .configFile("tool.toml")         // 配置文件名
    .flag(Flag("port").valueType(Int64Type).defaultValue("8080"))
    .flag(Flag("host").defaultValue("localhost"))
```

四级优先级自动融合：

```
CLI 参数 > 环境变量 > 配置文件 > 默认值
```

配置文件示例（TOML 子集）：

```toml
# tool.toml
port = 3000
host = "0.0.0.0"
```

```bash
$ MYAPP_PORT=4000 tool --host 127.0.0.1
# port = 4000 (来自环境变量)
# host = 127.0.0.1 (来自 CLI 参数)
```

---

## 约束与验证

### 互斥

```cangjie
Flag("json").action(SetTrue).conflictsWith("plain")
Flag("plain").action(SetTrue).conflictsWith("json")
// --json --plain → error: Flag '--json' conflicts with '--plain'.
```

### 依赖

```cangjie
Flag("output-format").requires("output")
// --output-format json → error: Flag '--output-format' requires '--output'.
```

### 约束组

```cangjie
Command("deploy")
    // 至少使用组内一个 Flag
    .requireGroup("target", ["staging", "production", "custom-url"])
    // 组内 Flag 互斥
    .mutuallyExclusiveGroup("format", ["json", "yaml", "text"])
```

### 自定义验证器

```cangjie
Flag("port")
    .valueType(Int64Type)
    .validator({ v =>
        let n = parseSimpleInt(v)
        n > 0 && n < 65536
    }, message: "must be 1-65535")
```

### 标记弃用

```cangjie
Flag("old-flag")
    .deprecatedSince("Use --new-flag instead", "new-flag", "v0.8.0")
// 使用时自动输出: warning: flag '--old-flag' is deprecated since v0.8.0. Use '--new-flag' instead.
```

---

## 交互组件

```cangjie
import cli.*

// 确认对话框
let mock = InputMock().addLine("yes")
let confirmed = Confirm("Deploy to production?").defaultValue(false).run(mock)

// 单选
let mock2 = InputMock().addLine("2")
let choice = Select("Choose environment:")
    .options(["dev", "staging", "production"])
    .run(mock2)    // → Some("staging")

// 多选
let mock3 = InputMock().addLine("1,3")
let items = MultiSelect("Select features:")
    .options(["logging", "metrics", "tracing"])
    .run(mock3)    // → ["logging", "tracing"]

// 进度条
let bar = ProgressBar(100).width(40).prefix("Downloading")
bar.advance(10)
println(bar.render())    // Downloading [████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 10%

// 旋转器
let spinner = Spinner(style: Dots).message("Loading...")
spinner.tick()
println(spinner.render())
```

---

## Shell 补全

```cangjie
let completionCmd = Command("completion")
    .flag(Flag("shell").choices(["bash", "zsh", "fish"]).required(true))
    .action({ ctx =>
        let shell = match (parseShellType(ctx.getFlagOrDefault("shell", "bash"))) {
            case Some(s) => s
            case None => Bash
        }
        println(CompletionGenerator.generate(app.getRootCommand(), shell))
        0
    })
```

生成补全脚本：

```bash
# Bash
tool completion --shell bash > /etc/bash_completion.d/tool

# Zsh
tool completion --shell zsh > ~/.zsh/completions/_tool

# Fish
tool completion --shell fish > ~/.config/fish/completions/tool.fish
```

`ValueHint` 提供智能补全：

```cangjie
Flag("config").valueHint(FilePath)     // 文件路径补全
Flag("output-dir").valueHint(DirPath)  // 目录路径补全
Flag("remote").valueHint(Hostname)     // 主机名补全
```

---

## 测试

### mockRun 沙箱测试

```cangjie
@Test
func testServe() {
    let app = App("tool")
        .command(Command("serve")
            .flag(Flag("port").valueType(Int64Type).defaultValue("8080"))
            .action({ ctx =>
                println("port=${ctx.getFlagOrDefault("port", "8080")}")
                0
            })
        )

    let result = app.mockRun(["serve", "--port", "3000"])
    @Expect(result.exitCode, 0)
    @Expect(result.stdout.contains("port=3000"), true)
}
```

### 错误诊断测试

```cangjie
@Test
func testUnknownCommand() {
    let app = App("tool").command(Command("serve"))
    let result = app.mockRun(["serv"])
    @Expect(result.exitCode, 2)
    @Expect(result.stderr.contains("Did you mean"), true)
}
```

### 快照测试

```cangjie
@Test
func testHelpSnapshot() {
    let app = buildMyApp()
    let result = app.mockRun(["--help"])
    let snap = Snapshot()
    let cmp = snap.compare("help-output", result.stdout)
    @Expect(cmp.matched, true)
}
```

### 配置管道测试

```cangjie
@Test
func testConfigMerge() {
    let app = App("tool")
        .configFile("tool.toml")
        .flag(Flag("port").valueType(Int64Type).defaultValue("8080"))
        .action({ ctx =>
            println(ctx.getFlagOrDefault("port", "8080"))
            0
        })

    // 注入配置文件内容
    let result = app.mockRunWithConfig(
        ["--port", "3000"],
        configContent: Some("port = 9090")
    )
    @Expect(result.stdout.contains("3000"), true)  // CLI > Config
}
```

---

## 国际化

```cangjie
class ChineseLocale <: Locale {
    public func labelError(): String { "错误" }
    public func labelWarning(): String { "警告" }
    public func helpUsagePrefix(): String { "用法: " }
    public func helpPrintHelp(): String { "打印帮助" }
    public func helpPrintVersion(): String { "打印版本" }
    public func errUnknownCommand(name: String): String {
        "未知命令 '${name}'。"
    }
    // 其余 50+ 方法使用接口默认英文实现
}

let app = App("tool")
    .locale(ChineseLocale())
```

---

## 完整示例

以下是一个包含多数框架特性的完整 CLI 工具：

```cangjie
import cli.*

main(): Int64 {
    let app = App("devtool")
        .description("A DevOps CLI toolkit")
        .version("2.0.0")
        .envPrefix("DEVTOOL")
        .configFile("devtool.toml")
        // 全局 Flag
        .globalFlag(Flag("verbose").short(r'v').action(Count))
        .globalFlag(Flag("format").choices(["text", "json"]).defaultValue("text"))
        // 中间件：日志输出
        .use({ ctx, next =>
            let level = match (ctx.getInt64Flag("verbose")) {
                case Some(n) => n; case None => 0
            }
            if (level >= 2) {
                println("[debug] Command: ${ctx.getCommandPathStr()}")
            }
            next()
        })
        // 子命令：serve
        .command(
            Command("serve")
                .alias("s")
                .description("Start development server")
                .flag(Flag("port").short(r'p')
                    .valueType(Int64Type)
                    .defaultValue("8080")
                    .envVar("PORT")
                    .validator({ v =>
                        let n = parseSimpleInt(v)
                        n > 0 && n < 65536
                    }, message: "must be 1-65535"))
                .flag(Flag("host")
                    .defaultValue("localhost")
                    .envVar("HOST")
                    .valueName("ADDR")
                    .valueHint(Hostname))
                .flag(Flag("tls").asBool())
                .flag(Flag("cert")
                    .requires("tls")
                    .valueHint(FilePath))
                .action({ ctx =>
                    let port = ctx.getFlagOrDefault("port", "8080")
                    let host = ctx.getFlagOrDefault("host", "localhost")
                    println("Server running at http://${host}:${port}")
                    0
                })
        )
        // 子命令：deploy (强制子命令)
        .command(
            Command("deploy")
                .description("Deploy application")
                .subcommandRequired()
                .command(Command("staging").action({ _ => println("→ staging"); 0 }))
                .command(Command("production").action({ _ => println("→ production"); 0 }))
        )

    app.run()
}
```

```bash
$ devtool serve -p 3000 --host 0.0.0.0
Server running at http://0.0.0.0:3000

$ devtool -vvv serve --port 8080
[debug] Command: devtool serve
Server running at http://localhost:8080

$ devtool deploy
error: 'deploy' requires a subcommand.

$ devtool deploy staging
→ staging

$ PORT=9090 devtool serve
Server running at http://localhost:9090
```

---

## 进一步阅读

- [API 参考文档](API.md) — 完整 API 签名
- [系统架构文档](ARCHITECTURE.md) — 内部设计详解
- [框架内部漫游指南](framework-internals.md) — 源码级深度解析
- `example/` — 完整 DevOps 示例应用
