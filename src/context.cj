package cli

import std.collection.*
import std.convert.Parsable

// 执行上下文：持有解析后的所有状态
public class Context {
    // flag 值多值存储: flagLongName -> ArrayList<String>
    let _flags: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    // 位置参数值
    let _arguments: ArrayList<String> = ArrayList<String>()
    // 匹配到的命令路径
    let _commandPath: ArrayList<String> = ArrayList<String>()
    // 自定义值存储（依赖注入）: key -> value
    let _values: HashMap<String, String> = HashMap<String, String>()

    // 设置 flag 值（覆盖模式：Set / SetTrue / SetFalse）
    public func setFlag(name: String, value: String): Unit {
        let list = ArrayList<String>()
        list.add(value)
        _flags[name] = list
    }

    // 追加 flag 值（Append 模式）
    public func appendFlag(name: String, value: String): Unit {
        if (_flags.contains(name)) {
            _flags[name].add(value)
        } else {
            let list = ArrayList<String>()
            list.add(value)
            _flags[name] = list
        }
    }

    // 获取 flag 的最后一个值
    public func getFlag(name: String): Option<String> {
        if (_flags.contains(name)) {
            let list = _flags[name]
            if (list.size > 0) {
                return Some(list[list.size - 1])
            }
        }
        None
    }

    // 获取 flag 所有值（用于 Append 模式）
    public func getFlagAll(name: String): Option<ArrayList<String>> {
        if (_flags.contains(name)) {
            Some(_flags[name])
        } else {
            None
        }
    }

    // 获取 flag 值，带默认值
    public func getFlagOrDefault(name: String, defaultVal: String): String {
        match (getFlag(name)) {
            case Some(v) => v
            case None => defaultVal
        }
    }

    // 泛型取值：利用 Parsable<T>
    public func get<T>(name: String): Option<T> where T <: Parsable<T> {
        match (getFlag(name)) {
            case Some(v) => T.tryParse(v)
            case None => None
        }
    }

    // 泛型取值所有值
    public func getAll<T>(name: String): Option<ArrayList<T>> where T <: Parsable<T> {
        match (getFlagAll(name)) {
            case Some(list) =>
                let result = ArrayList<T>()
                for (v in list) {
                    match (T.tryParse(v)) {
                        case Some(parsed) => result.add(parsed)
                        case None => return None
                    }
                }
                Some(result)
            case None => None
        }
    }

    // 获取 flag 的 String 值
    public func getString(name: String): Option<String> {
        getFlag(name)
    }

    // 获取 flag 的 Bool 值
    public func getBoolFlag(name: String): Bool {
        match (getFlag(name)) {
            case Some(v) => v == "true"
            case None => false
        }
    }

    // 获取 flag 的 Int64 值
    public func getInt64Flag(name: String): Option<Int64> {
        match (getFlag(name)) {
            case Some(s) =>
                if (isValidInt(s)) {
                    Some(parseSimpleInt(s))
                } else {
                    None
                }
            case None => None
        }
    }

    // 检查 flag 是否存在
    public func hasFlag(name: String): Bool {
        _flags.contains(name)
    }

    // 添加位置参数
    public func addArgument(value: String): Unit {
        _arguments.add(value)
    }

    // 获取位置参数
    public func getArgument(index: Int64): Option<String> {
        if (index >= 0 && index < _arguments.size) {
            Some(_arguments[index])
        } else {
            None
        }
    }

    // 获取所有位置参数
    public func getArguments(): ArrayList<String> {
        _arguments
    }

    // 获取位置参数数量
    public func argumentCount(): Int64 {
        _arguments.size
    }

    // 添加命令路径组件
    public func pushCommandPath(name: String): Unit {
        _commandPath.add(name)
    }

    // 获取命令路径字符串
    public func getCommandPathStr(): String {
        var result = ""
        var first = true
        for (p in _commandPath) {
            if (!first) {
                result = result + " "
            }
            result = result + p
            first = false
        }
        result
    }

    // 获取 flags 快照（用于测试、调试）
    public func getAllFlags(): HashMap<String, ArrayList<String>> {
        _flags
    }

    // --- 自定义值存储 (依赖注入) ---

    // 存储自定义值（字符串形式）
    public func setValue(key: String, value: String): Unit {
        _values[key] = value
    }

    // 获取自定义值
    public func getValue(key: String): Option<String> {
        _values.get(key)
    }

    // 检查自定义值是否存在
    public func hasValue(key: String): Bool {
        _values.contains(key)
    }
}

// 简单整数解析（仅内部使用）
public func parseSimpleInt(s: String): Int64 {
    let runes = s.toRuneArray()
    var negative = false
    var startIdx: Int64 = 0
    if (runes.size > 0 && runes[0] == r'-') {
        negative = true
        startIdx = 1
    } else if (runes.size > 0 && runes[0] == r'+') {
        startIdx = 1
    }
    var result: Int64 = 0
    var i = startIdx
    while (i < runes.size) {
        let digit = Int64(UInt32(runes[i])) - 48  // '0' = 48
        result = result * 10 + digit
        i++
    }
    if (negative) { -result } else { result }
}


