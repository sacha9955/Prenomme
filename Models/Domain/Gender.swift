enum Gender: String, CaseIterable, Sendable {
    case male = "male"
    case female = "female"
    case unisex = "unisex"

    var label: String {
        switch self {
        case .male:   return "Garçon"
        case .female: return "Fille"
        case .unisex: return "Mixte"
        }
    }
}
