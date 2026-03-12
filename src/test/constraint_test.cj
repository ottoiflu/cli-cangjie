internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 互斥标志测试 (Mutual Exclusion)
// ===============================================================
@Test
class ConflictsTest {
    @TestCase
    func testConflictingFlagsError() {
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("json").asBool().conflictsWith("text"))
                    .flag(Flag("text").asBool().conflictsWith("json"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run", "--json", "--text"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("cannot be used together"))
    }

    @TestCase
    func testNoConflictWhenOnlyOneSet() {
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("json").asBool().conflictsWith("text"))
                    .flag(Flag("text").asBool().conflictsWith("json"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run", "--json"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testConflictNotTriggeredByDefault() {
        // text 有默认值 false，只有 json 被显式设置 → 不冲突
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("json").asBool().conflictsWith("text"))
                    .flag(Flag("text").asBool())
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run", "--json"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testConflictWithShortFlag() {
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("verbose").short(r'v').asBool().conflictsWith("quiet"))
                    .flag(Flag("quiet").short(r'q').asBool().conflictsWith("verbose"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run", "-v", "-q"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("cannot be used together"))
    }
}

// ===============================================================
// 标志依赖测试 (Flag Dependencies)
// ===============================================================
@Test
class RequiresTest {
    @TestCase
    func testRequiresMet() {
        let app = App("tool")
            .command(
                Command("export")
                    .flag(Flag("output").description("Output path"))
                    .flag(Flag("format").requires("output").description("Format"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["export", "--output", "out.txt", "--format", "json"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testRequiresNotMet() {
        let app = App("tool")
            .command(
                Command("export")
                    .flag(Flag("output").description("Output path"))
                    .flag(Flag("format").requires("output").description("Format"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["export", "--format", "json"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("requires"))
        @Assert(result.stderr.contains("--output"))
    }

    @TestCase
    func testRequiresSatisfiedByDefault() {
        // output 有默认值，即使未显式设置也满足依赖
        let app = App("tool")
            .command(
                Command("export")
                    .flag(Flag("output").defaultValue("default.txt"))
                    .flag(Flag("format").requires("output"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["export", "--format", "json"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testMultipleRequires() {
        let app = App("tool")
            .command(
                Command("deploy")
                    .flag(Flag("host"))
                    .flag(Flag("port").valueType(Int64Type))
                    .flag(Flag("ssl").asBool().requires("host").requires("port"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["deploy", "--ssl", "--host", "localhost"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("--port"))
    }
}

// ===============================================================
// 自定义验证器测试 (Custom Validators)
// ===============================================================
@Test
class ValidatorTest {
    @TestCase
    func testValidatorPasses() {
        let app = App("tool")
            .command(
                Command("create")
                    .flag(
                        Flag("name")
                            .validator({ s => s.size > 0 && s.size < 20 }, message: "must be 1-20 characters")
                    )
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["create", "--name", "hello"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testValidatorFails() {
        let app = App("tool")
            .command(
                Command("create")
                    .flag(
                        Flag("name")
                            .validator({ s => s.size > 0 && s.size < 5 }, message: "must be 1-4 characters")
                    )
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["create", "--name", "toolongname"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Invalid value"))
        @Assert(result.stderr.contains("must be 1-4 characters"))
    }

    @TestCase
    func testValidatorWithoutMessage() {
        let app = App("tool")
            .command(
                Command("init")
                    .flag(Flag("level").valueType(Int64Type).validator({ s =>
                        let runes = s.toRuneArray()
                        var n: Int64 = 0
                        for (r in runes) {
                            if (r >= r'0' && r <= r'9') {
                                n = n * 10 + (Int64(UInt32(r)) - 48)
                            }
                        }
                        n >= 1 && n <= 5
                    }))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["init", "--level", "9"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("Invalid value for '--level'"))
    }

    @TestCase
    func testValidatorNotRunOnUnsetFlag() {
        // 未设置的 Flag 不触发验证
        let app = App("tool")
            .command(
                Command("test")
                    .flag(Flag("name").validator({ s => false }, message: "always fail"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["test"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testLintNameValidator() {
        // 对标 Clippy 的 lint_name() 验证器：只允许小写字母、数字、下划线
        let lintNameValidator = { s: String =>
            let runes = s.toRuneArray()
            if (runes.size == 0) { return false }
            for (r in runes) {
                if (!((r >= r'a' && r <= r'z') || (r >= r'0' && r <= r'9') || r == r'_')) {
                    return false
                }
            }
            true
        }
        let app = App("tool")
            .command(
                Command("lint")
                    .flag(Flag("name").validator(lintNameValidator, message: "must contain only lowercase letters, digits, and underscores"))
                    .action({ ctx => 0 })
            )
        // 合法
        let r1 = app.mockRun(["lint", "--name", "my_lint_1"])
        @Assert(r1.exitCode == 0)
        // 非法
        let r2 = app.mockRun(["lint", "--name", "MyLint"])
        @Assert(r2.exitCode == 2)
        @Assert(r2.stderr.contains("lowercase"))
    }
}

// ===============================================================
// 隐藏标志与命令测试 (Hidden)
// ===============================================================
@Test
class HiddenTest {
    @TestCase
    func testHiddenFlagNotInHelp() {
        let app = App("tool")
            .flag(Flag("debug").asBool().hidden())
            .flag(Flag("verbose").short(r'v').asBool())
        let result = app.mockRun(["--help"])
        @Assert(!result.stderr.contains("--debug"))
        @Assert(result.stderr.contains("--verbose"))
    }

    @TestCase
    func testHiddenFlagStillWorks() {
        let app = App("tool")
            .flag(Flag("debug").asBool().hidden())
            .action({ ctx =>
                if (ctx.getBoolFlag("debug")) { 42 } else { 0 }
            })
        let result = app.mockRun(["--debug"])
        @Assert(result.exitCode == 42)
    }

    @TestCase
    func testHiddenCommandNotInHelp() {
        let app = App("tool")
            .command(Command("serve").description("Start server").action({ _ => 0 }))
            .command(Command("internal").description("Internal use").hidden().action({ _ => 0 }))
        let result = app.mockRun(["--help"])
        @Assert(result.stderr.contains("serve"))
        @Assert(!result.stderr.contains("internal"))
    }

    @TestCase
    func testHiddenCommandStillWorks() {
        let app = App("tool")
            .command(Command("internal").hidden().action({ _ => 99 }))
        let result = app.mockRun(["internal"])
        @Assert(result.exitCode == 99)
    }
}

// ===============================================================
// 标志组验证测试 (Flag Group Validation)
// ===============================================================
@Test
class FlagGroupTest {
    @TestCase
    func testRequireGroupSatisfied() {
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("file").description("Input file"))
                    .flag(Flag("stdin").asBool().description("Read from stdin"))
                    .requireGroup("input", ["file", "stdin"])
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run", "--file", "input.txt"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testRequireGroupNotSatisfied() {
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("file").description("Input file"))
                    .flag(Flag("stdin").asBool().description("Read from stdin"))
                    .requireGroup("input", ["file", "stdin"])
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("group 'input'"))
        @Assert(result.stderr.contains("required"))
    }

    @TestCase
    func testMutuallyExclusiveGroupOK() {
        let app = App("tool")
            .command(
                Command("output")
                    .flag(Flag("json").asBool())
                    .flag(Flag("yaml").asBool())
                    .flag(Flag("text").asBool())
                    .mutuallyExclusiveGroup("format", ["json", "yaml", "text"])
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["output", "--json"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testMutuallyExclusiveGroupViolation() {
        let app = App("tool")
            .command(
                Command("output")
                    .flag(Flag("json").asBool())
                    .flag(Flag("yaml").asBool())
                    .mutuallyExclusiveGroup("format", ["json", "yaml"])
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["output", "--json", "--yaml"])
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("mutually exclusive"))
    }

    @TestCase
    func testRequireGroupWithExclusiveCombined() {
        // 组内至少选一且最多选一 → "恰好选一"
        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("fast").asBool())
                    .flag(Flag("safe").asBool())
                    .requireGroup("mode", ["fast", "safe"])
                    .mutuallyExclusiveGroup("mode", ["fast", "safe"])
                    .action({ ctx => 0 })
            )
        // 恰好一个 → OK
        let r1 = app.mockRun(["run", "--fast"])
        @Assert(r1.exitCode == 0)
        // 两个 → 互斥冲突
        let r2 = app.mockRun(["run", "--fast", "--safe"])
        @Assert(r2.exitCode == 2)
        // 零个 → requireGroup 失败
        let r3 = app.mockRun(["run"])
        @Assert(r3.exitCode == 2)
    }
}

// ===============================================================
// 约束集成测试
// ===============================================================
@Test
class ConstraintIntegrationTest {
    @TestCase
    func testClippyLintcheckPattern() {
        // 对标 Clippy lintcheck: --fix 与 --max-jobs 互斥
        let app = App("lintcheck")
            .flag(Flag("fix").asBool().conflictsWith("max-jobs"))
            .flag(Flag("max-jobs").valueType(Int64Type).defaultValue("4"))
            .action({ ctx => 0 })
        // 只用 fix → OK
        let r1 = app.mockRun(["--fix"])
        @Assert(r1.exitCode == 0)
        // fix + max-jobs → 冲突
        let r2 = app.mockRun(["--fix", "--max-jobs", "2"])
        @Assert(r2.exitCode == 2)
        @Assert(r2.stderr.contains("cannot be used together"))
    }

    @TestCase
    func testOutputFormatDependsOnOutput() {
        // --output-format 依赖 --output
        let app = App("tool")
            .flag(Flag("output").short(r'o'))
            .flag(Flag("output-format").requires("output"))
            .action({ ctx => 0 })
        let r1 = app.mockRun(["--output", "file.txt", "--output-format", "json"])
        @Assert(r1.exitCode == 0)
        let r2 = app.mockRun(["--output-format", "json"])
        @Assert(r2.exitCode == 2)
    }

    @TestCase
    func testAllConstraintsCombined() {
        // 综合测试：互斥 + 依赖 + 验证器 + 隐藏 + 组
        let portValidator = { s: String =>
            let runes = s.toRuneArray()
            var n: Int64 = 0
            for (r in runes) {
                if (r >= r'0' && r <= r'9') {
                    n = n * 10 + (Int64(UInt32(r)) - 48)
                }
            }
            n >= 1 && n <= 65535
        }
        let app = App("server")
            .command(
                Command("start")
                    .flag(Flag("host").defaultValue("localhost"))
                    .flag(Flag("port").valueType(Int64Type).validator(portValidator, message: "must be 1-65535").requires("host"))
                    .flag(Flag("http").asBool())
                    .flag(Flag("https").asBool())
                    .flag(Flag("internal-id").hidden())
                    .mutuallyExclusiveGroup("protocol", ["http", "https"])
                    .action({ ctx => 0 })
            )
        // 正常使用
        let r1 = app.mockRun(["start", "--port", "8080", "--http"])
        @Assert(r1.exitCode == 0)
        // 端口越界
        let r2 = app.mockRun(["start", "--port", "99999", "--http"])
        @Assert(r2.exitCode == 2)
        @Assert(r2.stderr.contains("must be 1-65535"))
        // 协议互斥
        let r3 = app.mockRun(["start", "--http", "--https"])
        @Assert(r3.exitCode == 2)
        // help 不显示 internal-id
        let r4 = app.mockRun(["start", "--help"])
        @Assert(!r4.stderr.contains("internal-id"))
        @Assert(r4.stderr.contains("--port"))
    }
}
