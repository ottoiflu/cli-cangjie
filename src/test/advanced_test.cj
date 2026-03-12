internal package cli.test

import std.unittest.*
import std.unittest.testmacro.*
import cli.*
import std.collection.*

// ==================== Shell 补全脚本生成测试 ====================

@Test
class BashCompletionTest {
    @TestCase
    func testBashBasicStructure() {
        let cmd = Command("myapp")
            .description("My app")
            .flag(Flag("verbose").short(r'v').description("Enable verbose").asBool())
            .flag(Flag("output").short(r'o').description("Output file"))
        let script = CompletionGenerator.generate(cmd, Bash)
        @Assert(script.contains("# Bash completion for myapp"))
        @Assert(script.contains("_myapp()"))
        @Assert(script.contains("_init_completion"))
        @Assert(script.contains("complete -F _myapp myapp"))
    }

    @TestCase
    func testBashWithSubcommands() {
        let cmd = Command("tool")
            .command(Command("lint").description("Run linter"))
            .command(Command("fix").description("Auto fix"))
        let script = CompletionGenerator.generate(cmd, Bash)
        @Assert(script.contains("lint)"))
        @Assert(script.contains("fix)"))
        @Assert(script.contains("lint fix"))
    }

    @TestCase
    func testBashHiddenExcluded() {
        let cmd = Command("app")
            .command(Command("visible").description("Visible cmd"))
            .command(Command("secret").description("Secret cmd").hidden())
            .flag(Flag("config").description("Config file"))
            .flag(Flag("debug").description("Debug mode").hidden())
        let script = CompletionGenerator.generate(cmd, Bash)
        @Assert(script.contains("visible"))
        @Assert(!script.contains("secret"))
        @Assert(script.contains("--config"))
        @Assert(!script.contains("--debug"))
    }

    @TestCase
    func testBashWithAliases() {
        let cmd = Command("pkg")
            .command(Command("install").alias("i").description("Install package"))
        let script = CompletionGenerator.generate(cmd, Bash)
        @Assert(script.contains("install|i)"))
    }

    @TestCase
    func testBashSpecialCharsInName() {
        let cmd = Command("my-tool")
            .flag(Flag("help").asBool())
        let script = CompletionGenerator.generate(cmd, Bash)
        @Assert(script.contains("_my_tool()"))
        @Assert(script.contains("complete -F _my_tool my-tool"))
    }
}

@Test
class ZshCompletionTest {
    @TestCase
    func testZshBasicStructure() {
        let cmd = Command("myapp")
            .flag(Flag("verbose").short(r'v').description("Enable verbose").asBool())
            .flag(Flag("output").description("Output file"))
        let script = CompletionGenerator.generate(cmd, Zsh)
        @Assert(script.contains("#compdef myapp"))
        @Assert(script.contains("_myapp()"))
        @Assert(script.contains("_arguments"))
        @Assert(script.contains("_myapp"))
    }

    @TestCase
    func testZshWithSubcommands() {
        let cmd = Command("tool")
            .command(Command("check").description("Run checks"))
            .command(Command("build").description("Build project"))
        let script = CompletionGenerator.generate(cmd, Zsh)
        @Assert(script.contains("_arguments -C"))
        @Assert(script.contains("'check:Run checks'"))
        @Assert(script.contains("'build:Build project'"))
        @Assert(script.contains("_describe 'command' commands"))
    }

    @TestCase
    func testZshFlagSpecs() {
        let cmd = Command("app")
            .flag(Flag("config").description("Config path"))
            .flag(Flag("debug").description("Debug mode").asBool())
        let script = CompletionGenerator.generate(cmd, Zsh)
        // 值类型 flag 用 =
        @Assert(script.contains("'--config="))
        // 布尔 flag 没有 =
        @Assert(script.contains("'--debug["))
    }

    @TestCase
    func testZshHiddenExcluded() {
        let cmd = Command("app")
            .command(Command("visible").description("Show"))
            .command(Command("hidden").description("Hide").hidden())
        let script = CompletionGenerator.generate(cmd, Zsh)
        @Assert(script.contains("visible"))
        @Assert(!script.contains("hidden"))
    }
}

@Test
class FishCompletionTest {
    @TestCase
    func testFishBasicStructure() {
        let cmd = Command("myapp")
            .flag(Flag("verbose").short(r'v').description("Enable verbose").asBool())
            .flag(Flag("output").short(r'o').description("Output file"))
        let script = CompletionGenerator.generate(cmd, Fish)
        @Assert(script.contains("# Fish completion for myapp"))
        @Assert(script.contains("complete -c myapp"))
        @Assert(script.contains("-l verbose"))
        @Assert(script.contains("-s v"))
        @Assert(script.contains("-l output"))
        @Assert(script.contains("-s o"))
    }

    @TestCase
    func testFishWithSubcommands() {
        let cmd = Command("tool")
            .command(Command("lint").description("Run linter"))
            .command(Command("fix").description("Auto fix"))
        let script = CompletionGenerator.generate(cmd, Fish)
        @Assert(script.contains("__fish_use_subcommand"))
        @Assert(script.contains("-a 'lint'"))
        @Assert(script.contains("-d 'Run linter'"))
        @Assert(script.contains("-a 'fix'"))
    }

    @TestCase
    func testFishSubcommandFlags() {
        let cmd = Command("tool")
            .command(
                Command("lint")
                    .description("Run linter")
                    .flag(Flag("fix").description("Auto fix").asBool())
            )
        let script = CompletionGenerator.generate(cmd, Fish)
        @Assert(script.contains("__fish_seen_subcommand_from lint"))
        @Assert(script.contains("-l fix"))
    }

    @TestCase
    func testFishRequiresArgument() {
        let cmd = Command("app")
            .flag(Flag("output").description("Output path"))
            .flag(Flag("debug").description("Debug mode").asBool())
        let script = CompletionGenerator.generate(cmd, Fish)
        // output 需要值: -r
        @Assert(script.contains("-l output -r"))
        // debug 是布尔: 不带 -r
        @Assert(!script.contains("-l debug -r"))
    }

    @TestCase
    func testFishAliases() {
        let cmd = Command("pkg")
            .command(Command("install").alias("i").description("Install"))
        let script = CompletionGenerator.generate(cmd, Fish)
        @Assert(script.contains("-a 'install'"))
        @Assert(script.contains("-a 'i'"))
    }

    @TestCase
    func testFishHiddenExcluded() {
        let cmd = Command("app")
            .command(Command("public").description("Public cmd"))
            .command(Command("internal").description("Internal").hidden())
            .flag(Flag("visible").description("Visible"))
            .flag(Flag("secret").description("Secret").hidden())
        let script = CompletionGenerator.generate(cmd, Fish)
        @Assert(script.contains("public"))
        @Assert(!script.contains("internal"))
        @Assert(script.contains("visible"))
        @Assert(!script.contains("secret"))
    }
}

@Test
class ShellTypeParsingTest {
    @TestCase
    func testParseShellType() {
        @Assert(parseShellType("bash").isSome())
        @Assert(parseShellType("zsh").isSome())
        @Assert(parseShellType("fish").isSome())
        @Assert(parseShellType("BASH").isSome())
        @Assert(parseShellType("Zsh").isSome())
        @Assert(parseShellType("unknown").isNone())
        @Assert(parseShellType("").isNone())
    }
}

// ==================== 输出格式模式测试 ====================

@Test
class OutputFormatTest {
    @TestCase
    func testParseOutputFormat() {
        @Assert(parseOutputFormat("text").isSome())
        @Assert(parseOutputFormat("json").isSome())
        @Assert(parseOutputFormat("TEXT").isSome())
        @Assert(parseOutputFormat("Json").isSome())
        @Assert(parseOutputFormat("xml").isNone())
        @Assert(parseOutputFormat("").isNone())
    }

    @TestCase
    func testJsonFormat() {
        let entries = ArrayList<(String, String)>()
        entries.add(("name", "myapp"))
        entries.add(("version", "1.0.0"))
        let json = OutputFormatter.toJson(entries)
        @Assert(json.contains("\"name\""))
        @Assert(json.contains("\"myapp\""))
        @Assert(json.contains("\"version\""))
        @Assert(json.contains("\"1.0.0\""))
    }

    @TestCase
    func testTextFormat() {
        let entries = ArrayList<(String, String)>()
        entries.add(("name", "myapp"))
        entries.add(("version", "1.0.0"))
        let text = OutputFormatter.toText(entries)
        @Assert(text.contains("name: myapp"))
        @Assert(text.contains("version: 1.0.0"))
    }

    @TestCase
    func testFormatDispatch() {
        let entries = ArrayList<(String, String)>()
        entries.add(("key", "value"))
        let text = OutputFormatter.format(entries, Text)
        @Assert(text.contains("key: value"))
        let json = OutputFormatter.format(entries, Json)
        @Assert(json.contains("\"key\""))
    }

    @TestCase
    func testJsonEscaping() {
        let entries = ArrayList<(String, String)>()
        entries.add(("msg", "hello \"world\""))
        let json = OutputFormatter.toJson(entries)
        @Assert(json.contains("\\\"world\\\""))
    }

    @TestCase
    func testTextCustomSeparator() {
        let entries = ArrayList<(String, String)>()
        entries.add(("k", "v"))
        let text = OutputFormatter.toText(entries, separator: " = ")
        @Assert(text.contains("k = v"))
    }
}

// ==================== 丰富版本信息测试 ====================

@Test
class VersionInfoTest {
    @TestCase
    func testShortString() {
        let info = VersionInfo().name("myapp").version("1.2.3")
        @Assert(info.shortString() == "myapp 1.2.3")
    }

    @TestCase
    func testStandardString() {
        let info = VersionInfo()
            .name("myapp")
            .version("1.2.3")
            .commitHash("abc1234def")
            .commitDate("2024-06-15")
        @Assert(info.toString() == "myapp 1.2.3 (abc1234def 2024-06-15)")
    }

    @TestCase
    func testStandardStringNoGit() {
        let info = VersionInfo().name("myapp").version("1.0.0")
        @Assert(info.toString() == "myapp 1.0.0")
    }

    @TestCase
    func testStandardStringHashOnly() {
        let info = VersionInfo()
            .name("tool")
            .version("0.1.0")
            .commitHash("deadbeef")
        @Assert(info.toString() == "tool 0.1.0 (deadbeef)")
    }

    @TestCase
    func testStandardStringDateOnly() {
        let info = VersionInfo()
            .name("tool")
            .version("0.1.0")
            .commitDate("2024-01-01")
        @Assert(info.toString() == "tool 0.1.0 (2024-01-01)")
    }

    @TestCase
    func testVerboseString() {
        let info = VersionInfo()
            .name("myapp")
            .version("1.0.0")
            .commitHash("abc123")
            .commitDate("2024-01-01")
            .buildDate("2024-01-02")
            .compiler("cjc 1.1.0")
        let verbose = info.verboseString()
        @Assert(verbose.contains("myapp 1.0.0"))
        @Assert(verbose.contains("commit: abc123"))
        @Assert(verbose.contains("commit-date: 2024-01-01"))
        @Assert(verbose.contains("build-date: 2024-01-02"))
        @Assert(verbose.contains("compiler: cjc 1.1.0"))
    }

    @TestCase
    func testExtraMetadata() {
        let info = VersionInfo()
            .name("app")
            .version("1.0.0")
            .extra("platform", "linux-x64")
            .extra("profile", "release")
        let verbose = info.verboseString()
        @Assert(verbose.contains("platform: linux-x64"))
        @Assert(verbose.contains("profile: release"))
    }

    @TestCase
    func testToEntries() {
        let info = VersionInfo()
            .name("app")
            .version("2.0.0")
            .commitHash("xyz789")
        let entries = info.toEntries()
        @Assert(entries.size == 3)
        @Assert(entries[0][0] == "name")
        @Assert(entries[0][1] == "app")
        @Assert(entries[2][0] == "commit-hash")
        @Assert(entries[2][1] == "xyz789")
    }

    @TestCase
    func testVersionInfoInApp() {
        let info = VersionInfo()
            .name("mytool")
            .version("3.0.0")
            .commitHash("aabbccdd")
            .commitDate("2024-12-01")

        let app = App("mytool")
            .version("3.0.0")
            .versionInfo(info)

        let result = app.mockRun(["--version"])
        @Assert(result.exitCode == 0)
        @Assert(result.stdout.contains("mytool 3.0.0"))
        @Assert(result.stdout.contains("aabbccdd"))
        @Assert(result.stdout.contains("2024-12-01"))
    }
}

// ==================== 弃用系统测试 ====================

@Test
class DeprecationInfoTest {
    @TestCase
    func testBasicDeprecation() {
        let info = DeprecationInfo("This feature will be removed.")
        @Assert(info.getReason() == "This feature will be removed.")
        @Assert(info.getReplacement().isNone())
        @Assert(info.getSince().isNone())
    }

    @TestCase
    func testDeprecationWithReplacement() {
        let info = DeprecationInfo("Superseded.", "--new-flag")
        @Assert(info.getReplacement().isSome())
        let msg = info.formatWarning("flag", "--old-flag")
        @Assert(msg.contains("deprecated"))
        @Assert(msg.contains("--old-flag"))
        @Assert(msg.contains("Superseded."))
        @Assert(msg.contains("Use '--new-flag' instead."))
    }

    @TestCase
    func testDeprecationWithSince() {
        let info = DeprecationInfo("Removed in next major.", "--new", "v2.0.0")
        let msg = info.formatWarning("command", "old-cmd")
        @Assert(msg.contains("since v2.0.0"))
        @Assert(msg.contains("'old-cmd'"))
    }

    @TestCase
    func testDeprecationCollector() {
        let collector = DeprecationCollector()
        @Assert(!collector.hasWarnings())
        collector.add("warning: flag '--old' is deprecated.")
        collector.add("warning: command 'legacy' is deprecated.")
        @Assert(collector.hasWarnings())
        @Assert(collector.getWarnings().size == 2)
        let output = collector.formatAll()
        @Assert(output.contains("--old"))
        @Assert(output.contains("legacy"))
    }
}

@Test
class DeprecatedFlagTest {
    @TestCase
    func testDeprecatedFlagWarning() {
        let app = App("myapp")
            .flag(Flag("old-flag").description("Deprecated").deprecated("Use new-flag.", replacement: "--new-flag"))
            .flag(Flag("new-flag").description("New flag"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--old-flag", "value"])
        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("deprecated"))
        @Assert(result.stderr.contains("--old-flag"))
        @Assert(result.stderr.contains("--new-flag"))
    }

    @TestCase
    func testDeprecatedFlagNoWarningIfNotUsed() {
        let app = App("myapp")
            .flag(Flag("old-flag").description("Old").defaultValue("x").deprecated("Gone."))
            .flag(Flag("new-flag").description("New"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--new-flag", "val"])
        @Assert(result.exitCode == 0)
        // 未使用弃用标志 -> 不应有弃用警告
        @Assert(!result.stderr.contains("deprecated"))
    }

    @TestCase
    func testDeprecatedFlagWithSince() {
        let app = App("myapp")
            .flag(Flag("legacy").description("Legacy").deprecatedSince("Removed.", "--modern", "v2.0"))
            .flag(Flag("modern").description("Modern"))
            .action({ ctx => 0 })
        let result = app.mockRun(["--legacy", "val"])
        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("since v2.0"))
    }
}

@Test
class DeprecatedCommandTest {
    @TestCase
    func testDeprecatedCommandWarning() {
        let app = App("myapp")
            .command(
                Command("old-cmd")
                    .description("Old command")
                    .deprecated("Replaced.", replacement: "new-cmd")
                    .action({ ctx => 0 })
            )
            .command(
                Command("new-cmd")
                    .description("New command")
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["old-cmd"])
        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("deprecated"))
        @Assert(result.stderr.contains("old-cmd"))
        @Assert(result.stderr.contains("new-cmd"))
    }

    @TestCase
    func testNonDeprecatedCommandNoWarning() {
        let app = App("myapp")
            .command(
                Command("new-cmd")
                    .description("New command")
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["new-cmd"])
        @Assert(result.exitCode == 0)
        @Assert(!result.stderr.contains("deprecated"))
    }
}

// ==================== 全局标志传播测试 ====================

@Test
class GlobalFlagPropagationTest {
    @TestCase
    func testGlobalFlagAccessInSubcommand() {
        let app = App("myapp")
            .globalFlag(Flag("verbose").short(r'v').description("Verbose").asBool())
            .command(
                Command("sub")
                    .description("Sub command")
                    .action({ ctx =>
                        if (ctx.getBoolFlag("verbose")) { 0 } else { 1 }
                    })
            )
        let result = app.mockRun(["--verbose", "sub"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testGlobalFlagDefaultInSubcommand() {
        let app = App("myapp")
            .globalFlag(Flag("color").description("Color mode").defaultValue("auto"))
            .command(
                Command("sub")
                    .description("Sub")
                    .action({ ctx =>
                        match (ctx.getFlag("color")) {
                            case Some(v) where v == "auto" => 0
                            case _ => 1
                        }
                    })
            )
        let result = app.mockRun(["sub"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testGlobalFlagInHelp() {
        let app = App("myapp")
            .globalFlag(Flag("verbose").short(r'v').description("Enable verbose output").asBool())
            .command(
                Command("sub")
                    .description("Sub command")
                    .flag(Flag("local").description("Local flag"))
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["sub", "--help"])
        @Assert(result.exitCode == 0)
        // 全局 flag 应该出现在子命令的帮助中
        @Assert(result.stderr.contains("--verbose"))
        @Assert(result.stderr.contains("--local"))
    }

    @TestCase
    func testGlobalFlagNoDuplicate() {
        // 如果子命令已有同名 flag，不应重复注册
        let app = App("myapp")
            .globalFlag(Flag("verbose").description("Global verbose").asBool())
            .command(
                Command("sub")
                    .description("Sub")
                    .flag(Flag("verbose").description("Local verbose").asBool())
                    .action({ ctx => 0 })
            )
        let result = app.mockRun(["sub", "--verbose"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testMultipleGlobalFlags() {
        let app = App("myapp")
            .globalFlags([
                Flag("verbose").short(r'v').description("Verbose").asBool(),
                Flag("quiet").short(r'q').description("Quiet").asBool()
            ])
            .command(
                Command("run")
                    .description("Run")
                    .action({ ctx =>
                        if (ctx.getBoolFlag("verbose") && !ctx.getBoolFlag("quiet")) { 0 } else { 1 }
                    })
            )
        let result = app.mockRun(["--verbose", "run"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testGlobalFlagDeepNesting() {
        let app = App("myapp")
            .globalFlag(Flag("debug").description("Debug").asBool())
            .command(
                Command("cloud")
                    .description("Cloud ops")
                    .command(
                        Command("server")
                            .description("Server ops")
                            .command(
                                Command("start")
                                    .description("Start server")
                                    .action({ ctx =>
                                        if (ctx.getBoolFlag("debug")) { 0 } else { 1 }
                                    })
                            )
                    )
            )
        let result = app.mockRun(["--debug", "cloud", "server", "start"])
        @Assert(result.exitCode == 0)
    }
}

// ==================== 集成测试 ====================

@Test
class Phase8IntegrationTest {
    @TestCase
    func testCompletionWithGlobalAndLocalFlags() {
        let cmd = Command("tool")
            .flag(Flag("verbose").short(r'v').description("Verbose").asBool())
            .command(
                Command("build")
                    .description("Build project")
                    .flag(Flag("target").short(r't').description("Build target"))
            )
        // 验证 Bash 补全包含全局和局部 flags
        let bash = CompletionGenerator.generate(cmd, Bash)
        @Assert(bash.contains("--verbose"))
        // Zsh
        let zsh = CompletionGenerator.generate(cmd, Zsh)
        @Assert(zsh.contains("--verbose"))
        @Assert(zsh.contains("build"))
        // Fish
        let fish = CompletionGenerator.generate(cmd, Fish)
        @Assert(fish.contains("-l verbose"))
        @Assert(fish.contains("-l target"))
    }

    @TestCase
    func testVersionInfoWithJsonFormat() {
        let info = VersionInfo()
            .name("myapp")
            .version("1.0.0")
            .commitHash("abc123")
        let entries = info.toEntries()
        let json = OutputFormatter.toJson(entries)
        @Assert(json.contains("\"name\": \"myapp\""))
        @Assert(json.contains("\"version\": \"1.0.0\""))
        @Assert(json.contains("\"commit-hash\": \"abc123\""))
    }

    @TestCase
    func testDeprecatedFlagWithAction() {
        var usedNew = false
        let app = App("myapp")
            .flag(Flag("old").description("Old way").deprecated("Use --new.", replacement: "--new"))
            .flag(Flag("new").description("New way"))
            .action({ ctx =>
                match (ctx.getFlag("old")) {
                    case Some(_) => 0
                    case None => 1
                }
            })
        let result = app.mockRun(["--old", "value"])
        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("deprecated"))
    }

    @TestCase
    func testGlobalFlagWithEnvVar() {
        let app = App("myapp")
            .envPrefix("MYAPP")
            .globalFlag(Flag("log-level").description("Log level").defaultValue("info"))
            .command(
                Command("run")
                    .description("Run")
                    .action({ ctx =>
                        match (ctx.getFlag("log-level")) {
                            case Some(v) where v == "info" => 0
                            case _ => 1
                        }
                    })
            )
        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testAllThreeShellTypes() {
        let cmd = Command("app")
            .flag(Flag("config").short(r'c').description("Config path"))
            .command(Command("init").description("Initialize project"))
        let bash = CompletionGenerator.generate(cmd, Bash)
        let zsh = CompletionGenerator.generate(cmd, Zsh)
        let fish = CompletionGenerator.generate(cmd, Fish)
        // 每种 shell 都应该生成非空脚本
        @Assert(bash.size > 50)
        @Assert(zsh.size > 50)
        @Assert(fish.size > 50)
        // 每种形式都应该包含 config 和 init
        @Assert(bash.contains("--config"))
        @Assert(zsh.contains("--config"))
        @Assert(fish.contains("config"))
        @Assert(bash.contains("init"))
        @Assert(zsh.contains("init"))
        @Assert(fish.contains("init"))
    }
}
