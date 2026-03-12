internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 类型转换测试
// ===============================================================
@Test
class TypeConversionTest {
    @TestCase
    func testValidInt() {
        @Assert(isValidInt("123") == true)
        @Assert(isValidInt("-42") == true)
        @Assert(isValidInt("+7") == true)
        @Assert(isValidInt("0") == true)
    }

    @TestCase
    func testInvalidInt() {
        @Assert(isValidInt("") == false)
        @Assert(isValidInt("abc") == false)
        @Assert(isValidInt("12.5") == false)
        @Assert(isValidInt("-") == false)
    }

    @TestCase
    func testValidFloat() {
        @Assert(isValidFloat("3.14") == true)
        @Assert(isValidFloat("-2.5") == true)
        @Assert(isValidFloat("100") == true)
        @Assert(isValidFloat("0.0") == true)
    }

    @TestCase
    func testInvalidFloat() {
        @Assert(isValidFloat("") == false)
        @Assert(isValidFloat("abc") == false)
        @Assert(isValidFloat("1.2.3") == false)
    }

    @TestCase
    func testBoolConversion() {
        @Assert(normalizeBool("true") == "true")
        @Assert(normalizeBool("false") == "false")
        @Assert(normalizeBool("yes") == "true")
        @Assert(normalizeBool("no") == "false")
        @Assert(normalizeBool("1") == "true")
        @Assert(normalizeBool("0") == "false")
    }

    @TestCase
    func testBoolConversionError() {
        var caught = false
        try {
            normalizeBool("maybe")
        } catch (e: TypeConversionException) {
            caught = true
            @Assert(e.message.contains("Cannot convert"))
        }
        @Assert(caught)
    }

    @TestCase
    func testValidateAndConvertString() {
        let result = validateAndConvert("hello", StringType)
        @Assert(result == "hello")
    }

    @TestCase
    func testValidateAndConvertInt() {
        let result = validateAndConvert("42", Int64Type)
        @Assert(result == "42")
    }

    @TestCase
    func testValidateAndConvertIntError() {
        var caught = false
        try {
            validateAndConvert("abc", Int64Type)
        } catch (e: TypeConversionException) {
            caught = true
        }
        @Assert(caught)
    }

    @TestCase
    func testSimpleIntParse() {
        @Assert(parseSimpleInt("123") == 123)
        @Assert(parseSimpleInt("-42") == -42)
        @Assert(parseSimpleInt("0") == 0)
    }
}
