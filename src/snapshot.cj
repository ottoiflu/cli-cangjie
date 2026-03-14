package cli

import std.fs.*

// 快照比对结果
public class SnapshotResult {
    // 是否匹配
    public let matched: Bool
    // 期望内容
    public let expected: String
    // 实际内容
    public let actual: String
    // 差异描述
    public let diff: String

    public init(matched: Bool, expected: String, actual: String, diff: String) {
        this.matched = matched
        this.expected = expected
        this.actual = actual
        this.diff = diff
    }
}

// 快照测试引擎：Golden File 比对
// 模式 1: compareSnapshot — 与磁盘上的 .golden 文件比对
// 模式 2: assertSnapshot — 直接断言匹配，不匹配时生成 .new 文件
public class Snapshot {
    // 快照文件根目录
    let _snapshotDir: String

    public init(snapshotDir!: String = "src/test/snapshots") {
        _snapshotDir = snapshotDir
    }

    // 比对快照：返回 SnapshotResult
    // name: 快照名称（不含扩展名，如 "help_main"）
    // actual: 实际输出
    public func compare(name: String, actual: String): SnapshotResult {
        let goldenPath = Path("${_snapshotDir}/${name}.golden")

        if (!exists(goldenPath)) {
            // 首次运行：自动创建 golden 文件
            ensureDir(_snapshotDir)
            writeText(goldenPath.toString(), actual)
            return SnapshotResult(true, actual, actual, "")
        }

        let expected = readText(goldenPath.toString())
        if (actual == expected) {
            return SnapshotResult(true, expected, actual, "")
        }

        // 不匹配：生成 .new 文件和 diff
        let newPath = "${_snapshotDir}/${name}.golden.new"
        writeText(newPath, actual)
        let diff = generateDiff(name, expected, actual)
        return SnapshotResult(false, expected, actual, diff)
    }

    // 更新快照（bless 模式）：用实际输出覆盖 golden 文件
    public func update(name: String, actual: String): Unit {
        ensureDir(_snapshotDir)
        let goldenPath = "${_snapshotDir}/${name}.golden"
        writeText(goldenPath, actual)
        // 清理 .new 文件
        let newPath = "${_snapshotDir}/${name}.golden.new"
        if (exists(Path(newPath))) {
            remove(Path(newPath))
        }
    }

    // 生成行级 diff 描述
    func generateDiff(name: String, expected: String, actual: String): String {
        let expectedLines = splitLines(expected)
        let actualLines = splitLines(actual)
        var diff = "Snapshot mismatch: ${name}.golden\n"
        diff = diff + "--- expected\n+++ actual\n"

        let maxLines = if (expectedLines.size > actualLines.size) {
            expectedLines.size
        } else {
            actualLines.size
        }

        var i: Int64 = 0
        while (i < maxLines) {
            let lineNum = i + 1
            let expLine = if (i < expectedLines.size) { expectedLines[i] } else { "" }
            let actLine = if (i < actualLines.size) { actualLines[i] } else { "" }

            if (expLine != actLine) {
                if (i < expectedLines.size) {
                    diff = diff + "  L${lineNum} - ${expLine}\n"
                }
                if (i < actualLines.size) {
                    diff = diff + "  L${lineNum} + ${actLine}\n"
                } else {
                    diff = diff + "  L${lineNum}   (line removed)\n"
                }
            }
            i++
        }
        diff
    }

    // --- 内部工具方法 ---

    func ensureDir(dir: String): Unit {
        if (!exists(Path(dir))) {
            Directory.create(Path(dir), recursive: true)
        }
    }

    func readText(path: String): String {
        let bytes = File.readFrom(Path(path))
        String.fromUtf8(bytes)
    }

    func writeText(path: String, content: String): Unit {
        File.writeTo(Path(path), content.toArray())
    }

    func splitLines(s: String): Array<String> {
        if (s.size == 0) {
            return Array<String>()
        }
        s.split("\n")
    }
}
