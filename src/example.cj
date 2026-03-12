// =============================================================================
// Cangjie CLI Framework — 完整示例应用: cj-devtool
//
// 演示框架全部核心特性的端到端示例 DevOps 工具
// 特性覆盖: 子命令树、Flag 约束、配置文件、帮助生成、Shell 补全、
//           中间件、生命周期钩子、环境变量映射、诊断系统、信号处理等
// =============================================================================

package cli

import std.collection.*

// ---- 辅助：构建示例 App ----

public func buildExampleApp(): App {
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
        .globalFlag(Flag("verbose").short(r'v').description("Enable verbose output").asBool())
        .globalFlag(Flag("color").description("Color output mode").choices(["auto", "always", "never"]).defaultValue("auto"))
        .globalFlag(Flag("format").short(r'f').description("Output format").choices(["text", "json"]).defaultValue("text"))
        // 全局中间件：记录命令执行
        .use({ ctx, next =>
            if (ctx.getBoolFlag("verbose")) {
                ctx.setValue("_verbose", "true")
            }
            next()
        })
        // 全局前置钩子
        .persistentPreRun({ ctx =>
            ctx.setValue("_started", "true")
        })
        // 全局后置钩子
        .persistentPostRun({ ctx =>
            ctx.setValue("_finished", "true")
        })

    // ---- 子命令: serve ----
    let serveCmd = Command("serve")
        .alias("s")
        .description("Start a development server")
        .subcommandGroup("Server Commands")
        .example("Start on default port", "cj-devtool serve")
        .example("Start on custom port", "cj-devtool serve --port 3000 --host 0.0.0.0")
        .afterHelp("Environment: DEVTOOL_PORT, DEVTOOL_HOST")
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
            ctx.setValue("_serve_result", "${scheme}://${host}:${port}")
            0
        })

    // ---- 子命令: deploy ----
    let deployCmd = Command("deploy")
        .alias("d")
        .description("Deploy application to target environment")
        .subcommandGroup("Deploy Commands")
        .example("Deploy to staging", "cj-devtool deploy --env staging --tag v1.0.0")
        .flag(Flag("env").short(r'e').description("Target environment").choices(["dev", "staging", "production"]).required(true))
        .flag(Flag("tag").short(r't').description("Image tag to deploy").required(true))
        .flag(Flag("dry-run").description("Simulate deployment without executing").asBool())
        .flag(Flag("force").description("Force deploy, skip confirmation").asBool().conflictsWith("dry-run"))
        .flag(Flag("replicas").short(r'r').description("Number of replicas").valueType(Int64Type).defaultValue("1")
            .validator({ v =>
                if (!isValidInt(v)) { return false }
                let n = parseSimpleInt(v)
                n > 0 && n <= 100
            }, message: "must be 1-100"))
        .flag(Flag("notify").short(r'n').description("Notification channels").delimiter(r','))
        .action({ ctx =>
            let env = ctx.getFlagOrDefault("env", "dev")
            let tag = ctx.getFlagOrDefault("tag", "latest")
            let dryRun = ctx.getBoolFlag("dry-run")
            let replicas = ctx.getFlagOrDefault("replicas", "1")
            let prefix = if (dryRun) { "[DRY-RUN] " } else { "" }
            ctx.setValue("_deploy_result", "${prefix}Deploying ${tag} to ${env} (${replicas} replicas)")
            // 处理通知渠道
            match (ctx.getFlagAll("notify")) {
                case Some(channels) =>
                    let list = ArrayList<String>()
                    for (c in channels) { list.add(c) }
                    ctx.setValue("_notify_channels", list.size.toString())
                case None => ()
            }
            0
        })

    // ---- 子命令树: cloud (嵌套子命令) ----
    let cloudListCmd = Command("list")
        .alias("ls")
        .description("List cloud instances")
        .flag(Flag("region").short(r'r').description("Filter by region").choices(["us-east", "us-west", "eu-west", "ap-east"]))
        .flag(Flag("status").description("Filter by status").choices(["running", "stopped", "pending"]))
        .action({ ctx =>
            let region = ctx.getFlagOrDefault("region", "all")
            ctx.setValue("_cloud_list_result", "Listing instances in ${region}")
            0
        })

    let cloudStartCmd = Command("start")
        .description("Start a cloud instance")
        .argument(Argument("instance-id").description("Instance ID to start").required(true))
        .flag(Flag("wait").short(r'w').description("Wait for instance to be running").asBool())
        .action({ ctx =>
            match (ctx.getArgument(0)) {
                case Some(id) =>
                    ctx.setValue("_cloud_start_result", "Starting instance ${id}")
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

    // ---- 子命令: lint (对标 Clippy 场景) ----
    let lintCmd = Command("lint")
        .alias("l")
        .description("Run linter checks on source files")
        .subcommandGroup("Dev Commands")
        .example("Lint current project", "cj-devtool lint ./src")
        .example("Lint with extra args", "cj-devtool lint ./src -- --strict --max-warnings 10")
        .beforeHelp("Run static analysis checks on your codebase.")
        .afterHelp("Use '--' to pass additional arguments to the underlying linter.")
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
            ctx.setValue("_lint_result", "Linting ${target} (mode=${mode}, max-warnings=${maxWarn})")
            // Pass-through args
            let pt = ctx.getPassthroughArgs()
            if (pt.size > 0) {
                ctx.setValue("_lint_passthrough_count", pt.size.toString())
            }
            0
        })

    // ---- 子命令: config (弃用示例 + 隐藏) ----
    let configShowCmd = Command("show")
        .description("Show current configuration")
        .action({ ctx =>
            ctx.setValue("_config_result", "config-show")
            0
        })

    let configSetCmd = Command("set")
        .description("Set a configuration value")
        .argument(Argument("key").description("Configuration key").required(true))
        .argument(Argument("value").description("Configuration value").required(true))
        .action({ ctx =>
            let key = match (ctx.getArgument(0)) { case Some(k) => k; case None => "" }
            let value = match (ctx.getArgument(1)) { case Some(v) => v; case None => "" }
            ctx.setValue("_config_result", "config-set:${key}=${value}")
            0
        })

    let configOldCmd = Command("init")
        .description("Initialize configuration (use 'config show' instead)")
        .deprecated("Use 'config show' instead", replacement: "show")
        .action({ ctx =>
            ctx.setValue("_config_result", "config-init-deprecated")
            0
        })

    // 隐藏的内部诊断命令
    let configDebugCmd = Command("debug")
        .description("Internal debug info")
        .hidden()
        .action({ ctx =>
            ctx.setValue("_config_result", "config-debug-hidden")
            0
        })

    let configCmd = Command("config")
        .description("Manage tool configuration")
        .subcommandGroup("Config Commands")
        .command(configShowCmd)
        .command(configSetCmd)
        .command(configOldCmd)
        .command(configDebugCmd)

    // ---- 子命令: completion ----
    let completionCmd = Command("completion")
        .description("Generate shell completion scripts")
        .subcommandGroup("Utility Commands")
        .flag(Flag("shell").short(r's').description("Target shell").choices(["bash", "zsh", "fish"]).required(true))
        .action({ ctx =>
            let shell = ctx.getFlagOrDefault("shell", "bash")
            ctx.setValue("_completion_shell", shell)
            0
        })

    // 组装
    app.command(serveCmd)
       .command(deployCmd)
       .command(cloudCmd)
       .command(lintCmd)
       .command(configCmd)
       .command(completionCmd)

    app
}
