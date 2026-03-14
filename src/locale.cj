package cli

// =============================================================================
// 本地化接口 (Localization / i18n)
//
// 为框架所有用户可见字符串提供统一的本地化接入点。
// 框架内部通过 Messages 单例获取所有文本，用户可通过 App.locale()
// 注入自定义 Locale 实现来覆盖默认英文文本。
// =============================================================================

// 本地化接口：定义框架所有用户可见字符串的获取方法
// 用户实现此接口即可完成全部框架文本的本地化/翻译
public interface Locale {

    // ── 诊断级别标签 ──
    // 对应 DiagnosticLevel 四个级别的显示文本
    func labelError(): String { "error" }
    func labelWarning(): String { "warning" }
    func labelHelp(): String { "help" }
    func labelNote(): String { "note" }

    // ── 帮助文档 ──
    func helpUsagePrefix(): String { "Usage: " }
    func helpCommandsPlaceholder(): String { " <COMMAND>" }
    func helpOptionsPlaceholder(): String { " [OPTIONS]" }
    func helpOptionsHeading(): String { "Options" }
    func helpArgumentsHeading(): String { "Arguments" }
    func helpExamplesHeading(): String { "Examples" }
    func helpDefaultLabel(value: String): String { "[default: ${value}]" }
    func helpValuePlaceholder(): String { "<VALUE>" }
    func helpPrintHelp(): String { "Print help" }
    func helpPrintVersion(): String { "Print version" }
    func helpMoreInfo(): String { "For more information, try '--help'." }

    // ── 命令解析错误 ──
    func errUnknownCommand(name: String): String {
        "Unknown command '${name}'."
    }
    func errUnknownCommandSuggestion(name: String, suggestion: String): String {
        "Unknown command '${name}'. Did you mean '${suggestion}'?"
    }
    func errUnknownCommandSuggestions(name: String, suggestions: String): String {
        "Unknown command '${name}'. Did you mean one of: ${suggestions}?"
    }

    // ── Flag/选项错误 ──
    func errUnknownOption(name: String): String {
        "Unknown option '--${name}'."
    }
    func errUnknownOptionSuggestion(name: String, suggestion: String): String {
        "Unknown option '--${name}'. Did you mean '--${suggestion}'?"
    }
    func errUnknownOptionSuggestions(name: String, suggestions: String): String {
        "Unknown option '--${name}'. Did you mean one of: ${suggestions}?"
    }
    func errUnknownShortOption(ch: String): String {
        "Unknown option '-${ch}'."
    }
    func errFlagRequiresValue(flag: String): String {
        "Flag '${flag}' requires a value."
    }
    func errRequiredFlagMissing(flag: String): String {
        "Required flag '--${flag}' was not provided."
    }

    // ── 值校验错误 ──
    func errInvalidChoiceValue(value: String, flag: String, choices: String): String {
        "Invalid value '${value}' for '--${flag}'. Valid options: ${choices}."
    }
    func errInvalidChoiceValueSuggestion(value: String, flag: String, choices: String, suggestion: String): String {
        "Invalid value '${value}' for '--${flag}'. Valid options: ${choices}. Did you mean '${suggestion}'?"
    }
    func errInvalidValueWithMessage(flag: String, message: String): String {
        "Invalid value for '--${flag}': ${message}"
    }
    func errInvalidValue(flag: String): String {
        "Invalid value for '--${flag}'."
    }

    // ── 约束错误 ──
    func errFlagConflict(flag: String, conflict: String): String {
        "Flag '--${flag}' cannot be used together with '--${conflict}'."
    }
    func errFlagRequires(flag: String, required: String): String {
        "Flag '--${flag}' requires '--${required}' to be set."
    }
    func errFlagGroupRequired(groupName: String, members: String): String {
        "At least one flag from group '${groupName}' is required: ${members}."
    }
    func errFlagGroupExclusive(flag1: String, flag2: String, groupName: String): String {
        "Flags '--${flag1}' and '--${flag2}' are mutually exclusive (group '${groupName}')."
    }

    // ── 子命令错误 ──
    func errSubcommandRequired(cmdName: String): String {
        "error: '${cmdName}' requires a subcommand but one was not provided."
    }

    // ── 位置参数错误 ──
    func errArgTooFew(name: String, min: Int64, got: Int64): String {
        "Argument '${name}' requires at least ${min} values, but got ${got}."
    }
    func errArgTooMany(name: String, max: Int64, got: Int64): String {
        "Argument '${name}' accepts at most ${max} values, but got ${got}."
    }
    func errArgRequired(name: String): String {
        "Required argument '${name}' was not provided."
    }

    // ── 类型转换错误 ──
    func errTypeBool(value: String): String {
        "Cannot convert '${value}' to Bool. Expected: true/false/yes/no/1/0"
    }
    func errTypeInt64(value: String): String {
        "Cannot convert '${value}' to Int64. Expected an integer value."
    }
    func errTypeFloat64(value: String): String {
        "Cannot convert '${value}' to Float64. Expected a numeric value."
    }

    // ── 错误聚合 ──
    func summaryErrors(count: Int64): String {
        "${count} error${if (count > 1) { "s" } else { "" }}"
    }
    func summaryWarnings(count: Int64): String {
        "${count} warning${if (count > 1) { "s" } else { "" }}"
    }
    func summaryFound(parts: String): String { "Found ${parts}" }
    func summaryAnd(): String { " and " }

    // ── 配置文件错误 ──
    func cfgExpectedFormat(): String { "expected 'key = value' format" }
    func cfgEmptyKey(): String { "empty key name" }
    func cfgDuplicateKey(key: String): String { "duplicate key '${key}'" }
    func cfgUnknownKey(key: String): String { "unknown key '${key}'" }
    func cfgDidYouMean(suggestion: String): String { "did you mean '${suggestion}'?" }

    // ── 弃用警告 ──
    func deprecatedWarning(itemType: String, itemName: String): String {
        "warning: ${itemType} '${itemName}' is deprecated"
    }
    func deprecatedSince(version: String): String { " since ${version}" }
    func deprecatedReason(reason: String): String { ". ${reason}" }
    func deprecatedReplacement(replacement: String): String {
        " Use '${replacement}' instead."
    }

    // ── 信号处理 ──
    func signalTerminated(sigName: String): String {
        "Terminated by ${sigName}"
    }

    // ── 交互组件 ──
    func widgetConfirmYes(): String { "[Y/n]" }
    func widgetConfirmNo(): String { "[y/N]" }
    func widgetMultiSelectHint(): String { " (comma-separated numbers)" }
    func widgetSpinnerDone(): String { "✓ " }
}

// 默认语言实现（英文） — 使用接口默认方法，无需覆盖
public class DefaultLocale <: Locale {
    public init() {}
}

// 框架全局消息源：单例模式，所有模块通过此对象获取本地化文本
// 线程安全说明：设置 locale 应在 App 构建阶段完成，运行时只读
public class Messages {
    private static var _locale: Locale = DefaultLocale()

    // 获取当前 Locale 实例
    public static func locale(): Locale { _locale }

    // 设置 Locale 实例（由 App.locale() 调用）
    public static func setLocale(l: Locale): Unit {
        _locale = l
    }

    // 重置为默认语言（主要用于测试）
    public static func reset(): Unit {
        _locale = DefaultLocale()
    }
}
