package cli

// 参数值类型枚举
public enum ValueType {
    | StringType
    | Int64Type
    | Float64Type
    | BoolType
}

// Flag 动作类型枚举（对标参考实现的 ArgAction）
public enum FlagAction {
    | Set           // 设置值（默认）
    | SetTrue       // 布尔开关：设为 true
    | SetFalse      // 布尔开关：设为 false
    | Append        // 追加模式：支持 --flag a --flag b
    | Terminate(() -> String)  // 触发回调并终止（如 --help / --version）
}

// 检查字符串是否为合法整数格式
public func isValidInt(s: String): Bool {
    if (s.size == 0) {
        return false
    }
    let runes = s.toRuneArray()
    var startIdx: Int64 = 0
    var hasDigit = false
    if (runes[0] == r'-' || runes[0] == r'+') {
        startIdx = 1
    }
    var i = startIdx
    while (i < runes.size) {
        let c = runes[i]
        if (c < r'0' || c > r'9') {
            return false
        }
        hasDigit = true
        i++
    }
    hasDigit
}

// 检查字符串是否为合法浮点数格式
public func isValidFloat(s: String): Bool {
    if (s.size == 0) {
        return false
    }
    let runes = s.toRuneArray()
    var startIdx: Int64 = 0
    var hasDot = false
    var hasDigit = false
    if (runes[0] == r'-' || runes[0] == r'+') {
        startIdx = 1
    }
    var i = startIdx
    while (i < runes.size) {
        let c = runes[i]
        if (c == r'.') {
            if (hasDot) {
                return false
            }
            hasDot = true
            i++
            continue
        }
        if (c < r'0' || c > r'9') {
            return false
        }
        hasDigit = true
        i++
    }
    hasDigit
}

// 规范化布尔值字符串
public func normalizeBool(s: String): String {
    if (s == "true" || s == "1" || s == "yes" || s == "TRUE" || s == "Yes" || s == "True") {
        return "true"
    }
    if (s == "false" || s == "0" || s == "no" || s == "FALSE" || s == "No" || s == "False") {
        return "false"
    }
    throw TypeConversionException(Messages.locale().errTypeBool(s))
}

// 对原始值进行类型校验和转换
public func validateAndConvert(raw: String, targetType: ValueType): String {
    match (targetType) {
        case StringType => raw
        case BoolType => normalizeBool(raw)
        case Int64Type =>
            if (!isValidInt(raw)) {
                throw TypeConversionException(Messages.locale().errTypeInt64(raw))
            }
            raw
        case Float64Type =>
            if (!isValidFloat(raw)) {
                throw TypeConversionException(Messages.locale().errTypeFloat64(raw))
            }
            raw
    }
}
