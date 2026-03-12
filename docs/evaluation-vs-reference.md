# 仓颉 CLI 框架实现评估报告 — 对标 reference/cli-cj

## 1. 评估目标

将本项目（`src/`）的 Phase 1 实现与仓颉官方参考框架 `reference/cli-cj`（以下简称"参考实现"）进行逐模块对比，识别设计差异、仓颉语言惯用法偏差和待改进项，为后续迭代提供依据。

---

## 2. 总体架构对比

| 维度             | 参考实现 (cli-cj)                           | 当前实现 (src/)                              | 评估   |
| ---------------- | ------------------------------------------- | -------------------------------------------- | ------ |
| 包输出类型       | `static`（库）                              | `executable`                                 | ⚠️ 改进 |
| API 风格         | `Command` + `Arg` + `ArgMatch`，声明式      | `App` + `Command` + `Flag` + `Argument` + `Context` | 合理但繁琐 |
| Builder 返回类型 | `This`（支持子类继承）                       | 具体类名 `Command` / `Flag` / `App`           | ⚠️ 改进 |
| 参数与命令合一   | `Arg` 同时表示 flag 和位置参数               | `Flag` 与 `Argument` 分离                      | 各有利弊 |
| 类型安全取值     | 泛型 `get<T>()` + `Parsable<T>` 约束        | 手动 `getInt64Flag()` / `getBoolFlag()`        | ⚠️ 改进 |
| 帮助系统         | `--help` 注册为 `Terminate` 动作的 Arg       | `mockRun` 中硬编码特殊处理                      | ⚠️ 改进 |
| 构建入口         | `command.build()` 直接读 `getCommandLine()`  | `app.mockRun(args)` 纯内存沙箱                 | ✅ 优势 |
| 参数分组         | 支持 `.group()` 分组输出                     | 不支持                                        | ⚠️ 缺失 |
| 参数动作类型     | `ArgAction` 枚举 (Set/SetTrue/SetFalse/Append/Terminate) | `asBool()` 仅布尔开关               | ⚠️ 改进 |
| 位置参数优先级   | `positionalArgsSet` 带 priority 分级接收     | 按定义顺序线性消费                              | 各有利弊 |
| 测试包声明       | `internal package cli.test`（独立内部子包）  | `package cli`（与源码同包）                     | ⚠️ 改进 |

---

## 3. 逐模块详细对比与改进建议

### 3.1 包输出类型与项目定位

**问题**：当前 `cjpm.toml` 声明 `output-type = "executable"`，但本项目是 **框架**，应供第三方项目依赖引用。

**参考实现**：`output-type = "static"`，作为静态库被 `cjpm.toml` 的 `[dependencies]` 引入。

**建议**：将 `output-type` 改为 `"static"`，使框架可被其他仓颉项目引入。`main` 入口应移至 example 或由用户自行编写。

---

### 3.2 Builder 返回类型：`This` vs 具体类名

**问题**：当前所有 Builder 方法返回具体类名（如 `func description(desc: String): Command`），这在仓颉里不太地道。若用户以后想继承 `Command`，返回类型就被锁死了。

**参考实现**：统一返回 `This`，这是仓颉惯用的 Builder 模式写法：

```cangjie
// 参考实现
public func about(about: String): This {
    this._about = Some(about)
    this
}
```

**建议**：所有 Builder 方法（`Command`、`Flag`、`Argument`、`App`）的返回类型统一改为 `This`。同时去掉冗余的 `return` 关键字（仓颉中最后表达式即返回值）。

---

### 3.3 Arg 设计：统一模型 vs Flag/Argument 分离

**参考实现**：只有一个 `Arg` 类，通过 `action(ArgAction)` 和 `positionalArgsSet()` 区分是选项还是位置参数。一个 `Arg` 同时可以接收命名参数和位置参数。

**当前实现**：`Flag`（命名选项）和 `Argument`（位置参数）是两个完全独立的类。

**评估**：

1. 分离设计在语义上更清晰，概念上更容易理解——这是一个**合理的设计决策**。
2. 但参考实现的 `ArgAction` 枚举（`Set` / `SetTrue` / `SetFalse` / `Append` / `Terminate`）远比当前的 `asBool()` 布尔开关丰富得多。

**建议**：
1. 保留 Flag/Argument 分离设计。
2. 为 `Flag` 引入 `ArgAction` 枚举，支持 `Append`（多值追加）和 `Terminate`（触发后立即执行回调并退出）等动作。
3. 当前 Context 中 flag 的存储为 `HashMap<String, String>`（单值），参考实现为 `HashMap<String, ArrayList<String>>`（多值）。应改为多值存储以支持 `--flag a --flag b` 的 Append 场景。

---

### 3.4 泛型类型安全取值

**参考实现**：利用仓颉的 `Parsable<T>` 接口提供泛型取值：

```cangjie
public func get<T>(name: String): T where T <: Parsable<T>
public func tryGet<T>(name: String): Option<T> where T <: Parsable<T>
```

**当前实现**：手写了具体类型的 helper 方法：

```cangjie
public func getBoolFlag(name: String): Bool
public func getInt64Flag(name: String): Option<Int64>
```

**建议**：引入泛型取值机制。参考实现中因为 `String` 不能扩展 `Parsable` 而额外提供了 `getString()` 系列方法（它自称为 "Hack"），这一点也值得注意——需要同样为 String 提供非泛型快捷方法。

---

### 3.5 帮助系统：Terminate 动作 vs 硬编码

**参考实现**：`--help` 被作为 `Terminate` 类型的 `Arg` 自动注册到每个命令：

```cangjie
command._args.add("help", Arg("help").short(r'h').action(Terminate {
    getStdOut().writeln(helpPrint(command))
}).help("打印帮助信息"))
```

**当前实现**：在 `mockRun()` 中硬编码了 `--help` / `-h` / `--version` / `-V` 的检测逻辑，与正常解析流程割裂。

**问题**：
1. 帮助和版本检测与解析管道分离，增加了维护复杂度。
2. 如果用户想自定义 `--help` 行为，只能修改 `App` 源码。

**建议**：将 `--help` 和 `--version` 实现为内置的特殊 Flag（类似 Terminate 动作），让它们走标准的解析管道，而非在 `mockRun` 里特殊分支处理。

---

### 3.6 字符串工具函数：手工实现 vs 标准库能力

**问题**：当前 `parser.cj` 自行实现了 `startsWith()`、`removePrefix()`、`splitOnFirstEquals()`、`toCharList()` 等字符串操作函数，使用 `split()` + 拼接或 `UInt32` 字节运算来模拟。

**参考实现**：直接使用仓颉 `String` 的内置方法 `startsWith("-")`、`s[2..]`（切片）、`toRuneArray()` 等。

**对比**：

| 操作 | 参考实现 | 当前实现 |
|------|----------|----------|
| 前缀检测 | `_inputArg.startsWith("-")` | 自定义 `startsWith(s, prefix)` 用 split 模拟 |
| 前缀移除 | `name[2..]`（String 切片） | 自定义 `removePrefix()` 用 split + 拼接 |
| 字符遍历 | `toRuneArray()` 获得 `Array<Rune>` | `for (b in s)` 遍历 UInt8 + `Rune(UInt32(b))` 转换 |

**建议**：
1. 使用 `String` 的原生 `startsWith()` 方法（如果 cjc 1.0.5 支持）或升级 cjc 版本以使用。
2. 使用 `String` 的下标切片 `s[n..]` 替代 `removePrefix()`。
3. 使用 `toRuneArray()` 替代当前的字节遍历 + UInt32 转换方式（当前方式在多字节 UTF-8 字符上会出 bug）。

---

### 3.7 短选项处理（Rune vs String）

**参考实现**：短选项使用 `Rune` 类型（`Arg(r'v')`，`short(r'c')`），这是语义上更正确的设计——短选项就是单个字符。

**当前实现**：短选项使用 `String` 类型（`Flag("verbose", "v")`，`short("c")`）。

**建议**：考虑将短选项类型改为 `Rune`，更贴合仓颉惯用法和语义正确性。但这不是必须的改动，只是改善代码表达力。

---

### 3.8 异常体系设计

**参考实现**：

```cangjie
abstract class CliException <: Exception {
    public prop diplayMessage: String  // property
}
```

使用 property `diplayMessage` 提供格式化消息，异常处理集中在 `handleCliException()` 函数中，通过 `match` 匹配不同异常类型。

**当前实现**：

```cangjie
public open class CliException <: Exception {
    public init(message: String) { super(message) }
}
```

使用 `open class`（而非 `abstract class`），错误消息通过基类 `Exception.message` 传递。

**评估**：两者都是合理的设计。参考实现的 `abstract class` + property 模式更严谨（强制子类实现显示消息）。当前实现更简洁。

**建议**：无需大改，但可以考虑将 `CliException` 改为 `abstract class`，如果未来需要每种异常子类提供不同格式的用户友好消息。

---

### 3.9 `Option<T>` vs 空字符串默认值

**参考实现**：大量使用 `Option<T>` 表示"无值"（如 `var _about = None<String>`、`var _help = None<String>`）。

**当前实现**：使用空字符串 `""` 作为"无值"标记（如 `var _description: String = ""`，`var _defaultValue: String = ""`）。

**建议**：对于可选字段，改用 `Option<String>` 更符合仓颉的习惯和类型安全原则。空字符串 `""` 和 "未设置" 在语义上不同——用户可能需要设置一个值就是空串。

---

### 3.10 HashMap 的使用方式

**参考实现**：子命令存储在 `HashMap<String, Command>` 中（包括别名也直接映射到同一子命令实例），查找为 O(1)。

**当前实现**：子命令存储在 `ArrayList<Command>` 中，查找时线性遍历O(n)。

**建议**：对于小规模子命令（<100 个），实际性能差异可忽略。但如果追求与参考实现一致的 O(1) 查找效率，可改用 HashMap 存储。保持当前方案也完全可行。

---

### 3.11 测试包声明与文件组织

**参考实现**：测试文件位于 `src/test/` 子目录，声明为 `internal package cli.test`。这是仓颉的内部子包机制，测试代码可以访问非 public 成员。

**当前实现**：测试文件直接放在 `src/` 目录下，声明为 `package cli`（与源码同包）。

**问题**：
1. 测试与源码混在同一目录层级，不利于职责分离。
2. 当前 cjpm.toml 配置为 `output-type = "executable"`，cjpm 能识别 `*_test.cj` 文件。但改为 `static` 后需要验证测试发现机制。

**建议**：将测试文件迁移到 `src/test/` 子目录（或 `tests/` 目录，视 cjpm 约定而定），并使用 `internal package cli.test` 声明。

---

### 3.12 缺失的功能特性

对标参考实现，当前框架缺少以下功能：

| 缺失功能 | 参考实现支持情况 | 优先级 |
| -------- | --------------- | ------ |
| `ArgAction.Append`（多值追加） | ✅ 支持重复 `--flag a --flag b` | 高 |
| `ArgAction.Terminate`（触发回调退出） | ✅ `--help` 基于此实现 | 高 |
| `ArgAction.SetTrue` / `SetFalse` | ✅ 枚举化的布尔动作 | 中 |
| 参数分组（`.group()`） | ✅ 帮助输出中分组展示 | 中 |
| `noInputBuild`（无输入时默认参数） | ✅ 为空命令提供默认行为 | 低 |
| 泛型取值 `get<T>()` | ✅ 基于 `Parsable<T>` | 高 |
| 批量添加 `.args()` / `.subcommands()` | ✅ 接受 Array 批量注册 | 低 |
| 帮助文本自动对齐 (`maxSubcommandOrArgSize`) | ✅ 动态计算最大宽度对齐 | 中 |
| `PeekableIterator` 模式 | ✅ 通过扩展 Iterator 实现 | 低 |

---

## 4. 当前实现的优势

对比参考实现，当前框架有以下**独有优势**：

| 优势项 | 说明 |
| ------ | ---- |
| `mockRun()` 沙箱 | 参考实现无此功能。支持纯内存测试捕获 stdout/stderr/exitCode，是本框架的核心测试基础设施。 |
| `TestResult` 结构 | 参考实现的测试需要通过 `Box` 手动捕获状态，本框架的 TestResult 更优雅。 |
| 退出码规范化 | 明确区分 0（成功）/1（业务错误）/2（解析错误），参考实现只有 0 和 1。 |
| 环境变量映射预留 | `Flag.envVar()` 为 Phase 3 配置合并流打基础，参考实现无此设计。 |
| 错误上下文输出 | `formatError()` 显示用户输入上下文，辅助定位问题。 |
| Flag 别名系统 | Flag 级别的别名（参考实现只有 Command 级别别名）。 |
| 变长参数的 min/max 校验 | 两者都支持，当前实现更明确地暴露在 API 上。 |

---

## 5. 改进优先级总结

### P0（必须修改）

1. **`output-type` 改为 `static`**：框架不应产出可执行文件。
2. **Builder 返回类型改为 `This`**：仓颉惯用法。
3. **修复 `toCharList()` 的 UTF-8 bug**：当前逐字节遍历会损坏多字节字符。应使用 `toRuneArray()` 或等效安全方式。

### P1（强烈建议）

4. **引入 `ArgAction` 枚举**：至少支持 `Set`、`SetTrue`、`SetFalse`、`Append`、`Terminate`。
5. **Flag 多值存储**：Context 中 flag 值改为 `ArrayList<String>` 支持 Append。
6. **泛型取值 `get<T>()`**：利用 `Parsable<T>` 接口取代手写 helper 方法。
7. **帮助系统走标准解析管道**：不在 `mockRun` 中硬编码，而是以 Terminate 动作实现。
8. **测试迁移至 `tests/` 目录**：与源码物理分离。

### P2（建议改进）

9. 可选字段使用 `Option<String>` 替代空字符串。
10. 参数分组 `.group()` 支持。
11. 帮助输出动态对齐（计算最长名称宽度）。
12. 批量注册 API `.args()` / `.subcommands()`。
13. 短选项类型考虑使用 `Rune`。
14. 去掉冗余 `return` 关键字。

---

## 6. 结论

当前 Phase 1 实现在**核心解析引擎、子命令路由、类型校验、mockRun 沙箱**等方面已经具备可用性，且 65 个测试全部通过。对标参考实现后，主要差距在于：

1. **仓颉语言惯用法**（`This` 返回类型、`Option<T>`、`Rune` 短选项、`toRuneArray()`）——这些是代码质量和安全性问题。
2. **ArgAction 枚举体系**——这是功能完整性的核心缺失，直接影响 `Append`、`Terminate` 等关键能力。
3. **帮助系统架构**——应从硬编码特殊分支改为标准管道处理。

建议在进入 Phase 2 之前先完成 P0 和 P1 的修正，确保框架内核的设计基础是坚实的。
