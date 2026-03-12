internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 解析引擎测试 (Parser)
// ===============================================================
@Test
class ParserTest {
    @TestCase
    func testParseLongFlag() {
        let cmd = Command("app")
            .flag(Flag("verbose").asBool())
            .flag(Flag("config").short(r'c'))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--verbose", "--config", "app.toml"])

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.getFlagOrDefault("config", "") == "app.toml")
    }

    @TestCase
    func testParseLongFlagWithEquals() {
        let cmd = Command("app")
            .flag(Flag("config").short(r'c'))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--config=app.toml"])

        @Assert(ctx.getFlagOrDefault("config", "") == "app.toml")
    }

    @TestCase
    func testParseShortFlag() {
        let cmd = Command("app")
            .flag(Flag("verbose").short(r'v').asBool())
            .flag(Flag("config").short(r'c'))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["-v", "-c", "app.toml"])

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.getFlagOrDefault("config", "") == "app.toml")
    }

    @TestCase
    func testSubcommandRouting() {
        let root = Command("tool")
            .command(
                Command("lint")
                    .flag(Flag("fix").short(r'f').asBool())
                    .action({ ctx => 0 })
            )

        let parser = Parser()
        let (matched, ctx) = parser.parse(root, ["lint", "--fix"])

        @Assert(matched.getName() == "lint")
        @Assert(ctx.getBoolFlag("fix") == true)
    }

    @TestCase
    func testDeepSubcommandRouting() {
        let root = Command("tool")
            .command(
                Command("cloud")
                    .command(
                        Command("server")
                            .command(
                                Command("start")
                                    .flag(Flag("port").short(r'p').valueType(Int64Type))
                                    .action({ ctx => 0 })
                            )
                    )
            )

        let parser = Parser()
        let (matched, ctx) = parser.parse(root, ["cloud", "server", "start", "--port", "8080"])

        @Assert(matched.getName() == "start")
        @Assert(ctx.getFlagOrDefault("port", "") == "8080")
        @Assert(ctx.getCommandPathStr() == "tool cloud server start")
    }

    @TestCase
    func testPositionalArguments() {
        let cmd = Command("app")
            .argument(Argument("input").required(true))
            .argument(Argument("output"))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["file.txt", "out.txt"])

        @Assert(ctx.argumentCount() == 2)
        match (ctx.getArgument(0)) {
            case Some(v) => @Assert(v == "file.txt")
            case None => @Assert(false)
        }
        match (ctx.getArgument(1)) {
            case Some(v) => @Assert(v == "out.txt")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testVariadicArguments() {
        let cmd = Command("app")
            .argument(Argument("files").variadic(true).minCount(1))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["a.txt", "b.txt", "c.txt"])

        @Assert(ctx.argumentCount() == 3)
    }

    @TestCase
    func testDoubleDashSeparator() {
        let cmd = Command("app")
            .flag(Flag("verbose").short(r'v').asBool())

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--verbose", "--", "--not-a-flag", "file.txt"])

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.argumentCount() == 2)
        match (ctx.getArgument(0)) {
            case Some(v) => @Assert(v == "--not-a-flag")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testDefaultValues() {
        let cmd = Command("app")
            .flag(Flag("config").defaultValue("default.toml"))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, [])

        @Assert(ctx.getFlagOrDefault("config", "") == "default.toml")
    }

    @TestCase
    func testRequiredFlagMissing() {
        let cmd = Command("app")
            .flag(Flag("output").short(r'o').required(true))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, [])
        } catch (e: ValidationException) {
            caught = true
            @Assert(e.message.contains("--output"))
        }
        @Assert(caught)
    }

    @TestCase
    func testRequiredArgumentMissing() {
        let cmd = Command("app")
            .argument(Argument("file").required(true))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, [])
        } catch (e: ValidationException) {
            caught = true
            @Assert(e.message.contains("file"))
        }
        @Assert(caught)
    }

    @TestCase
    func testUnknownLongFlag() {
        let cmd = Command("app")

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["--unknown"])
        } catch (e: ParseException) {
            caught = true
            @Assert(e.message.contains("--unknown"))
        }
        @Assert(caught)
    }

    @TestCase
    func testUnknownShortFlag() {
        let cmd = Command("app")

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["-x"])
        } catch (e: ParseException) {
            caught = true
            @Assert(e.message.contains("-x"))
        }
        @Assert(caught)
    }

    @TestCase
    func testFlagMissingValue() {
        let cmd = Command("app")
            .flag(Flag("output").short(r'o'))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["--output"])
        } catch (e: ParseException) {
            caught = true
            @Assert(e.message.contains("requires a value"))
        }
        @Assert(caught)
    }

    @TestCase
    func testTypedFlagInt64() {
        let cmd = Command("app")
            .flag(Flag("port").short(r'p').valueType(Int64Type))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--port", "8080"])

        @Assert(ctx.getFlagOrDefault("port", "") == "8080")
        match (ctx.getInt64Flag("port")) {
            case Some(v) => @Assert(v == 8080)
            case None => @Assert(false)
        }
    }

    @TestCase
    func testTypedFlagInt64Error() {
        let cmd = Command("app")
            .flag(Flag("port").short(r'p').valueType(Int64Type))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["--port", "abc"])
        } catch (e: TypeConversionException) {
            caught = true
        }
        @Assert(caught)
    }

    @TestCase
    func testTypedFlagBool() {
        let cmd = Command("app")
            .flag(Flag("debug").valueType(BoolType))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--debug", "yes"])

        @Assert(ctx.getFlagOrDefault("debug", "") == "true")
    }

    @TestCase
    func testSubcommandWithAlias() {
        let root = Command("tool")
            .command(Command("install").alias("i").action({ ctx => 0 }))

        let parser = Parser()
        let (matched, _) = parser.parse(root, ["i"])

        @Assert(matched.getName() == "install")
    }

    @TestCase
    func testMixedFlagsAndArgs() {
        let cmd = Command("app")
            .flag(Flag("verbose").short(r'v').asBool())
            .flag(Flag("output").short(r'o'))
            .argument(Argument("input").required(true))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["input.txt", "--verbose", "-o", "output.txt"])

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.getFlagOrDefault("output", "") == "output.txt")
        match (ctx.getArgument(0)) {
            case Some(v) => @Assert(v == "input.txt")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testVariadicMinCountViolation() {
        let cmd = Command("app")
            .argument(Argument("files").variadic(true).minCount(2))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["only-one.txt"])
        } catch (e: ValidationException) {
            caught = true
            @Assert(e.message.contains("at least"))
        }
        @Assert(caught)
    }

    @TestCase
    func testTerminateFlagThrows() {
        let cmd = Command("app")
            .flag(Flag("help").short(r'h').action(FlagAction.Terminate({ => "Help text" })))

        let parser = Parser()
        var caught = false
        try {
            parser.parse(cmd, ["--help"])
        } catch (e: TerminateException) {
            caught = true
            @Assert(e.execute() == "Help text")
        }
        @Assert(caught)
    }

    @TestCase
    func testAppendAction() {
        let cmd = Command("app")
            .flag(Flag("include").short(r'I').action(FlagAction.Append))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["-I", "src/", "-I", "lib/"])

        match (ctx.getFlagAll("include")) {
            case Some(vals) =>
                @Assert(vals.size == 2)
                @Assert(vals[0] == "src/")
                @Assert(vals[1] == "lib/")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSetTrueAction() {
        let cmd = Command("app")
            .flag(Flag("verbose").action(FlagAction.SetTrue))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--verbose"])

        @Assert(ctx.getBoolFlag("verbose") == true)
    }

    @TestCase
    func testSetFalseAction() {
        let cmd = Command("app")
            .flag(Flag("no-color").action(FlagAction.SetFalse))

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["--no-color"])

        @Assert(ctx.getBoolFlag("no-color") == false)
    }

    @TestCase
    func testBatchFlags() {
        let cmd = Command("app").flags([
            Flag("verbose").short(r'v').asBool(),
            Flag("config").short(r'c'),
            Flag("output").short(r'o')
        ])

        let parser = Parser()
        let (_, ctx) = parser.parse(cmd, ["-v", "-c", "app.toml", "-o", "out.txt"])

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.getFlagOrDefault("config", "") == "app.toml")
        @Assert(ctx.getFlagOrDefault("output", "") == "out.txt")
    }
}
