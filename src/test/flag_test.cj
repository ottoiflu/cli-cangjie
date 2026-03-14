internal package cli.test

import cli.*

import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// Flag 定义测试
// ===============================================================
@Test
class FlagDefinitionTest {
    @TestCase
    func testBasicFlag() {
        let f = Flag("config")
            .short(r'c')
            .description("Config file path")
            .defaultValue("config.toml")

        @Assert(f.getLongName() == "config")
        match (f.getShortName()) {
            case Some(r) => @Assert(r == r'c')
            case None => @Assert(false)
        }
        match (f.getDescription()) {
            case Some(d) => @Assert(d == "Config file path")
            case None => @Assert(false)
        }
        match (f.getDefaultValue()) {
            case Some(d) => @Assert(d == "config.toml")
            case None => @Assert(false)
        }
        @Assert(f.isBoolFlag() == false)
    }

    @TestCase
    func testBoolFlag() {
        let f = Flag("verbose").short(r'v').asBool()

        @Assert(f.isBoolFlag() == true)
        match (f.getDefaultValue()) {
            case Some(d) => @Assert(d == "false")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testFlagWithTypeAndRequired() {
        let f = Flag("port")
            .short(r'p')
            .valueType(Int64Type)
            .required(true)

        @Assert(f.isRequired() == true)
    }

    @TestCase
    func testFlagMatches() {
        let f = Flag("output").short(r'o').alias("out")
        @Assert(f.matches("output") == true)
        @Assert(f.matches("o") == true)
        @Assert(f.matches("out") == true)
        @Assert(f.matches("other") == false)
    }

    @TestCase
    func testFlagAction() {
        let f1 = Flag("verbose").action(FlagAction.SetTrue)
        @Assert(f1.isBoolFlag() == true)

        let f2 = Flag("no-color").action(FlagAction.SetFalse)
        @Assert(f2.isBoolFlag() == true)

        let f3 = Flag("include").action(FlagAction.Append)
        @Assert(f3.isBoolFlag() == false)
    }

    @TestCase
    func testFlagGroup() {
        let f = Flag("debug").group("Debug Options")
        @Assert(f.getGroup() == "Debug Options")
    }

    @TestCase
    func testFlagNoShortName() {
        let f = Flag("verbose")
        match (f.getShortName()) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
        match (f.getShortNameStr()) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testFlagShortNameStr() {
        let f = Flag("verbose").short(r'v')
        match (f.getShortNameStr()) {
            case Some(s) => @Assert(s == "v")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testTerminateFlag() {
        let f = Flag("help").action(FlagAction.Terminate({ => "Help text" }))
        @Assert(f.isTerminate() == true)
        @Assert(f.isBoolFlag() == false)
    }
}
