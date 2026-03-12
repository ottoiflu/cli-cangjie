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
                    // 若当前命令有子命令但未匹配: Phase 9 N-best suggestions
                    if (currentCmd.getSubcommands().size > 0 && currentCmd.getArguments().size == 0) {
                        let cmdNames = currentCmd.allCommandNames()
                        let suggestions = findAllSuggestions(arg, cmdNames, 0.7)
                        if (suggestions.size == 1) {
                            throw ParseException("Unknown command '${arg}'. Did you mean '${suggestions[0][0]}'?")
                        } else if (suggestions.size > 1) {
                            var hint = ""
                            var cnt: Int64 = 0
                            for (s in suggestions) {
                                if (cnt >= 3) { break }
                                if (cnt > 0) { hint = hint + ", " }
                                hint = hint + "'${s[0]}'"
                                cnt++
                            }
                            throw ParseException("Unknown command '${arg}'. Did you mean one of: ${hint}?")
                        }
                        throw ParseException("Unknown command '${arg}'.")
                    }
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
                // Phase 9: -- 分隔后的参数同时存入 pass-through
                positionalArgs.add(arg)
                ctx.addPassthroughArg(arg)
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

        // 步骤 5: 验证 Flag 约束（互斥、依赖、自定义验证器、标志组）
        validateFlagConstraints(currentCmd, ctx)
        if (currentCmd.getName() != rootCmd.getName()) {
            validateFlagConstraints(rootCmd, ctx)
        }
        validateFlagGroups(currentCmd, ctx)

        // 步骤 6: 处理位置参数
        processPositionalArgs(currentCmd, positionalArgs, ctx)

        (currentCmd, ctx)
    }

    // 仅解析命令行参数，不应用默认值和验证（供 App 实现四级优先级管道使用）
    // 流程：路由子命令 → 解析 flags → 收集位置参数
    // 返回: (matchedCmd, ctx, positionalArgs)
    public func parseOnly(rootCmd: Command, rawArgs: Array<String>): (Command, Context, ArrayList<String>) {
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
                    if (currentCmd.getSubcommands().size > 0 && currentCmd.getArguments().size == 0) {
                        let cmdNames = currentCmd.allCommandNames()
                        let suggestions2 = findAllSuggestions(arg, cmdNames, 0.7)
                        if (suggestions2.size == 1) {
                            throw ParseException("Unknown command '${arg}'. Did you mean '${suggestions2[0][0]}'?")
                        } else if (suggestions2.size > 1) {
                            var hint2 = ""
                            var cnt2: Int64 = 0
                            for (s in suggestions2) {
                                if (cnt2 >= 3) { break }
                                if (cnt2 > 0) { hint2 = hint2 + ", " }
                                hint2 = hint2 + "'${s[0]}'"
                                cnt2++
                            }
                            throw ParseException("Unknown command '${arg}'. Did you mean one of: ${hint2}?")
                        }
                        throw ParseException("Unknown command '${arg}'.")
                    }
                    break
            }
        }

        // 步骤 2: 解析 flags 和 positional arguments
        var positionalOnly = false
        let positionalArgs = ArrayList<String>()

        while (argIndex < rawArgs.size) {
            let arg = rawArgs[argIndex]
            if (arg == "--") {
                positionalOnly = true
                argIndex++
                continue
            }
            if (positionalOnly) {
                positionalArgs.add(arg)
                ctx.addPassthroughArg(arg)
                argIndex++
                continue
            }
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
            positionalArgs.add(arg)
            argIndex++
        }

        (currentCmd, ctx, positionalArgs)
    }

    // 完成解析：应用默认值、验证、处理位置参数（配合 parseOnly 使用）
    public func finalize(rootCmd: Command, matchedCmd: Command, ctx: Context, positionalArgs: ArrayList<String>): Unit {
        // 应用默认值
        applyDefaultFlags(matchedCmd, ctx)
        if (matchedCmd.getName() != rootCmd.getName()) {
            applyDefaultFlags(rootCmd, ctx)
        }

        // Phase 10: 错误聚合 — 收集所有验证错误后统一报告
        let collectedErrors = ArrayList<String>()

        // 验证必填 flag
        collectRequiredFlagErrors(matchedCmd, ctx, collectedErrors)

        // 验证 Flag 约束
        collectFlagConstraintErrors(matchedCmd, ctx, collectedErrors)
        if (matchedCmd.getName() != rootCmd.getName()) {
            collectFlagConstraintErrors(rootCmd, ctx, collectedErrors)
        }
        collectFlagGroupErrors(matchedCmd, ctx, collectedErrors)

        // 如果有多个错误，抛出聚合异常
        if (collectedErrors.size > 1) {
            throw AggregateException(collectedErrors)
        } else if (collectedErrors.size == 1) {
            throw ValidationException(collectedErrors[0])
        }

        // 处理位置参数
        processPositionalArgs(matchedCmd, positionalArgs, ctx)
    }

    // 处理长选项的值（带等号）
    func handleFlagValue(flag: Flag, rawValue: String, ctx: Context): Unit {
        match (flag.getAction()) {
            case Terminate(callback) =>
                throw TerminateException(callback)
            case SetTrue =>
                ctx.setFlag(flag.getLongName(), "true")
                ctx.markExplicit(flag.getLongName())
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
                ctx.markExplicit(flag.getLongName())
            case Append =>
                // Phase 9: 分隔符支持
                let values = splitByDelimiter(rawValue, flag.getDelimiter())
                for (v in values) {
                    let validated = validateAndConvert(v, flag.getValueType())
                    validateChoices(flag, validated)
                    ctx.appendFlag(flag.getLongName(), validated)
                }
                ctx.markExplicit(flag.getLongName())
            case Set =>
                // Phase 9: 分隔符支持（Set 模式下有分隔符则升级为多值）
                match (flag.getDelimiter()) {
                    case Some(_) =>
                        let values = splitByDelimiter(rawValue, flag.getDelimiter())
                        for (v in values) {
                            let validated = validateAndConvert(v, flag.getValueType())
                            validateChoices(flag, validated)
                            ctx.appendFlag(flag.getLongName(), validated)
                        }
                    case None =>
                        let validated = validateAndConvert(rawValue, flag.getValueType())
                        validateChoices(flag, validated)
                        ctx.setFlag(flag.getLongName(), validated)
                }
                ctx.markExplicit(flag.getLongName())
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
                ctx.markExplicit(flag.getLongName())
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
                ctx.markExplicit(flag.getLongName())
            case _ =>
                let nextIdx = argIndex + 1
                if (nextIdx >= rawArgs.size) {
                    throw ParseException("Flag '--${flagName}' requires a value.")
                }
                let nextVal = rawArgs[nextIdx]
                // Phase 9: 分隔符支持
                match (flag.getDelimiter()) {
                    case Some(_) =>
                        let values = splitByDelimiter(nextVal, flag.getDelimiter())
                        for (v in values) {
                            let validated = validateAndConvert(v, flag.getValueType())
                            validateChoices(flag, validated)
                            ctx.appendFlag(flag.getLongName(), validated)
                        }
                    case None =>
                        let validated = validateAndConvert(nextVal, flag.getValueType())
                        validateChoices(flag, validated)
                        match (flag.getAction()) {
                            case Append => ctx.appendFlag(flag.getLongName(), validated)
                            case _ => ctx.setFlag(flag.getLongName(), validated)
                        }
                }
                ctx.markExplicit(flag.getLongName())
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
                ctx.markExplicit(flag.getLongName())
            case SetFalse =>
                ctx.setFlag(flag.getLongName(), "false")
                ctx.markExplicit(flag.getLongName())
            case _ =>
                let nextIdx = argIndex + 1
                if (nextIdx >= rawArgs.size) {
                    throw ParseException("Flag '-${shortChar}' requires a value.")
                }
                let nextVal = rawArgs[nextIdx]
                match (flag.getDelimiter()) {
                    case Some(_) =>
                        let values = splitByDelimiter(nextVal, flag.getDelimiter())
                        for (v in values) {
                            let validated = validateAndConvert(v, flag.getValueType())
                            validateChoices(flag, validated)
                            ctx.appendFlag(flag.getLongName(), validated)
                        }
                    case None =>
                        let validated = validateAndConvert(nextVal, flag.getValueType())
                        validateChoices(flag, validated)
                        match (flag.getAction()) {
                            case Append => ctx.appendFlag(flag.getLongName(), validated)
                            case _ => ctx.setFlag(flag.getLongName(), validated)
                        }
                }
                ctx.markExplicit(flag.getLongName())
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
                    ctx.markExplicit(resolvedFlag.getLongName())
                case SetFalse =>
                    ctx.setFlag(resolvedFlag.getLongName(), "false")
                    ctx.markExplicit(resolvedFlag.getLongName())
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
                        ctx.markExplicit(resolvedFlag.getLongName())
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
        // Phase 9: N-best suggestions — 显示最多 3 条候选
        let candidates = currentCmd.allFlagNames()
        if (currentCmd.getName() != rootCmd.getName()) {
            for (n in rootCmd.allFlagNames()) {
                candidates.add(n)
            }
        }
        let suggestions = findAllSuggestions(name, candidates, 0.7)
        if (suggestions.size > 0) {
            if (suggestions.size == 1) {
                throw ParseException("Unknown option '--${name}'. Did you mean '--${suggestions[0][0]}'?")
            }
            var hint = ""
            var count: Int64 = 0
            for (s in suggestions) {
                if (count >= 3) { break }
                if (count > 0) { hint = hint + ", " }
                hint = hint + "'--${s[0]}'"
                count++
            }
            throw ParseException("Unknown option '--${name}'. Did you mean one of: ${hint}?")
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

    // Phase 6: 验证 Flag 约束（互斥、依赖、自定义验证器）
    func validateFlagConstraints(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            let flagName = f.getLongName()
            if (!ctx.isExplicit(flagName)) {
                continue
            }
            // 互斥检查：两个互斥 Flag 不能同时被显式设置
            for (conflict in f.getConflicts()) {
                if (ctx.isExplicit(conflict)) {
                    throw ValidationException(
                        "Flag '--${flagName}' cannot be used together with '--${conflict}'."
                    )
                }
            }
            // 依赖检查：显式设置的 Flag 其依赖必须存在（显式或默认均可）
            for (req in f.getRequires()) {
                if (!ctx.hasFlag(req)) {
                    throw ValidationException(
                        "Flag '--${flagName}' requires '--${req}' to be set."
                    )
                }
            }
            // 自定义验证器
            match (f.getValidator()) {
                case Some(validatorFn) =>
                    match (ctx.getFlag(flagName)) {
                        case Some(value) =>
                            if (!validatorFn(value)) {
                                let msg = f.getValidatorMessage()
                                if (msg.size > 0) {
                                    throw ValidationException(
                                        "Invalid value for '--${flagName}': ${msg}"
                                    )
                                } else {
                                    throw ValidationException(
                                        "Invalid value for '--${flagName}'."
                                    )
                                }
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    // Phase 6: 验证标志组约束
    func validateFlagGroups(cmd: Command, ctx: Context): Unit {
        // requireGroup: 组内至少有一个 Flag 被显式设置
        for (groupName in cmd.getRequireGroupNames()) {
            match (cmd.getRequireGroups().get(groupName)) {
                case Some(members) =>
                    var anyExplicit = false
                    for (m in members) {
                        if (ctx.isExplicit(m)) {
                            anyExplicit = true
                            break
                        }
                    }
                    if (!anyExplicit) {
                        var memberStr = ""
                        var first = true
                        for (m in members) {
                            if (!first) {
                                memberStr = memberStr + ", "
                            }
                            memberStr = memberStr + "--" + m
                            first = false
                        }
                        throw ValidationException(
                            "At least one flag from group '${groupName}' is required: ${memberStr}."
                        )
                    }
                case None => ()
            }
        }
        // mutuallyExclusiveGroup: 组内最多只能有一个 Flag 被显式设置
        for (groupName in cmd.getExclusiveGroupNames()) {
            match (cmd.getExclusiveGroups().get(groupName)) {
                case Some(members) =>
                    let setMembers = ArrayList<String>()
                    for (m in members) {
                        if (ctx.isExplicit(m)) {
                            setMembers.add(m)
                        }
                    }
                    if (setMembers.size > 1) {
                        throw ValidationException(
                            "Flags '--${setMembers[0]}' and '--${setMembers[1]}' are mutually exclusive (group '${groupName}')."
                        )
                    }
                case None => ()
            }
        }
    }

    // Phase 10: 错误聚合版本的验证方法 — 收集错误而非直接抛出

    func collectRequiredFlagErrors(cmd: Command, ctx: Context, errors: ArrayList<String>): Unit {
        for (f in cmd.getFlags()) {
            if (f.isRequired() && !ctx.hasFlag(f.getLongName())) {
                errors.add("Required flag '--${f.getLongName()}' was not provided.")
            }
        }
    }

    func collectFlagConstraintErrors(cmd: Command, ctx: Context, errors: ArrayList<String>): Unit {
        for (f in cmd.getFlags()) {
            let flagName = f.getLongName()
            if (!ctx.isExplicit(flagName)) {
                continue
            }
            // 互斥检查
            for (conflict in f.getConflicts()) {
                if (ctx.isExplicit(conflict)) {
                    errors.add("Flag '--${flagName}' cannot be used together with '--${conflict}'.")
                }
            }
            // 依赖检查
            for (req in f.getRequires()) {
                if (!ctx.hasFlag(req)) {
                    errors.add("Flag '--${flagName}' requires '--${req}' to be set.")
                }
            }
            // 自定义验证器
            match (f.getValidator()) {
                case Some(validatorFn) =>
                    match (ctx.getFlag(flagName)) {
                        case Some(value) =>
                            if (!validatorFn(value)) {
                                let msg = f.getValidatorMessage()
                                if (msg.size > 0) {
                                    errors.add("Invalid value for '--${flagName}': ${msg}")
                                } else {
                                    errors.add("Invalid value for '--${flagName}'.")
                                }
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    func collectFlagGroupErrors(cmd: Command, ctx: Context, errors: ArrayList<String>): Unit {
        // requireGroup: 至少选一
        for (groupName in cmd.getRequireGroupNames()) {
            match (cmd.getRequireGroups().get(groupName)) {
                case Some(members) =>
                    var anyExplicit = false
                    for (m in members) {
                        if (ctx.isExplicit(m)) {
                            anyExplicit = true
                            break
                        }
                    }
                    if (!anyExplicit) {
                        var memberStr = ""
                        var first = true
                        for (m in members) {
                            if (!first) { memberStr = memberStr + ", " }
                            memberStr = memberStr + "--" + m
                            first = false
                        }
                        errors.add("At least one flag from group '${groupName}' is required: ${memberStr}.")
                    }
                case None => ()
            }
        }
        // mutuallyExclusiveGroup: 最多选一
        for (groupName in cmd.getExclusiveGroupNames()) {
            match (cmd.getExclusiveGroups().get(groupName)) {
                case Some(members) =>
                    let setMembers = ArrayList<String>()
                    for (m in members) {
                        if (ctx.isExplicit(m)) {
                            setMembers.add(m)
                        }
                    }
                    if (setMembers.size > 1) {
                        errors.add("Flags '--${setMembers[0]}' and '--${setMembers[1]}' are mutually exclusive (group '${groupName}').")
                    }
                case None => ()
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

// Phase 9: 验证 Flag 值是否在可选值列表中
func validateChoices(flag: Flag, value: String): Unit {
    if (!flag.hasChoices()) { return }
    let choices = flag.getChoices()
    for (c in choices) {
        if (c == value) { return }
    }
    var choiceList = ""
    var first = true
    for (c in choices) {
        if (!first) { choiceList = choiceList + ", " }
        choiceList = choiceList + "'" + c + "'"
        first = false
    }
    // N-best: 检查是否有接近的可选值
    let suggestions = findAllSuggestions(value, choices, 0.5)
    if (suggestions.size > 0) {
        throw ValidationException(
            "Invalid value '${value}' for '--${flag.getLongName()}'. Valid options: ${choiceList}. Did you mean '${suggestions[0][0]}'?"
        )
    }
    throw ValidationException(
        "Invalid value '${value}' for '--${flag.getLongName()}'. Valid options: ${choiceList}."
    )
}

// Phase 9: 按分隔符拆分字符串
func splitByDelimiter(s: String, delimiter: Option<Rune>): ArrayList<String> {
    let result = ArrayList<String>()
    match (delimiter) {
        case Some(delim) =>
            let runes = s.toRuneArray()
            var current = ""
            var i: Int64 = 0
            while (i < runes.size) {
                if (runes[i] == delim) {
                    if (current.size > 0) {
                        result.add(current)
                    }
                    current = ""
                } else {
                    current = current + runes[i].toString()
                }
                i++
            }
            if (current.size > 0) {
                result.add(current)
            }
        case None =>
            result.add(s)
    }
    result
}
