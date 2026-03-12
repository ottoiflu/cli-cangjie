package cli

// CLI 位置参数定义
public class Argument {
    var _name: String
    var _description: Option<String> = None
    var _required: Bool = false
    var _defaultValue: Option<String> = None
    var _valueType: ValueType = StringType
    var _variadic: Bool = false
    var _minCount: Int64 = 0
    var _maxCount: Int64 = -1  // -1 表示无限

    public init(name: String) {
        _name = name
    }

    // Builder 方法：统一返回 This

    public func description(d: String): This {
        _description = Some(d)
        this
    }

    public func required(r: Bool): This {
        _required = r
        this
    }

    public func defaultValue(v: String): This {
        _defaultValue = Some(v)
        this
    }

    public func valueType(t: ValueType): This {
        _valueType = t
        this
    }

    public func variadic(v: Bool): This {
        _variadic = v
        this
    }

    public func minCount(n: Int64): This {
        _minCount = n
        this
    }

    public func maxCount(n: Int64): This {
        _maxCount = n
        this
    }

    // Getter 方法
    public func getName(): String { _name }
    public func getDescription(): Option<String> { _description }
    public func isRequired(): Bool { _required }
    public func getDefaultValue(): Option<String> { _defaultValue }
    public func getValueType(): ValueType { _valueType }
    public func isVariadic(): Bool { _variadic }
    public func getMinCount(): Int64 { _minCount }
    public func getMaxCount(): Int64 { _maxCount }
}
