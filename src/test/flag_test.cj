internal package cli.test

import cli.*

import std.collection.*
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
            .short("c")
            .description("Config file path")
            .defaultValue("config.toml")

        @Assert(f.getLongName() == "config")
        @Assert(f.getShortName() == "c")
        @Assert(f.getDescription() == "Config file path")
        @Assert(f.getDefaultValue() == "config.toml")
        @Assert(f.isBoolFlag() == false)
    }

    @TestCase
    func testBoolFlag() {
        let f = Flag("verbose").short("v").asBool()

        @Assert(f.isBoolFlag() == true)
        @Assert(f.getDefaultValue() == "false")
    }

    @TestCase
    func testFlagWithTypeAndRequired() {
        let f = Flag("port")
            .short("p")
            .valueType(Int64Type)
            .required(true)

        @Assert(f.isRequired() == true)
    }

    @TestCase
    func testFlagMatches() {
        let f = Flag("output", "o").alias("out")
        @Assert(f.matches("output") == true)
        @Assert(f.matches("o") == true)
        @Assert(f.matches("out") == true)
        @Assert(f.matches("other") == false)
    }
}
