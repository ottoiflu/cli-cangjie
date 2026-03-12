package cli

import std.collection.*
import std.fs.*
import std.env.*

// 配置文件解析错误
public class ConfigError {
    // 错误消息
    public let message: String
    // 配置文件路径
    public let filePath: String
    // 出错行号（1-based）
    public let line: Int64
    // 出错行内容
    public let lineContent: String
    // 修正建议（Did-You-Mean）
    public let suggestion: Option<String>

    public init(message: String, filePath: String, line: Int64, lineContent: String,
        suggestion!: Option<String> = None) {
        this.message = message
        this.filePath = filePath
        this.line = line
        this.lineContent = lineContent
        this.suggestion = suggestion
    }

    // 格式化为诊断字符串
    public func format(): String {
        var result = "error: ${message}\n"
        result = result + "  --> ${filePath}:${line}\n"
        let lineNumStr = line.toString()
        let pad = padString(" ", lineNumStr.size)
        result = result + "   ${pad}|\n"
        result = result + "   ${lineNumStr} | ${lineContent}\n"
        result = result + "   ${pad}|\n"
        match (suggestion) {
            case Some(s) =>
                result = result + "   = help: ${s}\n"
            case None => ()
        }
        result
    }
}

// 配置文件异常（解析失败时抛出）
public class ConfigException <: CliException {
    public let errors: ArrayList<ConfigError>

    public init(errors: ArrayList<ConfigError>) {
        super("configuration error")
        this.errors = errors
    }

    public override func getClassName(): String {
        "ConfigException"
    }

    // 格式化所有错误
    public func formatAll(): String {
        var result = ""
        for (e in errors) {
            result = result + e.format()
        }
        result
    }
}

// 配置文件中解析出的键值对
public class ConfigEntry {
    public let key: String
    public let value: String
    public let line: Int64 // 所在行号（1-based）

    public init(key: String, value: String, line: Int64) {
        this.key = key
        this.value = value
        this.line = line
    }
}

// 配置文件解析结果
public class ConfigData {
    let _entries: HashMap<String, ConfigEntry> = HashMap<String, ConfigEntry>()
    let _order: ArrayList<String> = ArrayList<String>()

    public func set(key: String, entry: ConfigEntry): Unit {
        if (!_entries.contains(key)) {
            _order.add(key)
        }
        _entries[key] = entry
    }

    public func get(key: String): Option<String> {
        match (_entries.get(key)) {
            case Some(entry) => Some(entry.value)
            case None => None
        }
    }

    public func getEntry(key: String): Option<ConfigEntry> {
        _entries.get(key)
    }

    public func contains(key: String): Bool {
        _entries.contains(key)
    }

    public func keys(): ArrayList<String> {
        _order
    }

    public func size(): Int64 {
        _entries.size
    }
}

// 配置加载器：支持 key = value 格式配置文件解析、目录遍历发现和 Did-You-Mean 建议
public class ConfigLoader {
    // 配置文件名（用于目录遍历查找）
    var _configFileNames: ArrayList<String> = ArrayList<String>()
    // 环境变量名（覆盖配置文件路径）
    var _configPathEnvVar: Option<String> = None
    // 已注册的合法 key（用于 Did-You-Mean 提示）
    let _knownKeys: ArrayList<String> = ArrayList<String>()

    public init() {}

    // 设置要查找的配置文件名（如 "app.toml", ".app.toml"）
    public func configFileName(name: String): This {
        _configFileNames.add(name)
        this
    }

    // 设置多个配置文件名
    public func configFileNames(names: Array<String>): This {
        for (n in names) {
            _configFileNames.add(n)
        }
        this
    }

    // 设置用于覆盖配置文件路径的环境变量名
    public func configPathEnvVar(envVarName: String): This {
        _configPathEnvVar = Some(envVarName)
        this
    }

    // 注册合法的 key（用于 Did-You-Mean 建议）
    public func knownKey(key: String): This {
        _knownKeys.add(key)
        this
    }

    // 注册多个合法 key
    public func knownKeys(keys: Array<String>): This {
        for (k in keys) {
            _knownKeys.add(k)
        }
        this
    }

    // 自动从已注册的 Flag 列表中提取合法 key
    public func knownKeysFromFlags(flags: ArrayList<Flag>): This {
        for (f in flags) {
            _knownKeys.add(f.getLongName())
        }
        this
    }

    // 查找配置文件：按优先级搜索
    // 1. CONFIG_PATH 环境变量指定的路径
    // 2. 从 startDir 向上遍历查找配置文件名
    public func discover(startDir!: String = "."): Option<String> {
        // 优先：环境变量指定路径
        match (_configPathEnvVar) {
            case Some(envName) =>
                match (getVariable(envName)) {
                    case Some(envPath) =>
                        if (fileExists(envPath)) {
                            return Some(envPath)
                        }
                    case None => ()
                }
            case None => ()
        }

        // 目录向上遍历查找
        if (_configFileNames.size == 0) {
            return None
        }

        var currentPath = startDir
        // 最多遍历 100 层防止无限循环
        var depth: Int64 = 0
        while (depth < 100) {
            for (fileName in _configFileNames) {
                let candidate = if (currentPath == ".") {
                    fileName
                } else if (currentPath.endsWith("/")) {
                    currentPath + fileName
                } else {
                    currentPath + "/" + fileName
                }
                if (fileExists(candidate)) {
                    return Some(candidate)
                }
            }
            // 上溯父目录
            let parentDir = getParentDir(currentPath)
            if (parentDir == currentPath) {
                break // 已到根目录
            }
            currentPath = parentDir
            depth++
        }
        None
    }

    // 解析配置文件内容为键值对
    // 格式: key = value（兼容 TOML 子集）
    // 支持:
    //   - 行注释 (#)
    //   - 空行
    //   - 带引号的字符串值 ("value" 或 'value')
    //   - 布尔值 (true/false)
    //   - 数字值
    //   - 数组值 [a, b, c]
    public func parse(content: String, filePath!: String = "<config>"): (ConfigData, ArrayList<ConfigError>) {
        let data = ConfigData()
        let errors = ArrayList<ConfigError>()
        let lines = content.split("\n")
        var lineNum: Int64 = 0

        while (lineNum < lines.size) {
            let rawLine = lines[lineNum]
            let trimmed = rawLine.trimAscii()
            lineNum++

            // 跳过空行和注释
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }

            // 跳过 section header [section.name]
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                continue
            }

            // 解析 key = value
            let eqIdx = findFirstEquals(trimmed)
            if (eqIdx < 0) {
                errors.add(ConfigError(
                    "expected 'key = value' format",
                    filePath, lineNum, rawLine
                ))
                continue
            }

            let key = trimmed[..eqIdx].trimAscii()
            let rawValue = trimmed[(eqIdx + 1)..].trimAscii()

            if (key.size == 0) {
                errors.add(ConfigError(
                    "empty key name",
                    filePath, lineNum, rawLine
                ))
                continue
            }

            // 检查重复 key
            if (data.contains(key)) {
                errors.add(ConfigError(
                    "duplicate key '${key}'",
                    filePath, lineNum, rawLine
                ))
                continue
            }

            // 处理值：去除引号
            let value = unquoteValue(rawValue)

            // 验证 key 合法性（如果注册了 knownKeys）
            if (_knownKeys.size > 0 && !isKnownKey(key)) {
                let suggestion = findSuggestionForKey(key)
                match (suggestion) {
                    case Some(s) =>
                        errors.add(ConfigError(
                            "unknown key '${key}'",
                            filePath, lineNum, rawLine,
                            suggestion: Some("did you mean '${s}'?")
                        ))
                    case None =>
                        errors.add(ConfigError(
                            "unknown key '${key}'",
                            filePath, lineNum, rawLine
                        ))
                }
                continue
            }

            data.set(key, ConfigEntry(key, value, lineNum))
        }

        (data, errors)
    }

    // 加载配置文件: discover + 读取 + parse
    public func load(startDir!: String = "."): (ConfigData, ArrayList<ConfigError>, Option<String>) {
        let filePath = discover(startDir: startDir)
        match (filePath) {
            case Some(path) =>
                let content = readTextFile(path)
                let (data, errors) = parse(content, filePath: path)
                (data, errors, Some(path))
            case None =>
                (ConfigData(), ArrayList<ConfigError>(), None)
        }
    }

    // 将配置数据应用到 Context：仅填充尚未设置的 Flag
    // 优先级：CLI > ENV > Config File > Defaults
    // 此方法在 ENV 合并之后、Defaults 之前调用
    public func applyToContext(data: ConfigData, ctx: Context): Unit {
        for (key in data.keys()) {
            // 配置 key 使用连字符格式（如 "db-host"），与 Flag longName 一致
            if (!ctx.hasFlag(key)) {
                match (data.get(key)) {
                    case Some(value) =>
                        ctx.setFlag(key, value)
                    case None => ()
                }
            }
        }
    }

    // --- 内部方法 ---

    func isKnownKey(key: String): Bool {
        // 支持连字符和下划线互换匹配
        let normalizedKey = normalizeKey(key)
        for (k in _knownKeys) {
            if (normalizeKey(k) == normalizedKey) {
                return true
            }
        }
        false
    }

    func findSuggestionForKey(key: String): Option<String> {
        let candidates = ArrayList<String>()
        for (k in _knownKeys) {
            candidates.add(k)
        }
        findSuggestion(key, candidates)
    }
}

// key 归一化：将下划线转换为连字符，用于匹配
public func normalizeKey(key: String): String {
    key.replace("_", "-")
}

// 获取父目录路径
func getParentDir(path: String): String {
    // 移除末尾的 /
    var p = path
    while (p.size > 1 && p.endsWith("/")) {
        p = p[..p.size - 1]
    }
    // 查找最后一个 /
    let runes = p.toRuneArray()
    var lastSlash: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'/') {
            lastSlash = i
        }
        i++
    }
    if (lastSlash <= 0) {
        if (p.startsWith("/")) {
            return "/"
        }
        return p // 无法再上溯
    }
    var result = ""
    var j: Int64 = 0
    while (j < lastSlash) {
        result = result + runes[j].toString()
        j++
    }
    if (result.size == 0) {
        return "/"
    }
    result
}

// 查找第一个未被引号包围的等号
func findFirstEquals(s: String): Int64 {
    let runes = s.toRuneArray()
    var inQuote = false
    var quoteChar: Rune = r'"'
    var i: Int64 = 0
    while (i < runes.size) {
        let c = runes[i]
        if (!inQuote && (c == r'"' || c == r'\'')) {
            inQuote = true
            quoteChar = c
        } else if (inQuote && c == quoteChar) {
            inQuote = false
        } else if (!inQuote && c == r'=') {
            return i
        }
        i++
    }
    -1
}

// 去掉值两端的引号
func unquoteValue(raw: String): String {
    if (raw.size < 2) {
        return raw
    }
    let runes = raw.toRuneArray()
    let first = runes[0]
    let last = runes[runes.size - 1]
    if ((first == r'"' && last == r'"') || (first == r'\'' && last == r'\'')) {
        // 去除首尾引号
        var result = ""
        var i: Int64 = 1
        while (i < runes.size - 1) {
            result = result + runes[i].toString()
            i++
        }
        return result
    }
    raw
}

// 读取文本文件
func readTextFile(path: String): String {
    let bytes = File.readFrom(Path(path))
    String.fromUtf8(bytes)
}



// 检查文件是否存在的包装
func fileExists(path: String): Bool {
    exists(Path(path))
}

// 字符串填充辅助函数
func padString(char: String, count: Int64): String {
    var result = ""
    var i: Int64 = 0
    while (i < count) {
        result = result + char
        i++
    }
    result
}
