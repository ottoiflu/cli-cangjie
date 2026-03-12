internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// Levenshtein 编辑距离与智能建议测试
// ===============================================================
@Test
class SuggestTest {
    // --- Levenshtein Distance ---

    @TestCase
    func testLevenshteinIdentical() {
        @Assert(levenshteinDistance("hello", "hello") == 0)
    }

    @TestCase
    func testLevenshteinEmpty() {
        @Assert(levenshteinDistance("", "abc") == 3)
        @Assert(levenshteinDistance("abc", "") == 3)
        @Assert(levenshteinDistance("", "") == 0)
    }

    @TestCase
    func testLevenshteinSingleEdit() {
        // 替换
        @Assert(levenshteinDistance("cat", "car") == 1)
        // 插入
        @Assert(levenshteinDistance("cat", "cats") == 1)
        // 删除
        @Assert(levenshteinDistance("cats", "cat") == 1)
    }

    @TestCase
    func testLevenshteinMultiEdit() {
        @Assert(levenshteinDistance("kitten", "sitting") == 3)
        @Assert(levenshteinDistance("sunday", "saturday") == 3)
    }

    @TestCase
    func testLevenshteinCompleteDiff() {
        @Assert(levenshteinDistance("abc", "xyz") == 3)
    }

    // --- Similarity ---

    @TestCase
    func testSimilarityIdentical() {
        let sim = similarity("config", "config")
        @Assert(sim > 0.99)
    }

    @TestCase
    func testSimilarityClose() {
        let sim = similarity("config", "confit")
        @Assert(sim > 0.7)
    }

    @TestCase
    func testSimilarityLow() {
        let sim = similarity("abc", "xyz")
        @Assert(sim < 0.3)
    }

    @TestCase
    func testSimilarityEmptyBoth() {
        let sim = similarity("", "")
        @Assert(sim > 0.99)
    }

    // --- findSuggestion ---

    @TestCase
    func testFindSuggestionMatch() {
        let candidates = ArrayList<String>(["config", "verbose", "output", "help"])
        match (findSuggestion("confi", candidates)) {
            case Some(s) => @Assert(s == "config")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testFindSuggestionNoMatch() {
        let candidates = ArrayList<String>(["config", "verbose", "output"])
        match (findSuggestion("xyz123", candidates)) {
            case Some(_) => @Assert(false)
            case None => @Assert(true)
        }
    }

    @TestCase
    func testFindSuggestionTypo() {
        let candidates = ArrayList<String>(["lint", "fmt", "check", "test"])
        match (findSuggestion("lnt", candidates)) {
            case Some(s) => @Assert(s == "lint")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testFindSuggestionCaseInsensitive() {
        let candidates = ArrayList<String>(["Config", "Verbose"])
        match (findSuggestion("config", candidates)) {
            case Some(s) => @Assert(s == "Config")
            case None => @Assert(false)
        }
    }

    // --- findAllSuggestions ---

    @TestCase
    func testFindAllSuggestionsSorted() {
        let candidates = ArrayList<String>(["config", "confirm", "connect", "xyz"])
        let results = findAllSuggestions("confi", candidates, 0.5)
        // config should be first (highest similarity)
        @Assert(results.size >= 2)
        @Assert(results[0][0] == "config")
    }
}
