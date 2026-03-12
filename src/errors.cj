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
