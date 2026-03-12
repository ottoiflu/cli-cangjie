package cli

import std.collection.*

// CLI 标志/选项定义
public class Flag {
    // 核心属性
    var _longName: String       // 长名称，如 "verbose"
    var _shortName: String      // 短名称，如 "v"
    var _description: String    // 描述文本
    var _required: Bool         // 是否必填
    var _defaultValue: String   // 默认值
    var _valueType: ValueType   // 值类型
    var _isBool: Bool           // 是否为布尔开关（无需后续值）
    var _envVar: String         // 关联的环境变量名（预留）
    var _aliases: ArrayList<String>  // 别名列表

    // 构造器：最小化参数，其余通过 Builder 链设置
    public init(longName: String) {
        _longName = longName
        _shortName = ""
        _description = ""
        _required = false
        _defaultValue = ""
        _valueType = StringType
        _isBool = false
        _envVar = ""
        _aliases = ArrayList<String>()
    }

    // 带短名称的构造器
    public init(longName: String, shortName: String) {
        _longName = longName
        _shortName = shortName
        _description = ""
        _required = false
        _defaultValue = ""
        _valueType = StringType
        _isBool = false
        _envVar = ""
        _aliases = ArrayList<String>()
    }

    // Builder 方法
    public func short(s: String): Flag {
        _shortName = s
        return this
    }

    public func description(d: String): Flag {
        _description = d
        return this
    }

    public func required(r: Bool): Flag {
        _required = r
        return this
    }

    public func defaultValue(v: String): Flag {
        _defaultValue = v
        return this
    }

    public func valueType(t: ValueType): Flag {
        _valueType = t
        return this
    }

    public func asBool(): Flag {
        _isBool = true
        _valueType = BoolType
        _defaultValue = "false"
        return this
    }

    public func envVar(e: String): Flag {
        _envVar = e
        return this
    }

    public func alias(a: String): Flag {
        _aliases.add(a)
        return this
    }

    // Getter 方法
    public func getLongName(): String { _longName }
    public func getShortName(): String { _shortName }
    public func getDescription(): String { _description }
    public func isRequired(): Bool { _required }
    public func getDefaultValue(): String { _defaultValue }
    public func getValueType(): ValueType { _valueType }
    public func isBoolFlag(): Bool { _isBool }
    public func getEnvVar(): String { _envVar }
    public func getAliases(): ArrayList<String> { _aliases }

    // 判断是否匹配给定的名称（长名、短名或别名）
    public func matches(name: String): Bool {
        if (name == _longName || name == _shortName) {
            return true
        }
        for (a in _aliases) {
            if (a == name) {
                return true
            }
        }
        return false
    }
}
