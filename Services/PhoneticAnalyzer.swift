import Foundation

// MARK: — Result types

struct CompatibilityScore {
    let firstName: String
    let lastName: String
    let alliteration: Double
    let rhythm: Double
    let elisionRisk: Bool
    let hardClash: Bool
    let endingRhyme: Bool

    /// Junction quality at the word boundary — replaces three boolean "no-penalty" bonuses
    /// so the score doesn't cluster high just because problems are absent.
    private var junctionScore: Double {
        if elisionRisk  { return 0.30 }
        if hardClash    { return 0.45 }
        if endingRhyme  { return 0.55 }
        return 0.85
    }

    /// Alliteration is a multiplier that caps the maximum achievable score.
    /// Raw score combines rhythm (flow) and junction (boundary quality).
    var global: Double {
        let raw = rhythm * 0.45 + junctionScore * 0.55
        let harmonyMultiplier = 0.20 + alliteration * 0.80
        return min(1, max(0, raw * harmonyMultiplier))
    }

    var verdict: String {
        switch global {
        case 0.70...: "Excellent"
        case 0.50...: "Bon"
        case 0.34...: "Moyen"
        default:      "À éviter"
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
            hardClash:    hardConsonantClash(firstName: firstName, lastName: lastName),
            endingRhyme:  endingRhymeRisk(firstName: firstName, lastName: lastName)
        )
    }

    /// Score 0..1: phonetic harmony score.
    /// Penalises same-first-letter (sounds repetitive in French), rewards
    /// consonant-family diversity, and vowel-density balance between the two names.
    func alliterationScore(firstName: String, lastName: String) -> Double {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard !f.isEmpty, !l.isEmpty else { return 0.5 }

        let fFirst = f.first!
        let lFirst = l.first!

        // Same first letter is a hard disqualifier regardless of diversity/balance
        if fFirst == lFirst { return 0.10 }

        // 1. Starting-sound relationship (30%)
        // Use pure vowels only — 'y' at the start of a French name is always a consonant (Yann, Yves).
        let pure: Set<Character> = ["a", "e", "i", "o", "u"]
        let startScore: Double
        if pure.contains(fFirst) != pure.contains(lFirst) {
            // Consonant/vowel contrast — cleanest phonetic distinction
            startScore = 0.85
        } else if pure.contains(fFirst) {
            // Both start with vowels — still OK, different vowel sounds are fine
            startScore = 0.65
        } else {
            // Both start with consonants
            startScore = phoneticallySimilar(fFirst, lFirst) ? 0.50 : 0.78
        }

        // 2. Consonant-family diversity (40%) — names that draw on different consonant
        //    groups create a richer, more varied full-name sound.
        let fFamilyIndices = consonantFamilyIndices(f)
        let lFamilyIndices = consonantFamilyIndices(l)
        let allFamilies = fFamilyIndices.union(lFamilyIndices)
        let sharedFamilies = fFamilyIndices.intersection(lFamilyIndices)
        let differentCount = allFamilies.count - sharedFamilies.count
        let diversityScore = allFamilies.isEmpty ? 0.5 : min(1.0, Double(differentCount) / 6.0)

        // 3. Vowel complement (30%) — rewards first names that introduce vowel sounds absent from the surname
        let fVowelSet = Set(f.filter { pure.contains($0) })
        let lVowelSet = Set(l.filter { pure.contains($0) })
        let newVowelCount = fVowelSet.subtracting(lVowelSet).count
        let vowelComplementScore: Double
        switch newVowelCount {
        case 2...: vowelComplementScore = 1.0
        case 1:    vowelComplementScore = 0.75
        default:   vowelComplementScore = 0.45
        }

        return startScore * 0.30 + diversityScore * 0.40 + vowelComplementScore * 0.30
    }

    /// Score 0..1: rhythmic flow between first and last name.
    /// Uses syllable pairing, character length ratio, ending vowel harmony,
    /// and combined-name length comfort.
    func rhythmScore(firstName: String, lastName: String) -> Double {
        let f = normalized(firstName)
        let l = normalized(lastName)
        let fSyl = syllableCount(firstName)
        let lSyl = syllableCount(lastName)

        let syllableScore = syllableTableScore(fSyl, lSyl)

        // Character length ratio: differentiates names with same syllable count
        let fLen = Double(f.count)
        let lLen = Double(l.count)
        let lengthScore = (fLen > 0 && lLen > 0)
            ? min(fLen, lLen) / max(fLen, lLen)
            : 0.5

        // Last stressed vowel similarity: ending sound harmony
        let endingScore = lastVowelScore(f, l)

        // Total character comfort: 8-14 chars is easiest to say together
        let total = fLen + lLen
        let comfortScore: Double
        switch total {
        case 8...14: comfortScore = 1.0
        case 7, 15:  comfortScore = 0.85
        case 6, 16:  comfortScore = 0.70
        default:     comfortScore = 0.50
        }

        return syllableScore * 0.40 + lengthScore * 0.25 + endingScore * 0.20 + comfortScore * 0.15
    }

    /// True when the first name ends in a vowel and the last name starts with a vowel or silent H,
    /// creating an oral contraction risk ("Léa Aubry" → "Léaubry").
    func elisionRisk(firstName: String, lastName: String) -> Bool {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard let last = f.last, let first = l.first else { return false }
        // firstName end: keep full vowel set — 'y' at the end sounds like 'i' (Romy, Ruby).
        // lastName start: pure vowels only — 'y' at the start of a French name is a consonant (Yaël, Yves).
        let pure: Set<Character> = ["a", "e", "i", "o", "u"]
        return vowels.contains(last) && (pure.contains(first) || first == "h")
    }

    /// True when consecutive hard consonants at the junction sound harsh.
    func hardConsonantClash(firstName: String, lastName: String) -> Bool {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard let last = f.last, let first = l.first else { return false }
        let silentFinals: Set<Character> = ["t", "s", "d", "p", "x", "z", "e"]
        guard !silentFinals.contains(last) else { return false }
        let hard: Set<Character> = ["k", "c", "g", "r", "l", "n", "m", "b", "v", "f"]
        return hard.contains(last) && hard.contains(first)
    }

    /// True when the last two normalized characters of the first name match the last two of the last name,
    /// creating an audible rhyme (e.g. "Louis Dubois" → "is"/"is", "Sophie Marie" → "ie"/"ie").
    func endingRhymeRisk(firstName: String, lastName: String) -> Bool {
        let f = normalized(firstName)
        let l = normalized(lastName)
        guard f.count >= 2, l.count >= 2 else { return false }
        return f.suffix(2) == l.suffix(2)
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

        var count = 0
        var inVowel = false
        for ch in s {
            if vowels.contains(ch) {
                if !inVowel { count += 1; inVowel = true }
            } else {
                inVowel = false
            }
        }
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

    private let consonantFamilies: [[Character]] = [
        ["b", "p"],
        ["d", "t"],
        ["g", "k", "c", "q"],
        ["f", "v"],
        ["s", "z", "j"],
        ["m", "n"],
        ["l", "r"],
    ]

    private func consonantFamilyIndices(_ s: String) -> Set<Int> {
        Set(consonantFamilies.indices.filter { idx in
            consonantFamilies[idx].contains(where: { s.contains($0) })
        })
    }

    private func syllableTableScore(_ f: Int, _ l: Int) -> Double {
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

    private func lastVowelScore(_ f: String, _ l: String) -> Double {
        // Use pure vowels only — 'y' at the end of surnames like -sky sounds like a
        // suffix, not a meaningful vowel for ending-harmony matching.
        let pure: Set<Character> = ["a", "e", "i", "o", "u"]
        let fLast = f.reversed().first(where: { pure.contains($0) })
        let lLast = l.reversed().first(where: { pure.contains($0) })
        guard let fv = fLast, let lv = lLast else { return 0.5 }
        if fv == lv { return 1.0 }
        let families: [[Character]] = [["a"], ["e"], ["i"], ["o"], ["u"]]
        return families.contains { $0.contains(fv) && $0.contains(lv) } ? 0.55 : 0.20
    }

    private func fallbackNicknames(_ name: String) -> [String] {
        guard name.count > 4 else { return [] }
        var results: [String] = []
        let short = String(name.prefix(4)).capitalized
        if short != name { results.append(short) }
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
