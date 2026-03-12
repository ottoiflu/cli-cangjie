internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// Argument 定义测试
// ===============================================================
@Test
class ArgumentDefinitionTest {
    @TestCase
    func testBasicArgument() {
        let arg = Argument("file")
            .description("Input file")
            .required(true)

        @Assert(arg.getName() == "file")
        match (arg.getDescription()) {
            case Some(d) => @Assert(d == "Input file")
            case None => @Assert(false)
        }
        @Assert(arg.isRequired() == true)
        @Assert(arg.isVariadic() == false)
    }

    @TestCase
    func testVariadicArgument() {
        let arg = Argument("files")
            .variadic(true)
            .minCount(1)
            .maxCount(10)

        @Assert(arg.isVariadic() == true)
        @Assert(arg.getMinCount() == 1)
        @Assert(arg.getMaxCount() == 10)
    }

    @TestCase
    func testTypedArgument() {
        let arg = Argument("count")
            .valueType(Int64Type)
            .defaultValue("5")

        match (arg.getDefaultValue()) {
            case Some(d) => @Assert(d == "5")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testArgumentNoDescription() {
        let arg = Argument("file")
        match (arg.getDescription()) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testArgumentNoDefaultValue() {
        let arg = Argument("file")
        match (arg.getDefaultValue()) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }
}
