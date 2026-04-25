import Foundation

struct FirstName: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let gender: Gender
    let origin: String
    let originLocale: String?
    let meaning: String
    let syllables: Int
    let popularityRankFR: Int?
    let popularityRankUS: Int?
    let themes: [String]
    let phonetic: String?

    var isFemale: Bool { gender == .female }
    var isMale: Bool { gender == .male }
}
