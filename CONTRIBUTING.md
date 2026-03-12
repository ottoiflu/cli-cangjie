# 贡献指南

感谢你对 Cangjie CLI Framework 的关注！欢迎以任何形式参与贡献。

## 开发环境

- 仓颉编译器 `cjc` >= 1.0.5
- 构建工具 `cjpm`

```bash
# 克隆项目
git clone <repo-url>
cd cli

# 构建
cjpm build

# 运行测试
cjpm test
```

## 项目结构

```
src/
  app.cj          # App 入口、mockRun 沙箱
  command.cj       # 命令树
  flag.cj          # Flag 定义
  argument.cj      # 位置参数
  parser.cj        # 解析引擎
  context.cj       # 执行上下文
  types.cj         # 值类型与转换
  errors.cj        # 异常体系
  diagnostic.cj    # 诊断系统
  suggest.cj       # 编辑距离 & Did-You-Mean
  style.cj         # ANSI 样式
  config.cj        # 配置文件加载
  input.cj         # InputMock / Prompt
  widget.cj        # 交互组件
  snapshot.cj      # 快照测试
  completion.cj    # Shell 补全生成
  advanced.cj      # 高级特性
  test/            # 测试套件
example/           # 示例应用
```

## 提交规范

采用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
feat: 添加新特性描述
fix: 修复 Bug 描述
test: 新增或更新测试
docs: 文档更新
refactor: 重构（无功能变更）
```

## 测试要求

- 所有新功能必须附带测试用例
- 使用 `cjpm test` 确保全部测试通过
- 使用框架的 `mockRun` API 编写集成测试
- 测试文件放在 `src/test/` 目录

```cangjie
@Test
class MyFeatureTest {
    @TestCase
    func testBasicCase() {
        let app = App("test-app")
            .command(Command("cmd").action({ _ => 0 }))
        let result = app.mockRun(["cmd"])
        @Expect(result.exitCode, 0)
    }
}
```

## 代码风格

- 遵循仓颉语言官方编码规范
- Builder 方法返回 `This` 以支持链式调用
- 公开 API 使用 `public` 修饰
- 测试文件使用 `internal package cli.test`

## Pull Request 流程

1. Fork 项目并创建功能分支
2. 编写代码和测试
3. 确保 `cjpm test` 全部通过
4. 提交 PR 并描述变更内容

## 许可证

贡献的代码将遵循项目的 [Apache-2.0 许可证](LICENSE)。
