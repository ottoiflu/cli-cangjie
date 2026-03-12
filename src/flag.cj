package cli

import std.collection.*

// CLI 标志/选项定义
public class Flag {
    var _longName: String
    var _shortName: Option<Rune> = None
    var _description: Option<String> = None
    var _group: String = "Options"
    var _required: Bool = false
    var _defaultValue: Option<String> = None
    var _valueType: ValueType = StringType
    var _action: FlagAction = FlagAction.Set
    var _envVar: Option<String> = None
    var _aliases: ArrayList<String> = ArrayList<String>()

    public init(longName: String) {
        _longName = longName
    }

    // Builder 方法：统一返回 This

    public func short(s: Rune): This {
        _shortName = Some(s)
        this
    }

    public func description(d: String): This {
        _description = Some(d)
        this
    }

    public func group(g: String): This {
        _group = g
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

    public func action(a: FlagAction): This {
        _action = a
        match (a) {
            case SetTrue =>
                _valueType = BoolType
                if (_defaultValue.isNone()) {
                    _defaultValue = Some("false")
                }
            case SetFalse =>
                _valueType = BoolType
                if (_defaultValue.isNone()) {
                    _defaultValue = Some("true")
                }
            case _ => ()
        }
        this
    }

    // 便捷方法：等价于 action(FlagAction.SetTrue)
    public func asBool(): This {
        action(FlagAction.SetTrue)
    }

    public func envVar(e: String): This {
        _envVar = Some(e)
        this
    }

    public func alias(a: String): This {
        _aliases.add(a)
        this
    }

    // Getter 方法
    public func getLongName(): String { _longName }
    public func getShortName(): Option<Rune> { _shortName }

    public func getShortNameStr(): Option<String> {
        match (_shortName) {
            case Some(r) => Some(r.toString())
            case None => None
        }
    }

    public func getDescription(): Option<String> { _description }
    public func getGroup(): String { _group }
    public func isRequired(): Bool { _required }
    public func getDefaultValue(): Option<String> { _defaultValue }
    public func getValueType(): ValueType { _valueType }
    public func getAction(): FlagAction { _action }
    public func getEnvVar(): Option<String> { _envVar }
    public func getAliases(): ArrayList<String> { _aliases }

    // 是否为布尔开关型 flag
    public func isBoolFlag(): Bool {
        match (_action) {
            case SetTrue | SetFalse => true
            case _ => false
        }
    }

    // 是否为 Terminate 类型
    public func isTerminate(): Bool {
        match (_action) {
            case Terminate(_) => true
            case _ => false
        }
    }

    // 判断是否匹配给定的名称（长名或别名）
    public func matches(name: String): Bool {
        if (name == _longName) {
            return true
        }
        // 检查短名称（单字符字符串匹配）
        match (_shortName) {
            case Some(s) where name == s.toString() => return true
            case _ => ()
        }
        for (a in _aliases) {
            if (a == name) {
                return true
            }
        }
        false
    }

    // 判断是否匹配短名称
    public func matchesShort(c: Rune): Bool {
        match (_shortName) {
            case Some(s) => s == c
            case None => false
        }
    }
}
