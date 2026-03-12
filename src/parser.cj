package cli

import std.collection.*

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
            if (arg.size > 0 && arg.startsWith("-")) {
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
            if (arg.size > 2 && arg.startsWith("--")) {
                let flagContent = arg[2..]
                let (flagName, flagValue, hasEquals) = splitOnFirstEquals(flagContent)

                if (hasEquals) {
                    let resolvedFlag = resolveFlag(currentCmd, rootCmd, flagName)
                    handleFlagValue(resolvedFlag, flagValue, ctx)
                } else {
                    let resolvedFlag = resolveFlag(currentCmd, rootCmd, flagName)
                    handleFlagNoEquals(resolvedFlag, flagName, rawArgs, ctx, argIndex)
                    if (!resolvedFlag.isBoolFlag() && !resolvedFlag.isTerminate()) {
                        argIndex++
                    }
                }
                argIndex++
                continue
            }

            // 短选项 -x 或 -x value 或 -abc
            if (arg.size > 1 && arg.startsWith("-") && !arg.startsWith("--")) {
                let runes = arg[1..].toRuneArray()

                if (runes.size == 1) {
                    let resolvedFlag = resolveFlagByShort(currentCmd, rootCmd, runes[0])
                    handleShortFlagSingle(resolvedFlag, runes[0], rawArgs, ctx, argIndex)
                    if (!resolvedFlag.isBoolFlag() && !resolvedFlag.isTerminate()) {
                        argIndex++
                    }
                } else {
                    parseCompositeShortFlags(runes, currentCmd, rootCmd, rawArgs, ctx, argIndex)
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

        (currentCmd, ctx)
    }

    // 处理长选项的值（带等号）
    func handleFlagValue(flag: Flag, rawValue: String, ctx: Context): Unit {
        match (flag.getAction()) {
            case Terminate(callback) =>
                throw TerminateException(callback)
            case SetTrue =>
                ctx.setFlag(flag.getLongName(), "true")
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
            case Append =>
                let validated = validateAndConvert(rawValue, flag.getValueType())
                ctx.appendFlag(flag.getLongName(), validated)
            case Set =>
                let validated = validateAndConvert(rawValue, flag.getValueType())
                ctx.setFlag(flag.getLongName(), validated)
        }
    }

    // 处理长选项（无等号）
    func handleFlagNoEquals(flag: Flag, flagName: String, rawArgs: Array<String>, ctx: Context,
        argIndex: Int64): Unit {
        match (flag.getAction()) {
            case Terminate(callback) =>
                throw TerminateException(callback)
            case SetTrue =>
                ctx.setFlag(flag.getLongName(), "true")
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
            case _ =>
                let nextIdx = argIndex + 1
                if (nextIdx >= rawArgs.size) {
                    throw ParseException("Flag '--${flagName}' requires a value.")
                }
                let nextVal = rawArgs[nextIdx]
                let validated = validateAndConvert(nextVal, flag.getValueType())
                match (flag.getAction()) {
                    case Append => ctx.appendFlag(flag.getLongName(), validated)
                    case _ => ctx.setFlag(flag.getLongName(), validated)
                }
        }
    }

    // 处理单个短选项
    func handleShortFlagSingle(flag: Flag, shortChar: Rune, rawArgs: Array<String>, ctx: Context,
        argIndex: Int64): Unit {
        match (flag.getAction()) {
            case Terminate(callback) =>
                throw TerminateException(callback)
            case SetTrue =>
                ctx.setFlag(flag.getLongName(), "true")
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
            case _ =>
                let nextIdx = argIndex + 1
                if (nextIdx >= rawArgs.size) {
                    throw ParseException("Flag '-${shortChar}' requires a value.")
                }
                let nextVal = rawArgs[nextIdx]
                let validated = validateAndConvert(nextVal, flag.getValueType())
                match (flag.getAction()) {
                    case Append => ctx.appendFlag(flag.getLongName(), validated)
                    case _ => ctx.setFlag(flag.getLongName(), validated)
                }
        }
    }

    // 解析组合短选项 -abc
    func parseCompositeShortFlags(runes: Array<Rune>, currentCmd: Command, rootCmd: Command,
        rawArgs: Array<String>, ctx: Context, argIndex: Int64): Unit {
        var charIdx: Int64 = 0
        while (charIdx < runes.size) {
            let c = runes[charIdx]
            let resolvedFlag = resolveFlagByShort(currentCmd, rootCmd, c)
            match (resolvedFlag.getAction()) {
                case Terminate(callback) =>
                    throw TerminateException(callback)
                case SetTrue =>
                    ctx.setFlag(resolvedFlag.getLongName(), "true")
                case SetFalse =>
                    ctx.setFlag(resolvedFlag.getLongName(), "false")
                case _ =>
                    if (charIdx < runes.size - 1) {
                        // 剩余字符作为值
                        var valueStr = ""
                        var vi = charIdx + 1
                        while (vi < runes.size) {
                            valueStr = valueStr + runes[vi].toString()
                            vi++
                        }
                        let validated = validateAndConvert(valueStr, resolvedFlag.getValueType())
                        match (resolvedFlag.getAction()) {
                            case Append => ctx.appendFlag(resolvedFlag.getLongName(), validated)
                            case _ => ctx.setFlag(resolvedFlag.getLongName(), validated)
                        }
                        return  // 剩余被消费完毕
                    } else {
                        // 尝试从后续 args 中取值— 但 argIndex 已在外层管理，这里只能抛异常
                        throw ParseException("Flag '-${c}' requires a value.")
                    }
            }
            charIdx++
        }
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
    func resolveFlagByShort(currentCmd: Command, rootCmd: Command, shortChar: Rune): Flag {
        match (currentCmd.findFlagByShort(shortChar)) {
            case Some(f) => return f
            case None => ()
        }
        if (currentCmd.getName() != rootCmd.getName()) {
            match (rootCmd.findFlagByShort(shortChar)) {
                case Some(f) => return f
                case None => ()
            }
        }
        throw ParseException("Unknown option '-${shortChar}'.")
    }

    // 给未设置的 flag 应用默认值
    func applyDefaultFlags(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (!ctx.hasFlag(f.getLongName())) {
                match (f.getDefaultValue()) {
                    case Some(dv) => ctx.setFlag(f.getLongName(), dv)
                    case None => ()
                }
            }
        }
    }

    // 验证必填 flag
    func validateRequiredFlags(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (f.isRequired() && !ctx.hasFlag(f.getLongName())) {
                throw ValidationException("Required flag '--${f.getLongName()}' was not provided.")
            }
        }
    }

    // 处理位置参数：校验数量和类型
    func processPositionalArgs(cmd: Command, positional: ArrayList<String>, ctx: Context): Unit {
        let argDefs = cmd.getArguments()
        var posIdx: Int64 = 0

        for (argDef in argDefs) {
            if (argDef.isVariadic()) {
                var count: Int64 = 0
                while (posIdx < positional.size) {
                    let validated = validateAndConvert(positional[posIdx], argDef.getValueType())
                    ctx.addArgument(validated)
                    posIdx++
                    count++
                }
                if (count < argDef.getMinCount()) {
                    throw ValidationException(
                        "Argument '${argDef.getName()}' requires at least ${argDef.getMinCount()} values, but got ${count}."
                    )
                }
                if (argDef.getMaxCount() >= 0 && count > argDef.getMaxCount()) {
                    throw ValidationException(
                        "Argument '${argDef.getName()}' accepts at most ${argDef.getMaxCount()} values, but got ${count}."
                    )
                }
            } else {
                if (posIdx < positional.size) {
                    let validated = validateAndConvert(positional[posIdx], argDef.getValueType())
                    ctx.addArgument(validated)
                    posIdx++
                } else if (argDef.isRequired()) {
                    throw ValidationException("Required argument '${argDef.getName()}' was not provided.")
                } else {
                    match (argDef.getDefaultValue()) {
                        case Some(dv) => ctx.addArgument(dv)
                        case None => ()
                    }
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

// 在字符串中按第一个 "=" 分割为 (key, value, found)
func splitOnFirstEquals(s: String): (String, String, Bool) {
    let runes = s.toRuneArray()
    var eqIdx: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'=') {
            eqIdx = i
            break
        }
        i++
    }
    if (eqIdx < 0) {
        return (s, "", false)
    }
    var key = ""
    var ki: Int64 = 0
    while (ki < eqIdx) {
        key = key + runes[ki].toString()
        ki++
    }
    var value = ""
    var vi = eqIdx + 1
    while (vi < runes.size) {
        value = value + runes[vi].toString()
        vi++
    }
    (key, value, true)
}
