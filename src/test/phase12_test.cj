// =============================================================================
// Phase 12: clap 对标特性测试
//
// 测试 FlagAction.Count, ValueHint, valueName, subcommandRequired,
// argRequiredElseHelp, longHelp/longAbout, envVar 帮助显示, 补全增强
// =============================================================================

internal package cli.test

import std.unittest.*
import std.unittest.testmacro.*
import cli.*

// ==================== FlagAction.Count 测试 ====================

@Test
class FlagCountTest {
    @TestCase
    func testCountSingleOccurrence() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("1"))
                0
            })
        let result = app.mockRun(["--verbose"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountMultipleLong() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("3"))
                0
            })
        let result = app.mockRun(["--verbose", "--verbose", "--verbose"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountMultipleShort() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("3"))
                0
            })
        let result = app.mockRun(["-v", "-v", "-v"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountCompositeShortFlags() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("3"))
                0
            })
        let result = app.mockRun(["-vvv"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountDefaultZero() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("0"))
                0
            })
        let result = app.mockRun([])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountMixedLongShort() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("4"))
                0
            })
        let result = app.mockRun(["-v", "--verbose", "-vv"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountWithOtherFlags() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .flag(Flag("quiet").short(r'q').action(SetTrue))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("2"))
                @Expect(ctx.getFlag("quiet"), Some("true"))
                0
            })
        let result = app.mockRun(["-v", "-q", "-v"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountCompositeWithBoolFlag() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').action(Count))
            .flag(Flag("quiet").short(r'q').action(SetTrue))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("2"))
                @Expect(ctx.getFlag("quiet"), Some("true"))
                0
            })
        let result = app.mockRun(["-vqv"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCountNotShownAsValueInHelp() {
        let app = App("tool")
            .flag(Flag("verbose").short(r'v').description("Increase verbosity").action(Count))
            .action({ _ => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        // Count flag 不应显示 <VALUE>
        @Expect(result.stderr.contains("<VALUE>") && result.stderr.contains("verbose"), false)
        @Expect(result.stderr.contains("Increase verbosity"), true)
    }

    @TestCase
    func testCountIsCountMethod() {
        let f = Flag("verbose").action(Count)
        @Expect(f.isCount(), true)
        let f2 = Flag("name")
        @Expect(f2.isCount(), false)
        let f3 = Flag("debug").action(SetTrue)
        @Expect(f3.isCount(), false)
    }
}

// ==================== ValueHint 测试 ====================

@Test
class ValueHintTest {
    @TestCase
    func testValueHintDefault() {
        let f = Flag("name")
        let isDefault = match (f.getValueHint()) { case Default => true; case _ => false }
        @Expect(isDefault, true)
    }

    @TestCase
    func testValueHintFilePath() {
        let f = Flag("input").valueHint(FilePath)
        let isFilePath = match (f.getValueHint()) { case FilePath => true; case _ => false }
        @Expect(isFilePath, true)
    }

    @TestCase
    func testValueHintDirPath() {
        let f = Flag("output-dir").valueHint(DirPath)
        let isDirPath = match (f.getValueHint()) { case DirPath => true; case _ => false }
        @Expect(isDirPath, true)
    }

    @TestCase
    func testValueHintUrl() {
        let f = Flag("endpoint").valueHint(Url)
        let isUrl = match (f.getValueHint()) { case Url => true; case _ => false }
        @Expect(isUrl, true)
    }

    @TestCase
    func testValueHintInZshCompletion() {
        let cmd = Command("tool")
            .flag(Flag("input").short(r'i').description("Input file").valueHint(FilePath))
            .flag(Flag("output-dir").short(r'o').description("Output dir").valueHint(DirPath))
        let script = CompletionGenerator.generate(cmd, Zsh)
        @Expect(script.contains("_files"), true)
        @Expect(script.contains("_directories"), true)
    }

    @TestCase
    func testValueHintInFishCompletion() {
        let cmd = Command("tool")
            .flag(Flag("input").short(r'i').description("Input file").valueHint(FilePath))
        let script = CompletionGenerator.generate(cmd, Fish)
        @Expect(script.contains("-F"), true)
    }
}

// ==================== valueName (值占位符) 测试 ====================

@Test
class ValueNameTest {
    @TestCase
    func testCustomValueName() {
        let f = Flag("output").valueName("FILE")
        @Expect(f.getValuePlaceholder(), "<FILE>")
    }

    @TestCase
    func testValueNameInHelp() {
        let app = App("tool")
            .flag(Flag("output").short(r'o').description("Output file").valueName("FILE"))
            .action({ _ => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("<FILE>"), true)
    }

    @TestCase
    func testValueNameOverridesChoicesDisplay() {
        let f = Flag("format").valueName("FMT").choices(["json", "text"])
        @Expect(f.getValuePlaceholder(), "<FMT>")
    }

    @TestCase
    func testDefaultValuePlaceholderWithChoices() {
        let f = Flag("format").choices(["json", "text"])
        @Expect(f.getValuePlaceholder(), "<json|text>")
    }

    @TestCase
    func testDefaultValuePlaceholder() {
        let f = Flag("name")
        @Expect(f.getValuePlaceholder(), "<VALUE>")
    }
}

// ==================== subcommandRequired 测试 ====================

@Test
class SubcommandRequiredTest {
    @TestCase
    func testSubcommandRequiredShowsError() {
        let app = App("tool")
            .subcommandRequired()
            .command(Command("serve").description("Start server").action({ _ => 0 }))
            .command(Command("build").description("Build project").action({ _ => 0 }))
        let result = app.mockRun([])
        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("requires a subcommand"), true)
    }

    @TestCase
    func testSubcommandRequiredPassesWithSubcommand() {
        let app = App("tool")
            .subcommandRequired()
            .command(Command("serve").description("Start server").action({ _ => 0 }))
        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testSubcommandRequiredGetter() {
        let cmd = Command("tool").subcommandRequired()
        @Expect(cmd.isSubcommandRequired(), true)
        let cmd2 = Command("tool2")
        @Expect(cmd2.isSubcommandRequired(), false)
    }
}

// ==================== argRequiredElseHelp 测试 ====================

@Test
class ArgRequiredElseHelpTest {
    @TestCase
    func testArgRequiredElseHelpShowsHelp() {
        let app = App("tool")
            .argRequiredElseHelp()
            .flag(Flag("output").short(r'o').description("Output file"))
            .action({ _ => 0 })
        let result = app.mockRun([])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("Usage:"), true)
    }

    @TestCase
    func testArgRequiredElseHelpPassesWithFlag() {
        let app = App("tool")
            .argRequiredElseHelp()
            .flag(Flag("output").short(r'o').description("Output file"))
            .action({ _ => 0 })
        let result = app.mockRun(["--output", "out.txt"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("Usage:"), false)
    }

    @TestCase
    func testArgRequiredElseHelpGetter() {
        let cmd = Command("tool").argRequiredElseHelp()
        @Expect(cmd.isArgRequiredElseHelp(), true)
        let cmd2 = Command("tool2")
        @Expect(cmd2.isArgRequiredElseHelp(), false)
    }
}

// ==================== longHelp / longAbout 测试 ====================

@Test
class LongHelpTest {
    @TestCase
    func testFlagLongHelp() {
        let f = Flag("verbose").longHelp("Enable verbose output with detailed logging information")
        @Expect(f.getLongHelp().isSome(), true)
    }

    @TestCase
    func testCommandLongAbout() {
        let cmd = Command("serve").longAbout("Start the development server with hot reloading support")
        @Expect(cmd.getLongAbout().isSome(), true)
    }

    @TestCase
    func testFlagLongHelpDefault() {
        let f = Flag("name")
        @Expect(f.getLongHelp().isNone(), true)
    }

    @TestCase
    func testCommandLongAboutDefault() {
        let cmd = Command("serve")
        @Expect(cmd.getLongAbout().isNone(), true)
    }
}

// ==================== envVar 帮助显示测试 ====================

@Test
class EnvVarHelpDisplayTest {
    @TestCase
    func testEnvVarShownInHelp() {
        let app = App("tool")
            .flag(Flag("port").short(r'p').description("Server port").envVar("APP_PORT"))
            .action({ _ => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("[env: APP_PORT]"), true)
    }

    @TestCase
    func testNoEnvVarNotShownInHelp() {
        let app = App("tool")
            .flag(Flag("port").short(r'p').description("Server port"))
            .action({ _ => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("[env:"), false)
    }
}

// ==================== allowHyphenValues 测试 ====================

@Test
class AllowHyphenValuesTest {
    @TestCase
    func testAllowHyphenValuesBuilder() {
        let f = Flag("offset").allowHyphenValues()
        @Expect(f.getAllowHyphenValues(), true)
    }

    @TestCase
    func testAllowHyphenValuesDefault() {
        let f = Flag("offset")
        @Expect(f.getAllowHyphenValues(), false)
    }

    @TestCase
    func testNegativeValueWithLongFlag() {
        let app = App("tool")
            .flag(Flag("offset").short(r'o').valueType(Int64Type).allowHyphenValues())
            .action({ ctx =>
                @Expect(ctx.getFlag("offset"), Some("-5"))
                0
            })
        let result = app.mockRun(["--offset", "-5"])
        @Expect(result.exitCode, 0)
    }
}

// ==================== hasAnyExplicit 测试 ====================

@Test
class ContextExplicitTest {
    @TestCase
    func testHasAnyExplicitTrue() {
        let ctx = Context()
        ctx.setFlag("name", "value")
        ctx.markExplicit("name")
        @Expect(ctx.hasAnyExplicit(), true)
    }

    @TestCase
    func testHasAnyExplicitFalse() {
        let ctx = Context()
        @Expect(ctx.hasAnyExplicit(), false)
    }
}

// ==================== 综合集成测试 ====================

@Test
class Phase12IntegrationTest {
    @TestCase
    func testVerbosityLevels() {
        // 模拟 -v, -vv, -vvv 不同日志级别
        let app = App("logger")
            .flag(Flag("verbose").short(r'v').description("Increase verbosity").action(Count))
            .action({ ctx =>
                let level = match (ctx.getFlag("verbose")) {
                    case Some(v) => parseSimpleInt(v)
                    case None => 0
                }
                @Expect(level >= 0, true)
                0
            })

        // 无 -v → 0
        let r0 = app.mockRun([])
        @Expect(r0.exitCode, 0)

        // -v → 1
        let app1 = App("logger")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("1"))
                0
            })
        let r1 = app1.mockRun(["-v"])
        @Expect(r1.exitCode, 0)

        // -vvv → 3
        let app3 = App("logger")
            .flag(Flag("verbose").short(r'v').action(Count))
            .action({ ctx =>
                @Expect(ctx.getFlag("verbose"), Some("3"))
                0
            })
        let r3 = app3.mockRun(["-vvv"])
        @Expect(r3.exitCode, 0)
    }

    @TestCase
    func testCountWithSubcommands() {
        let app = App("tool")
            .globalFlag(Flag("verbose").short(r'v').description("Verbosity").action(Count))
            .command(
                Command("serve")
                    .description("Start server")
                    .action({ ctx =>
                        @Expect(ctx.getFlag("verbose"), Some("2"))
                        0
                    })
            )
        let result = app.mockRun(["-vv", "serve"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testValueNameWithChoicesInHelp() {
        let app = App("tool")
            .flag(Flag("format").short(r'f').description("Output format").valueName("FMT").choices(["json", "text", "yaml"]))
            .action({ _ => 0 })
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        // valueName 应覆盖 choices 的显示
        @Expect(result.stderr.contains("<FMT>"), true)
    }

    @TestCase
    func testSubcommandRequiredWithHelpStillWorks() {
        let app = App("tool")
            .subcommandRequired()
            .command(Command("serve").description("Start server").action({ _ => 0 }))
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("serve"), true)
    }

    @TestCase
    func testCompletionWithCountFlag() {
        let cmd = Command("tool")
            .flag(Flag("verbose").short(r'v').description("Verbosity").action(Count))
        let bashScript = CompletionGenerator.generate(cmd, Bash)
        @Expect(bashScript.contains("--verbose"), true)

        let zshScript = CompletionGenerator.generate(cmd, Zsh)
        // Count flag 不应有 "=[" (非值型)
        @Expect(zshScript.contains("--verbose=["), false)
        @Expect(zshScript.contains("--verbose["), true)
    }
}
