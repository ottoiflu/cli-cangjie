internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 诊断系统测试
// ===============================================================
@Test
class DiagnosticTest {
    @TestCase
    func testErrorDiagRender() {
        let style = StyleEngine(false)  // 无颜色模式
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag("Unknown option '--foo'.")
        let output = renderer.render(diag)
        @Assert(output.contains("error:"))
        @Assert(output.contains("Unknown option '--foo'."))
    }

    @TestCase
    func testWarningDiagRender() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = warningDiag("Deprecated option '--old'.")
        let output = renderer.render(diag)
        @Assert(output.contains("warning:"))
        @Assert(output.contains("Deprecated option '--old'."))
    }

    @TestCase
    func testHelpDiagRender() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = helpDiag("Use '--new' instead.")
        let output = renderer.render(diag)
        @Assert(output.contains("help:"))
        @Assert(output.contains("Use '--new' instead."))
    }

    @TestCase
    func testNoteDiagRender() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = noteDiag("This is a note.")
        let output = renderer.render(diag)
        @Assert(output.contains("note:"))
        @Assert(output.contains("This is a note."))
    }

    @TestCase
    func testDiagWithContext() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag("Unknown option '--foo'.")
            .context("--verbose --foo bar")
            .position(10)
        let output = renderer.render(diag)
        @Assert(output.contains("--verbose --foo bar"))
        @Assert(output.contains("^"))
    }

    @TestCase
    func testDiagWithHints() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag("Missing required flag.")
            .hint("Try adding '--output <path>'.")
            .hint("For more info, try '--help'.")
        let output = renderer.render(diag)
        @Assert(output.contains("help:"))
        @Assert(output.contains("Try adding '--output <path>'."))
        @Assert(output.contains("For more info, try '--help'."))
    }

    @TestCase
    func testDiagWithColorEnabled() {
        let style = StyleEngine(true)
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag("something failed")
        let output = renderer.render(diag)
        // 应包含 ANSI 转义序列
        @Assert(output.contains("\u{001b}["))
    }

    @TestCase
    func testDiagWithColorDisabled() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diag = errorDiag("something failed")
        let output = renderer.render(diag)
        // 不应包含 ANSI 转义序列
        @Assert(!output.contains("\u{001b}["))
    }

    @TestCase
    func testRenderAll() {
        let style = StyleEngine(false)
        let renderer = DiagnosticRenderer(style)
        let diags = ArrayList<Diagnostic>()
        diags.add(errorDiag("first error"))
        diags.add(warningDiag("a warning"))
        diags.add(noteDiag("a note"))
        let output = renderer.renderAll(diags)
        @Assert(output.contains("error:"))
        @Assert(output.contains("warning:"))
        @Assert(output.contains("note:"))
    }
}

// ===============================================================
// Did-You-Mean 集成测试（通过 App.mockRun）
// ===============================================================
@Test
class DidYouMeanIntegrationTest {
    @TestCase
    func testUnknownFlagSuggestion() {
        let app = App("tool")
            .flag(Flag("config").short(r'c'))
            .flag(Flag("verbose").short(r'v').asBool())

        let result = app.mockRun(["--confi"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Did you mean"))
        @Assert(result.stderr.contains("config"))
    }

    @TestCase
    func testUnknownCommandSuggestion() {
        let app = App("tool")
            .command(Command("lint").description("Lint code").action({ _ => 0 }))
            .command(Command("fmt").description("Format code").action({ _ => 0 }))

        let result = app.mockRun(["lnt"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Did you mean"))
        @Assert(result.stderr.contains("lint"))
    }

    @TestCase
    func testUnknownCommandNoSuggestion() {
        let app = App("tool")
            .command(Command("lint").action({ _ => 0 }))

        let result = app.mockRun(["xyzabc"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Unknown command"))
        @Assert(!result.stderr.contains("Did you mean"))
    }

    @TestCase
    func testUnknownFlagNoSuggestion() {
        let app = App("tool")
            .flag(Flag("verbose").asBool())

        let result = app.mockRun(["--xyzabc"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Unknown option"))
        @Assert(!result.stderr.contains("Did you mean"))
    }

    @TestCase
    func testDiagnosticContextInError() {
        let app = App("tool")
            .flag(Flag("config").short(r'c'))

        let result = app.mockRun(["--confi", "value"])

        @Assert(result.exitCode == 2)
        // 应包含输入上下文
        @Assert(result.stderr.contains("--confi"))
        @Assert(result.stderr.contains("help:"))
    }

    @TestCase
    func testErrorContainsHelpHint() {
        let app = App("tool")
            .flag(Flag("config"))

        let result = app.mockRun(["--unknown"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("--help"))
    }
}
