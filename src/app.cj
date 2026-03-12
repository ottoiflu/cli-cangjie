package cli

import std.collection.*

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
    private let _rootCommand: Command
    private let _parser: Parser = Parser()

    public init(name: String) {
        this._rootCommand = Command(name)
    }

    // Builder 方法（代理到 rootCommand）

    public func description(desc: String): App {
        this._rootCommand.description(desc)
        return this
    }

    public func version(ver: String): App {
        this._rootCommand.version(ver)
        return this
    }

    public func author(auth: String): App {
        this._rootCommand.author(auth)
        return this
    }

    public func command(subCmd: Command): App {
        this._rootCommand.command(subCmd)
        return this
    }

    public func flag(f: Flag): App {
        this._rootCommand.flag(f)
        return this
    }

    public func argument(arg: Argument): App {
        this._rootCommand.argument(arg)
        return this
    }

    public func action(handler: ActionHandler): App {
        this._rootCommand.action(handler)
        return this
    }

    public func getRootCommand(): Command {
        return this._rootCommand
    }

    // 内存级沙箱执行接口：模拟运行 CLI 命令
    public func mockRun(args: Array<String>): TestResult {
        var stdoutBuf = ""
        var stderrBuf = ""

        // 特殊内置命令处理
        if (args.size > 0) {
            // --help / -h
            if (args[0] == "--help" || args[0] == "-h") {
                let helpText = generateHelp(_rootCommand)
                return TestResult(0, "", helpText)
            }
            // --version / -V
            if (args[0] == "--version" || args[0] == "-V") {
                let versionText = generateVersion(_rootCommand)
                return TestResult(0, versionText, "")
            }
        }

        // 检查子命令的 --help
        // 先尝试路由子命令，再检查是否有 --help
        var tempCmd = _rootCommand
        var helpIdx: Int64 = -1
        var i: Int64 = 0
        while (i < args.size) {
            if (args[i] == "--help" || args[i] == "-h") {
                helpIdx = i
                break
            }
            match (tempCmd.findSubcommand(args[i])) {
                case Some(sub) =>
                    tempCmd = sub
                case None => break
            }
            i++
        }
        if (helpIdx >= 0) {
            let helpText = generateHelp(tempCmd)
            return TestResult(0, "", helpText)
        }

        // 正式解析
        try {
            let (matchedCmd, ctx) = _parser.parse(_rootCommand, args)

            // 执行命令动作
            match (matchedCmd.getAction()) {
                case Some(handler) =>
                    let exitCode = handler(ctx)
                    return TestResult(exitCode, stdoutBuf, stderrBuf)
                case None =>
                    // 无动作处理器：显示帮助
                    let helpText = generateHelp(matchedCmd)
                    return TestResult(0, "", helpText)
            }
        } catch (e: CliException) {
            // 框架层异常：格式化错误输出，退出码 2
            stderrBuf = formatError(e, args)
            return TestResult(2, "", stderrBuf)
        } catch (e: Exception) {
            // 业务层通用异常：退出码 1
            stderrBuf = "error: ${e.message}\n"
            return TestResult(1, "", stderrBuf)
        }
    }

    // 生成帮助文档
    func generateHelp(cmd: Command): String {
        var help = ""
        // 标题
        if (cmd.getDescription().size > 0) {
            help = help + cmd.getDescription() + "\n\n"
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
            if (arg.isVariadic()) {
                help = help + " [${arg.getName()}...]"
            } else if (arg.isRequired()) {
                help = help + " <${arg.getName()}>"
            } else {
                help = help + " [${arg.getName()}]"
            }
        }
        help = help + "\n"

        // 子命令列表
        if (cmd.getSubcommands().size > 0) {
            help = help + "\nCommands:\n"
            for (sub in cmd.getSubcommands()) {
                var line = "  ${sub.getName()}"
                if (sub.getAliases().size > 0) {
                    line = line + " ("
                    var first = true
                    for (a in sub.getAliases()) {
                        if (!first) {
                            line = line + ", "
                        }
                        line = line + a
                        first = false
                    }
                    line = line + ")"
                }
                if (sub.getDescription().size > 0) {
                    // 填充到对齐位置
                    while (line.size < 24) {
                        line = line + " "
                    }
                    line = line + sub.getDescription()
                }
                help = help + line + "\n"
            }
        }

        // 选项列表
        if (cmd.getFlags().size > 0) {
            help = help + "\nOptions:\n"
            for (f in cmd.getFlags()) {
                var line = "  "
                if (f.getShortName().size > 0) {
                    line = line + "-${f.getShortName()}, "
                } else {
                    line = line + "    "
                }
                line = line + "--${f.getLongName()}"
                if (!f.isBoolFlag()) {
                    line = line + " <VALUE>"
                }
                if (f.getDescription().size > 0) {
                    while (line.size < 28) {
                        line = line + " "
                    }
                    line = line + f.getDescription()
                }
                if (f.getDefaultValue().size > 0 && !f.isBoolFlag()) {
                    line = line + " [default: ${f.getDefaultValue()}]"
                }
                help = help + line + "\n"
            }
        }

        // 参数列表
        if (cmd.getArguments().size > 0) {
            help = help + "\nArguments:\n"
            for (arg in cmd.getArguments()) {
                var line = "  "
                if (arg.isVariadic()) {
                    line = line + "${arg.getName()}..."
                } else {
                    line = line + arg.getName()
                }
                if (arg.getDescription().size > 0) {
                    while (line.size < 24) {
                        line = line + " "
                    }
                    line = line + arg.getDescription()
                }
                help = help + line + "\n"
            }
        }

        // 内置帮助选项提示
        help = help + "\n  -h, --help                Print help\n"
        if (cmd.getVersion().size > 0) {
            help = help + "  -V, --version             Print version\n"
        }

        return help
    }

    // 生成版本信息
    func generateVersion(cmd: Command): String {
        var ver = cmd.getName()
        if (cmd.getVersion().size > 0) {
            ver = ver + " ${cmd.getVersion()}"
        }
        return ver + "\n"
    }

    // 格式化框架层错误输出
    func formatError(e: CliException, args: Array<String>): String {
        var msg = "error: ${e.message}\n"
        // 显示用户输入上下文
        var inputStr = ""
        for (a in args) {
            if (inputStr.size > 0) {
                inputStr = inputStr + " "
            }
            inputStr = inputStr + a
        }
        if (inputStr.size > 0) {
            msg = msg + "\n  Input: ${inputStr}\n"
        }
        msg = msg + "\nFor more information, try '--help'.\n"
        return msg
    }
}
