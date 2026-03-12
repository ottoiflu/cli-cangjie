# 仓颉 CLI 框架 — Phase 3 测试报告

## 1. 基本信息

| 项目     | 值                                                       |
| -------- | -------------------------------------------------------- |
| 项目名称 | cangjie-cli-framework                                    |
| 阶段     | Phase 3 — 生命周期钩子、中间件、环境变量合并、Context DI |
| 版本     | v0.3.0                                                   |
| 测试框架 | `std.unittest` (cjpm test)                               |
| 执行环境 | Linux x86_64                                             |
| 执行日期 | 2026-03-12                                               |

## 2. 测试执行总览

| 指标         | 结果     |
| ------------ | -------- |
| **总用例数** | 146      |
| **通过**     | 146      |
| **失败**     | 0        |
| **跳过**     | 0        |
| **错误**     | 0        |
| **通过率**   | **100%** |
| **总耗时**   | 19.88 ms |

## 3. Phase 3 新增测试结果明细

### 3.1 LifecycleTest — 6/6 PASSED (新增)

| 用例名                      | 结果   | 耗时 (ns) |
| --------------------------- | ------ | ---------- |
| testPreRunHook              | PASSED | 21259      |
| testPostRunHook             | PASSED | 19522      |
| testPersistentPreRunHook    | PASSED | 18811      |
| testPersistentPostRunHook   | PASSED | 19604      |
| testFullLifecycleOrder      | PASSED | 21239      |
| testNoHooksStillWorks       | PASSED | 16626      |

**测试套件耗时**: 464387 ns

### 3.2 MiddlewareTest — 5/5 PASSED (新增)

| 用例名                            | 结果   | 耗时 (ns) |
| --------------------------------- | ------ | ---------- |
| testGlobalMiddleware              | PASSED | 20441      |
| testCommandLocalMiddleware        | PASSED | 20811      |
| testMultipleMiddlewareChaining    | PASSED | 19309      |
| testMiddlewareCanShortCircuit     | PASSED | 17130      |
| testMiddlewareWithLifecycleHooks  | PASSED | 19867      |

**测试套件耗时**: 405082 ns

### 3.3 EnvVarTest — 5/5 PASSED (新增)

| 用例名                          | 结果   | 耗时 (ns) |
| ------------------------------- | ------ | ---------- |
| testExplicitEnvVarMapping       | PASSED | 27549      |
| testCLIFlagOverridesEnvVar      | PASSED | 22591      |
| testAutoEnvPrefixMapping        | PASSED | 24231      |
| testEnvVarNotSetUsesDefault     | PASSED | 22824      |
| testExplicitEnvOverridesAutoPrefix | PASSED | 25625   |

**测试套件耗时**: 431486 ns

### 3.4 ContextValueTest — 4/4 PASSED (新增)

| 用例名                  | 结果   | 耗时 (ns) |
| ----------------------- | ------ | ---------- |
| testSetAndGetValue      | PASSED | 10139      |
| testHasValue            | PASSED | 11480      |
| testValueOverwrite      | PASSED | 9639       |
| testValueInMiddleware   | PASSED | 20404      |

**测试套件耗时**: 291019 ns

## 4. 全量回归测试结果

### 4.1 已有模块 (Phase 1 + Phase 2)

| 测试套件                    | 用例数 | 通过 | 失败 | 耗时 (ns)  |
| --------------------------- | ------ | ---- | ---- | ---------- |
| ArgumentDefinitionTest      | 5      | 5    | 0    | 726043     |
| CommandBuilderTest          | 9      | 9    | 0    | 590131     |
| ContextTest                 | 11     | 11   | 0    | 828124     |
| FlagDefinitionTest          | 9      | 9    | 0    | 551814     |
| AppIntegrationTest          | 16     | 16   | 0    | 1506905    |
| ParserTest                  | 24     | 24   | 0    | 1740256    |
| TypeConversionTest          | 10     | 10   | 0    | 646831     |
| SuggestTest                 | 14     | 14   | 0    | 973793     |
| StyleTest                   | 10     | 10   | 0    | 641727     |
| DiagnosticTest              | 9      | 9    | 0    | 577929     |
| DidYouMeanIntegrationTest   | 6      | 6    | 0    | 600511     |

### 4.2 Phase 3 新增模块

| 测试套件                    | 用例数 | 通过 | 失败 | 耗时 (ns)  |
| --------------------------- | ------ | ---- | ---- | ---------- |
| LifecycleTest               | 6      | 6    | 0    | 464387     |
| MiddlewareTest              | 5      | 5    | 0    | 405082     |
| EnvVarTest                  | 5      | 5    | 0    | 431486     |
| ContextValueTest            | 4      | 4    | 0    | 291019     |

## 5. 测试覆盖分析

| 功能模块                         | 覆盖场景                                                                         |
| -------------------------------- | -------------------------------------------------------------------------------- |
| 生命周期钩子 — PreRun/PostRun    | 单独 PreRun、单独 PostRun、不设钩子仍正常执行                                     |
| 生命周期钩子 — Persistent*       | PersistentPreRun 在子命令前执行、PersistentPostRun 在子命令后执行                  |
| 生命周期钩子 — 完整顺序          | PersistentPreRun → PreRun → Action → PostRun → PersistentPostRun 五阶段有序执行   |
| 中间件 — 全局                    | 全局中间件包裹 action 执行                                                        |
| 中间件 — 命令级别                | 命令本地中间件仅作用于该命令                                                       |
| 中间件 — 多层链式                | 全局 + 本地中间件按注册顺序依次执行                                                |
| 中间件 — 短路机制                | 中间件不调用 next() 可阻断后续执行                                                 |
| 中间件 — 与钩子协作              | 钩子在中间件外层正确触发                                                           |
| 环境变量 — 显式映射              | `envVar("VAR")` 显式绑定环境变量到 flag                                           |
| 环境变量 — CLI 优先级            | CLI 显式传值优先于环境变量                                                         |
| 环境变量 — 自动前缀              | `envPrefix("PREFIX")` 自动映射 `PREFIX_FLAG_NAME`                                 |
| 环境变量 — 缺省回退              | 环境变量不存在时使用 `defaultValue`                                                |
| 环境变量 — 优先级链              | 显式 envVar 优先于自动前缀映射                                                     |
| Context DI — 基本存取            | `setValue`/`getValue` 正确存取字符串                                               |
| Context DI — 存在性检查          | `hasValue` 在设置前返回 false，设置后返回 true                                     |
| Context DI — 覆盖写入            | 同 key 多次写入，后值覆盖前值                                                      |
| Context DI — 中间件传递          | 中间件通过 Context 注入值，action 中可读取                                          |

## 6. 版本增量对比

| 指标         | v0.1.0 | v0.2.0 | v0.3.0       |
| ------------ | ------ | ------ | ------------ |
| 测试总数     | 87     | 126    | **146**      |
| 新增用例     | —      | +39    | **+20**      |
| 测试套件数   | 7      | 11     | **15**       |
| 通过率       | 100%   | 100%   | **100%**     |
| 源文件数     | 8      | 11     | 11 (修改 3)  |
| 测试文件数   | 7      | 10     | **11**       |

## 7. 总结

Phase 3 新增 4 个测试套件共 20 个测试用例，覆盖生命周期钩子执行顺序、中间件链式调用与短路机制、环境变量三级优先级合并、Context 依赖注入全部核心场景。所有 146 个测试用例全部通过，无回归问题。
