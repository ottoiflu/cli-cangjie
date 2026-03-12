package cli

import std.collection.*

// CLI 框架异常基类
public open class CliException <: Exception {
    public init(message: String) {
        super(message)
    }
    public open override func getClassName(): String {
        "CliException"
    }
}

// 参数解析异常
public class ParseException <: CliException {
    public init(message: String) {
        super(message)
    }
    public override func getClassName(): String {
        "ParseException"
    }
}

// 类型转换异常
public class TypeConversionException <: CliException {
    public init(message: String) {
        super(message)
    }
    public override func getClassName(): String {
        "TypeConversionException"
    }
}

// 校验异常（缺少必要参数等）
public class ValidationException <: CliException {
    public init(message: String) {
        super(message)
    }
    public override func getClassName(): String {
        "ValidationException"
    }
}

// Terminate 动作触发的异常（用于 --help / --version 等提前终止）
public class TerminateException <: CliException {
    let _callback: () -> String

    public init(callback: () -> String) {
        super("terminate")
        _callback = callback
    }

    public func execute(): String {
        _callback()
    }

    public override func getClassName(): String {
        "TerminateException"
    }
}

// Phase 10: 聚合错误（收集多个验证错误后统一报告）
public class AggregateException <: CliException {
    let _errors: ArrayList<String>
    let _warnings: ArrayList<String>

    public init(errors: ArrayList<String>, warnings: ArrayList<String>) {
        super(formatSummary(errors, warnings))
        _errors = errors
        _warnings = warnings
    }

    public init(errors: ArrayList<String>) {
        super(formatSummary(errors, ArrayList<String>()))
        _errors = errors
        _warnings = ArrayList<String>()
    }

    public func getErrors(): ArrayList<String> { _errors }
    public func getWarnings(): ArrayList<String> { _warnings }
    public func errorCount(): Int64 { _errors.size }
    public func warningCount(): Int64 { _warnings.size }

    public override func getClassName(): String {
        "AggregateException"
    }
}

// 格式化聚合错误摘要
func formatSummary(errors: ArrayList<String>, warnings: ArrayList<String>): String {
    let l = Messages.locale()
    var parts = ArrayList<String>()
    if (errors.size > 0) {
        parts.add(l.summaryErrors(errors.size))
    }
    if (warnings.size > 0) {
        parts.add(l.summaryWarnings(warnings.size))
    }
    var summary = ""
    var first = true
    for (p in parts) {
        if (!first) { summary = summary + l.summaryAnd() }
        summary = summary + p
        first = false
    }
    l.summaryFound(summary)
}
