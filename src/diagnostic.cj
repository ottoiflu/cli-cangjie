package cli

import std.collection.*

// 诊断级别枚举：对标 Rust 编译器 / Clippy 的四级语义化输出
public enum DiagnosticLevel {
    | Note
    | Help
    | Warning
    | Error
}

// 获取诊断级别的显示标签
func levelLabel(level: DiagnosticLevel): String {
    match (level) {
        case Note => "note"
        case Help => "help"
        case Warning => "warning"
        case Error => "error"
    }
}

// 获取诊断级别对应的颜色
func levelColor(level: DiagnosticLevel): Color {
    match (level) {
        case Note => Color.Cyan
        case Help => Color.Green
        case Warning => Color.Yellow
        case Error => Color.Red
    }
}

// 单条诊断消息
public class Diagnostic {
    let _level: DiagnosticLevel
    let _message: String
    let _hints: ArrayList<String> = ArrayList<String>()
    var _context: Option<String> = None
    var _position: Option<Int64> = None  // 错误 token 在输入中的位置索引

    public init(level: DiagnosticLevel, message: String) {
        _level = level
        _message = message
    }

    // 添加提示（附加行）
    public func hint(h: String): This {
        _hints.add(h)
        this
    }

    // 设置原始输入上下文（用于错误定位高亮）
    public func context(ctx: String): This {
        _context = Some(ctx)
        this
    }

    // 设置错误位置索引
    public func position(pos: Int64): This {
        _position = Some(pos)
        this
    }

    public func getLevel(): DiagnosticLevel { _level }
    public func getMessage(): String { _message }
    public func getHints(): ArrayList<String> { _hints }
    public func getContext(): Option<String> { _context }
    public func getPosition(): Option<Int64> { _position }
}

// 诊断格式化渲染器
public class DiagnosticRenderer {
    let _style: StyleEngine

    public init(style: StyleEngine) {
        _style = style
    }

    public init() {
        _style = StyleEngine()
    }

    // 渲染单条诊断为字符串
    public func render(diag: Diagnostic): String {
        var sb = StringBuilder()

        // 第一行: level: message
        let label = levelLabel(diag.getLevel())
        let coloredLabel = _style.boldColor(label, levelColor(diag.getLevel()))
        let colonStr = _style.bold(":")
        let boldMsg = _style.bold(diag.getMessage())
        sb.append("${coloredLabel}${colonStr} ${boldMsg}\n")

        // 上下文定位（如有）
        match (diag.getContext()) {
            case Some(ctx) =>
                sb.append(renderContext(ctx, diag.getPosition()))
            case None => ()
        }

        // 附加提示行
        for (hint in diag.getHints()) {
            let hintLabel = _style.boldColor("help", Color.Green)
            let hintColon = _style.bold(":")
            sb.append("   ${hintLabel}${hintColon} ${hint}\n")
        }

        sb.toString()
    }

    // 渲染参数上下文定位：指出错误 token 的位置
    func renderContext(inputCtx: String, position: Option<Int64>): String {
        var sb = StringBuilder()
        // 显示输入行
        let pipe = _style.boldColor("|", Color.Blue)
        sb.append("   ${pipe} ${inputCtx}\n")

        // 位置指示箭头
        match (position) {
            case Some(pos) =>
                let caretLine = " " * (pos + 1)
                let caret = _style.boldColor("^", Color.Red)
                sb.append("   ${pipe}\u{0020}${caretLine}${caret}\n")
            case None => ()
        }
        sb.toString()
    }

    // 渲染一组诊断消息
    public func renderAll(diags: ArrayList<Diagnostic>): String {
        var sb = StringBuilder()
        for (d in diags) {
            sb.append(render(d))
        }
        sb.toString()
    }
}

// 便捷工厂函数
public func errorDiag(message: String): Diagnostic {
    Diagnostic(DiagnosticLevel.Error, message)
}

public func warningDiag(message: String): Diagnostic {
    Diagnostic(DiagnosticLevel.Warning, message)
}

public func helpDiag(message: String): Diagnostic {
    Diagnostic(DiagnosticLevel.Help, message)
}

public func noteDiag(message: String): Diagnostic {
    Diagnostic(DiagnosticLevel.Note, message)
}
