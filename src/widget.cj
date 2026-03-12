package cli

import std.collection.*

// ===============================================================
// 交互式终端组件 (Interactive Terminal Widgets)
// ===============================================================

// --- Spinner 加载指示器 ---

// Spinner 帧动画类型
public enum SpinnerStyle {
    | Dots        // ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    | Line        // - \ | /
    | Arrow       // ← ↖ ↑ ↗ → ↘ ↓ ↙
    | Simple      // . o O o
}

// Spinner 组件：在长时间操作时显示加载动画
public class Spinner {
    let _style: SpinnerStyle
    var _message: String
    var _frameIndex: Int64 = 0
    var _finished: Bool = false
    var _finishMessage: Option<String> = None

    public init(style!: SpinnerStyle = Dots) {
        _style = style
        _message = ""
    }

    // 设置显示消息
    public func message(msg: String): This {
        _message = msg
        this
    }

    // 获取当前帧字符
    public func currentFrame(): String {
        let frames = getFrames()
        frames[_frameIndex % frames.size]
    }

    // 步进到下一帧
    public func tick(): This {
        _frameIndex++
        this
    }

    // 标记完成
    public func finish(message!: String = ""): Unit {
        _finished = true
        if (message.size > 0) {
            _finishMessage = Some(message)
        }
    }

    // 渲染当前状态为字符串
    public func render(): String {
        if (_finished) {
            match (_finishMessage) {
                case Some(msg) => return "✓ ${msg}"
                case None =>
                    if (_message.size > 0) {
                        return "✓ ${_message}"
                    }
                    return "✓"
            }
        }
        let frame = currentFrame()
        if (_message.size > 0) {
            "${frame} ${_message}"
        } else {
            frame
        }
    }

    // 获取是否已完成
    public func isFinished(): Bool {
        _finished
    }

    // 重置状态
    public func reset(): Unit {
        _frameIndex = 0
        _finished = false
        _finishMessage = None
    }

    // 获取指定样式的帧列表
    func getFrames(): Array<String> {
        match (_style) {
            case Dots => ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            case Line => ["-", "\\", "|", "/"]
            case Arrow => ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"]
            case Simple => [".", "o", "O", "o"]
        }
    }
}

// --- ProgressBar 进度条 ---

// 进度条组件
public class ProgressBar {
    let _total: Int64
    var _current: Int64 = 0
    var _width: Int64 = 40
    var _filledChar: String = "█"
    var _emptyChar: String = "░"
    var _showPercent: Bool = true
    var _showCounts: Bool = true
    var _prefix: String = ""

    public init(total: Int64) {
        _total = total
    }

    // 设置进度条宽度
    public func width(w: Int64): This {
        _width = w
        this
    }

    // 设置填充字符
    public func filledChar(c: String): This {
        _filledChar = c
        this
    }

    // 设置空白字符
    public func emptyChar(c: String): This {
        _emptyChar = c
        this
    }

    // 是否显示百分比
    public func showPercent(show: Bool): This {
        _showPercent = show
        this
    }

    // 是否显示计数
    public func showCounts(show: Bool): This {
        _showCounts = show
        this
    }

    // 设置前缀文本
    public func prefix(p: String): This {
        _prefix = p
        this
    }

    // 设置当前进度
    public func set(value: Int64): This {
        _current = if (value > _total) { _total } else if (value < 0) { 0 } else { value }
        this
    }

    // 增加进度
    public func advance(delta!: Int64 = 1): This {
        set(_current + delta)
    }

    // 完成
    public func finish(): This {
        set(_total)
    }

    // 获取百分比 (0~100)
    public func percent(): Int64 {
        if (_total == 0) {
            return 100
        }
        _current * 100 / _total
    }

    // 获取当前进度
    public func getCurrent(): Int64 {
        _current
    }

    // 获取总量
    public func getTotal(): Int64 {
        _total
    }

    // 是否完成
    public func isComplete(): Bool {
        _current >= _total
    }

    // 渲染进度条字符串
    public func render(): String {
        let pct = percent()
        let filled = if (_total == 0) { _width } else { _current * _width / _total }
        let empty = _width - filled

        var bar = ""
        if (_prefix.size > 0) {
            bar = bar + _prefix + " "
        }

        var i: Int64 = 0
        while (i < filled) {
            bar = bar + _filledChar
            i++
        }
        i = 0
        while (i < empty) {
            bar = bar + _emptyChar
            i++
        }

        if (_showPercent) {
            bar = bar + " ${pct}%"
        }
        if (_showCounts) {
            bar = bar + " (${_current}/${_total})"
        }
        bar
    }
}

// --- Confirm 确认组件 ---

// 确认组件：使用 InputMock 实现可测试的确认交互
public class Confirm {
    let _message: String
    var _default: Bool = false

    public init(message: String) {
        _message = message
    }

    // 设置默认值
    public func defaultValue(val: Bool): This {
        _default = val
        this
    }

    // 使用 InputMock 执行确认
    public func run(mock: InputMock): Bool {
        match (mock.readLine()) {
            case Some(input) =>
                let trimmed = input.toAsciiLower()
                if (trimmed == "y" || trimmed == "yes") {
                    true
                } else if (trimmed == "n" || trimmed == "no") {
                    false
                } else if (trimmed.size == 0) {
                    _default
                } else {
                    _default
                }
            case None => _default
        }
    }

    // 渲染提示文本
    public func render(): String {
        let hint = if (_default) { "[Y/n]" } else { "[y/N]" }
        "${_message} ${hint}"
    }
}

// --- Select 选择组件 ---

// 选择组件：从选项列表中选择一个
public class Select {
    let _message: String
    let _options: ArrayList<String> = ArrayList<String>()
    var _default: Int64 = -1

    public init(message: String) {
        _message = message
    }

    // 添加选项
    public func option(opt: String): This {
        _options.add(opt)
        this
    }

    // 批量添加选项
    public func options(opts: Array<String>): This {
        for (o in opts) {
            _options.add(o)
        }
        this
    }

    // 设置默认选项索引 (1-based)
    public func defaultOption(index: Int64): This {
        _default = index
        this
    }

    // 使用 InputMock 执行选择
    public func run(mock: InputMock): Option<String> {
        match (mock.readLine()) {
            case Some(input) =>
                let trimmed = input.toAsciiLower()
                if (trimmed.size == 0 && _default > 0 && _default <= _options.size) {
                    return Some(_options[_default - 1])
                }
                // 尝试解析数字
                if (isNumeric(trimmed)) {
                    let idx = parseNum(trimmed)
                    if (idx >= 1 && idx <= _options.size) {
                        return Some(_options[idx - 1])
                    }
                }
                // 尝试匹配选项文本
                for (opt in _options) {
                    if (opt.toAsciiLower() == trimmed) {
                        return Some(opt)
                    }
                }
                None
            case None =>
                if (_default > 0 && _default <= _options.size) {
                    Some(_options[_default - 1])
                } else {
                    None
                }
        }
    }

    // 渲染选择菜单
    public func render(): String {
        var result = _message + "\n"
        var i: Int64 = 0
        while (i < _options.size) {
            let num = i + 1
            let marker = if (num == _default) { ">" } else { " " }
            result = result + " ${marker} ${num}. ${_options[i]}\n"
            i++
        }
        result
    }

    // 获取选项数量
    public func optionCount(): Int64 {
        _options.size
    }

    // 内部工具
    func isNumeric(s: String): Bool {
        let runes = s.toRuneArray()
        if (runes.size == 0) {
            return false
        }
        for (r in runes) {
            if (r < r'0' || r > r'9') {
                return false
            }
        }
        true
    }

    func parseNum(s: String): Int64 {
        var result: Int64 = 0
        for (r in s.toRuneArray()) {
            result = result * 10 + (Int64(UInt32(r)) - Int64(UInt32(r'0')))
        }
        result
    }
}

// --- MultiSelect 多选组件 ---

// 多选组件：从选项列表中选择多个
public class MultiSelect {
    let _message: String
    let _options: ArrayList<String> = ArrayList<String>()

    public init(message: String) {
        _message = message
    }

    // 添加选项
    public func option(opt: String): This {
        _options.add(opt)
        this
    }

    // 批量添加选项
    public func options(opts: Array<String>): This {
        for (o in opts) {
            _options.add(o)
        }
        this
    }

    // 使用 InputMock 执行多选
    // 输入格式: 逗号分割的数字序号，如 "1,3,5"
    public func run(mock: InputMock): ArrayList<String> {
        let result = ArrayList<String>()
        match (mock.readLine()) {
            case Some(input) =>
                let parts = input.split(",")
                for (part in parts) {
                    let trimmed = trimStr(part)
                    if (isNumeric(trimmed)) {
                        let idx = parseNum(trimmed)
                        if (idx >= 1 && idx <= _options.size) {
                            result.add(_options[idx - 1])
                        }
                    }
                }
            case None => ()
        }
        result
    }

    // 渲染多选菜单
    public func render(): String {
        var r = _message + " (comma-separated numbers)\n"
        var i: Int64 = 0
        while (i < _options.size) {
            r = r + "  ${i + 1}. ${_options[i]}\n"
            i++
        }
        r
    }

    // 内部工具
    func trimStr(s: String): String {
        let runes = s.toRuneArray()
        var start: Int64 = 0
        var end = runes.size
        while (start < end && runes[start] == r' ') {
            start++
        }
        while (end > start && runes[end - 1] == r' ') {
            end--
        }
        var result = ""
        var i = start
        while (i < end) {
            result = result + runes[i].toString()
            i++
        }
        result
    }

    func isNumeric(s: String): Bool {
        let runes = s.toRuneArray()
        if (runes.size == 0) {
            return false
        }
        for (r in runes) {
            if (r < r'0' || r > r'9') {
                return false
            }
        }
        true
    }

    func parseNum(s: String): Int64 {
        var result: Int64 = 0
        for (r in s.toRuneArray()) {
            result = result * 10 + (Int64(UInt32(r)) - Int64(UInt32(r'0')))
        }
        result
    }
}
