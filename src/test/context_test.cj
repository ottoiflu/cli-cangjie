internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// Context 测试
// ===============================================================
@Test
class ContextTest {
    @TestCase
    func testFlagStorage() {
        let ctx = Context()
        ctx.setFlag("verbose", "true")
        ctx.setFlag("config", "app.toml")

        match (ctx.getFlag("verbose")) {
            case Some(v) => @Assert(v == "true")
            case None => @Assert(false)
        }
        match (ctx.getFlag("config")) {
            case Some(v) => @Assert(v == "app.toml")
            case None => @Assert(false)
        }
        match (ctx.getFlag("unknown")) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testBoolFlagHelper() {
        let ctx = Context()
        ctx.setFlag("verbose", "true")
        ctx.setFlag("quiet", "false")

        @Assert(ctx.getBoolFlag("verbose") == true)
        @Assert(ctx.getBoolFlag("quiet") == false)
        @Assert(ctx.getBoolFlag("unknown") == false)
    }

    @TestCase
    func testGetFlagOrDefault() {
        let ctx = Context()
        ctx.setFlag("port", "8080")

        @Assert(ctx.getFlagOrDefault("port", "3000") == "8080")
        @Assert(ctx.getFlagOrDefault("host", "localhost") == "localhost")
    }

    @TestCase
    func testArguments() {
        let ctx = Context()
        ctx.addArgument("file1.txt")
        ctx.addArgument("file2.txt")

        @Assert(ctx.argumentCount() == 2)
        match (ctx.getArgument(0)) {
            case Some(v) => @Assert(v == "file1.txt")
            case None => @Assert(false)
        }
        match (ctx.getArgument(2)) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testCommandPath() {
        let ctx = Context()
        ctx.pushCommandPath("tool")
        ctx.pushCommandPath("cloud")
        ctx.pushCommandPath("deploy")

        @Assert(ctx.getCommandPathStr() == "tool cloud deploy")
    }

    @TestCase
    func testInt64FlagHelper() {
        let ctx = Context()
        ctx.setFlag("port", "8080")

        match (ctx.getInt64Flag("port")) {
            case Some(v) => @Assert(v == 8080)
            case None => @Assert(false)
        }
    }
}
