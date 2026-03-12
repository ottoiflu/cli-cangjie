# 仓颉 CLI 框架开发与测试需求文档 (Project: cangjie-cli-framework)

## 1. 项目概览

本项目旨在使用仓颉编程语言开发一个现代化的、具有极致用户体验的命令行（CLI）**框架**。该框架将帮助开发者快速构建对标 Rust Clippy、具有高健壮性和友好交互体验的 CLI 工具。

1. **核心目标**
    - **交互规范**：生成的 CLI 工具对标 Rust Clippy，遵循 clig.dev、GNU 及 Unix 实用工具规范。
    - **高健壮性**：框架层不仅实现基础解析，还要内置完善的错误拦截、容错与自动纠错建议机制。
    - **测试友好**：框架层面提供便捷的单元测试与集成测试 API，确保基于此框架构建的工具逻辑高度稳定。
    - **高扩展性**：支持中间件（Middleware）、生命周期钩子（Hooks）以及插件化机制。

2. **参考依据与源码路径**
    - **Clippy 源码参考**：对标的 Rust Clippy 源码位于本工作区的 `reference/rust-clippy` 文件夹中。构建框架时必须完全参考 Clippy 的 CLI 设计，并在必要时直接读取及分析其源码进行设计参考。
    - **CLI 设计标准**：设计必须严格遵循 [clig.dev](https://clig.dev/) 指南、GNU CLI 标准以及 Unix 实用工具规范。
    - **仓颉官方文档**：开发过程中涉及的语言特性与标准库参考，已经作为skills配置到.agent目录下，或者你也可以直接查阅位于本工作区 `reference/cangjie_docs` 目录下的官方文档。
    - **仓颉cli工具样式参考**:`reference/cli-cj`目录下是目前仓颉官方提供的几个 CLI 工具的源码实现以及测试用力编写，开发框架时可以参考这些工具的实现风格和设计思路。

## 2. 交互与设计规范 (遵照 clig.dev)

1. **基础准则 (UX & Diagnostics)**
    - **发现性**：自动生成极其美观的帮助文档树，开箱即用支持 `-h/--help` 和 `-V/--version`。自动生成帮助文档需对标 GNU 标准，支持根据终端宽度动态折行。
    - **输出流管理**：标准结果数据严格输出至 `stdout`，诊断、进度展示、帮助日志及错误信息严格输出至 `stderr`。分级诊断输出需内置 Note, Help, Warning, Error 四种语义化输出格式。
    - **标准退出码**：`0` 执行成功；`1` 通用业务逻辑错误；`2` 参数解析或框架层错误。框架应自动捕获并格式化输出。
    - **色彩与样式**：内置终端富文本（加粗、颜色、下划线）输出。自动检测 `NO_COLOR` 环境变量及非 TTY 环境（如管道符、CI 环境），自动退化为纯文本输出。

2. **Clippy 风格的诊断与错误提示**
    - **智能建议 (Did-you-mean)**：用户输入错误命令或选项时，利用 Levenshtein 距离算法（阈值 0.7）自动提示最接近的正确选项。示例：`Error: Unknown option '--conf'. Did you mean '--config'?`
    - **视觉化错误定位**：报错时不仅提供摘要，还需指出具体的发生错误上下文，尽可能指向发生错误的参数位置或配置文件行，支持视觉高亮。

## 3. 核心功能与架构设计

1. **增强型结构化命令树 (Command Builder)**
    - **递归子命令支持**：支持无限深度的子命令架构（如 `tool cloud server start`），每个子命令拥有独立上下文。提供流式（Builder）或宏增强的 API 来声明指令树（Command）。
    - **变长参数与占位符**：支持位置参数（Arguments）的最小/最大数量限制，支持 `...rest` 模式。
    - **别名系统**：支持为命令和选项设置别名（如 `--verbose` 缩写为 `-v`，`install` 别名为 `i`）。
    - **生命周期干预 (Hooks)**：支持 `PersistentPreRun` (全局前置)、`PreRun` (当前命令前置)、`Run` (业务)、`PostRun` (后置)、`PersistentPostRun` (全局后置) 等钩子函数。

2. **强类型参数与多源配置流合并 (The Configuration Pipeline)**
    - **优先级覆盖模型**：建立统一的参数获取管道，优先级严格遵循：命令行显式指定的 Flags > 环境变量映射 > 本地配置文件（如 `./config.toml`） > 用户全局配置文件 > 代码硬编码默认值。
    - **自动环境映射**：支持将命令行选项自动关联到特定的系统环境变量（如 `--db-host` 关联到 `PREFIX_DB_HOST`）。
    - **强类型校验**：提供内置转换器（Int64, Bool, Path, DateTime 等），框架层拦截并处理参数格式化错误，转化为友好报错提示。

3. **中间件与上下文传递 (Middleware & Context)**
    - **可插拔模块模式**：允许开发者注册全局或局部中间件，用于抽取如日志记录、耗时统计、身份鉴权等横切关注点。
    - **依赖注入**：Context 对象需支持在横跨生命周期中安全地存储和传递请求维度的状态。

## 4. 测试与工程化支持 (Testing Protocol)

AI 在编写框架及示例文档代码时，必须遵循并同步生成以下测试：

1. **框架自身的单元测试 (Unit Tests)**
    - **目标**：测试框架内部的解析引擎、生命周期流转、编辑距离算法等模块。
    - **要求**：使用仓颉内置的 `std.unit` 框架实现高覆盖率自测。

2. **虚拟执行沙箱与集成测试 (CLI Integration Tests)**
    - **隔离执行接口 (MockRun)**：提供类似 `mockRun(args: Array<String>) -> TestResult` 的测试 API，无需启动真实进程即可在内存中运行命令。
    - **IO 独立捕获**：测试沙箱能独立捕获 `stdout` 和 `stderr` 的流数据，通过内置便捷正则等断言能力断言输出和返回码。
    - **交互式模拟 (Input Mock)**：支持预设 `stdin` 的输入流数据，用于自动化测试 Prompt CLI 交互。

3. **黄金文件测试 (Golden Files)**
    - **快照比对能力**：支持将复杂的 CLI 输出（如大型且排版精确的 Help 树或错误堆栈）保存为文本文件，并在后续测试中进行 1:1 比对，检测微小 UI 变动。

## 5. 非功能性需求 (Non-Functional Requirements)

1. **核心非功能需求**
    - **冷启动性能**：框架核心解析逻辑在 100 个命令量级下，冷启动耗时应控制在 10ms 以内。
    - **极致稳定性**：框架核心必须能够优雅地捕获业务逻辑抛出的各类 Exception，保障用户层面看到错误报告，而不是直接 Core Dump 崩溃。
    - **规范依从性**：默认退出码严格顺应 Unix 规范（0:成功, 1:业务逻辑通用错误, 2:命令行解析相关错误, 130:Ctrl+C 主动终止）。


## 7. 仓颉代码示例参考 (使用本框架) 

典型的测试结构：

```cangjie
import std.unit.*
// import custom.cli.framework.*

@Test
func testCommandHelp() {
    // 模拟运行命令 --help (基于框架内部的沙箱 API)
    let app = App()
        .name("cj-tool")
        .command(LintCommand())
    
    let result = app.mockRun(["--help"]) 
    assertContains(result.stderr, "Usage:") // 帮助文档常推导至 stderr
    assertContains(result.stderr, "Options:")
    assertEquals(result.exitCode, 0)
}

@Test
func testDidYouMean() {
    let app = App().command(LintCommand())
    let result = app.mockRun(["lont"])
    assertNotEquals(result.exitCode, 0)
    assertContains(result.stderr, "Did you mean 'lint'?")
}
```

## 8. 框架开发与测试核心里程碑（Milestones）

为了在开发阶段有据可依并更好地指导各模块测试的展开，请参照此清单进行渐进式开发与校验分配（强烈对标 Clippy 及其底层 clap/cargo 的底层设计思路）：

1. **Phase 1: 核心路由与基础解析引擎 (The Core)** — `v0.1.0` ✅ 已完成
    - [x] **命令树构建 (Command Builder)**：支持多级层级声明和基础元数据设置。
    - [x] **多形态参数捕获 (Flags/Options/Args)**：短/长选项、布尔开关及定长/变长位置参数。
    - [x] **参数强类型转换**：内建转换器及解析异常自动上抛框架层。
    - [x] **mockRun 沙箱**：内存级执行，stdout/stderr 独立捕获，exitCode 断言。
    - [x] **Help/Version 自动生成**：`--help`/`-h`/`--version`/`-V` 自动注入与输出。
    - **测试**: 87 用例全部通过，覆盖命令树、解析器、类型转换、上下文、集成场景。

2. **Phase 2: 诊断系统与 Clippy 级别用户体验 (UX & Diagnostics)** — `v0.2.0` ✅ 已完成
    - [x] **智能拼写纠错 (Did-You-Mean)**：Levenshtein 算法，提供阈值 0.7 的相似度命令/选项推荐。对标 Clippy 的 `--explain` 纠错体验。
    - [x] **终端美化与无障碍引擎**：ANSI 样式（加粗、颜色、下划线）输出。自动检测 `NO_COLOR` 环境变量及非 TTY 环境，自动退化为纯文本。
    - [x] **结构化诊断输出**：内置 Note, Help, Warning, Error 四级语义化输出格式，对标 Rust 编译器 / Clippy 的诊断样式。
    - [x] **视觉化错误定位**：报错时指出具体参数位置上下文，支持高亮标注错误 token。
    - **测试**: 126 用例全部通过（新增 39 用例），覆盖编辑距离、样式引擎、诊断渲染、Did-You-Mean 端到端集成。

3. **Phase 3: 配置合并流与生命周期抽象 (Context & Pipeline)** — `v0.3.0` ✅ 已完成
    - [x] **生命周期流转机制**：实现 `PersistentPreRun`/`PreRun`/`Run`/`PostRun`/`PersistentPostRun` 钩子函数。
    - [x] **中间件 (Middleware)**：支持全局/局部中间件注册，用于日志、耗时统计、鉴权等横切关注点。
    - [x] **环境变量配置合并**：Flag 自动关联环境变量（如 `--db-host` → `PREFIX_DB_HOST`），优先级：CLI > ENV > 默认值。
    - [x] **Context 依赖注入**：Context 对象支持在生命周期中安全存储和传递请求维度状态。
    - **测试**: 146 用例全部通过（新增 20 用例），覆盖生命周期钩子顺序、中间件链式调用与短路、环境变量三级优先级、Context DI 存取传递。

4. **Phase 4: 测试套件增强与快照测试 (Testing Infra)** — `v0.4.0` ✅ 已完成
    - [x] **Golden Files (快照测试)**：对比生成的 Help 树、错误输出等文本快照，检测 UI 回退。
    - [x] **交互式模拟 (Input Mock)**：支持预设 stdin 输入流数据，自动化测试 Prompt 交互。
    - **测试**: 169 用例全部通过（新增 23 用例），覆盖快照引擎创建/比对/更新/diff、InputMock 队列、Prompt 文本/确认/选择/Action 集成。

5. **Phase 5: 交互式组件集支持补充** — `v0.5.0` ✅ 已完成
    - [x] **交互式终端组件**：Spinner（4 种动画样式）、ProgressBar（可配置宽度/字符/百分比）、Confirm / Select / MultiSelect 组件。
    - [x] **交互测试 Input Mock 方案**：所有组件与 InputMock 集成，支持在 mockRun 中端到端交互测试。
    - **测试**: 214 用例全部通过（新增 45 用例），覆盖 Spinner 帧循环/状态、ProgressBar 进度控制/渲染、Confirm y/n/默认值、Select 数字/文本选择、MultiSelect 多选、组件 mockRun 集成。

6. **Phase 6: Flag 约束与高级验证 (Constraints & Validation)** — `v0.6.0` ✅ 已完成
    - [x] **互斥标志 (Mutual Exclusion)**：支持 `conflictsWith()` 声明，运行时检测冲突并报错。对标 clap 的 `conflicts_with` 机制（如 Clippy lintcheck 中 `--fix` 与 `--max-jobs` 互斥）。
    - [x] **标志依赖 (Flag Dependencies)**：支持 `requires()` 声明，指定 Flag 前置依赖关系（如 `--output-format` 依赖 `--output`）。
    - [x] **自定义验证器 (Custom Validators)**：Flag 支持注册 `validator((String) -> Bool)` 回调，框架层拦截不合法值并生成诊断报错。对标 Clippy clippy_dev 的 `lint_name()` 校验器。
    - [x] **隐藏标志与命令 (Hidden)**：支持 `.hidden()` 标记，从 Help 输出中隐藏但仍可正常使用。对标 clap 的 `hide = true`。
    - [x] **标志组验证 (Group Validation)**：支持声明式标志组约束：`requireGroup(name, members)` (至少选一)、`mutuallyExclusiveGroup(name, members)` (最多选一)。
    - **测试**: 239 用例全部通过（新增 25 用例），覆盖互斥检测、依赖检查、自定义验证器、隐藏标志/命令、标志组约束、Clippy lintcheck 模式集成。

7. **Phase 7: 配置文件管道 (Configuration Files)** — `v0.7.0` ✅ 已完成
    - [x] **配置文件加载**：支持简洁的 `key = value` 格式配置文件（兼容 TOML 子集），提供 `ConfigLoader` 模块。
    - [x] **配置文件发现**：支持目录向上遍历查找配置文件（如从 CWD 向上查找 `app.toml`），支持 `CONFIG_PATH` 环境变量覆盖。对标 Clippy 的 `clippy.toml` 查找逻辑。
    - [x] **四级优先级管道**：完善配置合并流为：CLI 显式参数 > 环境变量 > 配置文件 > 代码默认值。
    - [x] **配置错误报告**：解析配置文件失败时提供行号定位与 Did-You-Mean 建议（对标 Clippy 的 `ConfError` + `edit_distance` 字段纠错）。
    - **测试**: 269 用例全部通过（新增 30 用例），覆盖配置解析、错误检测、目录发现、Key 归一化、四级优先级管道、配置错误 mockRun 集成。

8. **Phase 8: Shell 补全与高级特性 (Completion & Advanced)** — `v0.8.0`
    - [ ] **Shell 补全脚本生成**：支持生成 Bash/Zsh/Fish 三种 Shell 的自动补全脚本。对标 clap_complete 的补全生成能力。
    - [ ] **输出格式模式 (Output Formats)**：支持 `--format text|json` 切换输出格式。对标 Clippy lintcheck 的 `--format` 选项。
    - [ ] **丰富版本信息**：版本输出包含构建元数据（构建时间、Git commit hash）。对标 `rustc_tools_util` 的 `VersionInfo` 设计。
    - [ ] **标志/命令弃用系统 (Deprecation)**：支持 `.deprecated(reason, replacement)` 标记，使用时自动输出 Warning 级别迁移提示。对标 Clippy config 的 `#[conf_deprecated]` 机制。
    - [ ] **全局标志传播**：支持将 App 级 Flag（如 `--verbose`、`--color`）自动传播至所有子命令。
