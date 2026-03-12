# 示例应用: cj-devtool

完整的端到端示例 DevOps CLI 工具, 演示 Cangjie CLI Framework 全部核心特性。

源码位于 `src/example.cj`，测试位于 `src/test/phase11_test.cj`。

## 特性覆盖

- **子命令树**: serve / deploy / cloud (list, start) / lint / config (show, set, init, debug) / completion
- **全局标志**: --verbose / --color / --format, 自动传播至所有子命令
- **别名系统**: serve→s, deploy→d, cloud→c, lint→l, list→ls
- **Flag 约束**: 互斥 (force↔dry-run)、依赖 (cert→tls)、自定义验证器 (replicas 1-100)
- **Choices 枚举**: --env dev|staging|production, --region, --color, --format
- **值分隔符**: --notify slack,email,pager
- **Pass-Through**: lint ./src -- --strict --max-warnings 10
- **配置文件**: devtool.toml, 四级优先级管道
- **环境变量**: DEVTOOL_ 前缀自动映射
- **帮助增强**: Examples 段落、afterHelp、beforeHelp、子命令分组
- **弃用系统**: config init (deprecated)
- **隐藏命令**: config debug (hidden)
- **VersionInfo**: 丰富版本信息 (commit hash, build date)
- **信号处理**: SIGINT → 130, SIGTERM → 143
- **Did-You-Mean**: 命令/Flag 拼写纠错
