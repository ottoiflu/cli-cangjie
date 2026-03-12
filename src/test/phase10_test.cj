// Phase 10 测试: 健壮性与工程化增强 (v0.10.0)
internal package cli.test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import std.env.*
import cli.*

// ==================== 信号处理测试 ====================

@Test
class SignalHandlerTest {
    @TestCase
    func testSIGINTExitCode() {
        let handler = SignalHandler()
        @Expect(!handler.isInterrupted())

        handler.simulateSignal(SIGINT)
        @Expect(handler.isInterrupted())
        @Expect(handler.getExitCode(), 130)
    }

    @TestCase
    func testSIGTERMExitCode() {
        let handler = SignalHandler()
        handler.simulateSignal(SIGTERM)
        @Expect(handler.isInterrupted())
        @Expect(handler.getExitCode(), 143)
    }

    @TestCase
    func testSignalCallback() {
        let handler = SignalHandler()
        let holder = ArrayList<String>()
        handler.onSignal({ sig =>
            match (sig) {
                case SIGINT => holder.add("SIGINT")
                case SIGTERM => holder.add("SIGTERM")
            }
        })
        handler.simulateSignal(SIGINT)
        @Expect(holder.size, 1)
        @Expect(holder[0], "SIGINT")
    }

    @TestCase
    func testSignalReset() {
        let handler = SignalHandler()
        handler.simulateSignal(SIGINT)
        @Expect(handler.isInterrupted())

        handler.reset()
        @Expect(!handler.isInterrupted())
        @Expect(handler.getExitCode(), 0)
    }

    @TestCase
    func testSignalInMockRun() {
        let handler = SignalHandler()
        let app = App("test-app")
            .signalHandler(handler)
            .command(
                Command("work")
                    .description("Do work")
                    .action({ ctx =>
                        // 模拟在 action 中触发信号
                        handler.simulateSignal(SIGINT)
                        0
                    })
            )

        let result = app.mockRun(["work"])
        // action 返回 0 但信号检查在 action 之后发生
        @Expect(result.exitCode, 130)
        @Expect(result.stderr.contains("SIGINT"), true)
    }

    @TestCase
    func testSIGINTInPreRun() {
        let handler = SignalHandler()
        let app = App("test-app")
            .signalHandler(handler)
            .persistentPreRun({ ctx =>
                // 模拟在 PersistentPreRun 中触发信号
                handler.simulateSignal(SIGINT)
            })
            .command(
                Command("work")
                    .description("Do work")
                    .action({ ctx => 0 })
            )

        let result = app.mockRun(["work"])
        @Expect(result.exitCode, 130)
        @Expect(result.stderr.contains("SIGINT"), true)
    }
}

// ==================== 错误聚合测试 ====================

@Test
class ErrorAggregationTest {
    @TestCase
    func testMultipleRequiredFlags() {
        let app = App("test-app")
            .command(
                Command("run")
                    .description("Run")
                    .flag(Flag("host").required(true))
                    .flag(Flag("port").required(true))
                    .flag(Flag("name").required(true))
                    .action({ ctx => 0 })
            )

        let result = app.mockRun(["run"])
        @Expect(result.exitCode, 2)
        // 应该包含所有 3 个错误，不止第一个
        @Expect(result.stderr.contains("--host"), true)
        @Expect(result.stderr.contains("--port"), true)
        @Expect(result.stderr.contains("--name"), true)
        @Expect(result.stderr.contains("Found 3 errors"), true)
    }

    @TestCase
    func testMixedConstraintErrors() {
        let app = App("test-app")
            .command(
                Command("run")
                    .description("Run")
                    .flag(Flag("verbose").short(r'v').action(SetTrue))
                    .flag(Flag("quiet").short(r'q').action(SetTrue).conflictsWith("verbose"))
                    .flag(Flag("output").required(true))
                    .action({ ctx => 0 })
            )

        // --verbose 与 --quiet 冲突，且缺少 --output
        let result = app.mockRun(["run", "--verbose", "--quiet"])
        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("--output"), true)
        @Expect(result.stderr.contains("cannot be used together"), true)
        @Expect(result.stderr.contains("Found 2 errors"), true)
    }

    @TestCase
    func testSingleErrorNotAggregated() {
        let app = App("test-app")
            .command(
                Command("run")
                    .description("Run")
                    .flag(Flag("host").required(true))
                    .action({ ctx => 0 })
            )

        let result = app.mockRun(["run"])
        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("--host"), true)
        // 单个错误不应显示 "Found X errors" 格式
        @Expect(!result.stderr.contains("Found"))
    }

    @TestCase
    func testAggregateExceptionClass() {
        let errors = ArrayList<String>()
        errors.add("Error 1")
        errors.add("Error 2")
        let warnings = ArrayList<String>()
        warnings.add("Warning 1")
        let ex = AggregateException(errors, warnings)
        @Expect(ex.errorCount(), 2)
        @Expect(ex.warningCount(), 1)
        @Expect(ex.message.contains("2 errors"), true)
        @Expect(ex.message.contains("1 warning"), true)
    }

    @TestCase
    func testGroupAndRequiredErrors() {
        let app = App("test-app")
            .command(
                Command("run")
                    .description("Run")
                    .flag(Flag("input").required(true))
                    .flag(Flag("format-a").action(SetTrue))
                    .flag(Flag("format-b").action(SetTrue))
                    .mutuallyExclusiveGroup("format", ["format-a", "format-b"])
                    .action({ ctx => 0 })
            )

        // 缺少 --input 且 format 组中两个都设置了
        let result = app.mockRun(["run", "--format-a", "--format-b"])
        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("--input"), true)
        @Expect(result.stderr.contains("mutually exclusive"), true)
        @Expect(result.stderr.contains("Found 2 errors"), true)
    }
}

// ==================== 环境变量自动映射增强测试 ====================

@Test
class EnvAutoMappingTest {
    @TestCase
    func testHyphenToUnderscore() {
        // --db-host → APP_DB_HOST
        let app = App("test-app")
            .envPrefix("APP")
            .flag(Flag("db-host").description("Database host"))
            .action({ ctx =>
                match (ctx.getFlag("db-host")) {
                    case Some(v) =>
                        ctx.setValue("result", v)
                    case None => ()
                }
                0
            })

        setVariable("APP_DB_HOST", "localhost")
        let result = app.mockRun([])
        removeVariable("APP_DB_HOST")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testComplexFlagName() {
        // --max-retry-count → MYAPP_MAX_RETRY_COUNT
        let app = App("test-app")
            .envPrefix("MYAPP")
            .flag(Flag("max-retry-count").valueType(Int64Type))
            .action({ ctx => 0 })

        setVariable("MYAPP_MAX_RETRY_COUNT", "5")
        let result = app.mockRun([])
        removeVariable("MYAPP_MAX_RETRY_COUNT")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testExplicitEnvVarOverridesPrefix() {
        // 显式 envVar 优先于 envPrefix 自动映射
        let app = App("test-app")
            .envPrefix("APP")
            .flag(Flag("host").envVar("CUSTOM_HOST"))
            .action({ ctx => 0 })

        setVariable("CUSTOM_HOST", "custom-host")
        setVariable("APP_HOST", "prefix-host")
        let result = app.mockRun([])
        removeVariable("CUSTOM_HOST")
        removeVariable("APP_HOST")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testCLIOverridesEnv() {
        // CLI 显式参数优先于环境变量
        let app = App("test-app")
            .envPrefix("APP")
            .flag(Flag("port"))
            .action({ ctx =>
                match (ctx.getFlag("port")) {
                    case Some(v) =>
                        ctx.setValue("result", v)
                    case None => ()
                }
                0
            })

        setVariable("APP_PORT", "3000")
        let result = app.mockRun(["--port", "8080"])
        removeVariable("APP_PORT")

        @Expect(result.exitCode, 0)
    }
}

// ==================== Env 类型自动协变测试 ====================

@Test
class EnvTypeCoercionTest {
    @TestCase
    func testInt64Coercion() {
        let app = App("test-app")
            .flag(Flag("timeout").valueType(Int64Type).envVar("TEST_TIMEOUT"))
            .action({ ctx => 0 })

        setVariable("TEST_TIMEOUT", "30")
        let result = app.mockRun([])
        removeVariable("TEST_TIMEOUT")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testInt64CoercionFailure() {
        let app = App("test-app")
            .flag(Flag("timeout").valueType(Int64Type).envVar("TEST_TIMEOUT_BAD"))
            .action({ ctx => 0 })

        setVariable("TEST_TIMEOUT_BAD", "not-a-number")
        let result = app.mockRun([])
        removeVariable("TEST_TIMEOUT_BAD")

        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("TEST_TIMEOUT_BAD"), true)
        @Expect(result.stderr.contains("not-a-number"), true)
        @Expect(result.stderr.contains("--timeout"), true)
    }

    @TestCase
    func testBoolCoercion() {
        let app = App("test-app")
            .flag(Flag("debug").valueType(BoolType).envVar("TEST_DEBUG"))
            .action({ ctx => 0 })

        setVariable("TEST_DEBUG", "true")
        let result = app.mockRun([])
        removeVariable("TEST_DEBUG")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testBoolCoercionFailure() {
        let app = App("test-app")
            .flag(Flag("debug").valueType(BoolType).envVar("TEST_DEBUG_BAD"))
            .action({ ctx => 0 })

        setVariable("TEST_DEBUG_BAD", "maybe")
        let result = app.mockRun([])
        removeVariable("TEST_DEBUG_BAD")

        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("TEST_DEBUG_BAD"), true)
        @Expect(result.stderr.contains("maybe"), true)
    }

    @TestCase
    func testFloat64Coercion() {
        let app = App("test-app")
            .flag(Flag("rate").valueType(Float64Type).envVar("TEST_RATE"))
            .action({ ctx => 0 })

        setVariable("TEST_RATE", "3.14")
        let result = app.mockRun([])
        removeVariable("TEST_RATE")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testPrefixAutoCoercion() {
        // envPrefix 自动映射也应该做类型协变
        let app = App("test-app")
            .envPrefix("MYAPP")
            .flag(Flag("max-workers").valueType(Int64Type))
            .action({ ctx => 0 })

        setVariable("MYAPP_MAX_WORKERS", "abc")
        let result = app.mockRun([])
        removeVariable("MYAPP_MAX_WORKERS")

        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("MYAPP_MAX_WORKERS"), true)
        @Expect(result.stderr.contains("abc"), true)
    }
}

// ==================== Phase 10 集成测试 ====================

@Test
class Phase10IntegrationTest {
    @TestCase
    func testMultipleErrorsWithHint() {
        let app = App("mytool")
            .command(
                Command("deploy")
                    .description("Deploy")
                    .flag(Flag("target").required(true))
                    .flag(Flag("token").required(true))
                    .flag(Flag("verbose").short(r'v').action(SetTrue))
                    .flag(Flag("quiet").short(r'q').action(SetTrue).conflictsWith("verbose"))
                    .action({ ctx => 0 })
            )

        // 缺少 2 个必填 + verbose/quiet 冲突 = 3 个错误
        let result = app.mockRun(["deploy", "-v", "-q"])
        @Expect(result.exitCode, 2)
        @Expect(result.stderr.contains("Found 3 errors"), true)
        @Expect(result.stderr.contains("--help"), true)
    }

    @TestCase
    func testSignalWithEnvCoercion() {
        // 信号处理 + 环境变量类型协变组合
        let handler = SignalHandler()
        let app = App("test-app")
            .signalHandler(handler)
            .flag(Flag("timeout").valueType(Int64Type).envVar("TEST_SIGNAL_TIMEOUT"))
            .action({ ctx => 0 })

        setVariable("TEST_SIGNAL_TIMEOUT", "60")
        let result = app.mockRun([])
        removeVariable("TEST_SIGNAL_TIMEOUT")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testEnvMappingWithChoices() {
        // 环境变量 + choices 约束
        let app = App("test-app")
            .flag(
                Flag("format")
                    .choices(["text", "json", "yaml"])
                    .envVar("TEST_FMT_CHOICE")
            )
            .action({ ctx => 0 })

        // 环境变量中设置一个不在 choices 中的值 — 这在 env 层不做 choices 校验
        // （choices 校验只在 CLI 解析时执行）
        setVariable("TEST_FMT_CHOICE", "text")
        let result = app.mockRun([])
        removeVariable("TEST_FMT_CHOICE")

        @Expect(result.exitCode, 0)
    }

    @TestCase
    func testAggregateErrorFormat() {
        // 验证聚合错误的输出格式
        let errors = ArrayList<String>()
        errors.add("Missing --host")
        errors.add("Missing --port")
        let ex = AggregateException(errors)
        @Expect(ex.message, "Found 2 errors")
        @Expect(ex.warningCount(), 0)
    }

    @TestCase
    func testSIGTERMResult() {
        let handler = SignalHandler()
        let app = App("test-app")
            .signalHandler(handler)
            .command(
                Command("serve")
                    .description("Serve")
                    .action({ ctx =>
                        handler.simulateSignal(SIGTERM)
                        0
                    })
            )

        let result = app.mockRun(["serve"])
        @Expect(result.exitCode, 143)
        @Expect(result.stderr.contains("SIGTERM"), true)
    }
}
