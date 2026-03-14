package cli

import std.collection.*

// 输入模拟器：预设 stdin 输入流数据，用于测试交互式 Prompt
public class InputMock {
    // 预设的输入行队列
    let _inputs: ArrayList<String> = ArrayList<String>()
    // 当前读取索引
    var _index: Int64 = 0

    public init() {}

    // 添加一行预设输入
    public func addLine(line: String): This {
        _inputs.add(line)
        this
    }

    // 批量添加预设输入
    public func addLines(lines: Array<String>): This {
        for (line in lines) {
            _inputs.add(line)
        }
        this
    }

    // 读取下一行输入
    // 模拟 readLine() 行为：返回预设值或 None（表示 EOF）
    public func readLine(): Option<String> {
        if (_index < _inputs.size) {
            let line = _inputs[_index]
            _index++
            Some(line)
        } else {
            None
        }
    }

    // 读取下一行，超出范围时返回默认值
    public func readLineOrDefault(defaultVal: String): String {
        match (readLine()) {
            case Some(line) => line
            case None => defaultVal
        }
    }

    // 检查是否还有剩余输入
    public func hasMore(): Bool {
        _index < _inputs.size
    }

    // 重置读取索引（可重复使用同一组输入）
    public func reset(): Unit {
        _index = 0
    }

    // 获取已消费的输入数量
    public func consumed(): Int64 {
        _index
    }

    // 获取剩余未消费的行数
    public func remaining(): Int64 {
        _inputs.size - _index
    }
}

// Prompt 相关工具：基于 InputMock 的交互式输入辅助
public class Prompt {
    let _mock: Option<InputMock>

    // 正常模式（直接读取 stdin）
    public init() {
        _mock = None
    }

    // 测试模式（使用 InputMock）
    public init(mock: InputMock) {
        _mock = Some(mock)
    }

    // 提示并读取一行文本
    public func ask(question: String): Option<String> {
        let _ = question
        match (_mock) {
            case Some(m) => m.readLine()
            case None =>
                // 真实模式: 暂不实现真实 stdin 读取，框架层先支持测试模式
                None
        }
    }

    // 提示并读取，带默认值
    public func askOrDefault(question: String, defaultVal: String): String {
        match (ask(question)) {
            case Some(v) =>
                if (v.size == 0) { defaultVal } else { v }
            case None => defaultVal
        }
    }

    // 确认提示 (y/n)
    public func confirm(question: String): Bool {
        match (ask(question)) {
            case Some(v) =>
                let lower = v.toAsciiLower()
                lower == "y" || lower == "yes"
            case None => false
        }
    }

    // 选择提示：从选项列表中选择
    // 输入为选项序号（从 1 开始）
    public func select(question: String, options: Array<String>): Option<String> {
        match (ask(question)) {
            case Some(v) =>
                if (isValidIndex(v, options.size)) {
                    let idx = parseIndex(v)
                    Some(options[idx])
                } else {
                    None
                }
            case None => None
        }
    }

    // 检查输入是否为有效的选项序号
    func isValidIndex(s: String, max: Int64): Bool {
        let runes = s.toRuneArray()
        if (runes.size == 0) {
            return false
        }
        for (r in runes) {
            if (r < r'0' || r > r'9') {
                return false
            }
        }
        let idx = parseIndex(s)
        idx >= 0 && idx < max
    }

    // 解析选项序号（1-based 转 0-based）
    func parseIndex(s: String): Int64 {
        var result: Int64 = 0
        for (r in s.toRuneArray()) {
            result = result * 10 + (Int64(UInt32(r)) - Int64(UInt32(r'0')))
        }
        result - 1  // 1-based → 0-based
    }
}
