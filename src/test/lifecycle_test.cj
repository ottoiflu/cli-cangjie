internal package cli.test

import cli.*

import std.collection.*
import std.env.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 生命周期钩子测试
// ===============================================================
@Test
class LifecycleTest {
    @TestCase
    func testPreRunHook() {
        let log = ArrayList<String>()
        let app = App("tool")
            .command(
                Command("run")
                    .preRun({ _ =>
                        log.add("preRun")
                    })
                    .action({ _ =>
                        log.add("action")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 2)
        @Assert(log[0] == "preRun")
        @Assert(log[1] == "action")
    }

    @TestCase
    func testPostRunHook() {
        let log = ArrayList<String>()
        let app = App("tool")
            .command(
                Command("run")
                    .action({ _ =>
                        log.add("action")
                        0
                    })
                    .postRun({ _ =>
                        log.add("postRun")
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 2)
        @Assert(log[0] == "action")
        @Assert(log[1] == "postRun")
    }

    @TestCase
    func testPersistentPreRunHook() {
        let log = ArrayList<String>()
        let app = App("tool")
            .persistentPreRun({ _ =>
                log.add("persistentPreRun")
            })
            .command(
                Command("sub")
                    .preRun({ _ =>
                        log.add("preRun")
                    })
                    .action({ _ =>
                        log.add("action")
                        0
                    })
            )

        let result = app.mockRun(["sub"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 3)
        @Assert(log[0] == "persistentPreRun")
        @Assert(log[1] == "preRun")
        @Assert(log[2] == "action")
    }

    @TestCase
    func testPersistentPostRunHook() {
        let log = ArrayList<String>()
        let app = App("tool")
            .persistentPostRun({ _ =>
                log.add("persistentPostRun")
            })
            .command(
                Command("sub")
                    .action({ _ =>
                        log.add("action")
                        0
                    })
                    .postRun({ _ =>
                        log.add("postRun")
                    })
            )

        let result = app.mockRun(["sub"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 3)
        @Assert(log[0] == "action")
        @Assert(log[1] == "postRun")
        @Assert(log[2] == "persistentPostRun")
    }

    @TestCase
    func testFullLifecycleOrder() {
        let log = ArrayList<String>()
        let app = App("tool")
            .persistentPreRun({ _ =>
                log.add("1-persistentPreRun")
            })
            .persistentPostRun({ _ =>
                log.add("5-persistentPostRun")
            })
            .command(
                Command("cmd")
                    .preRun({ _ =>
                        log.add("2-preRun")
                    })
                    .action({ _ =>
                        log.add("3-action")
                        0
                    })
                    .postRun({ _ =>
                        log.add("4-postRun")
                    })
            )

        let result = app.mockRun(["cmd"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 5)
        @Assert(log[0] == "1-persistentPreRun")
        @Assert(log[1] == "2-preRun")
        @Assert(log[2] == "3-action")
        @Assert(log[3] == "4-postRun")
        @Assert(log[4] == "5-persistentPostRun")
    }

    @TestCase
    func testNoHooksStillWorks() {
        let app = App("tool")
            .command(
                Command("run")
                    .action({ _ => 42 })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 42)
    }
}

// ===============================================================
// 中间件测试
// ===============================================================
@Test
class MiddlewareTest {
    @TestCase
    func testGlobalMiddleware() {
        let log = ArrayList<String>()
        let app = App("tool")
            .use({ _, next =>
                log.add("mw-before")
                let code = next()
                log.add("mw-after")
                code
            })
            .command(
                Command("run")
                    .action({ _ =>
                        log.add("action")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 3)
        @Assert(log[0] == "mw-before")
        @Assert(log[1] == "action")
        @Assert(log[2] == "mw-after")
    }

    @TestCase
    func testCommandLocalMiddleware() {
        let log = ArrayList<String>()
        let app = App("tool")
            .command(
                Command("run")
                    .use({ _, next =>
                        log.add("local-mw")
                        next()
                    })
                    .action({ _ =>
                        log.add("action")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 2)
        @Assert(log[0] == "local-mw")
        @Assert(log[1] == "action")
    }

    @TestCase
    func testMultipleMiddlewareChaining() {
        let log = ArrayList<String>()
        let app = App("tool")
            .use({ _, next =>
                log.add("global-1")
                next()
            })
            .use({ _, next =>
                log.add("global-2")
                next()
            })
            .command(
                Command("run")
                    .use({ _, next =>
                        log.add("local-1")
                        next()
                    })
                    .action({ _ =>
                        log.add("action")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 4)
        @Assert(log[0] == "global-1")
        @Assert(log[1] == "global-2")
        @Assert(log[2] == "local-1")
        @Assert(log[3] == "action")
    }

    @TestCase
    func testMiddlewareCanShortCircuit() {
        let log = ArrayList<String>()
        let app = App("tool")
            .use({ _, _ =>
                log.add("auth-check")
                // 模拟鉴权失败：不调用 next()，直接返回错误码
                1
            })
            .command(
                Command("run")
                    .action({ _ =>
                        log.add("action-should-not-run")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 1)
        @Assert(log.size == 1)
        @Assert(log[0] == "auth-check")
    }

    @TestCase
    func testMiddlewareWithLifecycleHooks() {
        let log = ArrayList<String>()
        let app = App("tool")
            .persistentPreRun({ _ => log.add("1-persistentPreRun") })
            .use({ _, next =>
                log.add("2-middleware")
                next()
            })
            .persistentPostRun({ _ => log.add("4-persistentPostRun") })
            .command(
                Command("run")
                    .action({ _ =>
                        log.add("3-action")
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 4)
        @Assert(log[0] == "1-persistentPreRun")
        @Assert(log[1] == "2-middleware")
        @Assert(log[2] == "3-action")
        @Assert(log[3] == "4-persistentPostRun")
    }
}

// ===============================================================
// 环境变量配置合并测试
// ===============================================================
@Test
class EnvVarTest {
    @TestCase
    func testExplicitEnvVarMapping() {
        // 设置环境变量
        setVariable("TEST_DB_HOST", "localhost")

        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("db-host").envVar("TEST_DB_HOST"))
                    .action({ ctx =>
                        match (ctx.getFlag("db-host")) {
                            case Some(v) =>
                                if (v == "localhost") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)

        // 清理
        removeVariable("TEST_DB_HOST")
    }

    @TestCase
    func testCLIFlagOverridesEnvVar() {
        setVariable("TEST_PORT", "3000")

        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("port").envVar("TEST_PORT"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "8080") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        // CLI 显式指定的值优先于环境变量
        let result = app.mockRun(["run", "--port", "8080"])
        @Assert(result.exitCode == 0)

        removeVariable("TEST_PORT")
    }

    @TestCase
    func testAutoEnvPrefixMapping() {
        setVariable("MYAPP_DB_HOST", "db.example.com")

        let app = App("tool")
            .envPrefix("MYAPP")
            .command(
                Command("run")
                    .flag(Flag("db-host"))
                    .action({ ctx =>
                        match (ctx.getFlag("db-host")) {
                            case Some(v) =>
                                if (v == "db.example.com") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)

        removeVariable("MYAPP_DB_HOST")
    }

    @TestCase
    func testEnvVarNotSetUsesDefault() {
        removeVariable("NOEXIST_VAR")

        let app = App("tool")
            .command(
                Command("run")
                    .flag(Flag("port").envVar("NOEXIST_VAR").defaultValue("3000"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "3000") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testExplicitEnvOverridesAutoPrefix() {
        setVariable("EXPLICIT_HOST", "explicit.com")
        setVariable("MYAPP_HOST", "auto.com")

        let app = App("tool")
            .envPrefix("MYAPP")
            .command(
                Command("run")
                    .flag(Flag("host").envVar("EXPLICIT_HOST"))
                    .action({ ctx =>
                        match (ctx.getFlag("host")) {
                            case Some(v) =>
                                // 显式映射优先
                                if (v == "explicit.com") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)

        removeVariable("EXPLICIT_HOST")
        removeVariable("MYAPP_HOST")
    }
}

// ===============================================================
// Context 自定义值存储（依赖注入）测试
// ===============================================================
@Test
class ContextValueTest {
    @TestCase
    func testSetAndGetValue() {
        let ctx = Context()
        ctx.setValue("user", "admin")
        @Assert(ctx.hasValue("user"))
        match (ctx.getValue("user")) {
            case Some(v) =>
                @Assert(v == "admin")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testHasValue() {
        let ctx = Context()
        @Assert(!ctx.hasValue("key"))
        ctx.setValue("key", "val")
        @Assert(ctx.hasValue("key"))
    }

    @TestCase
    func testValueOverwrite() {
        let ctx = Context()
        ctx.setValue("count", "1")
        ctx.setValue("count", "2")
        match (ctx.getValue("count")) {
            case Some(v) =>
                @Assert(v == "2")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testValueInMiddleware() {
        let log = ArrayList<String>()
        let app = App("tool")
            .use({ ctx, next =>
                ctx.setValue("requestId", "req-123")
                next()
            })
            .command(
                Command("run")
                    .action({ ctx =>
                        match (ctx.getValue("requestId")) {
                            case Some(v) =>
                                log.add(v)
                            case None => ()
                        }
                        0
                    })
            )

        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 1)
        @Assert(log[0] == "req-123")
    }
}
