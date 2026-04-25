import Foundation

// MARK: — Result types

struct CompatibilityScore {
    let firstName: String
    let lastName: String
    let alliteration: Double
    let rhythm: Double
    let elisionRisk: Bool
    let hardClash: Bool

    var global: Double {
        let raw = alliteration * 0.25
            + rhythm * 0.35
            + (elisionRisk ? 0.0 : 0.20)
            + (hardClash  ? 0.0 : 0.20)
        return min(1, max(0, raw))
    }

    var verdict: String {
        switch global {
        case 0.8...: "Excellent"
        case 0.6...: "Bon"
        case 0.4...: "Moyen"
        default:     "À éviter"
        }
    }
}

// MARK: — PhoneticAnalyzer

struct PhoneticAnalyzer {

    static let shared = PhoneticAnalyzer()

    // MARK: — Public API

    func score(firstName: String, lastName: String) -> CompatibilityScore {
        CompatibilityScore(
            firstName:    firstName,
            lastName:     lastName,
            alliteration: alliterationScore(firstName: firstName, lastName: lastName),
            rhythm:       rhythmScore(firstName: firstName, lastName: lastName),
            elisionRisk:  elisionRisk(firstName: firstName, lastName: lastName),
            hardClash:    hardConsonantClash(firstName: firstName, lastName: lastName)
        )
    }

    /// Score 0..1: same leading consonant(s) = high score.
    func alliterationScore(firstName: String, lastName: String) -> Double {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard !f.isEmpty, !l.isEmpty else { return 0 }

        let fLeading = leadingConsonants(f)
        let lLeading = leadingConsonants(l)

        guard !fLeading.isEmpty, !lLeading.isEmpty else { return 0.1 }

        // Multi-consonant cluster exact match scores higher than single-letter coincidence
        if fLeading == lLeading { return fLeading.count >= 2 ? 1.0 : 0.85 }

        if fLeading.first == lLeading.first {
            let secondMatch = fLeading.count >= 2 && lLeading.count >= 2
                && fLeading.dropFirst().first == lLeading.dropFirst().first
            return secondMatch ? 0.95 : 0.85
        }

        if phoneticallySimilar(fLeading.first!, lLeading.first!) { return 0.50 }

        return 0.10
    }

    /// Score 0..1: syllable balance between first and last name.
    func rhythmScore(firstName: String, lastName: String) -> Double {
        let f = syllableCount(firstName)
        let l = syllableCount(lastName)
        guard f > 0, l > 0 else { return 0 }

        let table: [String: Double] = [
            "2+2": 0.95, "2+3": 0.90, "3+2": 0.90,
            "1+2": 0.75, "2+1": 0.75,
            "3+3": 0.80, "1+3": 0.60, "3+1": 0.60,
            "2+4": 0.65, "4+2": 0.65,
            "1+4": 0.45, "4+1": 0.45,
            "1+1": 0.50, "4+4": 0.55,
            "1+5": 0.30, "5+1": 0.30,
        ]
        let key = "\(f)+\(l)"
        if let v = table[key] { return v }

        let ratio = Double(min(f, l)) / Double(max(f, l))
        return max(0.1, ratio * 0.6)
    }

    /// True when the first name ends in a vowel and the last name starts with a vowel or silent H,
    /// creating an oral contraction risk ("Léa Aubry" → "Léaubry").
    func elisionRisk(firstName: String, lastName: String) -> Bool {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard let last = f.last, let first = l.first else { return false }
        return vowels.contains(last) && (vowels.contains(first) || first == "h")
    }

    /// True when consecutive hard consonants at the junction sound harsh.
    func hardConsonantClash(firstName: String, lastName: String) -> Bool {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard let last = f.last, let first = l.first else { return false }
        // Many French final consonants are silent — only check pronounced ones
        let silentFinals: Set<Character> = ["t", "s", "d", "p", "x", "z", "e"]
        guard !silentFinals.contains(last) else { return false }
        let hard: Set<Character> = ["k", "c", "g", "r", "l", "n", "m", "b", "v", "f"]
        return hard.contains(last) && hard.contains(first)
    }

    /// Returns common nicknames / short forms for a given first name.
    func generateNicknames(name: String) -> [String] {
        let key = name.lowercased()
        if let known = nicknameMap[key] { return known }
        return fallbackNicknames(name)
    }

    // MARK: — Syllable counting (French-aware)

    func syllableCount(_ word: String) -> Int {
        let s = normalized(word)
        guard !s.isEmpty else { return 0 }

        // Count vowel groups (consecutive vowels = 1 syllable)
        var count = 0
        var inVowel = false
        for ch in s {
            if vowels.contains(ch) {
                if !inVowel { count += 1; inVowel = true }
            } else {
                inVowel = false
            }
        }
        // Silent final 'e' only when preceded by a consonant (e.g. "Pierre" yes, "Marie" no)
        if s.last == "e" && count > 1,
           let beforeLast = s.dropLast().last, !vowels.contains(beforeLast) {
            count -= 1
        }
        return max(1, count)
    }

    // MARK: — Private helpers

    private let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y",
                                           "à", "â", "é", "è", "ê", "ë",
                                           "î", "ï", "ô", "ù", "û", "ü", "ÿ"]

    private func normalized(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "fr"))
    }

    private func leadingConsonants(_ s: String) -> [Character] {
        s.prefix(while: { !vowels.contains($0) }).map { $0 }
    }

    private func phoneticallySimilar(_ a: Character, _ b: Character) -> Bool {
        let groups: [[Character]] = [
            ["b", "p"], ["d", "t"], ["g", "k", "c", "q"],
            ["f", "v"], ["s", "z", "c"], ["m", "n"],
        ]
        return groups.contains { $0.contains(a) && $0.contains(b) }
    }

    private func fallbackNicknames(_ name: String) -> [String] {
        guard name.count > 4 else { return [] }
        var results: [String] = []
        // Keep first 3-4 chars as short form
        let short = String(name.prefix(4)).capitalized
        if short != name { results.append(short) }
        // Keep first 3 chars
        let shorter = String(name.prefix(3)).capitalized
        if shorter != name && shorter != short { results.append(shorter) }
        return results
    }

    // MARK: — Nickname dictionary

    private let nicknameMap: [String: [String]] = [
        "alexandre":  ["Alex", "Xan", "Sacha"],
        "alexis":     ["Alex"],
        "anthony":    ["Tony"],
        "benjamin":   ["Ben", "Benji"],
        "charles":    ["Charlie", "Charly"],
        "christophe": ["Chris", "Tof"],
        "clément":    ["Clem"],
        "edouard":    ["Ed", "Edou"],
        "elizabeth":  ["Liz", "Elisa", "Beth"],
        "emilie":     ["Emi"],
        "emma":       ["Em"],
        "emmanuel":   ["Manu", "Manol"],
        "etienne":    ["Tien"],
        "florent":    ["Flo"],
        "florence":   ["Flo"],
        "francois":   ["Fran", "Franck"],
        "frederique": ["Fred"],
        "gabriel":    ["Gab", "Gaby"],
        "georgette":  ["Geo"],
        "guillaume":  ["Guigui", "Will"],
        "isabelle":   ["Isa", "Belle"],
        "jean":       ["Jeannot"],
        "jerome":     ["Jérôme", "Jeje"],
        "josephine":  ["Jo", "Josie"],
        "julien":     ["Jules"],
        "laurent":    ["Lolo"],
        "lea":        ["Lee"],
        "louise":     ["Lou", "Louison"],
        "lucie":      ["Lu", "Lulu"],
        "marguerite": ["Margot", "Rita"],
        "marie":      ["Manon", "Mimi"],
        "mathieu":    ["Matt", "Mathou"],
        "maxime":     ["Max"],
        "maximillen": ["Max", "Maxi"],
        "nicolas":    ["Nico", "Nikki"],
        "olivier":    ["Olive", "Oli"],
        "patrick":    ["Pat", "Patou"],
        "pauline":    ["Paul", "Pau"],
        "pierre":     ["Piti", "Pierrot"],
        "raphael":    ["Raph", "Rafa"],
        "romain":     ["Rom"],
        "samuel":     ["Sam"],
        "sebastien":  ["Seb", "Bastien"],
        "sophie":     ["Soso"],
        "sylvain":    ["Syl", "Sylvio"],
        "thomas":     ["Tom", "Tommy"],
        "timothee":   ["Tim", "Timo"],
        "valentine":  ["Val", "Valou"],
        "victor":     ["Vic"],
        "victoria":   ["Vic", "Vicky", "Toria"],
        "vincent":    ["Vince", "Vin"],
        "william":    ["Will", "Billy"],
        "zacharie":   ["Zach"],
    ]
}
