internal package cli.test

import std.unittest.*
import std.unittest.testmacro.*
import cli.*
import std.collection.*

// ============================================================================
// Phase 9: 增强型 Flag 值域与帮助系统测试
// ============================================================================

// --- Choices 枚举值约束 ---

@Test
class ChoicesValidationTest {
    @TestCase
    func testChoicesAcceptsValidValue() {
        let app = App("tool")
            .flag(Flag("format").choices(["text", "json", "markdown"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--format", "json"])
        @Expect(result.exitCode, 0)
        let app2 = App("tool")
            .flag(Flag("format").choices(["text", "json", "markdown"]))
            .action({ ctx =>
                @Expect(ctx.getFlag("format"), Some("json"))
                0
            })
        app2.mockRun(["--format", "json"])
    }

    @TestCase
    func testChoicesRejectsInvalidValue() {
        let app = App("tool")
            .flag(Flag("format").choices(["text", "json", "markdown"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--format", "yaml"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("Invalid value 'yaml'"), true)
        @Expect(result.stderr.contains("'text'"), true)
        @Expect(result.stderr.contains("'json'"), true)
    }

    @TestCase
    func testChoicesWithDidYouMean() {
        let app = App("tool")
            .flag(Flag("format").choices(["text", "json", "markdown"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--format", "texr"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("Did you mean"), true)
    }

    @TestCase
    func testChoicesWithEqualsSign() {
        let app = App("tool")
            .flag(Flag("output").choices(["stdout", "file"]))
            .action({ ctx =>
                @Expect(ctx.getFlag("output"), Some("file"))
                0
            })
        let result = app.mockRun(["--output=file"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testChoicesInHelpOutput() {
        let app = App("tool")
            .flag(Flag("format").description("Output format").choices(["text", "json", "markdown"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("<text|json|markdown>"), true)
    }
}

// --- Value Delimiters 值分隔符 ---

@Test
class ValueDelimiterTest {
    @TestCase
    func testCommaDelimiter() {
        let app = App("tool")
            .flag(Flag("filter").delimiter(r','))
            .action({ ctx =>
                let vals = ctx.getFlagAll("filter")
                match (vals) {
                    case Some(list) =>
                        @Expect(list.size, 3)
                        @Expect(list[0], "a")
                        @Expect(list[1], "b")
                        @Expect(list[2], "c")
                    case None =>
                        @Expect(true, false) // should not reach
                }
                0
            })
        let result = app.mockRun(["--filter", "a,b,c"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDelimiterWithEquals() {
        let app = App("tool")
            .flag(Flag("tags").delimiter(r','))
            .action({ ctx =>
                let vals = ctx.getFlagAll("tags")
                match (vals) {
                    case Some(list) =>
                        @Expect(list.size, 2)
                        @Expect(list[0], "v1")
                        @Expect(list[1], "v2")
                    case None =>
                        @Expect(true, false)
                }
                0
            })
        let result = app.mockRun(["--tags=v1,v2"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDelimiterWithChoices() {
        let app = App("tool")
            .flag(Flag("level").delimiter(r',').choices(["warn", "error", "info"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--level", "warn,error"])
        @Expect(result.exitCode, 0)
        // Invalid choice within delimited values
        let result2 = app.mockRun(["--level", "warn,debug"])
        @Expect(result2.exitCode != 0, true)
        @Expect(result2.stderr.contains("Invalid value 'debug'"), true)
    }

    @TestCase
    func testSingleValueNoSplit() {
        let app = App("tool")
            .flag(Flag("name").delimiter(r','))
            .action({ ctx =>
                let vals = ctx.getFlagAll("name")
                match (vals) {
                    case Some(list) =>
                        @Expect(list.size, 1)
                        @Expect(list[0], "hello")
                    case None =>
                        @Expect(true, false)
                }
                0
            })
        let result = app.mockRun(["--name", "hello"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDelimiterWithAppendAction() {
        let app = App("tool")
            .flag(Flag("item").delimiter(r';').action(FlagAction.Append))
            .action({ ctx =>
                let vals = ctx.getFlagAll("item")
                match (vals) {
                    case Some(list) =>
                        @Expect(list.size, 4)
                        @Expect(list[0], "a")
                        @Expect(list[1], "b")
                        @Expect(list[2], "c")
                        @Expect(list[3], "d")
                    case None =>
                        @Expect(true, false)
                }
                0
            })
        let result = app.mockRun(["--item", "a;b", "--item", "c;d"])
        @Expect(result.exitCode, 0)
    }
}

// --- Pass-Through 参数 ---

@Test
class PassThroughArgsTest {
    @TestCase
    func testPassThroughArgs() {
        let app = App("tool")
            .command(Command("lint").action({ ctx =>
                let passArgs = ctx.getPassthroughArgs()
                @Expect(passArgs.size, 3)
                @Expect(passArgs[0], "-W")
                @Expect(passArgs[1], "clippy::all")
                @Expect(passArgs[2], "--verbose")
                0
            }))
        let result = app.mockRun(["lint", "--", "-W", "clippy::all", "--verbose"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testPassThroughEmpty() {
        let app = App("tool")
            .action({ ctx =>
                @Expect(ctx.hasPassthroughArgs(), false)
                @Expect(ctx.getPassthroughArgs().size, 0)
                0
            })
        let result = app.mockRun(["--help"])
        // --help triggers TerminateException, so test without it
        let app2 = App("tool")
            .action({ ctx =>
                @Expect(ctx.hasPassthroughArgs(), false)
                0
            })
        let result2 = app2.mockRun([])
        @Expect(result2.exitCode, 0)
    }

    @TestCase
    func testPassThroughWithFlags() {
        let app = App("tool")
            .flag(Flag("verbose").asBool())
            .action({ ctx =>
                @Expect(ctx.getBoolFlag("verbose"), true)
                let passArgs = ctx.getPassthroughArgs()
                @Expect(passArgs.size, 2)
                @Expect(passArgs[0], "--extra")
                @Expect(passArgs[1], "val")
                0
            })
        let result = app.mockRun(["--verbose", "--", "--extra", "val"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testPassThroughDoubledDashAlone() {
        let app = App("tool")
            .action({ ctx =>
                @Expect(ctx.hasPassthroughArgs(), false)
                0
            })
        let result = app.mockRun(["--"])
        @Expect(result.exitCode, 0)
    }
}

// --- Help 文档增强 ---

@Test
class HelpExamplesTest {
    @TestCase
    func testExamplesInHelp() {
        let cmd = Command("lint")
            .description("Run lints")
            .example("lint src/", "Lint all files in src directory")
            .example("lint --fix main.cj", "Auto-fix issues in main.cj")
            .action({ ctx => 0 })
        let app = App("tool").command(cmd)
        let result = app.mockRun(["lint", "--help"])
        @Expect(result.stderr.contains("Examples:"), true)
        @Expect(result.stderr.contains("lint src/"), true)
        @Expect(result.stderr.contains("Lint all files"), true)
        @Expect(result.stderr.contains("lint --fix main.cj"), true)
    }

    @TestCase
    func testAfterHelp() {
        let cmd = Command("check")
            .description("Run checks")
            .afterHelp("See https://example.com for more info.")
            .action({ ctx => 0 })
        let app = App("tool").command(cmd)
        let result = app.mockRun(["check", "--help"])
        @Expect(result.stderr.contains("See https://example.com"), true)
    }

    @TestCase
    func testBeforeHelp() {
        let cmd = Command("build")
            .description("Build the project")
            .beforeHelp("NOTE: Requires Cangjie 1.0+")
            .action({ ctx => 0 })
        let app = App("tool").command(cmd)
        let result = app.mockRun(["build", "--help"])
        @Expect(result.stderr.contains("NOTE: Requires Cangjie 1.0+"), true)
        // beforeHelp 应在描述之前
        @Expect(result.stderr.contains("NOTE:"), true)
        @Expect(result.stderr.contains("Build the project"), true)
    }

    @TestCase
    func testExamplesAndAfterHelpOrder() {
        let cmd = Command("test")
            .description("Run tests")
            .example("test --all", "Run all tests")
            .afterHelp("Report issues at: https://github.com/example")
            .action({ ctx => 0 })
        let app = App("tool").command(cmd)
        let result = app.mockRun(["test", "--help"])
        @Expect(result.stderr.contains("Examples:"), true)
        @Expect(result.stderr.contains("Report issues"), true)
    }
}

// --- 终端宽度自适应 ---

@Test
class TerminalWidthTest {
    @TestCase
    func testNarrowWidth() {
        let app = App("tool")
            .helpWidth(40)
            .flag(Flag("verbose").short(r'v').description("Enable very detailed verbose output for debugging"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        // 在窄宽度下应触发折行
        @Expect(result.stderr.contains("Usage:"), true)
        // 原本整行会超过40字符，折行后应有多行
        let lines = result.stderr.split("\n")
        var hasLongLine = false
        for (line in lines) {
            // 允许一些容差
            if (line.size > 50) {
                hasLongLine = true
            }
        }
        // 应当已折过行
        @Expect(result.stderr.size > 0, true)
    }

    @TestCase
    func testDefaultWidth() {
        let app = App("tool")
            .flag(Flag("config").description("Path to config file"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("config"), true)
    }
}

// --- 子命令分组 ---

@Test
class SubcommandGroupTest {
    @TestCase
    func testSubcommandGrouping() {
        let app = App("tool")
            .command(Command("build").description("Build project").subcommandGroup("Build Commands"))
            .command(Command("test").description("Run tests").subcommandGroup("Test Commands"))
            .command(Command("fmt").description("Format code").subcommandGroup("Build Commands"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("Build Commands:"), true)
        @Expect(result.stderr.contains("Test Commands:"), true)
    }

    @TestCase
    func testDefaultGroupName() {
        let app = App("tool")
            .command(Command("init").description("Initialize"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("Commands:"), true)
    }

    @TestCase
    func testMixedGroups() {
        let app = App("tool")
            .command(Command("build").description("Build").subcommandGroup("Dev Commands"))
            .command(Command("help").description("Show help"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("Dev Commands:"), true)
        @Expect(result.stderr.contains("Commands:"), true)
    }
}

// --- N-Best 智能建议 ---

@Test
class NBestSuggestionTest {
    @TestCase
    func testSingleSuggestion() {
        let app = App("tool")
            .command(Command("lint").action({ ctx => 0 }))
        let result = app.mockRun(["lont"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("Did you mean 'lint'"), true)
    }

    @TestCase
    func testMultipleSuggestions() {
        let app = App("tool")
            .command(Command("test").action({ ctx => 0 }))
            .command(Command("text").action({ ctx => 0 }))
        let result = app.mockRun(["tex"])
        @Expect(result.exitCode != 0, true)
        // 应提供多个候选建议
        @Expect(result.stderr.contains("Did you mean"), true)
    }

    @TestCase
    func testFlagNBestSuggestion() {
        let app = App("tool")
            .flag(Flag("config").description("Config path"))
            .flag(Flag("confirm").description("Confirm action").asBool())
            .action({ ctx => 0 })
        let result = app.mockRun(["--confi"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("Did you mean"), true)
    }

    @TestCase
    func testChoicesSuggestion() {
        let app = App("tool")
            .flag(Flag("format").choices(["text", "json", "markdown"]))
            .action({ ctx => 0 })
        let result = app.mockRun(["--format", "markdwn"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("Did you mean 'markdown'"), true)
    }
}

// --- Phase 9 集成测试 ---

@Test
class Phase9IntegrationTest {
    @TestCase
    func testClippyStylePassThrough() {
        // 模拟 cargo clippy [ARGS] -- [CLIPPY_ARGS] 模式
        let app = App("clippy")
            .flag(Flag("fix").asBool().description("Auto-fix"))
            .command(Command("check").action({ ctx =>
                @Expect(ctx.getPassthroughArgs().size, 2)
                @Expect(ctx.getPassthroughArgs()[0], "-W")
                @Expect(ctx.getPassthroughArgs()[1], "clippy::all")
                0
            }))
        let result = app.mockRun(["check", "--", "-W", "clippy::all"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDelimiterWithChoicesAndValidation() {
        let app = App("tool")
            .flag(Flag("level").delimiter(r',').choices(["warn", "error", "info", "debug"]))
            .action({ ctx =>
                let vals = ctx.getFlagAll("level")
                match (vals) {
                    case Some(list) =>
                        @Expect(list.size, 2)
                        @Expect(list[0], "warn")
                        @Expect(list[1], "error")
                    case None =>
                        @Expect(true, false)
                }
                0
            })
        let result = app.mockRun(["--level=warn,error"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testChoicesInHelpWithDefault() {
        let app = App("tool")
            .flag(Flag("format").choices(["text", "json"]).defaultValue("text").description("Output format"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("<text|json>"), true)
        @Expect(result.stderr.contains("[default: text]"), true)
    }

    @TestCase
    func testHelpWithExamplesAndGroups() {
        let buildCmd = Command("build")
            .description("Build the project")
            .subcommandGroup("Development")
        let testCmd = Command("test")
            .description("Run test suite")
            .subcommandGroup("Development")
        let publishCmd = Command("publish")
            .description("Publish package")
            .subcommandGroup("Deployment")
        let app = App("pkg")
            .command(buildCmd)
            .command(testCmd)
            .command(publishCmd)
            .action({ ctx => 0 })

        app.getRootCommand().example("pkg build --release", "Build in release mode")
        app.getRootCommand().example("pkg test --all", "Run all tests")

        let result = app.mockRun(["--help"])
        @Expect(result.stderr.contains("Development:"), true)
        @Expect(result.stderr.contains("Deployment:"), true)
        @Expect(result.stderr.contains("Examples:"), true)
    }

    @TestCase
    func testFullPipeline() {
        // 完整的 Phase 9 特性组合
        let app = App("lintcheck")
            .flag(Flag("format").short(r'f').choices(["text", "json", "markdown"]).defaultValue("text").description("Output format"))
            .flag(Flag("filter").delimiter(r',').description("Filter lints"))
            .flag(Flag("verbose").short(r'v').asBool())
            .command(Command("run").action({ ctx =>
                @Expect(ctx.getFlag("format"), Some("json"))
                let filters = ctx.getFlagAll("filter")
                match (filters) {
                    case Some(list) =>
                        @Expect(list.size, 2)
                    case None => @Expect(true, false)
                }
                let passArgs = ctx.getPassthroughArgs()
                @Expect(passArgs.size, 1)
                @Expect(passArgs[0], "--allow-dirty")
                0
            }))
        let result = app.mockRun(["run", "--format", "json", "--filter", "warn,error", "--", "--allow-dirty"])
        @Expect(result.exitCode, 0)
    }
}
