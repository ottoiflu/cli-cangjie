// =============================================================================
// cj-devtool — 基于 Cangjie CLI Framework 构建的示例 DevOps 工具
//
// 演示框架全部核心特性：子命令树、Flag 约束、配置管道、诊断系统、
// Shell 补全、中间件、生命周期钩子、交互组件等
// =============================================================================

package cj_devtool

import cli.*

main(): Int64 {
    let app = App("cj-devtool")
        .description("A modern DevOps CLI tool — powered by Cangjie CLI Framework")
        .version("1.0.0")
        .envPrefix("DEVTOOL")
        .configFile("devtool.toml")
        .helpWidth(80)
        .versionInfo(
            VersionInfo()
                .name("cj-devtool")
                .version("1.0.0")
                .commitHash("abc1234")
                .commitDate("2026-03-13")
                .buildDate("2026-03-13")
                .compiler("cjc 1.0.5")
        )
        // 全局标志
        .globalFlag(
            Flag("verbose").short(r'v')
                .description("Enable verbose output")
                .asBool()
        )
        .globalFlag(
            Flag("color")
                .description("Color output mode")
                .choices(["auto", "always", "never"])
                .defaultValue("auto")
        )
        .globalFlag(
            Flag("format").short(r'f')
                .description("Output format")
                .choices(["text", "json"])
                .defaultValue("text")
        )
        // 全局中间件：verbose 模式下输出额外调试信息
        .use({ ctx, next =>
            if (ctx.getBoolFlag("verbose")) {
                println("[verbose] Command starting...")
            }
            let code = next()
            if (ctx.getBoolFlag("verbose")) {
                println("[verbose] Command finished with exit code: ${code}")
            }
            code
        })
        // 全局生命周期钩子
        .persistentPreRun({ _ctx =>
            // 全局前置: 可用于初始化日志、加载全局配置等
        })
        .persistentPostRun({ _ctx =>
            // 全局后置: 可用于清理资源、刷新缓存等
        })

    // ── serve: 启动开发服务器 ──
    let serveCmd = Command("serve")
        .alias("s")
        .description("Start a development server")
        .subcommandGroup("Server Commands")
        .example("Start on default port", "cj-devtool serve")
        .example("Start on custom port", "cj-devtool serve --port 3000 --host 0.0.0.0")
        .example("Start with TLS", "cj-devtool serve --port 443 --tls --cert ./cert.pem --key ./key.pem")
        .afterHelp("Environment variables: DEVTOOL_PORT, DEVTOOL_HOST")
        .flag(Flag("port").short(r'p').description("Port to listen on").valueType(Int64Type).defaultValue("8080"))
        .flag(Flag("host").short(r'H').description("Host to bind to").defaultValue("127.0.0.1"))
        .flag(Flag("tls").description("Enable TLS").asBool())
        .flag(Flag("cert").description("TLS certificate path").requires("tls"))
        .flag(Flag("key").description("TLS key path").requires("tls"))
        .action({ ctx =>
            let port = ctx.getFlagOrDefault("port", "8080")
            let host = ctx.getFlagOrDefault("host", "127.0.0.1")
            let tls = ctx.getBoolFlag("tls")
            let scheme = if (tls) { "https" } else { "http" }
            println("Starting development server...")
            println("  Listening on: ${scheme}://${host}:${port}")
            if (tls) {
                let cert = ctx.getFlagOrDefault("cert", "")
                let key = ctx.getFlagOrDefault("key", "")
                println("  TLS cert: ${cert}")
                println("  TLS key:  ${key}")
            }
            println("  Press Ctrl+C to stop.")
            0
        })

    // ── deploy: 部署应用 ──
    let deployCmd = Command("deploy")
        .alias("d")
        .description("Deploy application to target environment")
        .subcommandGroup("Deploy Commands")
        .example("Deploy to staging", "cj-devtool deploy --env staging --tag v1.0.0")
        .example("Dry run deployment", "cj-devtool deploy --env production --tag v2.0.0 --dry-run")
        .example("Deploy with notifications", "cj-devtool deploy --env staging --tag v1.0.0 --notify slack,email")
        .flag(Flag("env").short(r'e').description("Target environment").choices(["dev", "staging", "production"]).required(true))
        .flag(Flag("tag").short(r't').description("Image tag to deploy").required(true))
        .flag(Flag("dry-run").description("Simulate deployment without executing").asBool())
        .flag(Flag("force").description("Force deploy, skip confirmation").asBool().conflictsWith("dry-run"))
        .flag(Flag("replicas").short(r'r').description("Number of replicas (1-100)").valueType(Int64Type).defaultValue("1")
            .validator({ v =>
                if (!isValidInt(v)) { return false }
                let n = parseSimpleInt(v)
                n > 0 && n <= 100
            }, message: "must be an integer between 1 and 100"))
        .flag(Flag("notify").short(r'n').description("Notification channels (comma-separated)").delimiter(r','))
        .action({ ctx =>
            let env = ctx.getFlagOrDefault("env", "dev")
            let tag = ctx.getFlagOrDefault("tag", "latest")
            let dryRun = ctx.getBoolFlag("dry-run")
            let replicas = ctx.getFlagOrDefault("replicas", "1")

            if (dryRun) {
                println("[DRY-RUN] Simulating deployment...")
            } else {
                println("Deploying application...")
            }
            println("  Environment: ${env}")
            println("  Image tag:   ${tag}")
            println("  Replicas:    ${replicas}")

            match (ctx.getFlagAll("notify")) {
                case Some(channels) =>
                    var chList = ""
                    var first = true
                    for (c in channels) {
                        if (!first) { chList = chList + ", " }
                        chList = chList + c
                        first = false
                    }
                    println("  Notify:      ${chList}")
                case None => ()
            }

            if (dryRun) {
                println("\n[DRY-RUN] No changes were made.")
            } else {
                println("\nDeployment of ${tag} to ${env} completed successfully.")
            }
            0
        })

    // ── cloud: 云基础设施管理 (嵌套子命令) ──
    let cloudListCmd = Command("list")
        .alias("ls")
        .description("List cloud instances")
        .flag(Flag("region").short(r'r').description("Filter by region").choices(["us-east", "us-west", "eu-west", "ap-east"]))
        .flag(Flag("status").description("Filter by status").choices(["running", "stopped", "pending"]))
        .action({ ctx =>
            let region = ctx.getFlagOrDefault("region", "all")
            let status = ctx.getFlagOrDefault("status", "all")
            println("Cloud Instances (region=${region}, status=${status}):")
            println("  ID            Region    Status    Type")
            println("  ──────────    ───────   ───────   ──────")
            println("  i-abc12345    us-east   running   t3.medium")
            println("  i-def67890    us-west   stopped   m5.large")
            println("  i-ghi24680    eu-west   running   t3.small")
            println("\n3 instances found.")
            0
        })

    let cloudStartCmd = Command("start")
        .description("Start a cloud instance")
        .argument(Argument("instance-id").description("Instance ID to start").required(true))
        .flag(Flag("wait").short(r'w').description("Wait for instance to be running").asBool())
        .action({ ctx =>
            match (ctx.getArgument(0)) {
                case Some(id) =>
                    println("Starting instance ${id}...")
                    if (ctx.getBoolFlag("wait")) {
                        println("Waiting for instance to reach 'running' state...")
                    }
                    println("Instance ${id} is now running.")
                    0
                case None =>
                    1
            }
        })

    let cloudCmd = Command("cloud")
        .alias("c")
        .description("Cloud infrastructure management")
        .subcommandGroup("Cloud Commands")
        .command(cloudListCmd)
        .command(cloudStartCmd)

    // ── lint: 静态检查 (对标 Clippy 场景) ──
    let lintCmd = Command("lint")
        .alias("l")
        .description("Run linter checks on source files")
        .subcommandGroup("Dev Commands")
        .example("Lint current project", "cj-devtool lint ./src")
        .example("Lint and auto-fix", "cj-devtool lint ./src --fix")
        .example("Pass extra args to linter", "cj-devtool lint ./src -- --strict --max-warnings 10")
        .beforeHelp("Run static analysis checks on your codebase.")
        .afterHelp("Use '--' to pass additional arguments to the underlying linter engine.")
        .argument(Argument("path").description("Path(s) to lint").minCount(0))
        .flag(Flag("fix").description("Auto-fix issues where possible").asBool())
        .flag(Flag("max-warnings").description("Maximum warnings before failing").valueType(Int64Type).defaultValue("100"))
        .flag(Flag("config-path").description("Custom config file path"))
        .flag(Flag("output").short(r'o').description("Output file path"))
        .flag(Flag("output-format").description("Output report format").choices(["text", "json", "markdown"]).requires("output"))
        .action({ ctx =>
            let fix = ctx.getBoolFlag("fix")
            let maxWarn = ctx.getFlagOrDefault("max-warnings", "100")
            let args = ctx.getArguments()
            let target = if (args.size > 0) { args[0] } else { "./src" }
            let mode = if (fix) { "fix" } else { "check" }

            println("Running linter (mode=${mode}) on ${target}...")
            println("  Max warnings: ${maxWarn}")

            // 展示 pass-through 参数
            let pt = ctx.getPassthroughArgs()
            if (pt.size > 0) {
                var ptStr = ""
                var first = true
                for (a in pt) {
                    if (!first) { ptStr = ptStr + " " }
                    ptStr = ptStr + a
                    first = false
                }
                println("  Extra args:   ${ptStr}")
            }

            println("")
            println("Checking source files...")
            println("  src/main.cj .............. ok")
            println("  src/parser.cj ............ 2 warnings")
            println("  src/utils.cj ............. ok")
            println("")
            if (fix) {
                println("Applied 2 automatic fixes.")
            } else {
                println("Found 2 warnings, 0 errors.")
            }
            0
        })

    // ── config: 配置管理 (含弃用 + 隐藏命令) ──
    let configShowCmd = Command("show")
        .description("Show current configuration")
        .action({ _ctx =>
            println("Current configuration:")
            println("  verbose = false")
            println("  color   = auto")
            println("  format  = text")
            println("  port    = 8080")
            println("  host    = 127.0.0.1")
            0
        })

    let configSetCmd = Command("set")
        .description("Set a configuration value")
        .argument(Argument("key").description("Configuration key").required(true))
        .argument(Argument("value").description("Configuration value").required(true))
        .action({ ctx =>
            let key = match (ctx.getArgument(0)) { case Some(k) => k; case None => "" }
            let value = match (ctx.getArgument(1)) { case Some(v) => v; case None => "" }
            println("Set '${key}' = '${value}'")
            0
        })

    // 弃用命令示例: init → 建议使用 config show
    let configInitCmd = Command("init")
        .description("Initialize configuration (use 'config show' instead)")
        .deprecated("Use 'config show' instead", replacement: "show")
        .action({ _ctx =>
            println("Initializing default configuration...")
            0
        })

    // 隐藏命令示例: debug — 不在帮助中显示但可正常使用
    let configDebugCmd = Command("debug")
        .description("Internal debug info")
        .hidden()
        .action({ _ctx =>
            println("Debug information:")
            println("  Framework version: 1.0.0")
            println("  Build target:      linux-x86_64")
            println("  Config path:       ./devtool.toml")
            0
        })

    let configCmd = Command("config")
        .description("Manage tool configuration")
        .subcommandGroup("Config Commands")
        .command(configShowCmd)
        .command(configSetCmd)
        .command(configInitCmd)
        .command(configDebugCmd)

    // ── completion: Shell 补全脚本生成 ──
    let completionCmd = Command("completion")
        .description("Generate shell completion scripts")
        .subcommandGroup("Utility Commands")
        .example("Generate Bash completion", "cj-devtool completion --shell bash > /etc/bash_completion.d/cj-devtool")
        .example("Generate Zsh completion", "cj-devtool completion --shell zsh > ~/.zsh/completions/_cj-devtool")
        .flag(Flag("shell").short(r's').description("Target shell").choices(["bash", "zsh", "fish"]).required(true))
        .action({ ctx =>
            let shell = ctx.getFlagOrDefault("shell", "bash")
            let shellType = match (parseShellType(shell)) {
                case Some(st) => st
                case None => Bash
            }
            // 使用框架的补全生成器，输出真实的补全脚本
            println(CompletionGenerator.generate(app.getRootCommand(), shellType))
            0
        })

    // 组装所有子命令
    app.command(serveCmd)
       .command(deployCmd)
       .command(cloudCmd)
       .command(lintCmd)
       .command(configCmd)
       .command(completionCmd)

    // 真实执行
    app.run()
}
