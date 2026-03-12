internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// ANSI 样式引擎测试
// ===============================================================
@Test
class StyleTest {
    @TestCase
    func testBoldWithColor() {
        let style = StyleEngine(true)
        let result = style.bold("hello")
        @Assert(result.contains("hello"))
        @Assert(result.contains("\u{001b}["))  // 包含 ANSI 转义
    }

    @TestCase
    func testBoldWithoutColor() {
        let style = StyleEngine(false)
        let result = style.bold("hello")
        @Assert(result == "hello")  // 纯文本
    }

    @TestCase
    func testColorEnabled() {
        let style = StyleEngine(true)
        let result = style.color("text", Color.Red)
        @Assert(result.contains("\u{001b}[31m"))
        @Assert(result.contains("text"))
    }

    @TestCase
    func testColorDisabled() {
        let style = StyleEngine(false)
        let result = style.color("text", Color.Red)
        @Assert(result == "text")
    }

    @TestCase
    func testBoldColor() {
        let style = StyleEngine(true)
        let result = style.boldColor("error", Color.Red)
        @Assert(result.contains("\u{001b}[1;31m"))
        @Assert(result.contains("error"))
    }

    @TestCase
    func testUnderline() {
        let style = StyleEngine(true)
        let result = style.underline("link")
        @Assert(result.contains("\u{001b}[4m"))
    }

    @TestCase
    func testItalic() {
        let style = StyleEngine(true)
        let result = style.italic("note")
        @Assert(result.contains("\u{001b}[3m"))
    }

    @TestCase
    func testDim() {
        let style = StyleEngine(true)
        let result = style.dim("faded")
        @Assert(result.contains("\u{001b}[2m"))
    }

    @TestCase
    func testAllColorsEnabled() {
        let style = StyleEngine(true)
        // 测试每种颜色都产生有效输出
        let colors = [Color.Red, Color.Green, Color.Yellow, Color.Blue,
            Color.Magenta, Color.Cyan, Color.White,
            Color.BrightRed, Color.BrightGreen, Color.BrightYellow,
            Color.BrightBlue, Color.BrightMagenta, Color.BrightCyan, Color.BrightWhite]
        for (c in colors) {
            let result = style.color("test", c)
            @Assert(result.contains("\u{001b}["))
            @Assert(result.contains("test"))
        }
    }

    @TestCase
    func testAllColorsDisabled() {
        let style = StyleEngine(false)
        let colors = [Color.Red, Color.Green, Color.Yellow, Color.Blue]
        for (c in colors) {
            let result = style.color("test", c)
            @Assert(result == "test")
        }
    }
}
