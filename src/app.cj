package cli

import std.collection.*
import std.env.*

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
        // 自动注入 --help / --version 为 Terminate Flag
        injectBuiltinFlags(_rootCommand)

        // 正式解析
        try {
            let (matchedCmd, ctx) = _parser.parse(_rootCommand, args)

            // 解析后应用环境变量合并
            applyEnvVars(_rootCommand, ctx)
            if (matchedCmd.getName() != _rootCommand.getName()) {
                applyEnvVars(matchedCmd, ctx)
            }

            // 无动作处理器：显示帮助（跳过生命周期和中间件）
            if (matchedCmd.getAction().isNone()) {
                let helpText = generateHelp(matchedCmd)
                return TestResult(0, "", helpText)
            }

            // 执行生命周期: PersistentPreRun → PreRun → Middleware → Action → PostRun → PersistentPostRun
            // 1. PersistentPreRun (根命令的)
            match (_rootCommand.getPersistentPreRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }

            // 2. PreRun (当前命令的)
            match (matchedCmd.getPreRun()) {
                case Some(hook) => hook(ctx)
                case None => ()
            }

            // 3. 构建中间件链 + Action 执行
            let exitCode = executeWithMiddleware(_rootCommand, matchedCmd, ctx)

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

            TestResult(exitCode, "", "")
        } catch (e: TerminateException) {
            // Terminate 动作：执行回调获取输出内容
            let output = e.execute()
            // 帮助 => stderr；版本 => stdout
            if (output.contains("Usage:")) {
                TestResult(0, "", output)
            } else {
                TestResult(0, output, "")
            }
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
    func applyEnvVars(cmd: Command, ctx: Context): Unit {
        for (f in cmd.getFlags()) {
            if (!ctx.hasFlag(f.getLongName())) {
                // 优先检查 Flag 显式关联的环境变量
                match (f.getEnvVar()) {
                    case Some(envName) =>
                        match (getVariable(envName)) {
                            case Some(envVal) =>
                                ctx.setFlag(f.getLongName(), envVal)
                            case None => ()
                        }
                    case None =>
                        // 自动环境映射: 使用 envPrefix + FLAG_NAME
                        match (_envPrefix) {
                            case Some(prefix) =>
                                let autoEnvName = prefix + "_" + flagNameToEnvKey(f.getLongName())
                                match (getVariable(autoEnvName)) {
                                    case Some(envVal) =>
                                        ctx.setFlag(f.getLongName(), envVal)
                                    case None => ()
                                }
                            case None => ()
                        }
                }
            }
        }
    }

    // 将 flag 名转换为环境变量名格式: "db-host" → "DB_HOST"
    func flagNameToEnvKey(name: String): String {
        name.replace("-", "_").toAsciiUpper()
    }

    // 递归注入内置 --help / --version flags
    func injectBuiltinFlags(cmd: Command): Unit {
        // 检查是否已注入（避免重复注入）
        let hasHelp = cmd.findFlag("help").isSome()
        if (!hasHelp) {
            let helpCmd = cmd  // 捕获当前命令用于闭包
            cmd.flag(
                Flag("help").short(r'h')
                    .description("Print help")
                    .action(Terminate({ => generateHelp(helpCmd) }))
            )
        }

        let hasVersion = cmd.findFlag("version").isSome()
        if (!hasVersion && cmd.getVersion().isSome()) {
            let verCmd = cmd
            cmd.flag(
                Flag("version").short(r'V')
                    .description("Print version")
                    .action(Terminate({ => generateVersion(verCmd) }))
            )
        }

        // 递归注入子命令
        for (sub in cmd.getSubcommands()) {
            // 子命令继承根命令的 version（如果子命令没有自己的 version）
            injectBuiltinFlags(sub)
        }
    }

    // 生成帮助文档（支持分组和动态对齐）
    public func generateHelp(cmd: Command): String {
        var help = ""
        // 标题（about）
        match (cmd.getDescription()) {
            case Some(desc) =>
                help = help + desc + "\n\n"
            case None => ()
        }

        // Usage 行
        help = help + "Usage: "
        help = help + cmd.getName()
        if (cmd.getSubcommands().size > 0) {
            help = help + " <COMMAND>"
        }
        if (cmd.getFlags().size > 0) {
            help = help + " [OPTIONS]"
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

        // 子命令列表（支持分组）
        let subcommands = cmd.getSubcommands()
        if (subcommands.size > 0) {
            // 计算动态对齐宽度
            var maxWidth: Int64 = 0
            for (sub in subcommands) {
                var w = sub.getName().size
                if (sub.getAliases().size > 0) {
                    for (a in sub.getAliases()) {
                        w = w + 2 + a.size  // ", alias"
                    }
                }
                if (w > maxWidth) {
                    maxWidth = w
                }
            }

            help = help + "\nCommands:\n"
            for (sub in subcommands) {
                var nameStr = sub.getName()
                if (sub.getAliases().size > 0) {
                    nameStr = nameStr + " ("
                    var first = true
                    for (a in sub.getAliases()) {
                        if (!first) {
                            nameStr = nameStr + ", "
                        }
                        nameStr = nameStr + a
                        first = false
                    }
                    nameStr = nameStr + ")"
                }

                var line = "  " + nameStr
                match (sub.getDescription()) {
                    case Some(desc) =>
                        let padTo = maxWidth + 6  // 2(indent) + 4(gap)
                        while (line.size < padTo) {
                            line = line + " "
                        }
                        line = line + desc
                    case None => ()
                }
                help = help + line + "\n"
            }
        }

        // 选项列表（支持分组）
        let flags = cmd.getFlags()
        if (flags.size > 0) {
            // 按 group 分组
            let groups = HashMap<String, ArrayList<Flag>>()
            let groupOrder = ArrayList<String>()
            for (f in flags) {
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
                        // 计算动态对齐宽度
                        var maxFlagWidth: Int64 = 0
                        for (f in groupFlags) {
                            var w: Int64 = 0
                            match (f.getShortName()) {
                                case Some(_) => w = 4  // "-x, "
                                case None => w = 4     // "    "
                            }
                            w = w + 2 + f.getLongName().size  // "--name"
                            if (!f.isBoolFlag() && !f.isTerminate()) {
                                w = w + 8  // " <VALUE>"
                            }
                            if (w > maxFlagWidth) {
                                maxFlagWidth = w
                            }
                        }

                        for (f in groupFlags) {
                            var line = "  "
                            match (f.getShortName()) {
                                case Some(s) =>
                                    line = line + "-${s}, "
                                case None =>
                                    line = line + "    "
                            }
                            line = line + "--${f.getLongName()}"
                            if (!f.isBoolFlag() && !f.isTerminate()) {
                                line = line + " <VALUE>"
                            }
                            match (f.getDescription()) {
                                case Some(desc) =>
                                    let padTo = maxFlagWidth + 6  // 2(indent) + 4(gap)
                                    while (line.size < padTo) {
                                        line = line + " "
                                    }
                                    line = line + desc
                                case None => ()
                            }
                            match (f.getDefaultValue()) {
                                case Some(dv) where !f.isBoolFlag() && !f.isTerminate() =>
                                    line = line + " [default: ${dv}]"
                                case _ => ()
                            }
                            help = help + line + "\n"
                        }
                    case None => ()
                }
            }
        }

        // 参数列表
        let args = cmd.getArguments()
        if (args.size > 0) {
            help = help + "\nArguments:\n"

            var maxArgWidth: Int64 = 0
            for (arg in args) {
                var w = arg.getName().size
                if (arg.isVariadic()) {
                    w = w + 3  // "..."
                }
                if (w > maxArgWidth) {
                    maxArgWidth = w
                }
            }

            for (arg in args) {
                var nameStr = arg.getName()
                if (arg.isVariadic()) {
                    nameStr = nameStr + "..."
                }
                var line = "  " + nameStr
                match (arg.getDescription()) {
                    case Some(desc) =>
                        let padTo = maxArgWidth + 6
                        while (line.size < padTo) {
                            line = line + " "
                        }
                        line = line + desc
                    case None => ()
                }
                help = help + line + "\n"
            }
        }

        help
    }

    // 生成版本信息
    func generateVersion(cmd: Command): String {
        var ver = cmd.getName()
        match (cmd.getVersion()) {
            case Some(v) =>
                ver = ver + " ${v}"
            case None => ()
        }
        ver + "\n"
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

        diag.hint("For more information, try '--help'.")
        renderer.render(diag)
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
}
