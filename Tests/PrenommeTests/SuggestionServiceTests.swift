import XCTest
@testable import Prenomme

final class SuggestionServiceTests: XCTestCase {

    private let service = SuggestionService.shared

    // MARK: — Fixtures

    private func makeName(
        id: Int,
        name: String,
        gender: Gender = .female,
        origin: String = "Français",
        syllables: Int = 2,
        rankFR: Int? = nil
    ) -> FirstName {
        FirstName(
            id: id,
            name: name,
            gender: gender,
            origin: origin,
            originLocale: nil,
            meaning: "",
            syllables: syllables,
            popularityRankFR: rankFR,
            popularityRankUS: nil,
            themes: [],
            phonetic: nil
        )
    }

    // MARK: — buildProfile

    func testBuildProfileReturnsNilForEmptyFavorites() {
        XCTAssertNil(service.buildProfile(from: []))
    }

    func testBuildProfileTopOriginsOrderedByFrequency() {
        let favorites = [
            makeName(id: 1, name: "Marie", origin: "Latin"),
            makeName(id: 2, name: "Claire", origin: "Latin"),
            makeName(id: 3, name: "Sophie", origin: "Grec"),
        ]
        let profile = service.buildProfile(from: favorites)!
        XCTAssertEqual(profile.topOrigins.first, "Latin")
    }

    func testBuildProfileTopOriginsMaxThree() {
        let favorites = (1...10).map {
            makeName(id: $0, name: "Name\($0)", origin: "Origin\($0)")
        }
        let profile = service.buildProfile(from: favorites)!
        XCTAssertLessThanOrEqual(profile.topOrigins.count, 3)
    }

    func testBuildProfileMedianSyllables() {
        let favorites = [
            makeName(id: 1, name: "A", syllables: 1),
            makeName(id: 2, name: "B", syllables: 2),
            makeName(id: 3, name: "C", syllables: 3),
        ]
        let profile = service.buildProfile(from: favorites)!
        XCTAssertEqual(profile.medianSyllables, 2)
    }

    func testBuildProfileDominantGenderWhenMajority() {
        let favorites = [
            makeName(id: 1, name: "A", gender: .female),
            makeName(id: 2, name: "B", gender: .female),
            makeName(id: 3, name: "C", gender: .male),
        ]
        let profile = service.buildProfile(from: favorites)!
        XCTAssertEqual(profile.dominantGender, .female)
    }

    func testBuildProfileNoDominantGenderWhenEven() {
        let favorites = [
            makeName(id: 1, name: "A", gender: .female),
            makeName(id: 2, name: "B", gender: .male),
        ]
        let profile = service.buildProfile(from: favorites)!
        XCTAssertNil(profile.dominantGender)
    }

    func testBuildProfileSingleFavorite() {
        let favorites = [makeName(id: 1, name: "Marie", origin: "Latin", syllables: 2)]
        let profile = service.buildProfile(from: favorites)!
        XCTAssertEqual(profile.topOrigins, ["Latin"])
        XCTAssertEqual(profile.medianSyllables, 2)
    }

    // MARK: — similarityScore

    func testSimilarityScoreOriginMatchBoostsScore() {
        let profile = SuggestionService.Profile(
            topOrigins: ["Latin", "Grec"],
            medianSyllables: 2,
            dominantGender: .female
        )
        let nameMatch = makeName(id: 1, name: "Claire", origin: "Latin", syllables: 2)
        let nameMiss  = makeName(id: 2, name: "Yuki",   origin: "Japonais", syllables: 2)

        let scoreMatch = service.similarityScore(name: nameMatch, profile: profile)
        let scoreMiss  = service.similarityScore(name: nameMiss,  profile: profile)

        XCTAssertGreaterThan(scoreMatch, scoreMiss)
    }

    func testSimilarityScoreGenderMatchBoostsScore() {
        let profile = SuggestionService.Profile(
            topOrigins: [],
            medianSyllables: 2,
            dominantGender: .male
        )
        let male   = makeName(id: 1, name: "Luc",  gender: .male,   syllables: 1)
        let female = makeName(id: 2, name: "Lucie", gender: .female, syllables: 3)

        let scoreMale   = service.similarityScore(name: male,   profile: profile)
        let scoreFemale = service.similarityScore(name: female, profile: profile)

        XCTAssertGreaterThan(scoreMale, scoreFemale)
    }

    func testSimilarityScoreSyllableProximityMatters() {
        let profile = SuggestionService.Profile(
            topOrigins: [],
            medianSyllables: 2,
            dominantGender: nil
        )
        let close = makeName(id: 1, name: "A", syllables: 2)
        let far   = makeName(id: 2, name: "B", syllables: 5)

        XCTAssertGreaterThan(
            service.similarityScore(name: close, profile: profile),
            service.similarityScore(name: far,   profile: profile)
        )
    }

    func testSimilarityScoreRankedNameGetsBonus() {
        let profile = SuggestionService.Profile(
            topOrigins: [],
            medianSyllables: 2,
            dominantGender: nil
        )
        let ranked   = makeName(id: 1, name: "A", syllables: 2, rankFR: 50)
        let unranked = makeName(id: 2, name: "B", syllables: 2, rankFR: nil)

        XCTAssertGreaterThan(
            service.similarityScore(name: ranked,   profile: profile),
            service.similarityScore(name: unranked, profile: profile)
        )
    }

    func testSimilarityScoreIsNormalized() {
        let profile = SuggestionService.Profile(
            topOrigins: ["Latin"],
            medianSyllables: 2,
            dominantGender: .female
        )
        let name = makeName(id: 1, name: "Marie", origin: "Latin", syllables: 2, rankFR: 1)
        let score = service.similarityScore(name: name, profile: profile)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    // MARK: — suggest

    func testSuggestReturnsEmptyForNoFavorites() {
        let all = (1...5).map { makeName(id: $0, name: "N\($0)") }
        XCTAssertTrue(service.suggest(from: all, favorites: []).isEmpty)
    }

    func testSuggestExcludesExistingFavorites() {
        let fav   = makeName(id: 1, name: "Marie", origin: "Latin")
        let other = makeName(id: 2, name: "Claire", origin: "Latin")
        let all   = [fav, other]

        let results = service.suggest(from: all, favorites: [fav], count: 10)
        XCTAssertFalse(results.contains { $0.id == fav.id })
    }

    func testSuggestRespectsCount() {
        let favorites = [makeName(id: 1, name: "Marie", origin: "Latin")]
        let all = (2...20).map { makeName(id: $0, name: "N\($0)", origin: "Latin") }

        let results = service.suggest(from: all, favorites: favorites, count: 5)
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func testSuggestResultsAreSortedByScoreDescending() {
        let favorites = [makeName(id: 1, name: "Marie", origin: "Latin", syllables: 2, rankFR: 1)]
        let highMatch  = makeName(id: 2, name: "Claire", origin: "Latin",    syllables: 2, rankFR: 50)
        let lowMatch   = makeName(id: 3, name: "Yuki",   origin: "Japonais", syllables: 3, rankFR: nil)
        let all = [favorites[0], highMatch, lowMatch]

        let results = service.suggest(from: all, favorites: favorites, count: 10)
        guard results.count >= 2 else { return }
        XCTAssertGreaterThanOrEqual(results[0].score, results[1].score)
    }

    func testSuggestionMatchPercentIsInRange() {
        let favorites = [makeName(id: 1, name: "Marie")]
        let all = [favorites[0], makeName(id: 2, name: "Claire")]
        let results = service.suggest(from: all, favorites: favorites, count: 10)
        for result in results {
            XCTAssertGreaterThanOrEqual(result.matchPercent, 0)
            XCTAssertLessThanOrEqual(result.matchPercent, 100)
        }
    }
}
