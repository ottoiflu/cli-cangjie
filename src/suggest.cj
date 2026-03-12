package cli

import std.collection.*

// Levenshtein 编辑距离算法：计算两个字符串之间的最小编辑操作数
public func levenshteinDistance(a: String, b: String): Int64 {
    let aRunes = a.toRuneArray()
    let bRunes = b.toRuneArray()
    let m = aRunes.size
    let n = bRunes.size

    if (m == 0) { return n }
    if (n == 0) { return m }

    // 使用单行 DP 优化空间: prev[j] = dp[i-1][j]
    var prev = Array<Int64>(n + 1, { i => i })
    var curr = Array<Int64>(n + 1, { _ => 0 })

    var i: Int64 = 1
    while (i <= m) {
        curr[0] = i
        var j: Int64 = 1
        while (j <= n) {
            let cost: Int64 = if (aRunes[i - 1] == bRunes[j - 1]) { 0 } else { 1 }
            let deleteCost = prev[j] + 1
            let insertCost = curr[j - 1] + 1
            let replaceCost = prev[j - 1] + cost
            // 三者取最小
            var minVal = deleteCost
            if (insertCost < minVal) { minVal = insertCost }
            if (replaceCost < minVal) { minVal = replaceCost }
            curr[j] = minVal
            j++
        }
        // 交换 prev 和 curr
        let tmp = prev
        prev = curr
        curr = tmp
        i++
    }
    prev[n]
}

// 计算两个字符串的归一化相似度 (0.0 ~ 1.0), 1.0 表示完全相同
public func similarity(a: String, b: String): Float64 {
    if (a.size == 0 && b.size == 0) { return 1.0 }
    let aRunes = a.toRuneArray()
    let bRunes = b.toRuneArray()
    let maxLen = if (aRunes.size > bRunes.size) { aRunes.size } else { bRunes.size }
    let dist = levenshteinDistance(a, b)
    1.0 - Float64(dist) / Float64(maxLen)
}

// 从候选列表中查找与输入最相似的建议，阈值默认为 0.7
public func findSuggestion(input: String, candidates: ArrayList<String>): Option<String> {
    findSuggestionWithThreshold(input, candidates, 0.7)
}

// 带自定义阈值的建议查找
public func findSuggestionWithThreshold(input: String, candidates: ArrayList<String>,
    threshold: Float64): Option<String> {
    var bestMatch: Option<String> = None
    var bestScore: Float64 = 0.0

    // 转为小写进行比较（大小写不敏感匹配）
    let inputLower = input.toAsciiLower()

    for (candidate in candidates) {
        let candidateLower = candidate.toAsciiLower()
        let score = similarity(inputLower, candidateLower)
        if (score >= threshold && score > bestScore) {
            bestScore = score
            bestMatch = Some(candidate)
        }
    }
    bestMatch
}

// 从候选列表中查找所有满足阈值的建议，按相似度降序排列
public func findAllSuggestions(input: String, candidates: ArrayList<String>,
    threshold: Float64): ArrayList<(String, Float64)> {
    let results = ArrayList<(String, Float64)>()
    let inputLower = input.toAsciiLower()

    for (candidate in candidates) {
        let candidateLower = candidate.toAsciiLower()
        let score = similarity(inputLower, candidateLower)
        if (score >= threshold) {
            results.add((candidate, score))
        }
    }
    // 简单冒泡排序（按 score 降序）
    var i: Int64 = 0
    while (i < results.size) {
        var j: Int64 = 0
        while (j < results.size - 1 - i) {
            if (results[j][1] < results[j + 1][1]) {
                let tmp = results[j]
                results[j] = results[j + 1]
                results[j + 1] = tmp
            }
            j++
        }
        i++
    }
    results
}
