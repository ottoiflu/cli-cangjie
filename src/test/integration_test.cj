internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// App 集成测试 (MockRun)
// ===============================================================
@Test
class AppIntegrationTest {
    @TestCase
    func testAppBuilder() {
        let app = App("cj-tool")
            .description("A cool CLI tool")
            .version("v1.0.0")

        let root = app.getRootCommand()
        @Assert(root.getName() == "cj-tool")
        @Assert(root.getDescription() == "A cool CLI tool")
        @Assert(root.getVersion() == "v1.0.0")
    }

    @TestCase
    func testMockRunHelp() {
        let app = App("cj-tool")
            .description("A testing tool")
            .version("1.0.0")
            .command(Command("lint").description("Lint code"))
            .command(Command("fmt").description("Format code"))

        let result = app.mockRun(["--help"])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Usage:"))
        @Assert(result.stderr.contains("Commands:"))
        @Assert(result.stderr.contains("lint"))
        @Assert(result.stderr.contains("fmt"))
    }

    @TestCase
    func testMockRunHelpShort() {
        let app = App("cj-tool").version("1.0.0")
        let result = app.mockRun(["-h"])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Usage:"))
    }

    @TestCase
    func testMockRunVersion() {
        let app = App("cj-tool").version("2.1.0")
        let result = app.mockRun(["--version"])

        @Assert(result.exitCode == 0)
        @Assert(result.stdout.contains("cj-tool"))
        @Assert(result.stdout.contains("2.1.0"))
    }

    @TestCase
    func testMockRunVersionShort() {
        let app = App("cj-tool").version("2.1.0")
        let result = app.mockRun(["-V"])

        @Assert(result.exitCode == 0)
        @Assert(result.stdout.contains("2.1.0"))
    }

    @TestCase
    func testMockRunSubcommandHelp() {
        let app = App("tool")
            .command(
                Command("lint")
                    .description("Lint source files")
                    .flag(Flag("fix", "f").asBool().description("Auto-fix issues"))
            )

        let result = app.mockRun(["lint", "--help"])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Lint source files"))
        @Assert(result.stderr.contains("--fix"))
    }

    @TestCase
    func testMockRunWithAction() {
        let app = App("tool")
            .command(
                Command("greet")
                    .flag(Flag("name", "n").defaultValue("World"))
                    .action({ ctx =>
                        0
                    })
            )

        let result = app.mockRun(["greet", "--name", "Cangjie"])

        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testMockRunParseError() {
        let app = App("tool")
            .flag(Flag("config", "c"))

        let result = app.mockRun(["--unknown-flag"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("error:"))
    }

    @TestCase
    func testMockRunRequiredFlagError() {
        let app = App("tool")
            .flag(Flag("output", "o").required(true))

        let result = app.mockRun([])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("--output"))
    }

    @TestCase
    func testMockRunTypedFlagError() {
        let app = App("tool")
            .flag(Flag("port", "p").valueType(Int64Type))

        let result = app.mockRun(["--port", "not-a-number"])

        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("error:"))
    }

    @TestCase
    func testMockRunComplexScenario() {
        let capturedEnv = ArrayList<String>()
        let capturedReplicas = ArrayList<String>()
        let capturedServiceArgs = ArrayList<String>()
        let app = App("deploy-tool")
            .version("3.0.0")
            .description("Deployment tool")
            .flag(Flag("verbose", "v").asBool().description("Verbose output"))
            .command(
                Command("deploy")
                    .description("Deploy application")
                    .alias("d")
                    .flag(Flag("env", "e").required(true).description("Target environment"))
                    .flag(Flag("replicas", "r").valueType(Int64Type).defaultValue("1"))
                    .argument(Argument("service").required(true).description("Service name"))
                    .action({ ctx =>
                        capturedEnv.add(ctx.getFlagOrDefault("env", ""))
                        capturedReplicas.add(ctx.getFlagOrDefault("replicas", ""))
                        let args = ctx.getArguments()
                        for (a in args) {
                            capturedServiceArgs.add(a)
                        }
                        0
                    })
            )

        let result = app.mockRun(["deploy", "--env", "production", "-r", "3", "my-service", "--verbose"])

        @Assert(result.exitCode == 0)
        @Assert(capturedEnv.size > 0)
        @Assert(capturedEnv[0] == "production")
        @Assert(capturedReplicas[0] == "3")
        @Assert(capturedServiceArgs.size > 0)
        @Assert(capturedServiceArgs[0] == "my-service")
    }

    @TestCase
    func testMockRunSubcommandByAlias() {
        let app = App("tool")
            .command(
                Command("install")
                    .alias("i")
                    .action({ ctx => 0 })
            )

        let result = app.mockRun(["i"])

        @Assert(result.exitCode == 0)
    }

    @TestCase
    func testHelpContainsOptions() {
        let app = App("tool")
            .flag(Flag("verbose", "v").asBool().description("Enable verbose mode"))
            .flag(Flag("config", "c").description("Config file path").defaultValue("config.toml"))

        let result = app.mockRun(["--help"])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Options:"))
        @Assert(result.stderr.contains("--verbose"))
        @Assert(result.stderr.contains("-v"))
        @Assert(result.stderr.contains("--config"))
        @Assert(result.stderr.contains("config.toml"))
    }

    @TestCase
    func testHelpContainsArguments() {
        let app = App("tool")
            .argument(Argument("input").description("Input file").required(true))
            .argument(Argument("files").description("Additional files").variadic(true))

        let result = app.mockRun(["--help"])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Arguments:"))
        @Assert(result.stderr.contains("input"))
        @Assert(result.stderr.contains("files"))
    }

    @TestCase
    func testNoActionShowsHelp() {
        let app = App("tool")
            .description("A tool without actions")
            .command(Command("sub1").description("First sub"))

        let result = app.mockRun([])

        @Assert(result.exitCode == 0)
        @Assert(result.stderr.contains("Usage:"))
    }

    @TestCase
    func testDoubleDashInMockRun() {
        let argValues = ArrayList<String>()
        let app = App("tool")
            .flag(Flag("verbose", "v").asBool())
            .action({ ctx =>
                let args = ctx.getArguments()
                for (a in args) {
                    argValues.add(a)
                }
                0
            })

        let result = app.mockRun(["--verbose", "--", "--not-flag", "plain-arg"])

        @Assert(result.exitCode == 0)
        @Assert(argValues.size == 2)
        @Assert(argValues[0] == "--not-flag")
        @Assert(argValues[1] == "plain-arg")
    }
}
