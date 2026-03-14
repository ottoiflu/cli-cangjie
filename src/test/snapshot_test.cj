internal package cli.test

import cli.*

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// 快照测试 (Golden File Testing)
// ===============================================================
@Test
class SnapshotTest {
    // 使用临时目录避免与其他测试冲突
    let testDir = "src/test/snapshots"

    // --- 核心 API 测试 ---

    @TestCase
    func testFirstRunCreatesGoldenFile() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_create_golden"
        let goldenPath = "${testDir}/${name}.golden"

        // 确保文件不存在
        if (exists(Path(goldenPath))) {
            remove(Path(goldenPath))
        }

        let result = snap.compare(name, "Hello, World!\n")
        @Assert(result.matched)
        @Assert(exists(Path(goldenPath)))

        // 清理
        remove(Path(goldenPath))
    }

    @TestCase
    func testMatchingSnapshot() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_matching"
        let goldenPath = "${testDir}/${name}.golden"

        // 创建 golden 文件
        snap.update(name, "expected output\n")

        // 比对：应完全匹配
        let result = snap.compare(name, "expected output\n")
        @Assert(result.matched)
        @Assert(result.diff.size == 0)

        // 清理
        remove(Path(goldenPath))
    }

    @TestCase
    func testMismatchGeneratesNewFile() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_mismatch"
        let goldenPath = "${testDir}/${name}.golden"
        let newPath = "${testDir}/${name}.golden.new"

        // 创建 golden 文件
        snap.update(name, "original output\n")

        // 不匹配
        let result = snap.compare(name, "changed output\n")
        @Assert(!result.matched)
        @Assert(result.expected == "original output\n")
        @Assert(result.actual == "changed output\n")
        @Assert(result.diff.contains("Snapshot mismatch"))
        @Assert(exists(Path(newPath)))

        // 清理
        remove(Path(goldenPath))
        if (exists(Path(newPath))) {
            remove(Path(newPath))
        }
    }

    @TestCase
    func testUpdateOverwritesGolden() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_update"
        let goldenPath = "${testDir}/${name}.golden"

        snap.update(name, "v1\n")
        let r1 = snap.compare(name, "v1\n")
        @Assert(r1.matched)

        // 更新到 v2
        snap.update(name, "v2\n")
        let r2 = snap.compare(name, "v2\n")
        @Assert(r2.matched)

        // v1 不再匹配
        let r3 = snap.compare(name, "v1\n")
        @Assert(!r3.matched)

        // 清理
        remove(Path(goldenPath))
        let newPath = "${testDir}/${name}.golden.new"
        if (exists(Path(newPath))) {
            remove(Path(newPath))
        }
    }

    @TestCase
    func testDiffShowsLineChanges() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_diff"
        let goldenPath = "${testDir}/${name}.golden"

        snap.update(name, "line1\nline2\nline3\n")
        let result = snap.compare(name, "line1\nLINE2\nline3\n")
        @Assert(!result.matched)
        @Assert(result.diff.contains("--- expected"))
        @Assert(result.diff.contains("+++ actual"))
        @Assert(result.diff.contains("LINE2"))

        // 清理
        remove(Path(goldenPath))
        let newPath = "${testDir}/${name}.golden.new"
        if (exists(Path(newPath))) {
            remove(Path(newPath))
        }
    }

    // --- 与 App.mockRun() 集成的快照测试 ---

    @TestCase
    func testHelpSnapshotRoundtrip() {
        let app = App("mytool")
            .description("A great CLI tool")
            .version("1.0.0")
            .command(Command("lint").description("Run linter"))
            .command(Command("fmt").description("Format code"))
            .flag(Flag("verbose").short(r'v').asBool().description("Enable verbose output"))

        let result = app.mockRun(["--help"])
        let helpOutput = result.stderr

        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_help_roundtrip"
        let goldenPath = "${testDir}/${name}.golden"

        // 首次运行创建
        if (exists(Path(goldenPath))) {
            remove(Path(goldenPath))
        }

        let r1 = snap.compare(name, helpOutput)
        @Assert(r1.matched)

        // 再次运行应完全匹配（确认 help 输出稳定）
        let result2 = app.mockRun(["--help"])
        let r2 = snap.compare(name, result2.stderr)
        @Assert(r2.matched)

        // 清理
        remove(Path(goldenPath))
    }

    @TestCase
    func testErrorSnapshotRoundtrip() {
        let app = App("tool")
            .command(Command("run").action({ _ => 0 }))

        let result = app.mockRun(["--unknown-flag"])
        let errorOutput = result.stderr

        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_error_roundtrip"
        let goldenPath = "${testDir}/${name}.golden"

        if (exists(Path(goldenPath))) {
            remove(Path(goldenPath))
        }

        let r1 = snap.compare(name, errorOutput)
        @Assert(r1.matched)

        // 再次运行验证稳定性
        let result2 = app.mockRun(["--unknown-flag"])
        let r2 = snap.compare(name, result2.stderr)
        @Assert(r2.matched)

        // 清理
        remove(Path(goldenPath))
    }

    @TestCase
    func testSubcommandHelpSnapshot() {
        let app = App("tool")
            .command(
                Command("deploy")
                    .description("Deploy application")
                    .flag(Flag("env").short(r'e').description("Target environment"))
                    .flag(Flag("force").short(r'f').asBool().description("Force deploy"))
                    .argument(Argument("target").description("Deploy target"))
            )

        let result = app.mockRun(["deploy", "--help"])
        let helpOutput = result.stderr

        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_sub_help_snapshot"
        let goldenPath = "${testDir}/${name}.golden"

        if (exists(Path(goldenPath))) {
            remove(Path(goldenPath))
        }

        let r1 = snap.compare(name, helpOutput)
        @Assert(r1.matched)

        // 稳定性验证
        let result2 = app.mockRun(["deploy", "--help"])
        let r2 = snap.compare(name, result2.stderr)
        @Assert(r2.matched)

        // 清理
        remove(Path(goldenPath))
    }

    @TestCase
    func testSnapshotDetectsUIRegression() {
        let snap = Snapshot(snapshotDir: testDir)
        let name = "test_ui_regression"
        let goldenPath = "${testDir}/${name}.golden"
        let newPath = "${testDir}/${name}.golden.new"

        // 模拟 v1 的帮助输出
        snap.update(name, "Usage: tool [OPTIONS]\n\nOptions:\n  -v, --verbose  Verbose\n")

        // 模拟 v2 中选项描述发生变化（UI 回退）
        let actualV2 = "Usage: tool [OPTIONS]\n\nOptions:\n  -v, --verbose  Enable verbose mode\n"
        let result = snap.compare(name, actualV2)
        @Assert(!result.matched)
        @Assert(result.diff.contains("Verbose"))
        @Assert(result.diff.contains("Enable verbose mode"))

        // 清理
        remove(Path(goldenPath))
        if (exists(Path(newPath))) {
            remove(Path(newPath))
        }
    }
}

// ===============================================================
// 输入模拟测试 (Input Mock Testing)
// ===============================================================
@Test
class InputMockTest {
    @TestCase
    func testReadLine() {
        let mock = InputMock()
            .addLine("hello")
            .addLine("world")

        @Assert(mock.remaining() == 2)
        match (mock.readLine()) {
            case Some(v) => @Assert(v == "hello")
            case None => @Assert(false)
        }
        match (mock.readLine()) {
            case Some(v) => @Assert(v == "world")
            case None => @Assert(false)
        }
        @Assert(mock.readLine().isNone())
    }

    @TestCase
    func testReadLineOrDefault() {
        let mock = InputMock().addLine("input")

        @Assert(mock.readLineOrDefault("fallback") == "input")
        @Assert(mock.readLineOrDefault("fallback") == "fallback")
    }

    @TestCase
    func testHasMore() {
        let mock = InputMock().addLine("x")
        @Assert(mock.hasMore())
        mock.readLine()
        @Assert(!mock.hasMore())
    }

    @TestCase
    func testReset() {
        let mock = InputMock().addLine("first").addLine("second")
        mock.readLine()
        mock.readLine()
        @Assert(mock.consumed() == 2)
        @Assert(mock.remaining() == 0)

        mock.reset()
        @Assert(mock.consumed() == 0)
        @Assert(mock.remaining() == 2)
        match (mock.readLine()) {
            case Some(v) => @Assert(v == "first")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testAddLines() {
        let mock = InputMock().addLines(["a", "b", "c"])
        @Assert(mock.remaining() == 3)
    }
}

@Test
class PromptTest {
    @TestCase
    func testAsk() {
        let mock = InputMock().addLine("otto")
        let prompt = Prompt(mock)

        match (prompt.ask("Name?")) {
            case Some(v) => @Assert(v == "otto")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testAskOrDefault() {
        let mock = InputMock().addLine("").addLine("custom")
        let prompt = Prompt(mock)

        // 空输入 → 使用默认值
        @Assert(prompt.askOrDefault("Q?", "default") == "default")
        // 有输入 → 使用输入值
        @Assert(prompt.askOrDefault("Q?", "default") == "custom")
    }

    @TestCase
    func testConfirmYes() {
        let mock = InputMock()
            .addLine("y")
            .addLine("yes")
            .addLine("YES")
            .addLine("Y")
        let prompt = Prompt(mock)

        @Assert(prompt.confirm("Sure?"))
        @Assert(prompt.confirm("Sure?"))
        @Assert(prompt.confirm("Sure?"))
        @Assert(prompt.confirm("Sure?"))
    }

    @TestCase
    func testConfirmNo() {
        let mock = InputMock()
            .addLine("n")
            .addLine("no")
            .addLine("")
        let prompt = Prompt(mock)

        @Assert(!prompt.confirm("Sure?"))
        @Assert(!prompt.confirm("Sure?"))
        @Assert(!prompt.confirm("Sure?"))
    }

    @TestCase
    func testConfirmEOF() {
        let mock = InputMock()
        let prompt = Prompt(mock)
        @Assert(!prompt.confirm("Sure?"))
    }

    @TestCase
    func testSelect() {
        let options = ["apple", "banana", "cherry"]
        let mock = InputMock().addLine("2")
        let prompt = Prompt(mock)

        match (prompt.select("Choose fruit:", options)) {
            case Some(v) => @Assert(v == "banana")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSelectInvalid() {
        let options = ["a", "b"]
        let mock = InputMock().addLine("5")
        let prompt = Prompt(mock)

        @Assert(prompt.select("Choose:", options).isNone())
    }

    @TestCase
    func testSelectZero() {
        let options = ["a", "b"]
        let mock = InputMock().addLine("0")
        let prompt = Prompt(mock)

        // 0 is invalid (1-based)
        @Assert(prompt.select("Choose:", options).isNone())
    }

    @TestCase
    func testPromptInAction() {
        let log = ArrayList<String>()
        let mock = InputMock().addLine("production")

        let app = App("tool")
            .command(
                Command("deploy")
                    .action({ _ =>
                        let prompt = Prompt(mock)
                        match (prompt.ask("Environment?")) {
                            case Some(env) => log.add(env)
                            case None => ()
                        }
                        0
                    })
            )

        let result = app.mockRun(["deploy"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 1)
        @Assert(log[0] == "production")
    }
}
