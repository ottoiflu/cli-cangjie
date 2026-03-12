# cj-devtool — Cangjie CLI Framework 示例应用

基于 [Cangjie CLI Framework](../) 构建的完整 DevOps 命令行工具示例。本程序演示了框架全部核心特性，你可以直接编译运行来体验框架效果。

## 快速开始

1. 确保已安装仓颉编译器 (cjc >= 1.0.5) 和 cjpm 构建工具

2. 编译示例程序

    ```bash
    cd example
    cjpm build
    ```

3. 运行

    ```bash
    ./target/release/bin/main --help
    ```

## 命令概览

```
cj-devtool <COMMAND> [OPTIONS]

Server Commands:
  serve (s)      启动开发服务器
Deploy Commands:
  deploy (d)     部署应用到目标环境
Cloud Commands:
  cloud (c)      云基础设施管理
Dev Commands:
  lint (l)       对源代码执行静态检查
Config Commands:
  config         管理工具配置
Utility Commands:
  completion     生成 Shell 自动补全脚本

全局选项:
  -v, --verbose                      启用详细输出
      --color <auto|always|never>    颜色模式 [默认: auto]
  -f, --format <text|json>           输出格式 [默认: text]
  -h, --help                         显示帮助
  -V, --version                      显示版本
```

## 功能演示

### 帮助与版本

```bash
# 查看主帮助
./target/release/bin/main --help

# 查看子命令帮助 (含 Examples 段落、afterHelp 等)
./target/release/bin/main serve --help
./target/release/bin/main lint --help

# 查看版本 (含构建元数据: commit hash、构建时间)
./target/release/bin/main --version
# 输出: cj-devtool 1.0.0 (abc1234 2026-03-13)
```

### serve — 启动开发服务器

```bash
# 使用默认端口 (8080)
./target/release/bin/main serve

# 自定义端口和主机
./target/release/bin/main serve --port 3000 --host 0.0.0.0

# 使用短选项
./target/release/bin/main s -p 3000 -H 0.0.0.0

# 启用 TLS (--cert 和 --key 依赖 --tls)
./target/release/bin/main serve --port 443 --tls --cert ./cert.pem --key ./key.pem
```

**演示特性**: 子命令别名 (`s`)、短选项 (`-p`, `-H`)、Flag 依赖 (`requires("tls")`)、Int64 类型转换、默认值、环境变量映射

### deploy — 部署应用

```bash
# 部署到 staging 环境
./target/release/bin/main deploy --env staging --tag v1.0.0

# 模拟部署 (dry-run)
./target/release/bin/main deploy --env production --tag v2.0.0 --dry-run

# 指定副本数 + 通知渠道 (逗号分隔多值)
./target/release/bin/main deploy --env staging --tag v1.0.0 --replicas 3 --notify slack,email

# 使用短选项
./target/release/bin/main d -e staging -t v1.0.0 -r 3 -n slack,email
```

**演示特性**: 枚举值约束 (`choices`)、值分隔符 (`delimiter`)、自定义验证器 (`replicas` 1-100)、互斥标志 (`--force` 与 `--dry-run`)、必填标志 (`required`)

### cloud — 云基础设施管理 (嵌套子命令)

```bash
# 列出所有实例
./target/release/bin/main cloud list

# 按区域筛选
./target/release/bin/main cloud list --region us-east

# 启动实例 (位置参数)
./target/release/bin/main cloud start i-abc12345

# 启动并等待运行状态
./target/release/bin/main cloud start i-abc12345 --wait

# 使用别名
./target/release/bin/main c ls -r us-west
```

**演示特性**: 嵌套子命令树 (`cloud list`, `cloud start`)、位置参数 (`instance-id`)、命令别名 (`c`, `ls`)

### lint — 静态代码检查 (对标 Clippy)

```bash
# 检查当前项目
./target/release/bin/main lint ./src

# 自动修复
./target/release/bin/main lint ./src --fix

# 透传参数给底层引擎 (-- 后的参数)
./target/release/bin/main lint ./src -- --strict --max-warnings 10

# 输出到文件 (--output-format 依赖 --output)
./target/release/bin/main lint ./src --output report.txt --output-format markdown
```

**演示特性**: Pass-Through 参数 (`--`)、Flag 依赖链 (`--output-format` 依赖 `--output`)、beforeHelp/afterHelp

### config — 配置管理

```bash
# 查看当前配置
./target/release/bin/main config show

# 设置配置项 (两个位置参数)
./target/release/bin/main config set port 3000

# 使用弃用命令 (会输出 Warning 迁移提示)
./target/release/bin/main config init

# 使用隐藏命令 (不在 --help 中显示，但可正常调用)
./target/release/bin/main config debug
```

**演示特性**: 弃用命令 (`deprecated`)、隐藏命令 (`hidden`)、多个位置参数

### completion — Shell 补全脚本

```bash
# 生成 Bash 补全
./target/release/bin/main completion --shell bash

# 生成 Zsh 补全
./target/release/bin/main completion --shell zsh

# 生成 Fish 补全
./target/release/bin/main completion --shell fish

# 安装 Bash 补全
./target/release/bin/main completion --shell bash > ~/.local/share/bash-completion/completions/cj-devtool
```

**演示特性**: Shell 补全生成 (Bash/Zsh/Fish)、choices 约束

## 错误处理与诊断演示

框架提供 Clippy 级别的诊断体验，以下命令展示各种错误场景：

```bash
# 拼写纠错 (Did-You-Mean)
./target/release/bin/main deploay
# error: Unknown command 'deploay'. Did you mean 'deploy'?

# 未知选项建议
./target/release/bin/main serve --prot 3000
# error: Unknown option '--prot'. Did you mean '--port'?

# 枚举值校验
./target/release/bin/main deploy --env invalid --tag v1.0
# error: Invalid value 'invalid' for '--env'. Valid options: 'dev', 'staging', 'production'.

# 互斥标志冲突
./target/release/bin/main deploy --env staging --tag v1.0 --dry-run --force
# error: Flag '--force' cannot be used together with '--dry-run'.

# 自定义验证器
./target/release/bin/main deploy --env staging --tag v1.0 --replicas 200
# error: Invalid value for '--replicas': must be an integer between 1 and 100

# 缺少必填参数
./target/release/bin/main deploy --env staging
# error: Required flag '--tag' is missing.

# Flag 依赖检查
./target/release/bin/main serve --cert ./cert.pem
# error: Flag '--cert' requires '--tls' to be set.
```

所有错误均包含：视觉化定位 (指向出错位置)、退出码 2、帮助提示。

## 环境变量映射

框架支持通过环境变量覆盖 Flag 默认值，优先级：CLI 参数 > 环境变量 > 配置文件 > 默认值。

本示例使用 `DEVTOOL` 前缀，映射规则：`--flag-name` → `DEVTOOL_FLAG_NAME`

```bash
# 通过环境变量设置端口
DEVTOOL_PORT=9090 ./target/release/bin/main serve
# 输出: Listening on: http://127.0.0.1:9090

# CLI 参数优先于环境变量
DEVTOOL_PORT=9090 ./target/release/bin/main serve --port 3000
# 输出: Listening on: http://127.0.0.1:3000

# 设置主机
DEVTOOL_HOST=0.0.0.0 ./target/release/bin/main serve
```

## 全局标志与中间件

```bash
# --verbose 全局标志输出调试信息
./target/release/bin/main deploy -v --env dev --tag v1.0
# [verbose] Command starting...
# Deploying application...
#   Environment: dev
#   ...
# [verbose] Command finished with exit code: 0
```

## 退出码规范

| 退出码 | 含义 |
|--------|------|
| 0      | 执行成功 |
| 1      | 业务逻辑错误 |
| 2      | 参数解析/框架错误 |
| 130    | SIGINT (Ctrl+C) |
| 143    | SIGTERM |

```bash
# 验证退出码
./target/release/bin/main serve; echo $?        # 0
./target/release/bin/main deploay; echo $?      # 2
```

## 项目结构

```
example/
├── cjpm.toml          # 项目配置，依赖 cli = { path = ".." }
├── src/
│   └── main.cj        # 示例应用入口
└── README.md           # 本文件
```

## 框架特性速查

本示例覆盖的框架特性完整列表：

| 特性 | 演示位置 |
|------|----------|
| 子命令树 (无限层级) | `cloud list`, `cloud start` |
| 命令别名 | `serve`→`s`, `deploy`→`d`, `cloud`→`c`, `lint`→`l` |
| 短选项 | `-p`, `-H`, `-e`, `-t`, `-r`, `-n`, `-v`, `-f` |
| 布尔开关 | `--tls`, `--fix`, `--dry-run`, `--force`, `--wait` |
| 必填标志 | `--env`, `--tag`, `--shell` |
| 默认值 | `--port 8080`, `--host 127.0.0.1`, `--replicas 1` |
| 枚举值约束 (choices) | `--env`, `--color`, `--format`, `--shell` |
| 值分隔符 (delimiter) | `--notify slack,email` |
| 自定义验证器 | `--replicas` (1-100) |
| 互斥标志 | `--force` ⟂ `--dry-run` |
| Flag 依赖 | `--cert`→`--tls`, `--output-format`→`--output` |
| 位置参数 | `cloud start <instance-id>`, `config set <key> <value>` |
| Pass-Through (`--`) | `lint ./src -- --strict` |
| 全局标志传播 | `--verbose`, `--color`, `--format` |
| 中间件 | verbose 模式调试输出 |
| 生命周期钩子 | `persistentPreRun`, `persistentPostRun` |
| 环境变量映射 | `DEVTOOL_PORT`, `DEVTOOL_HOST` |
| 配置文件 | `devtool.toml` |
| Shell 补全生成 | Bash / Zsh / Fish |
| 版本信息 (构建元数据) | commit hash, 构建时间 |
| 弃用命令 | `config init` |
| 隐藏命令 | `config debug` |
| 子命令分组显示 | Server / Deploy / Cloud / Dev / Config / Utility |
| 帮助 Examples | `serve --help`, `lint --help` |
| afterHelp / beforeHelp | `serve --help`, `lint --help` |
| Did-You-Mean 智能建议 | 命令/选项拼写错误 |
| 视觉化错误定位 | 所有错误输出 |
| 标准退出码 | 0 / 1 / 2 / 130 / 143 |
