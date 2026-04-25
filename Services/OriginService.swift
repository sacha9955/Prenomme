import SwiftUI

struct OriginMeta: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let colors: [Color]
    let description: String
    var count: Int = 0

    static func == (lhs: OriginMeta, rhs: OriginMeta) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

@Observable
final class OriginService {
    static let shared = OriginService()

    private(set) var origins: [OriginMeta] = []

    private init() {
        load()
    }

    private func load() {
        let counts = NameDatabase.shared.countByOrigin()
        origins = Self.palette.map { meta in
            var m = meta
            m.count = counts[meta.name] ?? 0
            return m
        }.filter { $0.count > 0 }
    }

    // MARK: — Color palette (27 origins)

    private static let palette: [OriginMeta] = [
        OriginMeta(name: "Hébreu",      colors: [Color(hex: "D4A5A5"), Color(hex: "C47E7E")], description: "Noms bibliques aux racines profondes"),
        OriginMeta(name: "Latin",       colors: [Color(hex: "D4B483"), Color(hex: "C49A5A")], description: "Héritage de la Rome antique"),
        OriginMeta(name: "Grec",        colors: [Color(hex: "88AACB"), Color(hex: "5C86AD")], description: "Mythologie et philosophie helléniques"),
        OriginMeta(name: "Germanique",  colors: [Color(hex: "8FAF8F"), Color(hex: "5E8A5E")], description: "Noms des peuples germaniques"),
        OriginMeta(name: "Anglais",     colors: [Color(hex: "B5C4D0"), Color(hex: "7FA0B5")], description: "Prénoms du monde anglophone"),
        OriginMeta(name: "Arabe",       colors: [Color(hex: "D4A35A"), Color(hex: "B87B30")], description: "Sagesse et beauté du monde arabe"),
        OriginMeta(name: "Breton",      colors: [Color(hex: "6AA8C0"), Color(hex: "3D7E9A")], description: "Traditions celtiques de Bretagne"),
        OriginMeta(name: "Nordique",    colors: [Color(hex: "8BBCCC"), Color(hex: "5091A8")], description: "Mythologie viking et scandinave"),
        OriginMeta(name: "Japonais",    colors: [Color(hex: "F0A0A0"), Color(hex: "D06060")], description: "Harmonie et nature japonaises"),
        OriginMeta(name: "Perse",       colors: [Color(hex: "C4A8D4"), Color(hex: "9A74B8")], description: "Grandeur de la Perse ancienne"),
        OriginMeta(name: "Sanskrit",    colors: [Color(hex: "D4C080"), Color(hex: "B09040")], description: "Sagesse védique de l'Inde"),
        // Celtique: aucun prénom en base (retiré du palette)
        OriginMeta(name: "Irlandais",   colors: [Color(hex: "68BB68"), Color(hex: "3A883A")], description: "Île d'Émeraude et ses légendes"),
        OriginMeta(name: "Gallois",     colors: [Color(hex: "7EB07E"), Color(hex: "4E884E")], description: "Prénoms du Pays de Galles"),
        OriginMeta(name: "Espagnol",    colors: [Color(hex: "D48888"), Color(hex: "B85050")], description: "Passion et soleil ibériques"),
        OriginMeta(name: "Basque",      colors: [Color(hex: "A8C870"), Color(hex: "78A840")], description: "Langue mystérieuse des Basques"),
        OriginMeta(name: "Occitan",     colors: [Color(hex: "D4A870"), Color(hex: "B07838")], description: "Troubadours et Midi de la France"),
        OriginMeta(name: "Normand",     colors: [Color(hex: "A8B8D0"), Color(hex: "7090B8")], description: "Héritage normand de Normandie"),
        OriginMeta(name: "Slave",       colors: [Color(hex: "B0A8D0"), Color(hex: "8070B0")], description: "Traditions slaves d'Europe"),
        OriginMeta(name: "Ukrainien",   colors: [Color(hex: "A8C8E8"), Color(hex: "60A0D8")], description: "Culture ukrainienne millénaire"),
        OriginMeta(name: "Chinois",     colors: [Color(hex: "E8A090"), Color(hex: "D06858")], description: "Civilisation de l'Empire du Milieu"),
        OriginMeta(name: "Coréen",      colors: [Color(hex: "C8A8D8"), Color(hex: "A070C0")], description: "Élégance de la culture coréenne"),
        OriginMeta(name: "Swahili",     colors: [Color(hex: "D0C058"), Color(hex: "A89820")], description: "Côtes et savanes d'Afrique de l'Est"),
        OriginMeta(name: "Yoruba",      colors: [Color(hex: "E8A850"), Color(hex: "C07820")], description: "Richesse culturelle yoruba"),
        OriginMeta(name: "Igbo",        colors: [Color(hex: "D8B870"), Color(hex: "B08830")], description: "Traditions igbo du Nigeria"),
        // Akan: aucun prénom en base (retiré du palette)
        OriginMeta(name: "Araméen",     colors: [Color(hex: "C8B898"), Color(hex: "A09060")], description: "Langue sémitique ancienne"),
        OriginMeta(name: "Autre",       colors: [Color(hex: "BBBBBB"), Color(hex: "999999")], description: "Prénoms d'origines diverses"),
    ]
}

private extension Color {
    init(hex: String) {
        let v = UInt64(hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
