package cli

import std.collection.*
import std.env.*

// Phase 10: 信号类型枚举
public enum SignalType {
    | SIGINT    // Ctrl+C 中断 (退出码 130)
    | SIGTERM   // 终止信号 (退出码 143)
}

// Phase 10: 信号处理器 — 框架级信号捕获抽象
// 在 mockRun 中支持 simulateSignal() 模拟信号到达
public class SignalHandler {
    var _interrupted: Bool = false
    var _signalType: Option<SignalType> = None
    let _callbacks: ArrayList<(SignalType) -> Unit> = ArrayList<(SignalType) -> Unit>()

    // 注册信号回调
    public func onSignal(callback: (SignalType) -> Unit): Unit {
        _callbacks.add(callback)
    }

    // 模拟信号到达（用于测试）
    public func simulateSignal(sig: SignalType): Unit {
        _interrupted = true
        _signalType = Some(sig)
        for (cb in _callbacks) {
            cb(sig)
        }
    }

    // 检查是否被中断
    public func isInterrupted(): Bool { _interrupted }

    // 获取信号类型
    public func getSignalType(): Option<SignalType> { _signalType }

    // 获取退出码（SIGINT=130, SIGTERM=143）
    public func getExitCode(): Int64 {
        match (_signalType) {
            case Some(SIGINT) => 130
            case Some(SIGTERM) => 143
            case None => 0
        }
    }

    // 重置状态
    public func reset(): Unit {
        _interrupted = false
        _signalType = None
    }
}

// 测试结果：捕获退出码和标准输出/错误输出
public class TestResult {
    public let exitCode: Int64
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int64, stdout: String, stderr: String) {
        this.exitCode = exitCode
        this.stdout = stdout
        this.stderr = stderr
    }
}

// CLI 应用入口
public class App {
    let _rootCommand: Command
    let _parser: Parser = Parser()
    var _envPrefix: Option<String> = None
    var _configLoader: Option<ConfigLoader> = None

    // Phase 8: 丰富版本信息
    var _versionInfo: Option<VersionInfo> = None
    // Phase 8: 全局标志传播列表
    let _globalFlags: ArrayList<Flag> = ArrayList<Flag>()
    // Phase 8: 弃用警告收集
    let _deprecationCollector: DeprecationCollector = DeprecationCollector()
    // Phase 10: 信号处理器
    var _signalHandler: Option<SignalHandler> = None

    public init(name: String) {
        _rootCommand = Command(name)
    }

    // Builder 方法：统一返回 This

    public func description(desc: String): This {
        _rootCommand.description(desc)
        this
    }

    public func version(ver: String): This {
        _rootCommand.version(ver)
        this
    }

    public func author(auth: String): This {
        _rootCommand.author(auth)
        this
    }

    public func command(subCmd: Command): This {
        _rootCommand.command(subCmd)
        this
    }

    public func commands(subs: Array<Command>): This {
        _rootCommand.commands(subs)
        this
    }

    public func flag(f: Flag): This {
        _rootCommand.flag(f)
        this
    }

    public func flags(fs: Array<Flag>): This {
        _rootCommand.flags(fs)
        this
    }

    public func argument(arg: Argument): This {
        _rootCommand.argument(arg)
        this
    }

    public func arguments(args: Array<Argument>): This {
        _rootCommand.arguments(args)
        this
    }

    public func action(handler: ActionHandler): This {
        _rootCommand.action(handler)
        this
    }

    // 设置环境变量前缀：自动将 Flag 关联到 PREFIX_FLAG_NAME 环境变量
    public func envPrefix(prefix: String): This {
        _envPrefix = Some(prefix)
        this
    }

    // 全局中间件注册
    public func use(mw: Middleware): This {
        _rootCommand.use(mw)
        this
    }

    // 配置加载器设定
    public func configLoader(loader: ConfigLoader): This {
        _configLoader = Some(loader)
        this
    }

    // 便捷方法：设置配置文件名（自动创建 ConfigLoader）
    public func configFile(name: String): This {
        if (_configLoader.isNone()) {
            _configLoader = Some(ConfigLoader())
        }
        match (_configLoader) {
            case Some(cl) => cl.configFileName(name)
            case None => ()
        }
        this
    }

    // 便捷方法：设置配置路径环境变量
    public func configPathEnvVar(envVarName: String): This {
        if (_configLoader.isNone()) {
            _configLoader = Some(ConfigLoader())
        }
        match (_configLoader) {
            case Some(cl) => cl.configPathEnvVar(envVarName)
            case None => ()
        }
        this
    }

    // Phase 8: 设置丰富版本信息
    public func versionInfo(info: VersionInfo): This {
        _versionInfo = Some(info)
        this
    }

    // Phase 9: 设置帮助文档终端宽度（默认 80）
    var _helpWidth: Int64 = 80

    public func helpWidth(width: Int64): This {
        _helpWidth = width
        this
    }

    // Phase 8: 注册全局 Flag（自动传播到所有子命令）
    public func globalFlag(f: Flag): This {
        _globalFlags.add(f)
        _rootCommand.flag(f)
        this
    }

    // Phase 8: 批量注册全局 Flag
    public func globalFlags(fs: Array<Flag>): This {
        for (f in fs) {
            globalFlag(f)
        }
        this
    }

    // Phase 10: 设置信号处理器
    public func signalHandler(handler: SignalHandler): This {
        _signalHandler = Some(handler)
        this
    }

    // 设置本地化实例（替换默认英文文本）
    public func locale(l: Locale): This {
        Messages.setLocale(l)
        this
    }

    // Phase 12: 要求必须指定子命令
    public func subcommandRequired(r!: Bool = true): This {
        _rootCommand.subcommandRequired(r: r)
        this
    }

    // Phase 12: 无参数时自动显示帮助
    public func argRequiredElseHelp(r!: Bool = true): This {
        _rootCommand.argRequiredElseHelp(r: r)
        this
    }

    // Phase 10: 获取信号处理器（便于在 action 中检查信号）
    public func getSignalHandler(): Option<SignalHandler> { _signalHandler }

    // 全局生命周期钩子
    public func persistentPreRun(hook: HookHandler): This {
        _rootCommand.persistentPreRun(hook)
        this
    }

    public func persistentPostRun(hook: HookHandler): This {
        _rootCommand.persistentPostRun(hook)
        this
    }

    public func getRootCommand(): Command {
        _rootCommand
    }

    // 内存级沙箱执行接口
    public func mockRun(args: Array<String>): TestResult {
        return mockRunWithConfig(args, configContent: None)
    }

    // 真实执行入口：解析命令行参数并输出到真实 stdout/stderr
    public func run(args: Array<String>): Int64 {
        let result = mockRun(args)
        if (!result.stdout.isEmpty()) {
            getStdOut().write(result.stdout)
        }
        if (!result.stderr.isEmpty()) {
            getStdErr().write(result.stderr)
        }
        return result.exitCode
    }

    // 便捷方法：自动从命令行获取参数
    public func run(): Int64 {
        return run(getCommandLine()[1..])
    }

    // 带配置内容的沙箱执行（用于测试时注入配置文件内容，不依赖磁盘文件）
    public func mockRunWithConfig(args: Array<String>, configContent!: Option<String> = None): TestResult {
        // 自动注入 --help / --version 为 Terminate Flag
        injectBuiltinFlags(_rootCommand)

        // Phase 8: 传播全局 Flag 到所有子命令
        propagateGlobalFlags(_rootCommand)

        // 正式解析
        try {
            // 使用四级优先级管道: CLI > ENV > Config File > Defaults
            let (matchedCmd, ctx, positionalArgs) = _parser.parseOnly(_rootCommand, args)

            // Phase 8: 检查弃用命令
            checkCommandDeprecation(matchedCmd)

            // 第二级：应用环境变量合并
            applyEnvVars(_rootCommand, ctx)
            if (matchedCmd.getName() != _rootCommand.getName()) {
                applyEnvVars(matchedCmd, ctx)
            }

            // 第三级：应用配置文件合并
            applyConfigValues(matchedCmd, ctx, configContent)

            // 第四级：应用默认值 + 验证 + 位置参数处理
            _parser.finalize(_rootCommand, matchedCmd, ctx, positionalArgs)

            // Phase 12: subcommandRequired — 如果命令要求子命令但未选择子命令
            if (matchedCmd.isSubcommandRequired() && matchedCmd.getSubcommands().size > 0) {
                let helpText = generateHelp(matchedCmd)
                let warnings = _deprecationCollector.formatAll()
                return TestResult(2, "", warnings + Messages.locale().errSubcommandRequired(matchedCmd.getName()) + "\n\n" + helpText)
            }

            // Phase 12: argRequiredElseHelp — 如果没有任何显式参数则显示帮助
            if (matchedCmd.isArgRequiredElseHelp() && !ctx.hasAnyExplicit() && positionalArgs.size == 0) {
                let helpText = generateHelp(matchedCmd)
                let warnings = _deprecationCollector.formatAll()
                return TestResult(0, "", warnings + helpText)
            }

            // Phase 8: 检查弃用 Flag
            checkFlagDeprecation(_rootCommand, ctx)
            if (matchedCmd.getName() != _rootCommand.getName()) {
                checkFlagDeprecation(matchedCmd, ctx)
            }

            // 无动作处理器：显示帮助（跳过生命周期和中间件）
            if (matchedCmd.getAction().isNone()) {
                let helpText = generateHelp(matchedCmd)
                let warnings = _deprecationCollector.formatAll()
                return TestResult(0, "", warnings + helpText)
            }

            // 执行生命周期: PersistentPreRun → PreRun → Middleware → Action → PostRun → PersistentPostRun
            // 1. PersistentPreRun (根命令的)
            match (_rootCommand.getPersistentPreRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }
            // Phase 10: 信号检查点
            if (checkSignalInterrupt()) {
                return buildSignalResult()
            }

            // 2. PreRun (当前命令的)
            match (matchedCmd.getPreRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }
            // Phase 10: 信号检查点
            if (checkSignalInterrupt()) {
                return buildSignalResult()
            }

            // 3. 构建中间件链 + Action 执行
            let exitCode = executeWithMiddleware(_rootCommand, matchedCmd, ctx)

            // Phase 10: 信号检查点（action 执行后）
            if (checkSignalInterrupt()) {
                return buildSignalResult()
            }

            // 4. PostRun (当前命令的)
            match (matchedCmd.getPostRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }

            // 5. PersistentPostRun (根命令的)
            match (_rootCommand.getPersistentPostRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }

            let warnings = _deprecationCollector.formatAll()
            TestResult(exitCode, "", warnings)
        } catch (e: TerminateException) {
            // Terminate 动作：执行回调获取输出内容
            let output = e.execute()
            // 帮助 => stderr；版本 => stdout
            // 使用 locale 的 helpUsagePrefix 进行检测，兼容本地化
            let usagePrefix = Messages.locale().helpUsagePrefix()
            if (output.contains(usagePrefix) || output.contains("Usage:")) {
                TestResult(0, "", output)
            } else {
                TestResult(0, output, "")
            }
        } catch (e: ConfigException) {
            // 配置文件错误：使用专用格式化
            let stderrBuf = e.formatAll()
            TestResult(2, "", stderrBuf)
        } catch (e: AggregateException) {
            // Phase 10: 多错误聚合报告
            let stderrBuf = formatAggregateError(e, args)
            TestResult(2, "", stderrBuf)
        } catch (e: CliException) {
            let stderrBuf = formatError(e, args)
            TestResult(2, "", stderrBuf)
        } catch (e: Exception) {
            let stderrBuf = "error: ${e.message}\n"
            TestResult(1, "", stderrBuf)
        }
    }

    // 构建中间件链并执行 Action
    func executeWithMiddleware(rootCmd: Command, matchedCmd: Command, ctx: Context): Int64 {
        // 收集中间件：根命令全局中间件 + 当前命令局部中间件
        let allMiddlewares = ArrayList<Middleware>()
        for (mw in rootCmd.getMiddlewares()) {
            allMiddlewares.add(mw)
        }
        if (matchedCmd.getName() != rootCmd.getName()) {
            for (mw in matchedCmd.getMiddlewares()) {
                allMiddlewares.add(mw)
            }
        }

        // 构建 action 调用
        let actionFn: () -> Int64 = { =>
            match (matchedCmd.getAction()) {
                case Some(handler) => handler(ctx)
                case None =>
                    // 无动作时显示帮助，不算错误
                    0
            }
        }

        // 从内向外构建中间件调用链
        if (allMiddlewares.size == 0) {
            return actionFn()
        }

        var chain: () -> Int64 = actionFn
        var i = allMiddlewares.size - 1
        while (i >= 0) {
            let mw = allMiddlewares[i]
            let nextFn = chain
            chain = { => mw(ctx, nextFn) }
            i--
        }
        chain()
    }

    // 应用环境变量合并: 对于未通过命令行设置的 Flag，尝试从环境变量读取
    // Phase 10: 环境变量值根据 Flag 的 valueType 自动执行类型转换
    func applyEnvVars(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (!ctx.hasFlag(f.getLongName())) {
                // 优先检查 Flag 显式关联的环境变量
                match (f.getEnvVar()) {
                    case Some(envName) =>
                        match (getVariable(envName)) {
                            case Some(envVal) =>
                                let coerced = coerceEnvValue(envVal, f)
                                ctx.setFlag(f.getLongName(), coerced)
                            case None => ()
                        }
                    case None =>
                        // 自动环境映射: 使用 envPrefix + FLAG_NAME
                        match (_envPrefix) {
                            case Some(prefix) =>
                                let autoEnvName = prefix + "_" + flagNameToEnvKey(f.getLongName())
                                match (getVariable(autoEnvName)) {
                                    case Some(envVal) =>
                                        let coerced = coerceEnvValue(envVal, f)
                                        ctx.setFlag(f.getLongName(), coerced)
                                    case None => ()
                                }
                            case None => ()
                        }
                }
            }
        }
    }

    // Phase 10: 环境变量值类型协变 — 根据 Flag 的 valueType 自动转换
    func coerceEnvValue(envVal: String, flag: Flag): String {
        try {
            validateAndConvert(envVal, flag.getValueType())
        } catch (e: TypeConversionException) {
            let envName = match (flag.getEnvVar()) {
                case Some(n) => n
                case None =>
                    match (_envPrefix) {
                        case Some(prefix) => prefix + "_" + flagNameToEnvKey(flag.getLongName())
                        case None => "ENV"
                    }
            }
            throw ValidationException(
                "Environment variable '${envName}' has invalid value '${envVal}' for flag '--${flag.getLongName()}': ${e.message}"
            )
        }
    }

    // 将 flag 名转换为环境变量名格式: "db-host" → "DB_HOST"
    func flagNameToEnvKey(name: String): String {
        name.replace("-", "_").toAsciiUpper()
    }

    // Phase 10: 检查信号处理器是否被中断
    func checkSignalInterrupt(): Bool {
        match (_signalHandler) {
            case Some(handler) => handler.isInterrupted()
            case None => false
        }
    }

    // Phase 10: 构建信号中断结果
    func buildSignalResult(): TestResult {
        match (_signalHandler) {
            case Some(handler) =>
                let sigName = match (handler.getSignalType()) {
                    case Some(SIGINT) => "SIGINT"
                    case Some(SIGTERM) => "SIGTERM"
                    case None => "UNKNOWN"
                }
                TestResult(handler.getExitCode(), "", Messages.locale().signalTerminated(sigName) + "\n")
            case None => TestResult(130, "", Messages.locale().signalTerminated("UNKNOWN") + "\n")
        }
    }

    // 应用配置文件值: 四级优先级中的第三级（CLI > ENV > Config > Defaults）
    func applyConfigValues(matchedCmd: Command, ctx: Context, configContent: Option<String>): Unit {
        match (_configLoader) {
            case Some(loader) =>
                // 自动注册已知 key（从 Flag 列表提取）
                loader.knownKeysFromFlags(_rootCommand.getFlags())
                if (matchedCmd.getName() != _rootCommand.getName()) {
                    loader.knownKeysFromFlags(matchedCmd.getFlags())
                }

                let (data, errors) = match (configContent) {
                    case Some(content) =>
                        // 测试模式：直接解析提供的内容
                        loader.parse(content, filePath: "<test-config>")
                    case None =>
                        // 正常模式：发现并加载配置文件
                        let (d, e, _) = loader.load()
                        (d, e)
                }

                // 配置错误处理
                if (errors.size > 0) {
                    throw ConfigException(errors)
                }

                // 应用配置值: 只填充未被 CLI 或 ENV 设置的 Flag
                loader.applyToContext(data, ctx)
            case None => ()
        }
    }

    // 递归注入内置 --help / --version flags
    func injectBuiltinFlags(cmd: Command): Unit {
        // 检查是否已注入（避免重复注入）
        let hasHelp = cmd.findFlag("help").isSome()
        if (!hasHelp) {
            let helpCmd = cmd  // 捕获当前命令用于闭包
            cmd.flag(
                Flag("help").short(r'h')
                    .description(Messages.locale().helpPrintHelp())
                    .action(Terminate({ => generateHelp(helpCmd) }))
            )
        }

        let hasVersion = cmd.findFlag("version").isSome()
        if (!hasVersion && cmd.getVersion().isSome()) {
            let verCmd = cmd
            cmd.flag(
                Flag("version").short(r'V')
                    .description(Messages.locale().helpPrintVersion())
                    .action(Terminate({ => generateVersion(verCmd) }))
            )
        }

        // 递归注入子命令
        for (sub in cmd.getSubcommands()) {
            // 子命令继承根命令的 version（如果子命令没有自己的 version）
            injectBuiltinFlags(sub)
        }
    }

    // 生成帮助文档（支持分组、示例、终端宽度折行）
    public func generateHelp(cmd: Command): String {
        let maxWidth = _helpWidth
        var help = ""

        // Phase 9: beforeHelp
        match (cmd.getBeforeHelp()) {
            case Some(text) =>
                help = help + wrapText(text, maxWidth) + "\n\n"
            case None => ()
        }

        // 标题（about）
        match (cmd.getDescription()) {
            case Some(desc) =>
                help = help + wrapText(desc, maxWidth) + "\n\n"
            case None => ()
        }

        // Usage 行
        help = help + Messages.locale().helpUsagePrefix()
        help = help + cmd.getName()
        if (cmd.getSubcommands().size > 0) {
            help = help + Messages.locale().helpCommandsPlaceholder()
        }
        if (cmd.getFlags().size > 0) {
            help = help + Messages.locale().helpOptionsPlaceholder()
        }
        for (arg in cmd.getArguments()) {
            match (arg.getDescription()) {
                case _ =>
                    if (arg.isVariadic()) {
                        help = help + " [${arg.getName()}...]"
                    } else if (arg.isRequired()) {
                        help = help + " <${arg.getName()}>"
                    } else {
                        help = help + " [${arg.getName()}]"
                    }
            }
        }
        help = help + "\n"

        // 子命令列表（Phase 9: 支持分组显示）
        let subcommands = cmd.getSubcommands()
        if (subcommands.size > 0) {
            // 按 group 分组
            let subGroups = HashMap<String, ArrayList<Command>>()
            let subGroupOrder = ArrayList<String>()
            for (sub in subcommands) {
                if (sub.isHidden()) { continue }
                let g = sub.getSubcommandGroup()
                if (!subGroups.contains(g)) {
                    subGroups[g] = ArrayList<Command>()
                    subGroupOrder.add(g)
                }
                subGroups[g].add(sub)
            }

            for (groupName in subGroupOrder) {
                match (subGroups.get(groupName)) {
                    case Some(groupSubs) =>
                        // 计算动态对齐宽度
                        var maxW: Int64 = 0
                        for (sub in groupSubs) {
                            var w = sub.getName().size
                            if (sub.getAliases().size > 0) {
                                for (a in sub.getAliases()) {
                                    w = w + 2 + a.size
                                }
                            }
                            if (w > maxW) { maxW = w }
                        }

                        help = help + "\n${groupName}:\n"
                        for (sub in groupSubs) {
                            var nameStr = sub.getName()
                            if (sub.getAliases().size > 0) {
                                nameStr = nameStr + " ("
                                var first = true
                                for (a in sub.getAliases()) {
                                    if (!first) { nameStr = nameStr + ", " }
                                    nameStr = nameStr + a
                                    first = false
                                }
                                nameStr = nameStr + ")"
                            }
                            var line = "  " + nameStr
                            match (sub.getDescription()) {
                                case Some(desc) =>
                                    let padTo = maxW + 6
                                    while (line.size < padTo) { line = line + " " }
                                    line = line + desc
                                case None => ()
                            }
                            help = help + wrapLine(line, maxWidth, maxW + 6) + "\n"
                        }
                    case None => ()
                }
            }
        }

        // 选项列表（支持分组）
        let flags = cmd.getFlags()
        if (flags.size > 0) {
            let groups = HashMap<String, ArrayList<Flag>>()
            let groupOrder = ArrayList<String>()
            for (f in flags) {
                if (f.isHidden()) { continue }
                let g = f.getGroup()
                if (!groups.contains(g)) {
                    groups[g] = ArrayList<Flag>()
                    groupOrder.add(g)
                }
                groups[g].add(f)
            }

            for (groupName in groupOrder) {
                help = help + "\n${groupName}:\n"
                match (groups.get(groupName)) {
                    case Some(groupFlags) =>
                        var maxFlagWidth: Int64 = 0
                        for (f in groupFlags) {
                            var w: Int64 = 0
                            match (f.getShortName()) {
                                case Some(_) => w = 4
                                case None => w = 4
                            }
                            w = w + 2 + f.getLongName().size
                            if (!f.isBoolFlag() && !f.isTerminate() && !f.isCount()) {
                                w = w + 1 + f.getValuePlaceholder().size
                            }
                            if (w > maxFlagWidth) { maxFlagWidth = w }
                        }

                        for (f in groupFlags) {
                            var line = "  "
                            match (f.getShortName()) {
                                case Some(s) => line = line + "-${s}, "
                                case None => line = line + "    "
                            }
                            line = line + "--${f.getLongName()}"
                            if (!f.isBoolFlag() && !f.isTerminate() && !f.isCount()) {
                                line = line + " " + f.getValuePlaceholder()
                            }
                            match (f.getDescription()) {
                                case Some(desc) =>
                                    let padTo = maxFlagWidth + 6
                                    while (line.size < padTo) { line = line + " " }
                                    line = line + desc
                                case None => ()
                            }
                            match (f.getDefaultValue()) {
                                case Some(dv) where !f.isBoolFlag() && !f.isTerminate() =>
                                    line = line + " " + Messages.locale().helpDefaultLabel(dv)
                                case _ => ()
                            }
                            // 显示环境变量信息
                            match (f.getEnvVar()) {
                                case Some(envName) =>
                                    line = line + " [env: ${envName}]"
                                case None => ()
                            }
                            help = help + wrapLine(line, maxWidth, maxFlagWidth + 6) + "\n"
                        }
                    case None => ()
                }
            }
        }

        // 参数列表
        let args = cmd.getArguments()
        if (args.size > 0) {
            help = help + "\n" + Messages.locale().helpArgumentsHeading() + ":\n"

            var maxArgWidth: Int64 = 0
            for (arg in args) {
                var w = arg.getName().size
                if (arg.isVariadic()) { w = w + 3 }
                if (w > maxArgWidth) { maxArgWidth = w }
            }

            for (arg in args) {
                var nameStr = arg.getName()
                if (arg.isVariadic()) { nameStr = nameStr + "..." }
                var line = "  " + nameStr
                match (arg.getDescription()) {
                    case Some(desc) =>
                        let padTo = maxArgWidth + 6
                        while (line.size < padTo) { line = line + " " }
                        line = line + desc
                    case None => ()
                }
                help = help + wrapLine(line, maxWidth, maxArgWidth + 6) + "\n"
            }
        }

        // Phase 9: Examples 段落
        let examples = cmd.getExamples()
        if (examples.size > 0) {
            help = help + "\n" + Messages.locale().helpExamplesHeading() + ":\n"
            for (ex in examples) {
                help = help + "  " + ex[0] + "\n"
                help = help + "      " + ex[1] + "\n"
            }
        }

        // Phase 9: afterHelp
        match (cmd.getAfterHelp()) {
            case Some(text) =>
                help = help + "\n" + wrapText(text, maxWidth) + "\n"
            case None => ()
        }

        help
    }

    // 生成版本信息
    func generateVersion(cmd: Command): String {
        // Phase 8: 优先使用 VersionInfo
        match (_versionInfo) {
            case Some(info) => info.toString() + "\n"
            case None =>
                var ver = cmd.getName()
                match (cmd.getVersion()) {
                    case Some(v) =>
                        ver = ver + " ${v}"
                    case None => ()
                }
                ver + "\n"
        }
    }

    // Phase 8: 生成补全脚本
    public func generateCompletion(shell: ShellType): String {
        CompletionGenerator.generate(_rootCommand, shell)
    }

    // 格式化框架层错误输出（使用诊断系统）
    // mockRun 中始终禁用颜色，保证测试断言稳定
    func formatError(e: CliException, args: Array<String>): String {
        let style = StyleEngine(false)  // mockRun 内禁用颜色
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag(e.message)

        // 构建输入上下文字符串
        var inputStr = ""
        for (a in args) {
            if (inputStr.size > 0) {
                inputStr = inputStr + " "
            }
            inputStr = inputStr + a
        }
        if (inputStr.size > 0) {
            diag.context(inputStr)
            // 尝试定位错误 token 的位置
            let errorPos = findErrorTokenPosition(e.message, args)
            match (errorPos) {
                case Some(pos) => diag.position(pos)
                case None => ()
            }
        }

        diag.hint(Messages.locale().helpMoreInfo())
        renderer.render(diag)
    }

    // Phase 10: 格式化聚合错误（多个验证错误统一报告）
    func formatAggregateError(e: AggregateException, _: Array<String>): String {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        var result = ""

        // 输出每个独立错误
        for (errMsg in e.getErrors()) {
            let diag = errorDiag(errMsg)
            result = result + renderer.render(diag)
        }

        // 输出每个警告
        for (warnMsg in e.getWarnings()) {
            let diag = warningDiag(warnMsg)
            result = result + renderer.render(diag)
        }

        // 输出摘要行
        result = result + "error: ${e.message}\n"
        result = result + "\n" + Messages.locale().helpMoreInfo() + "\n"
        result
    }

    // 从错误消息中提取错误 token，然后在参数列表中定位其位置
    func findErrorTokenPosition(message: String, args: Array<String>): Option<Int64> {
        // 尝试从消息中提取引号内的 token（如 '--unknown' 或 'lint'）
        var token = extractQuotedToken(message)
        match (token) {
            case Some(t) =>
                var pos: Int64 = 0
                for (a in args) {
                    if (a == t || a.contains(t)) {
                        return Some(pos)
                    }
                    pos = pos + a.size + 1  // +1 for space
                }
                None
            case None => None
        }
    }

    // 从字符串中提取单引号括起的第一个 token
    func extractQuotedToken(s: String): Option<String> {
        let runes = s.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] == r'\'') {
                var j = i + 1
                while (j < runes.size && runes[j] != r'\'') {
                    j++
                }
                if (j < runes.size) {
                    var token = ""
                    var k = i + 1
                    while (k < j) {
                        token = token + runes[k].toString()
                        k++
                    }
                    return Some(token)
                }
            }
            i++
        }
        None
    }

    // Phase 8: 传播全局 Flag 到所有子命令（递归）
    func propagateGlobalFlags(cmd: Command): Unit {
        for (sub in cmd.getSubcommands()) {
            for (gf in _globalFlags) {
                // 检查子命令是否已有同名 Flag，避免重复注册
                if (sub.findFlag(gf.getLongName()).isNone()) {
                    sub.flag(gf)
                }
            }
            propagateGlobalFlags(sub)
        }
    }

    // Phase 8: 检查弃用命令
    func checkCommandDeprecation(cmd: Command): Unit {
        match (cmd.getDeprecation()) {
            case Some(info) =>
                _deprecationCollector.add(info.formatWarning("command", cmd.getName()))
            case None => ()
        }
    }

    // Phase 8: 检查弃用 Flag（仅对用户显式设置的 Flag 发出警告）
    func checkFlagDeprecation(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (!ctx.isExplicit(f.getLongName())) { continue }
            match (f.getDeprecation()) {
                case Some(info) =>
                    _deprecationCollector.add(info.formatWarning("flag", "--" + f.getLongName()))
                case None => ()
            }
        }
    }

    // Phase 9: 文本折行（按终端宽度，不在单词中间断开）
    func wrapText(text: String, maxWidth: Int64): String {
        let runes = text.toRuneArray()
        if (runes.size <= maxWidth) { return text }
        var result = ""
        var lineStart: Int64 = 0
        while (lineStart < runes.size) {
            if (lineStart + maxWidth >= runes.size) {
                var remaining = ""
                var ri = lineStart
                while (ri < runes.size) {
                    remaining = remaining + runes[ri].toString()
                    ri++
                }
                result = result + remaining
                break
            }
            // 从 maxWidth 位置向左查找空格断点
            var breakAt: Int64 = lineStart + maxWidth
            while (breakAt > lineStart && runes[breakAt] != r' ') {
                breakAt--
            }
            if (breakAt == lineStart) {
                breakAt = lineStart + maxWidth  // 无空格则强制断开
            }
            var segment = ""
            var si = lineStart
            while (si < breakAt) {
                segment = segment + runes[si].toString()
                si++
            }
            result = result + segment + "\n"
            lineStart = breakAt
            // 跳过断点处的空格
            if (lineStart < runes.size && runes[lineStart] == r' ') {
                lineStart++
            }
        }
        result
    }

    // Phase 9: 带缩进的行折行（用于帮助文档中长描述的折行）
    func wrapLine(line: String, maxWidth: Int64, indentWidth: Int64): String {
        if (line.size <= maxWidth) { return line }
        let runes = line.toRuneArray()
        // 找到描述文本起止点（indentWidth 处开始是描述）
        if (indentWidth >= maxWidth) { return line }
        var breakAt: Int64 = maxWidth
        while (breakAt > indentWidth && breakAt < runes.size && runes[breakAt] != r' ') {
            breakAt--
        }
        if (breakAt <= indentWidth) { return line }  // 无法折行
        var firstLine = ""
        var fi: Int64 = 0
        while (fi < breakAt) {
            firstLine = firstLine + runes[fi].toString()
            fi++
        }
        // 剩余部分缩进到 indentWidth
        var rest: Int64 = breakAt
        if (rest < runes.size && runes[rest] == r' ') { rest++ }
        var indent = "\n"
        var ii: Int64 = 0
        while (ii < indentWidth) {
            indent = indent + " "
            ii++
        }
        var remaining = ""
        while (rest < runes.size) {
            remaining = remaining + runes[rest].toString()
            rest++
        }
        if (remaining.size == 0) { return firstLine }
        firstLine + indent + remaining
    }
}
