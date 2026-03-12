internal package cli.test

import cli.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import std.env.*
import std.fs.*

// Phase 7: 配置文件解析测试
@Test
class ConfigParserTest {
    // 基本 key = value 解析
    @TestCase
    func testBasicKeyValue() {
        let loader = ConfigLoader()
        let content = "name = hello\nport = 8080"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        @Assert(data.size() == 2)
        match (data.get("name")) {
            case Some(v) => @Assert(v == "hello")
            case None => @Assert(false)
        }
        match (data.get("port")) {
            case Some(v) => @Assert(v == "8080")
            case None => @Assert(false)
        }
    }

    // 带引号的字符串值
    @TestCase
    func testQuotedValues() {
        let loader = ConfigLoader()
        let content = "name = \"hello world\"\npath = '/usr/bin'"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        match (data.get("name")) {
            case Some(v) => @Assert(v == "hello world")
            case None => @Assert(false)
        }
        match (data.get("path")) {
            case Some(v) => @Assert(v == "/usr/bin")
            case None => @Assert(false)
        }
    }

    // 注释和空行
    @TestCase
    func testCommentsAndBlankLines() {
        let loader = ConfigLoader()
        let content = "# This is a comment\n\nname = test\n  # Another comment\nport = 3000"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        @Assert(data.size() == 2)
    }

    // Section headers 被跳过
    @TestCase
    func testSectionHeaders() {
        let loader = ConfigLoader()
        let content = "[database]\nhost = localhost\nport = 5432"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        @Assert(data.size() == 2)
        match (data.get("host")) {
            case Some(v) => @Assert(v == "localhost")
            case None => @Assert(false)
        }
    }

    // 布尔值
    @TestCase
    func testBooleanValues() {
        let loader = ConfigLoader()
        let content = "verbose = true\nquiet = false"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        match (data.get("verbose")) {
            case Some(v) => @Assert(v == "true")
            case None => @Assert(false)
        }
        match (data.get("quiet")) {
            case Some(v) => @Assert(v == "false")
            case None => @Assert(false)
        }
    }

    // 值中包含等号
    @TestCase
    func testValueWithEquals() {
        let loader = ConfigLoader()
        let content = "url = http://host?key=value&a=b"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        match (data.get("url")) {
            case Some(v) => @Assert(v == "http://host?key=value&a=b")
            case None => @Assert(false)
        }
    }

    // 空内容
    @TestCase
    func testEmptyContent() {
        let loader = ConfigLoader()
        let content = ""
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        @Assert(data.size() == 0)
    }

    // 仅注释
    @TestCase
    func testOnlyComments() {
        let loader = ConfigLoader()
        let content = "# comment 1\n# comment 2"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        @Assert(data.size() == 0)
    }
}

// 配置错误检测测试
@Test
class ConfigErrorTest {
    // 格式错误行
    @TestCase
    func testInvalidFormat() {
        let loader = ConfigLoader()
        let content = "name = ok\ninvalid-line-no-equals\nport = 3000"
        let (data, errors) = loader.parse(content, filePath: "test.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].line == 2)
        @Assert(errors[0].message.contains("expected"))
        // 有效行仍被解析
        @Assert(data.size() == 2)
    }

    // 重复 key
    @TestCase
    func testDuplicateKey() {
        let loader = ConfigLoader()
        let content = "name = hello\nname = world"
        let (data, errors) = loader.parse(content, filePath: "test.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].message.contains("duplicate"))
        @Assert(errors[0].line == 2)
    }

    // 空 key
    @TestCase
    func testEmptyKey() {
        let loader = ConfigLoader()
        let content = " = value"
        let (_, errors) = loader.parse(content, filePath: "test.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].message.contains("empty key"))
    }

    // 未知 key + Did-You-Mean 建议
    @TestCase
    func testUnknownKeyWithDidYouMean() {
        let loader = ConfigLoader()
            .knownKeys(["verbose", "output", "config", "port"])
        let content = "verboes = true"
        let (_, errors) = loader.parse(content, filePath: "app.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].message.contains("unknown key"))
        @Assert(errors[0].suggestion.isSome())
        match (errors[0].suggestion) {
            case Some(s) => @Assert(s.contains("verbose"))
            case None => @Assert(false)
        }
    }

    // 未知 key 无建议
    @TestCase
    func testUnknownKeyNoSuggestion() {
        let loader = ConfigLoader()
            .knownKeys(["verbose", "output"])
        let content = "zzzzz = 123"
        let (_, errors) = loader.parse(content, filePath: "app.toml")
        @Assert(errors.size == 1)
        @Assert(errors[0].suggestion.isNone())
    }

    // 错误格式化输出包含行号和路径
    @TestCase
    func testErrorFormat() {
        let err = ConfigError(
            "unknown key 'verboes'",
            "app.toml",
            3,
            "verboes = true",
            suggestion: Some("did you mean 'verbose'?")
        )
        let formatted = err.format()
        @Assert(formatted.contains("app.toml:3"))
        @Assert(formatted.contains("verboes = true"))
        @Assert(formatted.contains("did you mean 'verbose'?"))
    }
}

// 目录遍历和配置发现测试
@Test
class ConfigDiscoveryTest {
    // 环境变量覆盖路径
    @TestCase
    func testEnvVarOverridesDiscovery() {
        // 创建临时配置文件
        let testDir = "src/test/_config_test_tmp"
        let testPath = "${testDir}/env_config.toml"
        ensureTestDir(testDir)
        File.writeTo(Path(testPath), "name = from-env".toArray())

        setVariable("TEST_CONFIG_PATH_7", testPath)

        let loader = ConfigLoader()
            .configFileName("nonexistent.toml")
            .configPathEnvVar("TEST_CONFIG_PATH_7")

        let result = loader.discover()
        @Assert(result.isSome())
        match (result) {
            case Some(p) => @Assert(p == testPath)
            case None => @Assert(false)
        }

        // 清理
        removeVariable("TEST_CONFIG_PATH_7")
        remove(Path(testPath))
        remove(Path(testDir))
    }

    // 文件不存在时返回 None
    @TestCase
    func testFileNotFound() {
        let loader = ConfigLoader()
            .configFileName("__nonexistent_config_12345.toml")

        let result = loader.discover(startDir: "/tmp")
        @Assert(result.isNone())
    }
}

// key 归一化测试（连字符/下划线兼容）
@Test
class ConfigKeyNormalizationTest {
    // 下划线 key 匹配连字符 knownKey
    @TestCase
    func testUnderscoreMatchesHyphen() {
        let loader = ConfigLoader()
            .knownKeys(["db-host", "db-port"])
        let content = "db_host = localhost"
        let (data, errors) = loader.parse(content)
        @Assert(errors.size == 0)
        match (data.get("db_host")) {
            case Some(v) => @Assert(v == "localhost")
            case None => @Assert(false)
        }
    }
}

// 四级优先级管道集成测试
@Test
class ConfigPriorityPipelineTest {
    // Config File 值在 CLI 和 ENV 未设置时生效
    @TestCase
    func testConfigValueApplied() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "9090") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRunWithConfig(["run"], configContent: Some("port = 9090"))
        @Assert(result.exitCode == 0)
    }

    // CLI 显式参数优先于 Config File
    @TestCase
    func testCLIOverridesConfig() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "8080") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRunWithConfig(["run", "--port", "8080"], configContent: Some("port = 9090"))
        @Assert(result.exitCode == 0)
    }

    // ENV 优先于 Config File
    @TestCase
    func testEnvOverridesConfig() {
        setVariable("TEST_ENV_PORT_7", "7070")

        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port").envVar("TEST_ENV_PORT_7"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "7070") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRunWithConfig(["run"], configContent: Some("port = 9090"))
        @Assert(result.exitCode == 0)

        removeVariable("TEST_ENV_PORT_7")
    }

    // Config File 优先于 Default
    @TestCase
    func testConfigOverridesDefault() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port").defaultValue("3000"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "9090") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        let result = app.mockRunWithConfig(["run"], configContent: Some("port = 9090"))
        @Assert(result.exitCode == 0)
    }

    // 无 Config File 时 Default 生效
    @TestCase
    func testDefaultWhenNoConfig() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port").defaultValue("3000"))
                    .action({ ctx =>
                        match (ctx.getFlag("port")) {
                            case Some(v) =>
                                if (v == "3000") { 0 } else { 1 }
                            case None => 2
                        }
                    })
            )

        // 不提供配置内容
        let result = app.mockRun(["run"])
        @Assert(result.exitCode == 0)
    }

    // 完整四级优先级: CLI > ENV > Config > Default
    @TestCase
    func testFullPriorityChain() {
        setVariable("TEST_FULL_PRIO_HOST", "env-host")

        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("host").envVar("TEST_FULL_PRIO_HOST").defaultValue("default-host"))
                    .flag(Flag("port").defaultValue("3000"))
                    .flag(Flag("db").defaultValue("sqlite"))
                    .action({ ctx =>
                        let host = ctx.getFlagOrDefault("host", "none")
                        let port = ctx.getFlagOrDefault("port", "none")
                        let db = ctx.getFlagOrDefault("db", "none")
                        // host: CLI 显式 > ENV = "env-host" (由前序测试清理)
                        // 这里 host 设了 ENV，所以 ENV 优先: "env-host"
                        // port: config = 9090 > default = 3000
                        // db: 无 config 值，default = "sqlite"
                        if (host == "env-host" && port == "9090" && db == "sqlite") { 0 } else { 1 }
                    })
            )

        let result = app.mockRunWithConfig(["run"],
            configContent: Some("port = 9090"))
        @Assert(result.exitCode == 0)

        removeVariable("TEST_FULL_PRIO_HOST")
    }
}

// 配置错误在 mockRun 中的集成测试
@Test
class ConfigErrorIntegrationTest {
    // 配置解析错误输出到 stderr
    @TestCase
    func testConfigErrorInMockRun() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port"))
                    .action({ ctx => 0 })
            )

        let result = app.mockRunWithConfig(["run"],
            configContent: Some("pors = 8080"))
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("unknown key"))
        @Assert(result.stderr.contains("port"))
    }

    // 多个配置错误都被报告
    @TestCase
    func testMultipleConfigErrors() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("host"))
                    .flag(Flag("port"))
                    .action({ ctx => 0 })
            )

        let result = app.mockRunWithConfig(["run"],
            configContent: Some("hosr = localhost\npors = 8080"))
        @Assert(result.exitCode == 2)
        // 第一个错误就会抛出（配置错误是批量收集后抛出的）
        @Assert(result.stderr.contains("unknown key"))
    }

    // 不合法格式行的报错包含行号
    @TestCase
    func testFormatErrorWithLineNumber() {
        let app = App("tool")
            .configFile("app.toml")
            .command(
                Command("run")
                    .flag(Flag("port"))
                    .action({ ctx => 0 })
            )

        let result = app.mockRunWithConfig(["run"],
            configContent: Some("port = 8080\nbad-line-no-equals"))
        @Assert(result.exitCode == 2)
        @Assert(result.stderr.contains("expected"))
    }
}

// getParentDir 辅助函数测试
@Test
class ParentDirTest {
    @TestCase
    func testSimplePath() {
        @Assert(getParentDir("/home/user/project") == "/home/user")
    }

    @TestCase
    func testRootPath() {
        @Assert(getParentDir("/") == "/")
    }

    @TestCase
    func testSingleDir() {
        @Assert(getParentDir("/home") == "/")
    }

    @TestCase
    func testTrailingSlash() {
        @Assert(getParentDir("/home/user/") == "/home")
    }
}

// 辅助方法
func ensureTestDir(dir: String): Unit {
    if (!exists(Path(dir))) {
        Directory.create(Path(dir), recursive: true)
    }
}
