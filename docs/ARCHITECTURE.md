# Cangjie CLI Framework — 系统架构文档

> 版本：v1.1.0 (M12) · 包名：`cli` · 工具链：cjc 1.0.5 + cjpm

---

## 目录

1. [设计哲学](#1-设计哲学)
2. [模块全景图](#2-模块全景图)
3. [核心执行管道](#3-核心执行管道)
4. [命令树与路由](#4-命令树与路由)
5. [解析引擎](#5-解析引擎)
6. [四级配置优先级系统](#6-四级配置优先级系统)
7. [生命周期模型](#7-生命周期模型)
8. [中间件链](#8-中间件链)
9. [约束与验证系统](#9-约束与验证系统)
10. [诊断与错误报告](#10-诊断与错误报告)
11. [Shell 补全生成](#11-shell-补全生成)
12. [本地化架构](#12-本地化架构)
13. [测试基础设施](#13-测试基础设施)
14. [信号处理](#14-信号处理)
15. [模块依赖关系](#15-模块依赖关系)
16. [Flag 动作类型系统](#16-flag-动作类型系统)

---

## 1. 设计哲学

本框架不是一个简单的参数解析器，而是一个**声明式 CLI 应用容器**，对标 Rust 生态的 [clap](https://github.com/clap-rs/clap)，遵循 [clig.dev](https://clig.dev/)、GNU 及 POSIX 规范。

### 核心设计原则

1. **一切皆命令**：根程序和子功能统一为 `Command` 实例，支持无限嵌套
2. **声明式构建**：通过 Builder 链式 API 描述 CLI 结构，而非 if/else 分支判断
3. **上下文流转**：所有运行时数据封装在 `Context` 中，在生命周期各阶段间流动
4. **测试优先**：内置 `mockRun` 沙箱、`InputMock` 输入模拟、`Snapshot` 快照测试基建
5. **诊断驱动**：Clippy 风格的四级诊断系统，错误不仅告知"哪里错了"，还指明"怎么修"

---

## 2. 模块全景图

框架由 19 个源码模块组成，按职责划分为 5 个层次：

```
┌──────────────────────────────────────────────────────────────────┐
│                         应用层 (Application)                       │
│   app.cj — 入口协调器，执行管道编排，帮助/版本生成                    │
├──────────────────────────────────────────────────────────────────┤
│                         模型层 (Model)                             │
│   command.cj   flag.cj   argument.cj   types.cj   context.cj     │
│   命令树定义    选项定义   位置参数      类型枚举    运行时状态       │
├──────────────────────────────────────────────────────────────────┤
│                         引擎层 (Engine)                            │
│   parser.cj    config.cj    suggest.cj    completion.cj           │
│   解析引擎      配置管道     拼写纠错       Shell补全生成            │
├──────────────────────────────────────────────────────────────────┤
│                         展示层 (Presentation)                      │
│   diagnostic.cj   style.cj   locale.cj   widget.cj               │
│   诊断渲染        ANSI样式    国际化        交互组件                 │
├──────────────────────────────────────────────────────────────────┤
│                         基建层 (Infrastructure)                    │
│   errors.cj   input.cj   snapshot.cj   advanced.cj   example.cj  │
│   异常体系     输入模拟    快照测试       输出格式化    示例应用     │
└──────────────────────────────────────────────────────────────────┘
```

### 模块职责一览

| 模块 | 职责 |
|------|------|
| `app.cj` | 应用生命周期编排、mockRun 沙箱、帮助/版本生成、配置管道协调 |
| `command.cj` | 命令树结构、子命令路由、生命周期钩子注册、约束组声明 |
| `flag.cj` | Flag 定义（长短名/默认值/类型/动作/约束/弃用/ValueHint） |
| `argument.cj` | 位置参数定义（必需/变长/数量约束/类型） |
| `context.cj` | 运行时状态管理（Flag 存储/DI 值存储/显式标记/Pass-Through） |
| `parser.cj` | 两阶段解析引擎（parseOnly + finalize），错误收集与聚合 |
| `types.cj` | 值类型枚举、FlagAction 枚举、ValueHint 枚举、类型验证/转换 |
| `errors.cj` | 异常继承体系（5 种专用异常类） |
| `diagnostic.cj` | Clippy 风格诊断消息渲染（Error/Warning/Help/Note + 上下文高亮） |
| `style.cj` | ANSI 颜色/粗体/下划线，自动检测 `NO_COLOR` 环境 |
| `suggest.cj` | Damerau-Levenshtein 编辑距离、Did-You-Mean 拼写建议 |
| `locale.cj` | i18n 接口（60+ 方法），Messages 单例全局路由 |
| `config.cj` | TOML 子集配置文件发现/解析/合并，行级错误定位 |
| `input.cj` | InputMock 输入队列、Prompt 交互封装 |
| `widget.cj` | 终端 UI 组件（Spinner/ProgressBar/Confirm/Select/MultiSelect） |
| `advanced.cj` | OutputFormatter(JSON/Text)、VersionInfo、DeprecationInfo |
| `completion.cj` | Bash/Zsh/Fish 补全脚本静态生成 |
| `snapshot.cj` | Golden Files 快照测试引擎、Diff 比对 |
| `example.cj` | 完整 DevOps 示例应用构建器 |

---

## 3. 核心执行管道

当用户输入 `tool serve --port 8080 --verbose` 时，框架按以下管道进行处理：

```
╔════════════════════════════════════════════════════════════════╗
║  用户输入: ["serve", "--port", "8080", "--verbose"]             ║
╚═══════════════════════╤════════════════════════════════════════╝
                        ▼
┌───────────────────────────────────────────────────┐
│  Phase 1: 静态分析 (parseOnly)                      │
│  ┌─────────────────────────────────────────┐       │
│  │ ① Token 化：识别子命令/Flag/位置参数       │       │
│  │ ② 命令路由：遍历命令树匹配 "serve"        │       │
│  │ ③ Flag 收集：--port=8080, --verbose=true  │       │
│  │ ④ 未知项检测 → 拼写纠错 (suggest.cj)      │       │
│  └─────────────────────────────────────────┘       │
│  输出: (matchedCmd, context, positionalArgs)         │
└───────────────────────┬───────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────┐
│  Phase 2: 配置融合 (app.cj 编排)                     │
│  ┌─────────────────────────────────────────┐       │
│  │ ① 应用环境变量覆盖 (envPrefix)             │       │
│  │ ② 加载/合并配置文件 (ConfigLoader)         │       │
│  │ ③ 应用代码默认值 (defaultValue)            │       │
│  │ 优先级: CLI > EnvVar > Config > Default    │       │
│  └─────────────────────────────────────────┘       │
└───────────────────────┬───────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────┐
│  Phase 3: 验证 (finalize)                            │
│  ┌─────────────────────────────────────────┐       │
│  │ ① 类型转换验证 (Int64/Float64/Bool)       │       │
│  │ ② 必需 Flag 检查                          │       │
│  │ ③ 约束检查 (requires/conflictsWith/group)  │       │
│  │ ④ Choices 枚举验证                         │       │
│  │ ⑤ 自定义 validator 验证                    │       │
│  │ ⑥ 位置参数赋值与数量校验                    │       │
│  │ ⑦ SubcommandRequired / ArgRequiredElseHelp │       │
│  └─────────────────────────────────────────┘       │
│  错误聚合: AggregateException 批量报告               │
└───────────────────────┬───────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────┐
│  Phase 4: 执行管道                                    │
│  ┌─────────────────────────────────────────┐       │
│  │ ① PersistentPreRun (全局前置)              │       │
│  │ ② Middleware 中间件链 (洋葱模型)            │       │
│  │   ┌──────────────────────────────┐        │       │
│  │   │ ③ PreRun (命令前置)            │        │       │
│  │   │ ④ Action (业务逻辑)            │        │       │
│  │   │ ⑤ PostRun (命令后置)           │        │       │
│  │   └──────────────────────────────┘        │       │
│  │ ⑥ PersistentPostRun (全局后置)             │       │
│  └─────────────────────────────────────────┘       │
│  输出: exitCode (0=成功, 1=应用错误, 2=解析错误)       │
└───────────────────────────────────────────────────┘
```

---

## 4. 命令树与路由

### 树结构

```cangjie
App("cj-devtool")               // 根命令
├── Command("serve")             // 子命令
│   ├── Flag("port")
│   └── Flag("host")
├── Command("cloud")             // 嵌套子命令
│   ├── Command("list")
│   └── Command("start")
│       └── Argument("instance-id")
└── Command("config")
    ├── Command("show")
    └── Command("set")
```

### 路由算法

1. 从 `rawArgs` 逐个提取 token
2. 在当前命令的 `_subcommandMap` 中查找匹配（含别名映射）
3. 匹配成功 → 递归进入子命令，将命令名推入 `Context.commandPath`
4. 匹配失败 → 如果 token 以 `-` 开头则视为 Flag，否则视为位置参数
5. 未知子命令 → 调用 `suggest.cj` 计算编辑距离，给出 Did-You-Mean 建议

### 别名机制

```cangjie
Command("serve").alias("s")       // "s" → 路由到 "serve"
Command("cloud").aliases(["c", "infra"])
```

`findSubcommand()` 同时检查命令名和所有别名。

---

## 5. 解析引擎

### 两阶段设计

解析器采用**两阶段分离**设计，这是配置管道正确运作的关键：

```
输入 → [parseOnly] → 中间状态 → [配置融合] → [finalize] → 最终状态
         只做解析       不验证       填充缺失值     类型转换+约束检查
```

**为什么不一次完成？** 因为"必需 Flag 检查"必须在环境变量和配置文件值注入之后才能进行。如果解析时就检查必需性，那通过 `envVar` 或配置文件提供的值会被误报为缺失。

### Flag 解析模式

Parser 处理 4 种 Flag 输入格式：

| 格式 | 示例 | 处理函数 |
|------|------|----------|
| `--flag=value` | `--port=8080` | `handleFlagValue` |
| `--flag value` | `--port 8080` | `handleFlagNoEquals` |
| `-f value` | `-p 8080` | `handleShortFlagSingle` |
| `-abc` | `-vvv` | `parseCompositeShortFlags` |

### FlagAction 分派

每种 Flag 格式的处理函数根据 `FlagAction` 类型决定行为：

| FlagAction | 行为 |
|------------|------|
| `Set` | 直接赋值 `ctx.setFlag(name, value)` |
| `SetTrue` | 布尔开关 `ctx.setFlag(name, "true")` |
| `SetFalse` | 布尔关闭 `ctx.setFlag(name, "false")` |
| `Append` | 追加值 `ctx.appendFlag(name, value)` |
| `Count` | 计数器 `incrementCount(ctx, name)` |
| `Terminate` | 抛出 `TerminateException`，由 App 层捕获并输出 |

### 复合短选项

`-vvv` 会被逐字符拆解：

```
-vvv → ['v', 'v', 'v']
  v → 查找 Flag → isCount() → incrementCount → 1
  v → 查找 Flag → isCount() → incrementCount → 2
  v → 查找 Flag → isCount() → incrementCount → 3
```

---

## 6. 四级配置优先级系统

```
  优先级最高          优先级最低
  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ CLI 参数  │ > │ 环境变量   │ > │ 配置文件   │ > │ 代码默认   │
  └─────────┘  └──────────┘  └──────────┘  └──────────┘

  来源:             来源:              来源:             来源:
  --port 8080       APP_PORT=3000      port = 9090       .defaultValue("80")
```

### 融合流程

```cangjie
// 1. 解析 CLI 参数（不验证）
let (cmd, ctx, positionalArgs) = parser.parseOnly(root, args)

// 2. 应用环境变量覆盖（仅补充未显式设置的 Flag）
for (flag in cmd.getFlags()) {
    if (!ctx.isExplicit(flag.getLongName())) {
        // 检查 envPrefix + flag 名 → 环境变量值
    }
}

// 3. 加载配置文件（仅补充仍未设置的 Flag）
let configData = configLoader.load()
configLoader.applyToContext(configData, ctx)

// 4. 应用默认值（仅补充仍未设置的 Flag）
for (flag in cmd.getFlags()) {
    if (!ctx.hasFlag(flag.getLongName())) {
        ctx.setFlag(flag.getLongName(), flag.getDefaultValue())
    }
}

// 5. 验证所有约束
parser.finalize(root, cmd, ctx, positionalArgs)
```

### 配置文件发现

`ConfigLoader.discover()` 从当前目录向上递归查找：

```
./devtool.toml → ../devtool.toml → ../../devtool.toml → ... → ~/devtool.toml
```

配置文件解析错误会携带行号和 Did-You-Mean 建议：

```
error: unknown key 'prot' in devtool.toml:3
  |
3 | prot = 8080
  |
  = help: did you mean 'port'?
```

---

## 7. 生命周期模型

```
┌──────────────────────────────────────────────────────┐
│                   App 执行管道                         │
│                                                       │
│  ① PersistentPreRun(ctx)     ← 全局，只执行一次        │
│  │                                                     │
│  ▼                                                     │
│  ② [Middleware 链]            ← 洋葱模型包装             │
│  │  ┌──────────────────────────────────────┐          │
│  │  │ ③ PreRun(ctx)         ← 当前命令前置   │          │
│  │  │ ④ Action(ctx) → Int64  ← 业务逻辑     │          │
│  │  │ ⑤ PostRun(ctx)        ← 当前命令后置   │          │
│  │  └──────────────────────────────────────┘          │
│  ▼                                                     │
│  ⑥ PersistentPostRun(ctx)    ← 全局，只执行一次        │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### 钩子注册维度

| 钩子 | 注册位置 | 触发时机 |
|------|----------|----------|
| `persistentPreRun` | `App` 或根 `Command` | 任何命令执行前（全局一次） |
| `preRun` | `Command` | 该命令的 Action 之前 |
| `postRun` | `Command` | 该命令的 Action 之后 |
| `persistentPostRun` | `App` 或根 `Command` | 任何命令执行后（全局一次） |

### 信号检查点

在 PreRun → Middleware → Action → PostRun 各阶段之间，框架检查 `SignalHandler.isInterrupted()`，收到中断信号时立即返回对应退出码（130/143）。

---

## 8. 中间件链

中间件采用**洋葱模型**（inside-out composition）：

```cangjie
// 注册顺序
app.use(loggingMiddleware)    // ①
   .use(timingMiddleware)     // ②
   .use(authMiddleware)       // ③

// 执行顺序（洋葱模型）
logging → timing → auth → [core: preRun+action+postRun] → auth → timing → logging
```

### 实现原理

```cangjie
// 中间件组合
var chain = coreExecution    // 最内层：preRun + action + postRun
for (mw in middlewares.reverse()) {     // 从内到外包装
    let current = chain
    chain = { => mw(ctx, current) }
}
chain()    // 触发执行
```

### 中间件签名

```cangjie
type Middleware = (Context, () -> Int64) -> Int64
```

- `ctx`：运行时上下文
- `next`：调用下一层（不调用则短路）
- 返回值：退出码

---

## 9. 约束与验证系统

### 约束类型

| 约束 | 注册方式 | 验证时机 |
|------|----------|----------|
| 必需 Flag | `Flag.required(true)` | finalize 阶段 |
| 互斥 | `Flag.conflictsWith("other")` | finalize 阶段 |
| 依赖 | `Flag.requires("other")` | finalize 阶段 |
| 必需组 | `Command.requireGroup(name, members)` | finalize 阶段 |
| 互斥组 | `Command.mutuallyExclusiveGroup(name, members)` | finalize 阶段 |
| 类型验证 | `Flag.valueType(Int64Type)` | finalize 阶段 |
| 枚举验证 | `Flag.choices(["a", "b"])` | finalize 阶段 |
| 自定义验证 | `Flag.validator(fn, message)` | finalize 阶段 |
| 数量约束 | `Argument.minCount(n)` / `maxCount(n)` | finalize 阶段 |
| 子命令必需 | `Command.subcommandRequired()` | finalize 后检查 |
| 无参显示帮助 | `Command.argRequiredElseHelp()` | finalize 后检查 |

### 错误聚合

所有验证错误**不逐个抛出**，而是收集到 `AggregateException` 中批量报告：

```
error: Required flag '--host' was not provided.
error: Required flag '--port' was not provided.
error: Found 2 errors

For more information, try '--help'.
```

---

## 10. 诊断与错误报告

### 四级诊断

```
┌─────────┬─────────────────────────────────────────────────┐
│  Error  │ 致命错误，阻止执行                                 │
│ Warning │ 非致命警告（如弃用通知）                            │
│  Help   │ 操作指引（如 "try '--help'"）                      │
│  Note   │ 附加信息（如 Did-You-Mean 建议）                   │
└─────────┴─────────────────────────────────────────────────┘
```

### 渲染示例

```
error: Unknown option '--confi'. Did you mean '--config'?
  |
  | tool --confi value
  |      ^^^^^^^^
  |
  = help: For more information, try '--help'.
```

### 实现架构

```
Diagnostic(level, message)
    ├── .hint("...")        → 附加提示行
    ├── .context("...")     → 原始输入行
    └── .position(n)        → 错误 Token 位置

DiagnosticRenderer(StyleEngine)
    └── .render(diag) → 格式化文本（含 ANSI 颜色/高亮/下划线）
```

---

## 11. Shell 补全生成

### 生成架构

```cangjie
CompletionGenerator.generate(rootCommand, ShellType)
    ├── Bash → generateBash(cmd)
    ├── Zsh  → generateZsh(cmd)
    └── Fish → generateFish(cmd)
```

### ValueHint → Shell 动作映射

| ValueHint | Zsh | Fish |
|-----------|-----|------|
| `FilePath` | `_files` | `-F` (force file completion) |
| `DirPath` | `_directories` | `__fish_complete_directories` |
| `CommandName` | `_command_names` | `-a '(complete -C "")'` |
| `Username` | `_users` | `-a '(cut -d: -f1 /etc/passwd)'` |
| `Hostname` | `_hosts` | `-a '(cat /etc/hosts)'` |
| `Url` | `_urls` | (无特殊映射) |

### Count 类型处理

Count Flag（如 `-v`）在补全脚本中标记为**可重复**，不要求值参数。

---

## 12. 本地化架构

```
┌─────────┐     ┌──────────┐     ┌──────────────────┐
│  App    │ ──→ │ Messages  │ ──→ │ Locale (interface) │
│ .locale()│     │ singleton │     │  60+ 方法          │
└─────────┘     └──────────┘     │  全部有默认英文实现   │
                                  └──────────────────┘
                                          ▲
                                  ┌───────┴────────┐
                                  │ DefaultLocale   │
                                  │ ChineseLocale   │
                                  │ JapaneseLocale  │
                                  │ ...             │
                                  └────────────────┘
```

- **Locale 接口**：60+ 方法覆盖所有用户可见文本
- **默认实现**：所有方法在接口内提供英文默认值
- **自定义翻译**：只需覆盖需要翻译的方法
- **全局注入**：`App.locale()` → `Messages.setLocale()`
- **运行时读取**：所有模块通过 `Messages.locale()` 获取当前翻译

---

## 13. 测试基础设施

### mockRun 沙箱

```cangjie
let result = app.mockRun(["serve", "--port", "8080"])
// result.exitCode: Int64
// result.stdout: String (截获的标准输出)
// result.stderr: String (截获的标准错误)
```

`mockRun` 内部替换 stdout/stderr 为内存缓冲区，完全隔离真实终端 IO。

### InputMock 交互模拟

```cangjie
let mock = InputMock().addLine("yes").addLine("Alice")
let prompt = Prompt(mock)
prompt.confirm("Continue?")   // → true (消费 "yes")
prompt.ask("Name?")           // → Some("Alice")
```

### 快照测试

```cangjie
let snap = Snapshot(snapshotDir: "src/test/snapshots")
let result = snap.compare("help-output", actualText)
if (!result.matched) {
    println(result.diff)    // 显示差异
    snap.update("help-output", actualText)   // 更新基线
}
```

快照文件存储在 `src/test/snapshots/` 目录，每个测试名对应一个 `.snap` 文件。

### 测试统计

| 里程碑 | 测试数 | 覆盖领域 |
|--------|--------|----------|
| M01-M11 | 452 | 核心解析/诊断/生命周期/配置/补全/约束/交互/快照/信号/i18n |
| M12 | 43 | Count/ValueHint/valueName/subcommandRequired/argRequiredElseHelp/longHelp/envVar 显示 |
| **总计** | **495** | 全功能覆盖 |

---

## 14. 信号处理

```cangjie
let handler = SignalHandler()
handler.onSignal({ sig =>
    match (sig) {
        case SIGINT  => println("Interrupted!")
        case SIGTERM => println("Terminated!")
    }
})

let app = App("tool").signalHandler(handler)
```

### 信号检查点

框架在生命周期的关键节点检查中断状态：

```
PersistentPreRun → [检查] → Middleware → [检查] → PreRun → [检查] → Action → [检查] → PostRun
```

### 退出码

| 信号 | 退出码 | 含义 |
|------|--------|------|
| SIGINT | 130 | Ctrl+C 中断 |
| SIGTERM | 143 | kill 终止 |

---

## 15. 模块依赖关系

```
app.cj ──┬── command.cj ── flag.cj ── types.cj
         │                 argument.cj ── types.cj
         ├── parser.cj ── context.cj
         │               errors.cj
         │               suggest.cj
         ├── config.cj ── context.cj
         │               suggest.cj
         ├── diagnostic.cj ── style.cj
         ├── completion.cj ── command.cj
         ├── locale.cj ── (Messages 单例)
         ├── advanced.cj ── (VersionInfo, OutputFormatter)
         └── input.cj ── (InputMock, Prompt)
```

核心依赖方向：**app.cj → 所有模块**（app.cj 是唯一的全局协调器）。

---

## 16. Flag 动作类型系统

| FlagAction | 解析行为 | Context 存储 | 典型用法 |
|------------|----------|-------------|----------|
| `Set` | 取下一个 token 作为值 | `setFlag(name, value)` | `--port 8080` |
| `SetTrue` | 无需值，出现即为 true | `setFlag(name, "true")` | `--verbose` |
| `SetFalse` | 无需值，出现即为 false | `setFlag(name, "false")` | `--no-color` |
| `Append` | 取值并追加 | `appendFlag(name, value)` | `--filter a --filter b` |
| `Count` | 无需值，每次出现计数+1 | `setFlag(name, "N")` | `-vvv` → `"3"` |
| `Terminate` | 触发回调并终止 | 抛出 `TerminateException` | `--help`, `--version` |

### Count 计数器详解

```cangjie
Flag("verbose").short(r'v').action(Count)

// 输入: -v        → ctx.getFlag("verbose") = "1"
// 输入: -vvv      → ctx.getFlag("verbose") = "3"
// 输入: -v -v -v  → ctx.getFlag("verbose") = "3"
// 无输入          → ctx.getFlag("verbose") = "0" (默认)
```

通过 `getInt64Flag("verbose")` 获取整数值，可用于实现分级日志等场景。

### ValueHint 补全提示

`ValueHint` 不影响解析行为，仅用于 Shell 补全脚本生成：

```cangjie
Flag("config").valueHint(FilePath)   // Zsh: _files, Fish: -F
Flag("output-dir").valueHint(DirPath) // Zsh: _directories
```

帮助文本中 `valueName` 优先于 `choices()` 优先于默认 `<VALUE>`：

```
--config <CONFIG>          valueName("CONFIG")
--format <text|json|yaml>  choices(["text", "json", "yaml"])
--port <VALUE>              默认占位
```
