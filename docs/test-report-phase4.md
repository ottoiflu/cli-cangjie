# 仓颉 CLI 框架 — Phase 4 测试报告

## 1. 基本信息

| 项目     | 值                                                  |
| -------- | --------------------------------------------------- |
| 项目名称 | cangjie-cli-framework                               |
| 阶段     | Phase 4 — 快照测试 (Golden Files) 与交互式模拟 (Input Mock) |
| 版本     | v0.4.0                                              |
| 测试框架 | `std.unittest` (cjpm test)                          |
| 执行环境 | Linux x86_64                                        |
| 执行日期 | 2026-03-12                                          |

## 2. 测试执行总览

| 指标         | 结果     |
| ------------ | -------- |
| **总用例数** | 169      |
| **通过**     | 169      |
| **失败**     | 0        |
| **跳过**     | 0        |
| **错误**     | 0        |
| **通过率**   | **100%** |
| **总耗时**   | 22.23 ms |

## 3. Phase 4 新增测试结果明细

### 3.1 SnapshotTest — 9/9 PASSED (新增)

| 用例名                            | 结果   | 耗时 (ns) |
| --------------------------------- | ------ | ---------- |
| testFirstRunCreatesGoldenFile     | PASSED | 103578     |
| testMatchingSnapshot              | PASSED | 79783      |
| testMismatchGeneratesNewFile      | PASSED | 96174      |
| testUpdateOverwritesGolden        | PASSED | 1528842    |
| testDiffShowsLineChanges          | PASSED | 100982     |
| testHelpSnapshotRoundtrip         | PASSED | 155250     |
| testErrorSnapshotRoundtrip        | PASSED | 130237     |
| testSubcommandHelpSnapshot        | PASSED | 117001     |
| testSnapshotDetectsUIRegression   | PASSED | 96641      |

**测试套件耗时**: 3239618 ns

### 3.2 InputMockTest — 5/5 PASSED (新增)

| 用例名                  | 结果   | 耗时 (ns) |
| ----------------------- | ------ | ---------- |
| testReadLine            | PASSED | 11251      |
| testReadLineOrDefault   | PASSED | 8255       |
| testHasMore             | PASSED | 10187      |
| testReset               | PASSED | 7783       |
| testAddLines            | PASSED | 9084       |

**测试套件耗时**: 356331 ns

### 3.3 PromptTest — 9/9 PASSED (新增)

| 用例名               | 结果   | 耗时 (ns) |
| -------------------- | ------ | ---------- |
| testAsk              | PASSED | 7464       |
| testAskOrDefault     | PASSED | 8042       |
| testConfirmYes       | PASSED | 8036       |
| testConfirmNo        | PASSED | 7538       |
| testConfirmEOF       | PASSED | 6859       |
| testSelect           | PASSED | 8855       |
| testSelectInvalid    | PASSED | 8194       |
| testSelectZero       | PASSED | 6461       |
| testPromptInAction   | PASSED | 21161      |

**测试套件耗时**: 532760 ns

## 4. 全量回归测试结果

### 4.1 已有模块 (Phase 1~3)

| 测试套件                    | 用例数 | 通过 | 失败 | 耗时 (ns)  |
| --------------------------- | ------ | ---- | ---- | ---------- |
| ArgumentDefinitionTest      | 5      | 5    | 0    | 726043     |
| CommandBuilderTest          | 9      | 9    | 0    | 590131     |
| ContextTest                 | 11     | 11   | 0    | 828124     |
| FlagDefinitionTest          | 9      | 9    | 0    | 551814     |
| AppIntegrationTest          | 16     | 16   | 0    | 1506905    |
| ParserTest                  | 24     | 24   | 0    | 1740256    |
| TypeConversionTest          | 10     | 10   | 0    | 615226     |
| SuggestTest                 | 14     | 14   | 0    | 916186     |
| StyleTest                   | 10     | 10   | 0    | 598982     |
| DiagnosticTest              | 9      | 9    | 0    | 577929     |
| DidYouMeanIntegrationTest   | 6      | 6    | 0    | 600511     |
| LifecycleTest               | 6      | 6    | 0    | 464387     |
| MiddlewareTest              | 5      | 5    | 0    | 405082     |
| EnvVarTest                  | 5      | 5    | 0    | 431486     |
| ContextValueTest            | 4      | 4    | 0    | 291019     |

### 4.2 Phase 4 新增模块

| 测试套件                    | 用例数 | 通过 | 失败 | 耗时 (ns)  |
| --------------------------- | ------ | ---- | ---- | ---------- |
| SnapshotTest                | 9      | 9    | 0    | 3239618    |
| InputMockTest               | 5      | 5    | 0    | 356331     |
| PromptTest                  | 9      | 9    | 0    | 532760     |

## 5. 测试覆盖分析

| 功能模块                         | 覆盖场景                                                                         |
| -------------------------------- | -------------------------------------------------------------------------------- |
| 快照 — 首次运行                  | 自动创建 .golden 文件                                                            |
| 快照 — 匹配比对                  | 输出与 golden 文件完全一致时返回 matched=true                                     |
| 快照 — 不匹配检测                | 发现差异时生成 .golden.new 文件并提供 diff 描述                                   |
| 快照 — 更新模式 (bless)          | 用实际输出覆盖 golden 文件                                                        |
| 快照 — 行级 Diff                 | diff 输出包含 expected/actual 标签和具体行差异                                    |
| 快照 — Help 输出稳定性           | 两次 mockRun --help 结果一致                                                      |
| 快照 — 错误输出稳定性            | 两次相同错误输入产生一致的诊断输出                                                 |
| 快照 — 子命令 Help 快照          | 子命令级别的 help 输出稳定性验证                                                   |
| 快照 — UI 回退检测               | 选项描述变更被正确识别为 mismatch                                                  |
| InputMock — 基本读取             | readLine 按队列顺序返回预设输入                                                   |
| InputMock — EOF 处理             | 超出预设范围返回 None / 使用默认值                                                 |
| InputMock — 状态查询             | hasMore/consumed/remaining 正确反映状态                                           |
| InputMock — 重置                 | reset 后可重新读取同一组输入                                                       |
| InputMock — 批量添加             | addLines 批量注入输入行                                                           |
| Prompt — 文本输入                | ask 返回预设文本                                                                  |
| Prompt — 带默认值               | 空输入使用默认值，非空输入使用实际值                                                |
| Prompt — 确认 (y/n)             | y/yes/Y/YES 返回 true，n/no/空/EOF 返回 false                                    |
| Prompt — 选择                   | 有效序号返回对应选项，无效序号返回 None                                             |
| Prompt — 与 Action 集成         | 在 mockRun action 中使用 Prompt 读取模拟输入                                       |

## 6. 版本增量对比

| 指标         | v0.1.0 | v0.2.0 | v0.3.0 | v0.4.0       |
| ------------ | ------ | ------ | ------ | ------------ |
| 测试总数     | 87     | 126    | 146    | **169**      |
| 新增用例     | —      | +39    | +20    | **+23**      |
| 测试套件数   | 7      | 11     | 15     | **18**       |
| 通过率       | 100%   | 100%   | 100%   | **100%**     |
| 源文件数     | 8      | 11     | 11     | **13**       |
| 测试文件数   | 7      | 10     | 11     | **12**       |

## 7. 总结

Phase 4 新增 3 个测试套件共 23 个测试用例，完整覆盖快照测试引擎（创建/比对/更新/diff/UI回退检测）和交互式输入模拟（InputMock 队列、Prompt 文本/确认/选择、Action 集成）。所有 169 个测试用例全部通过，无回归问题。
