package cli

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
