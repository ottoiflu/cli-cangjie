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

    // Phase 6: 约束与验证
    var _conflictsWith: ArrayList<String> = ArrayList<String>()
    var _requires: ArrayList<String> = ArrayList<String>()
    var _hidden: Bool = false
    var _validator: Option<(String) -> Bool> = None
    var _validatorMessage: String = ""

    // Phase 8: 弃用
    var _deprecated: Option<DeprecationInfo> = None

    // Phase 9: 可选值约束与分隔符
    var _choices: ArrayList<String> = ArrayList<String>()
    var _delimiter: Option<Rune> = None

    // Phase 12: clap 对标特性
    var _valueName: Option<String> = None       // 自定义值占位名 (如 <FILE>)
    var _valueHint: ValueHint = ValueHint.Default  // Shell 补全提示
    var _allowHyphenValues: Bool = false         // 允许 -开头的值
    var _longHelp: Option<String> = None         // --help 时显示的详细描述

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
            case Count =>
                _valueType = Int64Type
                if (_defaultValue.isNone()) {
                    _defaultValue = Some("0")
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

    // Phase 6: 约束 Builder 方法

    // 声明与指定 Flag 互斥
    public func conflictsWith(flagName: String): This {
        _conflictsWith.add(flagName)
        this
    }

    // 声明依赖指定 Flag
    public func requires(flagName: String): This {
        _requires.add(flagName)
        this
    }

    // 标记从 Help 输出中隐藏
    public func hidden(h!: Bool = true): This {
        _hidden = h
        this
    }

    // 注册自定义值验证器
    public func validator(fn: (String) -> Bool, message!: String = ""): This {
        _validator = Some(fn)
        _validatorMessage = message
        this
    }

    // Phase 8: 弃用标记
    public func deprecated(reason: String, replacement!: String = ""): This {
        if (replacement.size > 0) {
            _deprecated = Some(DeprecationInfo(reason, replacement))
        } else {
            _deprecated = Some(DeprecationInfo(reason))
        }
        this
    }

    public func deprecatedSince(reason: String, replacement: String, since: String): This {
        _deprecated = Some(DeprecationInfo(reason, replacement, since))
        this
    }

    // Phase 9: 限定可选值集合
    public func choices(values: Array<String>): This {
        for (v in values) {
            _choices.add(v)
        }
        this
    }

    // Phase 9: 设置值分隔符（如逗号分隔多值）
    public func delimiter(d: Rune): This {
        _delimiter = Some(d)
        this
    }

    // Phase 12: 自定义值占位名（在帮助中显示为 --output <FILE>）
    public func valueName(name: String): This {
        _valueName = Some(name)
        this
    }

    // Phase 12: Shell 补全值类型提示
    public func valueHint(hint: ValueHint): This {
        _valueHint = hint
        this
    }

    // Phase 12: 允许以连字符开头的值（如 --offset -5）
    public func allowHyphenValues(allow!: Bool = true): This {
        _allowHyphenValues = allow
        this
    }

    // Phase 12: 详细帮助描述（--help 显示，-h 不显示）
    public func longHelp(text: String): This {
        _longHelp = Some(text)
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

    // Phase 6: 约束 Getter 方法
    public func getConflicts(): ArrayList<String> { _conflictsWith }
    public func getRequires(): ArrayList<String> { _requires }
    public func isHidden(): Bool { _hidden }
    public func getValidator(): Option<(String) -> Bool> { _validator }
    public func getValidatorMessage(): String { _validatorMessage }

    // Phase 8: 弃用 Getter
    public func getDeprecation(): Option<DeprecationInfo> { _deprecated }
    public func isDeprecated(): Bool { _deprecated.isSome() }

    // Phase 9: Getter
    public func getChoices(): ArrayList<String> { _choices }
    public func getDelimiter(): Option<Rune> { _delimiter }
    public func hasChoices(): Bool { _choices.size > 0 }

    // Phase 12: Getter
    public func getValueName(): Option<String> { _valueName }
    public func getValueHint(): ValueHint { _valueHint }
    public func getAllowHyphenValues(): Bool { _allowHyphenValues }
    public func getLongHelp(): Option<String> { _longHelp }

    // 获取值的占位符文本（优先 valueName，其次 choices，最后默认）
    public func getValuePlaceholder(): String {
        match (_valueName) {
            case Some(name) => "<${name}>"
            case None =>
                if (hasChoices()) {
                    var cStr = "<"
                    var fst = true
                    for (c in _choices) {
                        if (!fst) { cStr = cStr + "|" }
                        cStr = cStr + c
                        fst = false
                    }
                    cStr + ">"
                } else {
                    Messages.locale().helpValuePlaceholder()
                }
        }
    }

    // 是否为布尔开关型 flag
    public func isBoolFlag(): Bool {
        match (_action) {
            case SetTrue | SetFalse => true
            case _ => false
        }
    }

    // 是否为 Count 类型
    public func isCount(): Bool {
        match (_action) {
            case Count => true
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
