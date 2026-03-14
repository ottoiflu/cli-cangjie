internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 本地化接口测试 (Locale / i18n)
// ===============================================================

// 自定义中文 Locale 实现（用于测试覆盖）
class ChineseLocale <: Locale {
    public func labelError(): String { "错误" }
    public func labelWarning(): String { "警告" }
    public func labelHelp(): String { "帮助" }
    public func labelNote(): String { "注意" }

    public func helpUsagePrefix(): String { "用法: " }
    public func helpPrintHelp(): String { "打印帮助" }
    public func helpPrintVersion(): String { "打印版本" }
    public func helpMoreInfo(): String { "更多信息请尝试 '--help'。" }
    public func helpArgumentsHeading(): String { "参数" }
    public func helpExamplesHeading(): String { "示例" }
    public func helpValuePlaceholder(): String { "<值>" }
    public func helpDefaultLabel(value: String): String { "[默认: ${value}]" }

    public func errUnknownCommand(name: String): String {
        "未知命令 '${name}'。"
    }
    public func errUnknownCommandSuggestion(name: String, suggestion: String): String {
        "未知命令 '${name}'。你是否想输入 '${suggestion}'？"
    }
    public func errUnknownOption(name: String): String {
        "未知选项 '--${name}'。"
    }
    public func errUnknownOptionSuggestion(name: String, suggestion: String): String {
        "未知选项 '--${name}'。你是否想输入 '--${suggestion}'？"
    }
    public func errFlagRequiresValue(flag: String): String {
        "选项 '${flag}' 需要一个值。"
    }
    public func errRequiredFlagMissing(flag: String): String {
        "必需的选项 '--${flag}' 未提供。"
    }

    public func errTypeBool(value: String): String {
        "无法将 '${value}' 转换为布尔值。"
    }
    public func errTypeInt64(value: String): String {
        "无法将 '${value}' 转换为整数。"
    }

    public func errFlagConflict(flag: String, conflict: String): String {
        "选项 '--${flag}' 与 '--${conflict}' 不能同时使用。"
    }
    public func errArgRequired(name: String): String {
        "必需的参数 '${name}' 未提供。"
    }

    public func signalTerminated(sigName: String): String {
        "被 ${sigName} 信号终止"
    }

    public func widgetConfirmYes(): String { "[是/否]" }
    public func widgetConfirmNo(): String { "[是/否]" }
    public func widgetMultiSelectHint(): String { "（逗号分隔数字）" }
    public func widgetSpinnerDone(): String { "✔ " }

    public func summaryErrors(count: Int64): String { "${count} 个错误" }
    public func summaryWarnings(count: Int64): String { "${count} 个警告" }
    public func summaryFound(parts: String): String { "发现 ${parts}" }
    public func summaryAnd(): String { "和" }

    public func cfgExpectedFormat(): String { "期望 'key = value' 格式" }
    public func cfgUnknownKey(key: String): String { "未知键 '${key}'" }

    public func deprecatedWarning(itemType: String, itemName: String): String {
        "警告: ${itemType} '${itemName}' 已弃用"
    }
    public func deprecatedSince(version: String): String { "（自 ${version} 起）" }
    public func deprecatedReason(reason: String): String { "。${reason}" }
    public func deprecatedReplacement(replacement: String): String {
        " 请使用 '${replacement}' 代替。"
    }
}

@Test
class LocaleDefaultTest {
    @TestCase
    func testDefaultLocaleIsEnglish() {
        Messages.reset()
        let l = Messages.locale()
        @Assert(l.labelError() == "error")
        @Assert(l.labelWarning() == "warning")
        @Assert(l.helpUsagePrefix() == "Usage: ")
        @Assert(l.helpPrintHelp() == "Print help")
        @Assert(l.helpPrintVersion() == "Print version")
        @Assert(l.errUnknownCommand("foo") == "Unknown command 'foo'.")
        @Assert(l.errUnknownOption("bar") == "Unknown option '--bar'.")
        @Assert(l.errTypeBool("abc") == "Cannot convert 'abc' to Bool. Expected: true/false/yes/no/1/0")
    }

    @TestCase
    func testSetAndResetLocale() {
        Messages.reset()
        @Assert(Messages.locale().labelError() == "error")

        Messages.setLocale(ChineseLocale())
        @Assert(Messages.locale().labelError() == "错误")
        @Assert(Messages.locale().labelWarning() == "警告")

        Messages.reset()
        @Assert(Messages.locale().labelError() == "error")
    }

    @TestCase
    func testDefaultLocaleMethodsParamFormat() {
        Messages.reset()
        let l = Messages.locale()
        @Assert(l.errUnknownCommandSuggestion("lont", "lint") == "Unknown command 'lont'. Did you mean 'lint'?")
        @Assert(l.errFlagRequiresValue("--port") == "Flag '--port' requires a value.")
        @Assert(l.errRequiredFlagMissing("output") == "Required flag '--output' was not provided.")
        @Assert(l.errFlagConflict("fix", "check") == "Flag '--fix' cannot be used together with '--check'.")
        @Assert(l.errArgTooFew("files", 2, 1) == "Argument 'files' requires at least 2 values, but got 1.")
        @Assert(l.errArgRequired("input") == "Required argument 'input' was not provided.")
        @Assert(l.helpDefaultLabel("8080") == "[default: 8080]")
        @Assert(l.signalTerminated("SIGINT") == "Terminated by SIGINT")
    }

    @TestCase
    func testSummaryFormatDefault() {
        Messages.reset()
        let l = Messages.locale()
        @Assert(l.summaryErrors(1) == "1 error")
        @Assert(l.summaryErrors(3) == "3 errors")
        @Assert(l.summaryWarnings(1) == "1 warning")
        @Assert(l.summaryWarnings(5) == "5 warnings")
        @Assert(l.summaryFound("2 errors") == "Found 2 errors")
    }
}

@Test
class LocaleCustomTest {
    @TestCase
    func testCustomLocaleOverridesErrors() {
        Messages.setLocale(ChineseLocale())
        let l = Messages.locale()
        @Assert(l.labelError() == "错误")
        @Assert(l.errUnknownCommand("foo") == "未知命令 'foo'。")
        @Assert(l.errUnknownOption("bar") == "未知选项 '--bar'。")
        @Assert(l.errFlagRequiresValue("--port") == "选项 '--port' 需要一个值。")
        @Assert(l.errTypeBool("abc") == "无法将 'abc' 转换为布尔值。")
        @Assert(l.errTypeInt64("xyz") == "无法将 'xyz' 转换为整数。")
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleInMockRun() {
        Messages.setLocale(ChineseLocale())
        let app = App("test-app")
            .version("1.0.0")
            .command(Command("lint").description("Run lint"))
        let result = app.mockRun(["lont"])
        // 中文错误消息应包含自定义文本
        @Assert(result.stderr.contains("未知命令 'lont'"))
        @Assert(result.exitCode == 2)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleHelp() {
        Messages.setLocale(ChineseLocale())
        let app = App("test-app")
            .version("1.0.0")
            .command(Command("lint").description("Run lint"))
        let result = app.mockRun(["--help"])
        // 帮助文本应使用自定义 locale
        @Assert(result.stderr.contains("用法: "))
        @Assert(result.stderr.contains("打印帮助"))
        @Assert(result.stderr.contains("打印版本"))
        @Assert(result.exitCode == 0)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleFlagError() {
        Messages.setLocale(ChineseLocale())
        let app = App("test-app")
            .flag(Flag("port").short(r'p').valueType(Int64Type))
        let result = app.mockRun(["--port", "abc"])
        @Assert(result.stderr.contains("无法将 'abc' 转换为整数"))
        @Assert(result.exitCode == 2)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleFlagConflict() {
        Messages.setLocale(ChineseLocale())
        let app = App("test-app")
            .flag(Flag("fix").action(SetTrue).conflictsWith("check"))
            .flag(Flag("check").action(SetTrue))
            .action({ _ => 0 })
        let result = app.mockRun(["--fix", "--check"])
        @Assert(result.stderr.contains("不能同时使用"))
        @Assert(result.exitCode == 2)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleRequiredArg() {
        Messages.setLocale(ChineseLocale())
        let app = App("test-app")
            .argument(Argument("input").required(true))
            .action({ _ => 0 })
        let result = app.mockRun([])
        @Assert(result.stderr.contains("必需的参数 'input' 未提供"))
        @Assert(result.exitCode == 2)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleSignal() {
        Messages.setLocale(ChineseLocale())
        let handler = SignalHandler()
        let app = App("test-app")
            .signalHandler(handler)
            .action({ _ =>
                handler.simulateSignal(SIGINT)
                0
            })
        let result = app.mockRun([])
        @Assert(result.stderr.contains("被 SIGINT 信号终止"))
        @Assert(result.exitCode == 130)
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleWidgetConfirm() {
        Messages.setLocale(ChineseLocale())
        let confirm = Confirm("继续操作？").defaultValue(true)
        @Assert(confirm.render().contains("[是/否]"))
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleWidgetMultiSelect() {
        Messages.setLocale(ChineseLocale())
        let ms = MultiSelect("选择").option("A").option("B")
        @Assert(ms.render().contains("（逗号分隔数字）"))
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleWidgetSpinner() {
        Messages.setLocale(ChineseLocale())
        let spinner = Spinner()
        spinner.message("加载中")
        spinner.finish()
        @Assert(spinner.render().contains("✔ "))
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleDeprecation() {
        Messages.setLocale(ChineseLocale())
        let info = DeprecationInfo("功能已过时", "new-cmd", "2.0")
        let warning = info.formatWarning("command", "old-cmd")
        @Assert(warning.contains("警告: command 'old-cmd' 已弃用"))
        @Assert(warning.contains("（自 2.0 起）"))
        @Assert(warning.contains("请使用 'new-cmd' 代替"))
        Messages.reset()
    }

    @TestCase
    func testAppLocaleBuilder() {
        // 测试 App.locale() 构建器方法
        let app = App("test-app")
            .locale(ChineseLocale())
            .version("1.0.0")
            .command(Command("lint").description("Run lint"))
        @Assert(Messages.locale().labelError() == "错误")
        let result = app.mockRun(["--help"])
        @Assert(result.stderr.contains("用法: "))
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleConfigError() {
        Messages.setLocale(ChineseLocale())
        let loader = ConfigLoader()
        loader.knownKeys(["host", "port"])
        let (_, errors) = loader.parse("host = localhost\nbadkey = value", filePath: "test.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].message.contains("未知键"))
        Messages.reset()
    }

    @TestCase
    func testCustomLocaleAggregateError() {
        Messages.setLocale(ChineseLocale())
        let errors = ArrayList<String>(["err1", "err2"])
        let warnings = ArrayList<String>(["warn1"])
        let ex = AggregateException(errors, warnings)
        @Assert(ex.message.contains("2 个错误"))
        @Assert(ex.message.contains("1 个警告"))
        @Assert(ex.message.contains("发现"))
        Messages.reset()
    }

    @TestCase
    func testPartialOverridePreservesDefaults() {
        // 只覆盖部分方法，其余保持默认英文
        Messages.setLocale(ChineseLocale())
        let l = Messages.locale()
        // 已覆盖的方法
        @Assert(l.labelError() == "错误")
        // 未覆盖的方法应保持接口默认值
        @Assert(l.helpCommandsPlaceholder() == " <COMMAND>")
        @Assert(l.helpOptionsPlaceholder() == " [OPTIONS]")
        @Assert(l.helpOptionsHeading() == "Options")
        @Assert(l.errUnknownShortOption("x") == "Unknown option '-x'.")
        Messages.reset()
    }
}
