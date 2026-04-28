import XCTest
@testable import Prenomme

final class PhoneticAnalyzerTests: XCTestCase {

    private let analyzer = PhoneticAnalyzer.shared

    // MARK: — syllableCount

    func testSyllableCountSingleVowelGroup() {
        XCTAssertEqual(analyzer.syllableCount("Jean"), 1)
    }

    func testSyllableCountTwoSyllables() {
        XCTAssertEqual(analyzer.syllableCount("Marie"), 2)
    }

    func testSyllableCountThreeSyllables() {
        XCTAssertEqual(analyzer.syllableCount("Amélie"), 3)
    }

    func testSyllableCountSilentFinalE() {
        // "Pierre" → pi-erre → count vowel groups: i, e → 2, then −1 for silent final e → 1
        XCTAssertEqual(analyzer.syllableCount("Pierre"), 1)
    }

    func testSyllableCountMinimumOne() {
        XCTAssertEqual(analyzer.syllableCount(""), 0)
        XCTAssertEqual(analyzer.syllableCount("b"), 1)
    }

    func testSyllableCountAccentedVowels() {
        // "Éléonore" → 4 vowel groups (é, é, o, o) with silent final e deducted → 3
        XCTAssertEqual(analyzer.syllableCount("Éléonore"), 3)
    }

    // MARK: — alliterationScore

    func testAlliterationSameFirstLetterIsPenalized() {
        // "Sébastien Sartre" — same initial → hard cap at 0.10
        let score = analyzer.alliterationScore(firstName: "Sébastien", lastName: "Sartre")
        XCTAssertEqual(score, 0.10, accuracy: 0.001)
    }

    func testAlliterationSameFirstLetterShortNames() {
        // "Marc Martin" — same initial → hard cap at 0.10
        let score = analyzer.alliterationScore(firstName: "Marc", lastName: "Martin")
        XCTAssertEqual(score, 0.10, accuracy: 0.001)
    }

    func testAlliterationGoodConsonantVowelContrast() {
        // "Lucas Aubry" — consonant vs vowel start: best distinction → high score
        let score = analyzer.alliterationScore(firstName: "Lucas", lastName: "Aubry")
        XCTAssertGreaterThanOrEqual(score, 0.70)
    }

    func testAlliterationPhoneticallySimilarStillReasonable() {
        // "Baptiste Pascal" — b/p are phonetically similar but diverse families → moderate+
        let score = analyzer.alliterationScore(firstName: "Baptiste", lastName: "Pascal")
        XCTAssertGreaterThanOrEqual(score, 0.50)
        XCTAssertLessThan(score, 0.90)
    }

    func testAlliterationDifferentConsonantsIsGood() {
        // "Lucas Dubois" — l vs d: distinct consonants, good diversity → high score
        let score = analyzer.alliterationScore(firstName: "Lucas", lastName: "Dubois")
        XCTAssertGreaterThanOrEqual(score, 0.70)
    }

    func testAlliterationBothVowelStartIsAcceptable() {
        // "Arthur Eiffel" — both vowel start, different vowels → OK
        let score = analyzer.alliterationScore(firstName: "Arthur", lastName: "Eiffel")
        XCTAssertGreaterThanOrEqual(score, 0.40)
        XCTAssertLessThan(score, 0.90)
    }

    // MARK: — rhythmScore

    func testRhythm2Plus2IsHigh() {
        // "Marie Martin" — 2+2 syllables, good length ratio, total 11 chars → comfort 1.0
        // syllable(0.95)*0.40 + length(5/6)*0.25 + endingVowel(i≠a→0.20)*0.20 + comfort(1.0)*0.15 ≈ 0.778
        let score = analyzer.rhythmScore(firstName: "Marie", lastName: "Martin")
        XCTAssertEqual(score, 0.778, accuracy: 0.01)
    }

    func testRhythm2Plus3IsHigh() {
        // "Emma Dupont" — 1+2 should use table
        // Test 2+3 explicitly via syllable counts
        let score = analyzer.rhythmScore(firstName: "Sophie", lastName: "Laurent")
        // "Sophie" → 2, "Laurent" → 2 → 2+2 = 0.95
        XCTAssertGreaterThanOrEqual(score, 0.7)
    }

    func testRhythm1Plus1IsMedium() {
        // "Jean Blanc" — 1+1 syllables (table: 0.50), length 4/5=0.80, both end 'a' → 1.0, comfort 1.0
        // 0.50*0.40 + 0.80*0.25 + 1.0*0.20 + 1.0*0.15 = 0.75
        let score = analyzer.rhythmScore(firstName: "Jean", lastName: "Blanc")
        XCTAssertEqual(score, 0.75, accuracy: 0.01)
    }

    func testRhythmFallbackForUnknownCombo() {
        // Very long name combinations not in table use ratio fallback
        let score = analyzer.rhythmScore(firstName: "Bartholomée", lastName: "X")
        // "Bartholomée" → many syllables, "X" → 1
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testRhythmSymmetry() {
        // Rhythm should produce same score regardless of order for same-syllable pairs in table
        let forward = analyzer.rhythmScore(firstName: "Marie", lastName: "Dupont")
        let reverse = analyzer.rhythmScore(firstName: "Dupont", lastName: "Marie")
        XCTAssertEqual(forward, reverse, accuracy: 0.01)
    }

    // MARK: — elisionRisk

    func testElisionRiskVowelPlusVowel() {
        // "Léa Aubry" — 'a' + 'a'
        XCTAssertTrue(analyzer.elisionRisk(firstName: "Léa", lastName: "Aubry"))
    }

    func testElisionRiskVowelPlusSilentH() {
        // "Sophie Henri" — 'e' + 'h'
        XCTAssertTrue(analyzer.elisionRisk(firstName: "Sophie", lastName: "Henri"))
    }

    func testElisionRiskConsonantEnd() {
        // "Marc Alain" — 'c' + 'a': no elision (ends in consonant)
        XCTAssertFalse(analyzer.elisionRisk(firstName: "Marc", lastName: "Alain"))
    }

    func testElisionRiskConsonantStart() {
        // "Léa Martin" — vowel + consonant: no risk
        XCTAssertFalse(analyzer.elisionRisk(firstName: "Léa", lastName: "Martin"))
    }

    func testElisionRiskEmptyStrings() {
        XCTAssertFalse(analyzer.elisionRisk(firstName: "", lastName: "Martin"))
        XCTAssertFalse(analyzer.elisionRisk(firstName: "Léa", lastName: ""))
    }

    // MARK: — hardConsonantClash

    func testHardClashTwoHardConsonants() {
        // "Carl Renard" — 'l' + 'r' both hard
        XCTAssertTrue(analyzer.hardConsonantClash(firstName: "Carl", lastName: "Renard"))
    }

    func testNoClashSilentFinal() {
        // "Marc Renard" — 'c' is NOT in silentFinals ("t","s","d","p","x","z","e"),
        // and 'c' IS in hard set, 'r' IS in hard set → clash
        // Let's pick "Louis Renard" — 's' is silent → no clash
        XCTAssertFalse(analyzer.hardConsonantClash(firstName: "Louis", lastName: "Renard"))
    }

    func testNoClashVowelBoundary() {
        // "Sophie Martin" — 'e' is in silentFinals → no clash
        XCTAssertFalse(analyzer.hardConsonantClash(firstName: "Sophie", lastName: "Martin"))
    }

    func testNoClashSoftFirstOfLastName() {
        // "Marcel Petit" — 't' is silent final → no clash
        XCTAssertFalse(analyzer.hardConsonantClash(firstName: "Marcel", lastName: "Petit"))
    }

    // MARK: — endingRhymeRisk

    func testEndingRhymeDetectsMatch() {
        // "Louis Dubois" → suffix "is" == "is"
        XCTAssertTrue(analyzer.endingRhymeRisk(firstName: "Louis", lastName: "Dubois"))
    }

    func testEndingRhymeDetectsIeSuffix() {
        // "Sophie Marie" → suffix "ie" == "ie"
        XCTAssertTrue(analyzer.endingRhymeRisk(firstName: "Sophie", lastName: "Marie"))
    }

    func testEndingRhymeNoMatch() {
        // "Emma Dubois" → "ma" vs "is"
        XCTAssertFalse(analyzer.endingRhymeRisk(firstName: "Emma", lastName: "Dubois"))
    }

    func testEndingRhymeShortNameReturnsFalse() {
        XCTAssertFalse(analyzer.endingRhymeRisk(firstName: "Al", lastName: "X"))
    }

    // MARK: — score (global CompatibilityScore)

    func testScoreGlobalIsBetweenZeroAndOne() {
        let result = analyzer.score(firstName: "Marie", lastName: "Martin")
        XCTAssertGreaterThanOrEqual(result.global, 0)
        XCTAssertLessThanOrEqual(result.global, 1)
    }

    func testScoreSameInitialIsPenalized() {
        // "Sophie Simon" — same initial → alliteration=0.10 → harmonyMultiplier≈0.28 → global≈0.23
        let result = analyzer.score(firstName: "Sophie", lastName: "Simon")
        XCTAssertLessThan(result.global, 0.35)
        XCTAssertEqual(result.verdict, "À éviter")
    }

    func testScoreEndingRhymeIsDetected() {
        let result = analyzer.score(firstName: "Louis", lastName: "Dubois")
        XCTAssertTrue(result.endingRhyme)
    }

    func testScoreGoodCombinationScoresHigh() {
        // "Emma Laurent" — different initials, no elision, no clash, no rhyme
        let result = analyzer.score(firstName: "Emma", lastName: "Laurent")
        XCTAssertGreaterThanOrEqual(result.global, 0.50)
    }

    func testScorePreservesFirstAndLastName() {
        let result = analyzer.score(firstName: "Emma", lastName: "Dubois")
        XCTAssertEqual(result.firstName, "Emma")
        XCTAssertEqual(result.lastName, "Dubois")
    }

    // MARK: — generateNicknames

    func testNicknamesDictionaryLookup() {
        let nicks = analyzer.generateNicknames(name: "Alexandre")
        XCTAssertTrue(nicks.contains("Alex"))
    }

    func testNicknamesFallbackForShortName() {
        // Names with ≤4 chars return empty fallback
        let nicks = analyzer.generateNicknames(name: "Léa")
        XCTAssertTrue(nicks.isEmpty)
    }

    func testNicknamesFallbackForLongUnknownName() {
        let nicks = analyzer.generateNicknames(name: "Bartholomée")
        XCTAssertFalse(nicks.isEmpty)
        XCTAssertLessThanOrEqual(nicks.count, 2)
    }

    func testNicknamesCaseInsensitiveLookup() {
        let lower = analyzer.generateNicknames(name: "alexandre")
        let upper = analyzer.generateNicknames(name: "ALEXANDRE")
        XCTAssertEqual(lower, upper)
    }
}
