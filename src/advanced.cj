package cli

import std.collection.*

// ===================== 输出格式模式 (Output Formats) =====================

// 输出格式枚举
public enum OutputFormat {
    | Text
    | Json
}

// 从字符串解析输出格式
public func parseOutputFormat(s: String): Option<OutputFormat> {
    let lower = s.toAsciiLower()
    if (lower == "text") { return Some(Text) }
    if (lower == "json") { return Some(Json) }
    None
}

// 格式化工具：将键值对按指定格式渲染
public class OutputFormatter {
    // 将键值对集合格式化为 JSON 字符串
    public static func toJson(entries: ArrayList<(String, String)>): String {
        var result = "{\n"
        var first = true
        for (entry in entries) {
            if (!first) {
                result = result + ",\n"
            }
            result = result + "  " + jsonEscapeStr(entry[0]) + ": " + jsonEscapeStr(entry[1])
            first = false
        }
        result = result + "\n}"
        result
    }

    // 将键值对集合格式化为文本
    public static func toText(entries: ArrayList<(String, String)>, separator!: String = ": "): String {
        var result = ""
        for (entry in entries) {
            result = result + entry[0] + separator + entry[1] + "\n"
        }
        result
    }

    // 格式化输出
    public static func format(entries: ArrayList<(String, String)>, fmt: OutputFormat): String {
        match (fmt) {
            case Text => toText(entries)
            case Json => toJson(entries)
        }
    }
}

// JSON 字符串转义
func jsonEscapeStr(s: String): String {
    var result = "\""
    let runes = s.toRuneArray()
    for (r in runes) {
        if (r == r'"') {
            result = result + "\\\""
        } else if (r == r'\\') {
            result = result + "\\\\"
        } else if (r == r'\n') {
            result = result + "\\n"
        } else if (r == r'\r') {
            result = result + "\\r"
        } else if (r == r'\t') {
            result = result + "\\t"
        } else {
            result = result + r.toString()
        }
    }
    result + "\""
}

// ===================== 丰富版本信息 (Rich Version Info) =====================

// 版本信息结构体: 对标 rustc_tools_util 的 VersionInfo
public class VersionInfo {
    var _name: String = ""
    var _version: String = ""
    var _commitHash: Option<String> = None
    var _commitDate: Option<String> = None
    var _buildDate: Option<String> = None
    var _compiler: Option<String> = None
    let _extras: ArrayList<(String, String)> = ArrayList<(String, String)>()

    public init() {}

    public func name(n: String): This {
        _name = n
        this
    }

    public func version(v: String): This {
        _version = v
        this
    }

    public func commitHash(h: String): This {
        _commitHash = Some(h)
        this
    }

    public func commitDate(d: String): This {
        _commitDate = Some(d)
        this
    }

    public func buildDate(d: String): This {
        _buildDate = Some(d)
        this
    }

    public func compiler(c: String): This {
        _compiler = Some(c)
        this
    }

    // 添加自定义元数据
    public func extra(key: String, value: String): This {
        _extras.add((key, value))
        this
    }

    // Getter 方法
    public func getName(): String { _name }
    public func getVersion(): String { _version }
    public func getCommitHash(): Option<String> { _commitHash }
    public func getCommitDate(): Option<String> { _commitDate }
    public func getBuildDate(): Option<String> { _buildDate }
    public func getCompiler(): Option<String> { _compiler }
    public func getExtras(): ArrayList<(String, String)> { _extras }

    // 短格式: "app-name 1.0.0"
    public func shortString(): String {
        "${_name} ${_version}"
    }

    // 标准格式: "app-name 1.0.0 (abc1234 2024-01-01)"
    // 对标 Clippy 的 "clippy 0.1.96 (a1b2c3d4e5 2024-03-12)"
    public func toString(): String {
        var result = "${_name} ${_version}"
        let hasHash = _commitHash.isSome()
        let hasDate = _commitDate.isSome()
        if (hasHash || hasDate) {
            result = result + " ("
            match (_commitHash) {
                case Some(h) => result = result + h
                case None => ()
            }
            match (_commitDate) {
                case Some(d) =>
                    if (hasHash) {
                        result = result + " "
                    }
                    result = result + d
                case None => ()
            }
            result = result + ")"
        }
        result
    }

    // 详细格式（多行）
    public func verboseString(): String {
        var result = "${_name} ${_version}\n"
        match (_commitHash) {
            case Some(h) => result = result + "commit: ${h}\n"
            case None => ()
        }
        match (_commitDate) {
            case Some(d) => result = result + "commit-date: ${d}\n"
            case None => ()
        }
        match (_buildDate) {
            case Some(d) => result = result + "build-date: ${d}\n"
            case None => ()
        }
        match (_compiler) {
            case Some(c) => result = result + "compiler: ${c}\n"
            case None => ()
        }
        for (kv in _extras) {
            result = result + "${kv[0]}: ${kv[1]}\n"
        }
        result
    }

    // 以键值对列表格式导出（用于 OutputFormatter）
    public func toEntries(): ArrayList<(String, String)> {
        let entries = ArrayList<(String, String)>()
        entries.add(("name", _name))
        entries.add(("version", _version))
        match (_commitHash) {
            case Some(h) => entries.add(("commit-hash", h))
            case None => ()
        }
        match (_commitDate) {
            case Some(d) => entries.add(("commit-date", d))
            case None => ()
        }
        match (_buildDate) {
            case Some(d) => entries.add(("build-date", d))
            case None => ()
        }
        match (_compiler) {
            case Some(c) => entries.add(("compiler", c))
            case None => ()
        }
        for (kv in _extras) {
            entries.add(kv)
        }
        entries
    }
}

// ===================== 弃用系统 (Deprecation) =====================

// 弃用信息
public class DeprecationInfo {
    let _reason: String
    let _replacement: Option<String>
    let _since: Option<String>

    public init(reason: String) {
        _reason = reason
        _replacement = None
        _since = None
    }

    public init(reason: String, replacement: String) {
        _reason = reason
        _replacement = Some(replacement)
        _since = None
    }

    public init(reason: String, replacement: String, since: String) {
        _reason = reason
        _replacement = Some(replacement)
        _since = Some(since)
    }

    public func getReason(): String { _reason }
    public func getReplacement(): Option<String> { _replacement }
    public func getSince(): Option<String> { _since }

    // 生成弃用警告消息
    public func formatWarning(itemType: String, itemName: String): String {
        var msg = "warning: ${itemType} '${itemName}' is deprecated"
        match (_since) {
            case Some(s) => msg = msg + " since ${s}"
            case None => ()
        }
        msg = msg + ". ${_reason}"
        match (_replacement) {
            case Some(r) => msg = msg + " Use '${r}' instead."
            case None => ()
        }
        msg
    }
}

// ===================== 弃用异常（用于收集弃用警告） =====================

// 弃用警告收集器：累积警告但不中止执行，最后输出到 stderr
public class DeprecationCollector {
    let _warnings: ArrayList<String> = ArrayList<String>()

    public func add(warning: String): Unit {
        _warnings.add(warning)
    }

    public func hasWarnings(): Bool {
        _warnings.size > 0
    }

    public func getWarnings(): ArrayList<String> {
        _warnings
    }

    // 将所有警告格式化为输出字符串
    public func formatAll(): String {
        var result = ""
        for (w in _warnings) {
            result = result + w + "\n"
        }
        result
    }
}
