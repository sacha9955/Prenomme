import Foundation

struct SuggestionService {

    static let shared = SuggestionService()

    struct Suggestion: Identifiable {
        let name: FirstName
        let score: Double

        var id: Int { name.id }

        /// Human-readable match percentage.
        var matchPercent: Int { Int(score * 100) }
    }

    struct Profile {
        let topOrigins: [String]
        let medianSyllables: Int
        let dominantGender: Gender?
    }

    // MARK: — Public API

    func buildProfile(from favorites: [FirstName]) -> Profile? {
        guard !favorites.isEmpty else { return nil }

        let originCounts = favorites
            .reduce(into: [String: Int]()) { $0[$1.origin, default: 0] += 1 }
            .sorted { $0.value > $1.value }
        let topOrigins = originCounts.prefix(3).map(\.key)

        let sorted = favorites.map(\.syllables).sorted()
        let medianSyllables = sorted[sorted.count / 2]

        let genderCounts = favorites
            .reduce(into: [Gender: Int]()) { $0[$1.gender, default: 0] += 1 }
            .sorted { $0.value > $1.value }
        let dominantGender: Gender? = genderCounts.first.flatMap {
            $0.value > favorites.count / 2 ? $0.key : nil
        }

        return Profile(
            topOrigins: Array(topOrigins),
            medianSyllables: medianSyllables,
            dominantGender: dominantGender
        )
    }

    func suggest(from allNames: [FirstName], favorites: [FirstName], count: Int = 10) -> [Suggestion] {
        guard let profile = buildProfile(from: favorites) else { return [] }
        let favoriteIds = Set(favorites.map(\.id))

        return allNames
            .filter { !favoriteIds.contains($0.id) }
            .map { Suggestion(name: $0, score: similarityScore(name: $0, profile: profile)) }
            .sorted { $0.score > $1.score }
            .prefix(count)
            .map { $0 }
    }

    // MARK: — Scoring

    func similarityScore(name: FirstName, profile: Profile) -> Double {
        var score = 0.0

        // Origin match: 40 %
        if let idx = profile.topOrigins.firstIndex(of: name.origin) {
            let originWeight = 1.0 - Double(idx) * 0.25
            score += 0.40 * originWeight
        }

        // Syllable proximity: 30 %
        let diff = abs(name.syllables - profile.medianSyllables)
        score += 0.30 * max(0, 1.0 - Double(diff) * 0.35)

        // Gender match: 20 %
        if let dominant = profile.dominantGender {
            if name.gender == dominant { score += 0.20 }
        } else {
            score += 0.10
        }

        // Popularity bonus: 10 %
        if let rank = name.popularityRankFR, rank <= 200 {
            score += 0.10 * (1.0 - Double(rank) / 200.0)
        }

        return min(1, max(0, score))
    }
}
