import Foundation

struct NameFilter: Equatable {
    var gender: Gender? = nil
    var origins: [String] = []
    var syllables: Int? = nil       // nil = any; 5 means "5 or more"
    var initialLetter: Character? = nil
    var searchQuery: String = ""
    var sortByPopularity: Bool = true

    var isActive: Bool {
        gender != nil || !origins.isEmpty || syllables != nil || initialLetter != nil
    }
}
