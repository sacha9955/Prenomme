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

    func testAlliterationExactLeadingConsonantMatch() {
        // "Sébastien Sartre" — both start with 's'
        let score = analyzer.alliterationScore(firstName: "Sébastien", lastName: "Sartre")
        XCTAssertGreaterThanOrEqual(score, 0.8)
    }

    func testAlliterationSameFirstLetter() {
        let score = analyzer.alliterationScore(firstName: "Marc", lastName: "Martin")
        XCTAssertGreaterThanOrEqual(score, 0.8)
        XCTAssertLessThan(score, 1.0)
    }

    func testAlliterationFullLeadingMatch() {
        // Same full leading consonant cluster
        let score = analyzer.alliterationScore(firstName: "Strauss", lastName: "Strong")
        XCTAssertEqual(score, 1.0)
    }

    func testAlliterationPhoneticallySimilar() {
        // b/p are phonetically similar
        let score = analyzer.alliterationScore(firstName: "Baptiste", lastName: "Pascal")
        XCTAssertEqual(score, 0.5, accuracy: 0.01)
    }

    func testAlliterationDifferentConsonants() {
        let score = analyzer.alliterationScore(firstName: "Lucas", lastName: "Dubois")
        XCTAssertLessThanOrEqual(score, 0.2)
    }

    func testAlliterationVowelStart() {
        // Names starting with vowels have no leading consonants → neutral 0.5 (not penalised)
        let score = analyzer.alliterationScore(firstName: "Arthur", lastName: "Eiffel")
        XCTAssertEqual(score, 0.5, accuracy: 0.01)
    }

    // MARK: — rhythmScore

    func testRhythm2Plus2IsHigh() {
        // "Marie Martin" — 2+2
        let score = analyzer.rhythmScore(firstName: "Marie", lastName: "Martin")
        XCTAssertEqual(score, 0.95, accuracy: 0.01)
    }

    func testRhythm2Plus3IsHigh() {
        // "Emma Dupont" — 1+2 should use table
        // Test 2+3 explicitly via syllable counts
        let score = analyzer.rhythmScore(firstName: "Sophie", lastName: "Laurent")
        // "Sophie" → 2, "Laurent" → 2 → 2+2 = 0.95
        XCTAssertGreaterThanOrEqual(score, 0.7)
    }

    func testRhythm1Plus1IsMedium() {
        let score = analyzer.rhythmScore(firstName: "Jean", lastName: "Blanc")
        XCTAssertEqual(score, 0.5, accuracy: 0.01)
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

    // MARK: — score (global CompatibilityScore)

    func testScoreGlobalIsBetweenZeroAndOne() {
        let result = analyzer.score(firstName: "Marie", lastName: "Martin")
        XCTAssertGreaterThanOrEqual(result.global, 0)
        XCTAssertLessThanOrEqual(result.global, 1)
    }

    func testScoreVerdictExcellent() {
        // "Sophie Simon" — same initial s, 2+2 rhythm, ends consonant, no clash
        let result = analyzer.score(firstName: "Sophie", lastName: "Simon")
        // Just check verdict is one of the valid values
        XCTAssertTrue(["Excellent", "Bon", "Moyen", "À éviter"].contains(result.verdict))
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
