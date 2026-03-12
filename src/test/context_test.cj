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

    @TestCase
    func testAppendFlag() {
        let ctx = Context()
        ctx.appendFlag("include", "src/")
        ctx.appendFlag("include", "lib/")
        ctx.appendFlag("include", "test/")

        match (ctx.getFlagAll("include")) {
            case Some(vals) =>
                @Assert(vals.size == 3)
                @Assert(vals[0] == "src/")
                @Assert(vals[1] == "lib/")
                @Assert(vals[2] == "test/")
            case None => @Assert(false)
        }
        // getFlag returns the last value
        match (ctx.getFlag("include")) {
            case Some(v) => @Assert(v == "test/")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testHasFlag() {
        let ctx = Context()
        ctx.setFlag("verbose", "true")

        @Assert(ctx.hasFlag("verbose") == true)
        @Assert(ctx.hasFlag("unknown") == false)
    }

    @TestCase
    func testGetString() {
        let ctx = Context()
        ctx.setFlag("name", "test")

        match (ctx.getString("name")) {
            case Some(v) => @Assert(v == "test")
            case None => @Assert(false)
        }
        match (ctx.getString("missing")) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testGetAllFlags() {
        let ctx = Context()
        ctx.setFlag("a", "1")
        ctx.appendFlag("b", "x")
        ctx.appendFlag("b", "y")

        let all = ctx.getAllFlags()
        @Assert(all.contains("a"))
        @Assert(all.contains("b"))
        match (all.get("b")) {
            case Some(vals) => @Assert(vals.size == 2)
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSetFlagOverwrites() {
        let ctx = Context()
        ctx.setFlag("key", "val1")
        ctx.setFlag("key", "val2")

        match (ctx.getFlag("key")) {
            case Some(v) => @Assert(v == "val2")
            case None => @Assert(false)
        }
        // setFlag replaces the entire list
        match (ctx.getFlagAll("key")) {
            case Some(vals) => @Assert(vals.size == 1)
            case None => @Assert(false)
        }
    }
}
