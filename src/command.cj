package cli

import std.collection.*

// 命令动作处理函数类型
public type ActionHandler = (Context) -> Int64

// 钩子函数类型：返回 Unit，抛异常时可中断流程
public type HookHandler = (Context) -> Unit

// 中间件类型：接收 Context 和 next 回调，返回退出码
public type Middleware = (Context, () -> Int64) -> Int64

// 增强型命令定义：支持子命令树、Flag、Argument、别名、动作处理、生命周期钩子
public class Command {
    let _name: String
    var _description: Option<String> = None
    var _version: Option<String> = None
    var _author: Option<String> = None
    let _aliases: ArrayList<String> = ArrayList<String>()

    // 子命令：HashMap 提供 O(1) 查找（名称+别名均映射）
    let _subcommands: HashMap<String, Command> = HashMap<String, Command>()
    // 保留注册顺序用于 help 输出
    let _subcommandOrder: ArrayList<String> = ArrayList<String>()
    let _flags: ArrayList<Flag> = ArrayList<Flag>()
    let _arguments: ArrayList<Argument> = ArrayList<Argument>()

    var _action: Option<ActionHandler> = None

    // 生命周期钩子
    var _persistentPreRun: Option<HookHandler> = None
    var _preRun: Option<HookHandler> = None
    var _postRun: Option<HookHandler> = None
    var _persistentPostRun: Option<HookHandler> = None

    // 中间件链
    let _middlewares: ArrayList<Middleware> = ArrayList<Middleware>()

    // Phase 6: 隐藏与标志组约束
    var _hidden: Bool = false
    let _requireGroups: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    let _requireGroupNames: ArrayList<String> = ArrayList<String>()
    let _exclusiveGroups: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    let _exclusiveGroupNames: ArrayList<String> = ArrayList<String>()

    // 帮助输出的动态对齐宽度
    var _maxNameWidth: Int64 = 0

    public init(name: String) {
        _name = name
    }

    // Builder 方法：统一返回 This

    public func description(desc: String): This {
        _description = Some(desc)
        this
    }

    public func version(ver: String): This {
        _version = Some(ver)
        this
    }

    public func author(auth: String): This {
        _author = Some(auth)
        this
    }

    public func alias(a: String): This {
        _aliases.add(a)
        this
    }

    public func aliases(arr: Array<String>): This {
        for (a in arr) {
            _aliases.add(a)
        }
        this
    }

    public func command(subCmd: Command): This {
        _subcommands[subCmd.getName()] = subCmd
        _subcommandOrder.add(subCmd.getName())
        for (a in subCmd.getAliases()) {
            _subcommands[a] = subCmd
        }
        // 更新动态对齐宽度
        if (subCmd.getName().size > _maxNameWidth) {
            _maxNameWidth = subCmd.getName().size
        }
        this
    }

    // 批量注册子命令
    public func commands(subs: Array<Command>): This {
        for (sub in subs) {
            command(sub)
        }
        this
    }

    public func flag(f: Flag): This {
        _flags.add(f)
        // 更新动态对齐宽度：考虑短选项前缀
        var nameLen = f.getLongName().size + 2  // "--" prefix
        match (f.getShortName()) {
            case Some(_) => nameLen = nameLen + 4  // "-x, " prefix
            case None => ()
        }
        if (nameLen > _maxNameWidth) {
            _maxNameWidth = nameLen
        }
        this
    }

    // 批量注册 flag
    public func flags(fs: Array<Flag>): This {
        for (f in fs) {
            flag(f)
        }
        this
    }

    public func argument(arg: Argument): This {
        _arguments.add(arg)
        if (arg.getName().size > _maxNameWidth) {
            _maxNameWidth = arg.getName().size
        }
        this
    }

    // 批量注册位置参数
    public func arguments(args: Array<Argument>): This {
        for (arg in args) {
            argument(arg)
        }
        this
    }

    public func action(handler: ActionHandler): This {
        _action = Some(handler)
        this
    }

    // 生命周期钩子 Builder 方法

    public func persistentPreRun(hook: HookHandler): This {
        _persistentPreRun = Some(hook)
        this
    }

    public func preRun(hook: HookHandler): This {
        _preRun = Some(hook)
        this
    }

    public func postRun(hook: HookHandler): This {
        _postRun = Some(hook)
        this
    }

    public func persistentPostRun(hook: HookHandler): This {
        _persistentPostRun = Some(hook)
        this
    }

    // 中间件注册
    public func use(mw: Middleware): This {
        _middlewares.add(mw)
        this
    }

    // Phase 6: 隐藏命令
    public func hidden(h!: Bool = true): This {
        _hidden = h
        this
    }

    // 声明标志组：至少选一 (at-least-one)
    public func requireGroup(name: String, members: Array<String>): This {
        let memberList = ArrayList<String>()
        for (m in members) {
            memberList.add(m)
        }
        _requireGroups[name] = memberList
        _requireGroupNames.add(name)
        this
    }

    // 声明标志组：最多选一 (at-most-one)
    public func mutuallyExclusiveGroup(name: String, members: Array<String>): This {
        let memberList = ArrayList<String>()
        for (m in members) {
            memberList.add(m)
        }
        _exclusiveGroups[name] = memberList
        _exclusiveGroupNames.add(name)
        this
    }

    // Getter 方法

    public func getName(): String { _name }

    public func getDescription(): Option<String> { _description }

    public func getDescriptionStr(): String {
        match (_description) {
            case Some(d) => d
            case None => ""
        }
    }

    public func getVersion(): Option<String> { _version }

    public func getVersionStr(): String {
        match (_version) {
            case Some(v) => v
            case None => ""
        }
    }

    public func getAuthor(): Option<String> { _author }

    public func getAliases(): ArrayList<String> { _aliases }

    public func getSubcommandMap(): HashMap<String, Command> { _subcommands }

    // 按注册顺序返回子命令（去重）
    public func getSubcommands(): ArrayList<Command> {
        let result = ArrayList<Command>()
        for (name in _subcommandOrder) {
            match (_subcommands.get(name)) {
                case Some(cmd) => result.add(cmd)
                case None => ()
            }
        }
        result
    }

    public func getFlags(): ArrayList<Flag> { _flags }

    public func getArguments(): ArrayList<Argument> { _arguments }

    public func getAction(): Option<ActionHandler> { _action }

    public func getPersistentPreRun(): Option<HookHandler> { _persistentPreRun }
    public func getPreRun(): Option<HookHandler> { _preRun }
    public func getPostRun(): Option<HookHandler> { _postRun }
    public func getPersistentPostRun(): Option<HookHandler> { _persistentPostRun }
    public func getMiddlewares(): ArrayList<Middleware> { _middlewares }

    // Phase 6 Getter
    public func isHidden(): Bool { _hidden }
    public func getRequireGroups(): HashMap<String, ArrayList<String>> { _requireGroups }
    public func getRequireGroupNames(): ArrayList<String> { _requireGroupNames }
    public func getExclusiveGroups(): HashMap<String, ArrayList<String>> { _exclusiveGroups }
    public func getExclusiveGroupNames(): ArrayList<String> { _exclusiveGroupNames }

    public func getMaxNameWidth(): Int64 { _maxNameWidth }

    // 按名称或别名查找子命令（O(1)）
    public func findSubcommand(name: String): Option<Command> {
        _subcommands.get(name)
    }

    // 按长名或别名查找 Flag
    public func findFlag(name: String): Option<Flag> {
        for (f in _flags) {
            if (f.matches(name)) {
                return Some(f)
            }
        }
        None
    }

    // 按短名查找 Flag
    public func findFlagByShort(c: Rune): Option<Flag> {
        for (f in _flags) {
            if (f.matchesShort(c)) {
                return Some(f)
            }
        }
        None
    }

    // 获取所有已注册命令名称（含别名）用于错误提示
    public func allCommandNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (name in _subcommandOrder) {
            names.add(name)
            match (_subcommands.get(name)) {
                case Some(cmd) =>
                    for (a in cmd.getAliases()) {
                        names.add(a)
                    }
                case None => ()
            }
        }
        names
    }

    // 获取所有已注册 Flag 名称用于错误提示
    public func allFlagNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (f in _flags) {
            names.add(f.getLongName())
            match (f.getShortNameStr()) {
                case Some(s) => names.add(s)
                case None => ()
            }
            for (a in f.getAliases()) {
                names.add(a)
            }
        }
        names
    }
}
