package cli

import std.collection.*

// 命令动作处理函数类型
public type ActionHandler = (Context) -> Int64

// 增强型命令定义：支持子命令树、Flag、Argument、别名与动作处理
public class Command {
    private let _name: String
    private var _description: String = ""
    private var _version: String = ""
    private var _author: String = ""
    private let _aliases: ArrayList<String> = ArrayList<String>()

    private let _subcommands: ArrayList<Command> = ArrayList<Command>()
    private let _flags: ArrayList<Flag> = ArrayList<Flag>()
    private let _arguments: ArrayList<Argument> = ArrayList<Argument>()

    private var _action: Option<ActionHandler> = None

    public init(name: String) {
        this._name = name
    }

    // Builder 方法（返回 this 支持链式调用）

    public func description(desc: String): Command {
        this._description = desc
        return this
    }

    public func version(ver: String): Command {
        this._version = ver
        return this
    }

    public func author(auth: String): Command {
        this._author = auth
        return this
    }

    public func alias(a: String): Command {
        this._aliases.add(a)
        return this
    }

    public func command(subCmd: Command): Command {
        this._subcommands.add(subCmd)
        return this
    }

    public func flag(f: Flag): Command {
        this._flags.add(f)
        return this
    }

    public func argument(arg: Argument): Command {
        this._arguments.add(arg)
        return this
    }

    public func action(handler: ActionHandler): Command {
        this._action = Some(handler)
        return this
    }

    // Getter 方法

    public func getName(): String {
        return this._name
    }

    public func getDescription(): String {
        return this._description
    }

    public func getVersion(): String {
        return this._version
    }

    public func getAuthor(): String {
        return this._author
    }

    public func getAliases(): ArrayList<String> {
        return this._aliases
    }

    public func getSubcommands(): ArrayList<Command> {
        return this._subcommands
    }

    public func getFlags(): ArrayList<Flag> {
        return this._flags
    }

    public func getArguments(): ArrayList<Argument> {
        return this._arguments
    }

    public func getAction(): Option<ActionHandler> {
        return this._action
    }

    // 按名称或别名查找子命令
    public func findSubcommand(name: String): Option<Command> {
        for (sub in _subcommands) {
            if (sub.getName() == name) {
                return Some(sub)
            }
            for (a in sub.getAliases()) {
                if (a == name) {
                    return Some(sub)
                }
            }
        }
        return None
    }

    // 按长名、短名或别名查找 Flag
    public func findFlag(name: String): Option<Flag> {
        for (f in _flags) {
            if (f.matches(name)) {
                return Some(f)
            }
        }
        return None
    }

    // 获取所有已注册命令名称（含别名）用于错误提示
    public func allCommandNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (sub in _subcommands) {
            names.add(sub.getName())
            for (a in sub.getAliases()) {
                names.add(a)
            }
        }
        return names
    }

    // 获取所有已注册 Flag 名称（含别名）用于错误提示
    public func allFlagNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (f in _flags) {
            if (f.getLongName().size > 0) {
                names.add(f.getLongName())
            }
            if (f.getShortName().size > 0) {
                names.add(f.getShortName())
            }
            for (a in f.getAliases()) {
                names.add(a)
            }
        }
        return names
    }
}
