package cli

import std.env.*

// ANSI 颜色枚举
public enum Color {
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White
    | BrightRed
    | BrightGreen
    | BrightYellow
    | BrightBlue
    | BrightMagenta
    | BrightCyan
    | BrightWhite
}

// 获取颜色的 ANSI 前景色代码
func colorCode(c: Color): String {
    match (c) {
        case Red => "31"
        case Green => "32"
        case Yellow => "33"
        case Blue => "34"
        case Magenta => "35"
        case Cyan => "36"
        case White => "37"
        case BrightRed => "91"
        case BrightGreen => "92"
        case BrightYellow => "93"
        case BrightBlue => "94"
        case BrightMagenta => "95"
        case BrightCyan => "96"
        case BrightWhite => "97"
    }
}

// 终端样式引擎：管理是否启用 ANSI 样式
public class StyleEngine {
    let _colorEnabled: Bool

    // 自动检测: NO_COLOR 环境变量存在时禁用颜色
    public init() {
        _colorEnabled = !hasNoColorEnv()
    }

    // 手动指定是否启用颜色
    public init(colorEnabled: Bool) {
        _colorEnabled = colorEnabled
    }

    public func isColorEnabled(): Bool { _colorEnabled }

    // 加粗
    public func bold(text: String): String {
        if (_colorEnabled) {
            "\u{001b}[1m${text}\u{001b}[0m"
        } else {
            text
        }
    }

    // 下划线
    public func underline(text: String): String {
        if (_colorEnabled) {
            "\u{001b}[4m${text}\u{001b}[0m"
        } else {
            text
        }
    }

    // 前景色
    public func color(text: String, c: Color): String {
        if (_colorEnabled) {
            "\u{001b}[${colorCode(c)}m${text}\u{001b}[0m"
        } else {
            text
        }
    }

    // 加粗 + 前景色
    public func boldColor(text: String, c: Color): String {
        if (_colorEnabled) {
            "\u{001b}[1;${colorCode(c)}m${text}\u{001b}[0m"
        } else {
            text
        }
    }

    // 斜体
    public func italic(text: String): String {
        if (_colorEnabled) {
            "\u{001b}[3m${text}\u{001b}[0m"
        } else {
            text
        }
    }

    // 暗淡
    public func dim(text: String): String {
        if (_colorEnabled) {
            "\u{001b}[2m${text}\u{001b}[0m"
        } else {
            text
        }
    }
}

// 检测 NO_COLOR 环境变量是否存在
func hasNoColorEnv(): Bool {
    match (getVariable("NO_COLOR")) {
        case Some(_) => true
        case None => false
    }
}

// 全局便捷函数：创建默认样式引擎
public func defaultStyleEngine(): StyleEngine {
    StyleEngine()
}
