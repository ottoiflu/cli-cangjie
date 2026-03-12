package cli

import std.collection.*

// 执行上下文：持有解析后的所有状态
public class Context {
    // 解析后的 flag 值: flagLongName -> value
    let _flags: HashMap<String, String> = HashMap<String, String>()
    // 解析后的位置参数值
    let _arguments: ArrayList<String> = ArrayList<String>()
    // 匹配到的命令路径
    let _commandPath: ArrayList<String> = ArrayList<String>()

    // 设置 flag 值
    public func setFlag(name: String, value: String): Unit {
        _flags[name] = value
    }

    // 获取 flag 值（如果存在）
    public func getFlag(name: String): Option<String> {
        if (_flags.contains(name)) {
            return Some(_flags[name])
        }
        return None
    }

    // 获取 flag 值，带默认值
    public func getFlagOrDefault(name: String, defaultVal: String): String {
        if (_flags.contains(name)) {
            return _flags[name]
        }
        return defaultVal
    }

    // 获取 flag 的 Bool 值
    public func getBoolFlag(name: String): Bool {
        if (_flags.contains(name)) {
            return _flags[name] == "true"
        }
        return false
    }

    // 获取 flag 的 Int64 值
    public func getInt64Flag(name: String): Option<Int64> {
        if (_flags.contains(name)) {
            let s = _flags[name]
            if (isValidInt(s)) {
                return Some(parseSimpleInt(s))
            }
        }
        return None
    }

    // 添加位置参数
    public func addArgument(value: String): Unit {
        _arguments.add(value)
    }

    // 获取位置参数
    public func getArgument(index: Int64): Option<String> {
        if (index >= 0 && index < _arguments.size) {
            return Some(_arguments[index])
        }
        return None
    }

    // 获取所有位置参数
    public func getArguments(): ArrayList<String> {
        return _arguments
    }

    // 获取位置参数数量
    public func argumentCount(): Int64 {
        return _arguments.size
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
        return result
    }

    // 获取 flags 快照（用于测试、调试）
    public func getAllFlags(): HashMap<String, String> {
        return _flags
    }
}

// 简易 Int64 手动解析（不依赖标准库 parse）
public func parseSimpleInt(s: String): Int64 {
    var result: Int64 = 0
    var negative = false
    var isFirst = true
    for (c in s) {
        let cv = UInt32(c)
        if (isFirst && cv == 45) {  // '-' = 45
            negative = true
            isFirst = false
            continue
        }
        if (isFirst && cv == 43) {  // '+' = 43
            isFirst = false
            continue
        }
        isFirst = false
        if (cv >= 48 && cv <= 57) {  // '0'=48, '9'=57
            let digit: Int64 = Int64(cv - 48)
            result = result * 10 + digit
        } else {
            throw TypeConversionException("Invalid integer character in '${s}'")
        }
    }
    if (negative) {
        return -result
    }
    return result
}
