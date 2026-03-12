package cli

// CLI 位置参数定义
public class Argument {
    var _name: String           // 参数名称
    var _description: String    // 描述
    var _required: Bool         // 是否必填
    var _defaultValue: String   // 默认值
    var _valueType: ValueType   // 值类型
    var _variadic: Bool         // 是否为变长参数（接收多个值）
    var _minCount: Int64        // 最少数量（变长时有效）
    var _maxCount: Int64        // 最多数量（-1 表示无限）

    public init(name: String) {
        _name = name
        _description = ""
        _required = false
        _defaultValue = ""
        _valueType = StringType
        _variadic = false
        _minCount = 0
        _maxCount = -1
    }

    // Builder 方法
    public func description(d: String): Argument {
        _description = d
        return this
    }

    public func required(r: Bool): Argument {
        _required = r
        return this
    }

    public func defaultValue(v: String): Argument {
        _defaultValue = v
        return this
    }

    public func valueType(t: ValueType): Argument {
        _valueType = t
        return this
    }

    public func variadic(v: Bool): Argument {
        _variadic = v
        return this
    }

    public func minCount(n: Int64): Argument {
        _minCount = n
        return this
    }

    public func maxCount(n: Int64): Argument {
        _maxCount = n
        return this
    }

    // Getter 方法
    public func getName(): String { _name }
    public func getDescription(): String { _description }
    public func isRequired(): Bool { _required }
    public func getDefaultValue(): String { _defaultValue }
    public func getValueType(): ValueType { _valueType }
    public func isVariadic(): Bool { _variadic }
    public func getMinCount(): Int64 { _minCount }
    public func getMaxCount(): Int64 { _maxCount }
}
