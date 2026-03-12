package cli

// 参数值类型枚举
public enum ValueType {
    | StringType
    | Int64Type
    | Float64Type
    | BoolType
}

// 检查字符串是否为合法整数格式
public func isValidInt(s: String): Bool {
    if (s.size == 0) {
        return false
    }
    var isFirst = true
    var hasDigit = false
    for (c in s) {
        let cv = UInt32(c)
        if (isFirst && (cv == 45 || cv == 43)) {  // '-'=45, '+'=43
            isFirst = false
            continue
        }
        isFirst = false
        if (cv < 48 || cv > 57) {  // '0'=48, '9'=57
            return false
        }
        hasDigit = true
    }
    return hasDigit
}

// 检查字符串是否为合法浮点数格式
public func isValidFloat(s: String): Bool {
    if (s.size == 0) {
        return false
    }
    var hasDot = false
    var hasDigit = false
    var isFirst = true
    for (c in s) {
        let cv = UInt32(c)
        if (isFirst && (cv == 45 || cv == 43)) {  // '-'=45, '+'=43
            isFirst = false
            continue
        }
        isFirst = false
        if (cv == 46) {  // '.'=46
            if (hasDot) {
                return false
            }
            hasDot = true
            continue
        }
        if (cv < 48 || cv > 57) {  // '0'=48, '9'=57
            return false
        }
        hasDigit = true
    }
    return hasDigit
}

// 规范化布尔值字符串
public func normalizeBool(s: String): String {
    if (s == "true" || s == "1" || s == "yes" || s == "TRUE" || s == "Yes" || s == "True") {
        return "true"
    }
    if (s == "false" || s == "0" || s == "no" || s == "FALSE" || s == "No" || s == "False") {
        return "false"
    }
    throw TypeConversionException("Cannot convert '${s}' to Bool. Expected: true/false/yes/no/1/0")
}

// 对原始值进行类型校验和转换
public func validateAndConvert(raw: String, targetType: ValueType): String {
    match (targetType) {
        case StringType => raw
        case BoolType => normalizeBool(raw)
        case Int64Type =>
            if (!isValidInt(raw)) {
                throw TypeConversionException("Cannot convert '${raw}' to Int64. Expected an integer value.")
            }
            raw
        case Float64Type =>
            if (!isValidFloat(raw)) {
                throw TypeConversionException("Cannot convert '${raw}' to Float64. Expected a numeric value.")
            }
            raw
    }
}
