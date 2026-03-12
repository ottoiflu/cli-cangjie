internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 命令树构建测试 (Command Builder)
// ===============================================================
@Test
class CommandBuilderTest {
    @TestCase
    func testBasicCommandCreation() {
        let cmd = Command("lint")
            .description("Lint source code")
            .version("1.0.0")
            .author("dev")

        @Assert(cmd.getName() == "lint")
        @Assert(cmd.getDescription() == "Lint source code")
        @Assert(cmd.getVersion() == "1.0.0")
        @Assert(cmd.getAuthor() == "dev")
    }

    @TestCase
    func testSubcommandRegistration() {
        let root = Command("tool")
            .command(Command("lint").description("Lint code"))
            .command(Command("fmt").description("Format code"))

        let subs = root.getSubcommands()
        @Assert(subs.size == 2)
        @Assert(subs[0].getName() == "lint")
        @Assert(subs[1].getName() == "fmt")
    }

    @TestCase
    func testDeepNestedSubcommands() {
        let root = Command("tool")
            .command(
                Command("cloud")
                    .command(
                        Command("server")
                            .command(Command("start").description("Start the server"))
                    )
            )

        let cloud = root.getSubcommands()[0]
        @Assert(cloud.getName() == "cloud")
        let server = cloud.getSubcommands()[0]
        @Assert(server.getName() == "server")
        let start = server.getSubcommands()[0]
        @Assert(start.getName() == "start")
        @Assert(start.getDescription() == "Start the server")
    }

    @TestCase
    func testCommandAliases() {
        let cmd = Command("install").alias("i").alias("add")
        let aliases = cmd.getAliases()
        @Assert(aliases.size == 2)
        @Assert(aliases[0] == "i")
        @Assert(aliases[1] == "add")
    }

    @TestCase
    func testFindSubcommandByName() {
        let root = Command("tool")
            .command(Command("lint"))
            .command(Command("fmt"))

        match (root.findSubcommand("lint")) {
            case Some(cmd) => @Assert(cmd.getName() == "lint")
            case None => @Assert(false)
        }
        match (root.findSubcommand("unknown")) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testFindSubcommandByAlias() {
        let root = Command("tool")
            .command(Command("install").alias("i"))

        match (root.findSubcommand("i")) {
            case Some(cmd) => @Assert(cmd.getName() == "install")
            case None => @Assert(false)
        }
    }
}
