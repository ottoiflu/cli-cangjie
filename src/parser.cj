package cli

import std.collection.*

// 字符串工具函数（仅使用 split / contains / size / 拼接，无字节级操作）

// 检查字符串是否以指定前缀开头
func startsWith(s: String, prefix: String): Bool {
    if (s.size < prefix.size) {
        return false
    }
    if (prefix.size == 0) {
        return true
    }
    let parts = s.split(prefix)
    return parts.size >= 2 && parts[0].size == 0
}

// 移除字符串的指定前缀（仅移除第一次出现的前缀）
func removePrefix(s: String, prefix: String): String {
    if (!startsWith(s, prefix)) {
        return s
    }
    // s = prefix + rest，split 结果的 parts[0] 为空，parts[1..] 为后续部分
    let parts = s.split(prefix)
    var result = ""
    var i: Int64 = 1
    while (i < parts.size) {
        if (i > 1) {
            result = result + prefix
        }
        result = result + parts[i]
        i++
    }
    return result
}

// 在字符串中按第一个 "=" 分割为 (key, value, found)
func splitOnFirstEquals(s: String): (String, String, Bool) {
    if (!s.contains("=")) {
        return (s, "", false)
    }
    let parts = s.split("=")
    let key = parts[0]
    var value = ""
    var i: Int64 = 1
    while (i < parts.size) {
        if (i > 1) {
            value = value + "="
        }
        value = value + parts[i]
        i++
    }
    return (key, value, true)
}

// 将字符串分解为单字符字符串列表
func toCharList(s: String): ArrayList<String> {
    let result = ArrayList<String>()
    // 利用空字符串分割获取每个字符
    // 遍历每个字节并转成 Rune 再转成 String
    for (b in s) {
        let ch = Rune(UInt32(b))
        result.add(ch.toString())
    }
    return result
}

// 核心解析引擎
public class Parser {
    // 解析参数列表，路由到正确的命令并提取 flags/arguments
    public func parse(rootCmd: Command, rawArgs: Array<String>): (Command, Context) {
        let ctx = Context()
        var currentCmd = rootCmd
        ctx.pushCommandPath(rootCmd.getName())

        // 步骤 1: 路由子命令
        var argIndex: Int64 = 0
        while (argIndex < rawArgs.size) {
            let arg = rawArgs[argIndex]
            if (arg.size > 0 && startsWith(arg, "-")) {
                break
            }
            match (currentCmd.findSubcommand(arg)) {
                case Some(sub) =>
                    currentCmd = sub
                    ctx.pushCommandPath(sub.getName())
                    argIndex++
                case None =>
                    break
            }
        }

        // 步骤 2: 解析 flags 和 positional arguments
        var positionalOnly = false
        let positionalArgs = ArrayList<String>()

        while (argIndex < rawArgs.size) {
            let arg = rawArgs[argIndex]

            // "--" 分隔符
            if (arg == "--") {
                positionalOnly = true
                argIndex++
                continue
            }

            if (positionalOnly) {
                positionalArgs.add(arg)
                argIndex++
                continue
            }

            // 长选项 --name 或 --name=value
            if (arg.size > 2 && startsWith(arg, "--")) {
                let flagContent = removePrefix(arg, "--")
                let (flagName, flagValue, hasEquals) = splitOnFirstEquals(flagContent)

                if (hasEquals) {
                    let resolvedFlag = resolveFlag(currentCmd, rootCmd, flagName)
                    let validated = validateAndConvert(flagValue, resolvedFlag.getValueType())
                    ctx.setFlag(resolvedFlag.getLongName(), validated)
                } else {
                    let resolvedFlag = resolveFlag(currentCmd, rootCmd, flagName)
                    if (resolvedFlag.isBoolFlag()) {
                        ctx.setFlag(resolvedFlag.getLongName(), "true")
                    } else {
                        argIndex++
                        if (argIndex >= rawArgs.size) {
                            throw ParseException("Flag '--${flagName}' requires a value.")
                        }
                        let nextVal = rawArgs[argIndex]
                        let validated = validateAndConvert(nextVal, resolvedFlag.getValueType())
                        ctx.setFlag(resolvedFlag.getLongName(), validated)
                    }
                }
                argIndex++
                continue
            }

            // 短选项 -x 或 -x value 或 -abc
            if (arg.size > 1 && startsWith(arg, "-") && !startsWith(arg, "--")) {
                let shortContent = removePrefix(arg, "-")
                let chars = toCharList(shortContent)

                if (chars.size == 1) {
                    let resolvedFlag = resolveFlagByShort(currentCmd, rootCmd, chars[0])
                    if (resolvedFlag.isBoolFlag()) {
                        ctx.setFlag(resolvedFlag.getLongName(), "true")
                    } else {
                        argIndex++
                        if (argIndex >= rawArgs.size) {
                            throw ParseException("Flag '-${chars[0]}' requires a value.")
                        }
                        let nextVal = rawArgs[argIndex]
                        let validated = validateAndConvert(nextVal, resolvedFlag.getValueType())
                        ctx.setFlag(resolvedFlag.getLongName(), validated)
                    }
                } else {
                    // 组合短选项 -abc 或 -cVALUE
                    var charIdx: Int64 = 0
                    while (charIdx < chars.size) {
                        let shortStr = chars[charIdx]
                        let resolvedFlag = resolveFlagByShort(currentCmd, rootCmd, shortStr)
                        if (resolvedFlag.isBoolFlag()) {
                            ctx.setFlag(resolvedFlag.getLongName(), "true")
                        } else {
                            if (charIdx < chars.size - 1) {
                                // 剩余字符作为值
                                var valueStr = ""
                                var vi = charIdx + 1
                                while (vi < chars.size) {
                                    valueStr = valueStr + chars[vi]
                                    vi++
                                }
                                let validated = validateAndConvert(valueStr, resolvedFlag.getValueType())
                                ctx.setFlag(resolvedFlag.getLongName(), validated)
                                break
                            } else {
                                argIndex++
                                if (argIndex >= rawArgs.size) {
                                    throw ParseException("Flag '-${shortStr}' requires a value.")
                                }
                                let nextVal = rawArgs[argIndex]
                                let validated = validateAndConvert(nextVal, resolvedFlag.getValueType())
                                ctx.setFlag(resolvedFlag.getLongName(), validated)
                            }
                        }
                        charIdx++
                    }
                }
                argIndex++
                continue
            }

            // 位置参数
            positionalArgs.add(arg)
            argIndex++
        }

        // 步骤 3: 应用默认值
        applyDefaultFlags(currentCmd, ctx)
        if (currentCmd.getName() != rootCmd.getName()) {
            applyDefaultFlags(rootCmd, ctx)
        }

        // 步骤 4: 验证必填 flag
        validateRequiredFlags(currentCmd, ctx)

        // 步骤 5: 处理位置参数
        processPositionalArgs(currentCmd, positionalArgs, ctx)

        return (currentCmd, ctx)
    }

    // 在当前命令和根命令中查找长名称匹配的 flag
    func resolveFlag(currentCmd: Command, rootCmd: Command, name: String): Flag {
        match (currentCmd.findFlag(name)) {
            case Some(f) => return f
            case None => ()
        }
        if (currentCmd.getName() != rootCmd.getName()) {
            match (rootCmd.findFlag(name)) {
                case Some(f) => return f
                case None => ()
            }
        }
        throw ParseException("Unknown option '--${name}'.")
    }

    // 在当前命令和根命令中查找短名称匹配的 flag
    func resolveFlagByShort(currentCmd: Command, rootCmd: Command, shortName: String): Flag {
        // 搜索当前命令的 flags
        for (f in currentCmd.getFlags()) {
            if (f.getShortName() == shortName) {
                return f
            }
        }
        // 搜索根命令的 flags
        if (currentCmd.getName() != rootCmd.getName()) {
            for (f in rootCmd.getFlags()) {
                if (f.getShortName() == shortName) {
                    return f
                }
            }
        }
        throw ParseException("Unknown option '-${shortName}'.")
    }

    // 给未设置的 flag 应用默认值
    func applyDefaultFlags(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            match (ctx.getFlag(f.getLongName())) {
                case None =>
                    if (f.getDefaultValue().size > 0) {
                        ctx.setFlag(f.getLongName(), f.getDefaultValue())
                    }
                case _ => ()
            }
        }
    }

    // 验证必填 flag
    func validateRequiredFlags(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (f.isRequired()) {
                match (ctx.getFlag(f.getLongName())) {
                    case None =>
                        throw ValidationException("Required flag '--${f.getLongName()}' was not provided.")
                    case _ => ()
                }
            }
        }
    }

    // 处理位置参数：校验数量和类型
    func processPositionalArgs(cmd: Command, positional: ArrayList<String>, ctx: Context): Unit {
        let argDefs = cmd.getArguments()
        var posIdx: Int64 = 0

        for (argDef in argDefs) {
            if (argDef.isVariadic()) {
                // 变长参数：收集所有剩余的位置参数
                var count: Int64 = 0
                while (posIdx < positional.size) {
                    let validated = validateAndConvert(positional[posIdx], argDef.getValueType())
                    ctx.addArgument(validated)
                    posIdx++
                    count++
                }
                // 校验最小数量
                if (count < argDef.getMinCount()) {
                    throw ValidationException(
                        "Argument '${argDef.getName()}' requires at least ${argDef.getMinCount()} values, but got ${count}."
                    )
                }
                // 校验最大数量
                if (argDef.getMaxCount() >= 0 && count > argDef.getMaxCount()) {
                    throw ValidationException(
                        "Argument '${argDef.getName()}' accepts at most ${argDef.getMaxCount()} values, but got ${count}."
                    )
                }
            } else {
                // 定长参数：消耗一个位置参数
                if (posIdx < positional.size) {
                    let validated = validateAndConvert(positional[posIdx], argDef.getValueType())
                    ctx.addArgument(validated)
                    posIdx++
                } else if (argDef.isRequired()) {
                    throw ValidationException("Required argument '${argDef.getName()}' was not provided.")
                } else if (argDef.getDefaultValue().size > 0) {
                    ctx.addArgument(argDef.getDefaultValue())
                }
            }
        }

        // 如果没有参数定义但有位置参数传入，也收集起来（宽松模式）
        if (argDefs.size == 0) {
            while (posIdx < positional.size) {
                ctx.addArgument(positional[posIdx])
                posIdx++
            }
        }
    }
}
