// =============================================================================
// Phase 11 综合集成测试: cj-devtool 示例应用功能验收
//
// 使用 mockRun 沙箱全面测试示例应用，覆盖框架全部核心特性
// =============================================================================

internal package cli.test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import std.env.*
import cli.*

// ==================== Help & Version 测试 ====================

@Test
class ExampleHelpTest {
    @TestCase
    func testRootHelp() {
        let app = buildExampleApp()
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("cj-devtool"), true)
        @Expect(result.stderr.contains("A modern DevOps CLI tool"), true)
        @Expect(result.stderr.contains("serve"), true)
        @Expect(result.stderr.contains("deploy"), true)
        @Expect(result.stderr.contains("cloud"), true)
        @Expect(result.stderr.contains("lint"), true)
        @Expect(result.stderr.contains("config"), true)
    }

    @TestCase
    func testRootHelpShort() {
        let app = buildExampleApp()
        let result = app.mockRun(["-h"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("cj-devtool"), true)
    }

    @TestCase
    func testVersionFlag() {
        let app = buildExampleApp()
        let result = app.mockRun(["--version"])
        @Expect(result.exitCode, 0)
        @Expect(result.stdout.contains("1.0.0"), true)
    }

    @TestCase
    func testVersionShort() {
        let app = buildExampleApp()
        let result = app.mockRun(["-V"])
        @Expect(result.exitCode, 0)
        @Expect(result.stdout.contains("1.0.0"), true)
    }

    @TestCase
    func testSubcommandHelp() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("Start a development server"), true)
        @Expect(result.stderr.contains("--port"), true)
        @Expect(result.stderr.contains("--host"), true)
        @Expect(result.stderr.contains("Examples:"), true)
    }

    @TestCase
    func testDeepSubcommandHelp() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "list", "--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("List cloud instances"), true)
        @Expect(result.stderr.contains("--region"), true)
    }

    @TestCase
    func testHelpContainsSubcommandGroups() {
        let app = buildExampleApp()
        let result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("Server Commands"), true)
        @Expect(result.stderr.contains("Deploy Commands"), true)
        @Expect(result.stderr.contains("Cloud Commands"), true)
    }

    @TestCase
    func testHiddenCommandNotInHelp() {
        let app = buildExampleApp()
        let result = app.mockRun(["config", "--help"])
        @Expect(result.exitCode, 0)
        // debug 命令被标记为 hidden, 不应出现在帮助中
        @Expect(!result.stderr.contains("debug"), true)
        // 但 show 和 set 应可见
        @Expect(result.stderr.contains("show"), true)
        @Expect(result.stderr.contains("set"), true)
    }
}

// ==================== Serve 命令测试 ====================

@Test
class ExampleServeTest {
    @TestCase
    func testServeDefault() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testServeWithPort() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--port", "3000"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testServeAlias() {
        let app = buildExampleApp()
        let result = app.mockRun(["s", "--port", "3000"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testServeShortFlags() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "-p", "9090", "-H", "0.0.0.0"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testServeTlsRequiresCert() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--tls", "--cert", "cert.pem", "--key", "key.pem"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testServePortTypeError() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--port", "abc"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("port"), true)
    }
}

// ==================== Deploy 命令测试 ====================

@Test
class ExampleDeployTest {
    @TestCase
    func testDeployBasic() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "staging", "--tag", "v1.0.0"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDeployAlias() {
        let app = buildExampleApp()
        let result = app.mockRun(["d", "--env", "dev", "--tag", "v2.0.0"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDeployDryRun() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "production", "--tag", "v1.0.0", "--dry-run"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDeployConflictForceAndDryRun() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "staging", "--tag", "v1.0.0", "--force", "--dry-run"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("cannot be used together with"), true)
    }

    @TestCase
    func testDeployInvalidEnv() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "invalid", "--tag", "v1.0.0"])
        @Expect(result.exitCode != 0, true)
        // choices 校验失败
        @Expect(result.stderr.contains("dev") || result.stderr.contains("staging") || result.stderr.contains("production"), true)
    }

    @TestCase
    func testDeployMissingRequired() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy"])
        @Expect(result.exitCode != 0, true)
        // 缺少 --env 和 --tag
        @Expect(result.stderr.contains("env") || result.stderr.contains("tag"), true)
    }

    @TestCase
    func testDeployWithDelimiterNotify() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "dev", "--tag", "v1.0.0", "--notify", "slack,email,pager"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testDeployReplicasValidatorFail() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "dev", "--tag", "v1.0.0", "--replicas", "200"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("1-100"), true)
    }
}

// ==================== Cloud 子命令树测试 ====================

@Test
class ExampleCloudTest {
    @TestCase
    func testCloudHelp() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("list"), true)
        @Expect(result.stderr.contains("start"), true)
    }

    @TestCase
    func testCloudListDefault() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "list"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCloudListAlias() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "ls", "--region", "us-east"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCloudListInvalidRegion() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "list", "--region", "mars"])
        @Expect(result.exitCode != 0, true)
    }

    @TestCase
    func testCloudStartWithArg() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "start", "i-12345678"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCloudAlias() {
        let app = buildExampleApp()
        let result = app.mockRun(["c", "list"])
        @Expect(result.exitCode, 0)
    }
}

// ==================== Lint 命令测试 (Clippy 场景) ====================

@Test
class ExampleLintTest {
    @TestCase
    func testLintBasic() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "./src"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testLintAlias() {
        let app = buildExampleApp()
        let result = app.mockRun(["l"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testLintWithPassThrough() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "./src", "--", "--strict", "--max-warnings", "10"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testLintWithFix() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "--fix", "./src"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testLintOutputFormatRequiresOutput() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "--output-format", "json"])
        @Expect(result.exitCode != 0, true)
        // --output-format requires --output
        @Expect(result.stderr.contains("output"), true)
    }

    @TestCase
    func testLintOutputFormatChoices() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "--output", "report.txt", "--output-format", "xml"])
        @Expect(result.exitCode != 0, true)
        // xml 不在 choices 中
    }

    @TestCase
    func testLintHelpContainsExamples() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "--help"])
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("Examples:"), true)
        @Expect(result.stderr.contains("Lint current project"), true)
    }
}

// ==================== Config 命令测试 ====================

@Test
class ExampleConfigTest {
    @TestCase
    func testConfigShow() {
        let app = buildExampleApp()
        let result = app.mockRun(["config", "show"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testConfigSetWithArgs() {
        let app = buildExampleApp()
        let result = app.mockRun(["config", "set", "theme", "dark"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testConfigHiddenDebugStillWorks() {
        let app = buildExampleApp()
        let result = app.mockRun(["config", "debug"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testConfigDeprecatedInit() {
        let app = buildExampleApp()
        let result = app.mockRun(["config", "init"])
        // 弃用的命令仍能执行，但应有 warning
        @Expect(result.exitCode, 0)
        @Expect(result.stderr.contains("deprecated") || result.stderr.contains("Deprecated") || result.stderr.contains("warning") || result.stderr.contains("Warning"), true)
    }
}

// ==================== Did-You-Mean 诊断测试 ====================

@Test
class ExampleDiagnosticTest {
    @TestCase
    func testUnknownCommandSuggestion() {
        let app = buildExampleApp()
        let result = app.mockRun(["serv"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("serve"), true)
    }

    @TestCase
    func testUnknownFlagSuggestion() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--por"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("port"), true)
    }

    @TestCase
    func testDeployTypoEnv() {
        let app = buildExampleApp()
        let result = app.mockRun(["deplo", "--env", "staging", "--tag", "v1.0.0"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("deploy"), true)
    }

    @TestCase
    func testCloudTypoSubcommand() {
        let app = buildExampleApp()
        let result = app.mockRun(["cloud", "lst"])
        @Expect(result.exitCode != 0, true)
        @Expect(result.stderr.contains("list"), true)
    }
}

// ==================== 全局 Flag 与环境变量测试 ====================

@Test
class ExampleGlobalFlagTest {
    @TestCase
    func testGlobalVerboseFlag() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--verbose"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testGlobalFormatFlag() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--format", "json"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testGlobalColorChoices() {
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--color", "invalid"])
        @Expect(result.exitCode != 0, true)
    }

    @TestCase
    func testEnvPrefixMapping() {
        setVariable("DEVTOOL_PORT", "9999")
        let app = buildExampleApp()
        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 0)
        removeVariable("DEVTOOL_PORT")
    }

    @TestCase
    func testCliOverridesEnv() {
        setVariable("DEVTOOL_PORT", "9999")
        let app = buildExampleApp()
        let result = app.mockRun(["serve", "--port", "3000"])
        @Expect(result.exitCode, 0)
        removeVariable("DEVTOOL_PORT")
    }
}

// ==================== 信号处理测试 ====================

@Test
class ExampleSignalTest {
    @TestCase
    func testSignalInterruptInAction() {
        let handler = SignalHandler()
        let app = buildExampleApp().signalHandler(handler)
        // 在 action 执行前模拟 SIGINT
        handler.simulateSignal(SIGINT)
        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 130)
    }

    @TestCase
    func testSignalTermInAction() {
        let handler = SignalHandler()
        let app = buildExampleApp().signalHandler(handler)
        handler.simulateSignal(SIGTERM)
        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 143)
    }
}

// ==================== 端到端综合测试 ====================

@Test
class ExampleE2ETest {
    @TestCase
    func testFullWorkflow() {
        // 1. Help
        var app = buildExampleApp()
        var result = app.mockRun(["--help"])
        @Expect(result.exitCode, 0)

        // 2. 正常命令
        app = buildExampleApp()
        result = app.mockRun(["serve", "-p", "8080"])
        @Expect(result.exitCode, 0)

        // 3. 嵌套命令
        app = buildExampleApp()
        result = app.mockRun(["cloud", "list", "--region", "us-east"])
        @Expect(result.exitCode, 0)

        // 4. 错误恢复
        app = buildExampleApp()
        result = app.mockRun(["serv"])
        @Expect(result.exitCode != 0, true)
    }

    @TestCase
    func testDeployFullScenario() {
        let app = buildExampleApp()
        let result = app.mockRun(["deploy", "--env", "staging", "--tag", "v2.0.0", "--replicas", "3", "--notify", "slack,email"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testLintPassThroughScenario() {
        let app = buildExampleApp()
        let result = app.mockRun(["lint", "./src", "--fix", "--", "-W", "all", "--strict"])
        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testMultipleErrors() {
        let app = buildExampleApp()
        // deploy 缺少 --env 和 --tag
        let result = app.mockRun(["deploy"])
        @Expect(result.exitCode != 0, true)
    }

    @TestCase
    func testConfigFileIntegration() {
        let app = buildExampleApp()
        let configContent = "port = 9090\nhost = \"0.0.0.0\""
        let result = app.mockRunWithConfig(["serve"], configContent: Some(configContent))
        @Expect(result.exitCode, 0)
    }
}
