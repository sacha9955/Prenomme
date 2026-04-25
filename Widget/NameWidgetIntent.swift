import AppIntents
import WidgetKit

// MARK: — GenderFilter

enum GenderFilter: String, AppEnum {
    case all, female, male, unisex

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Genre"
    static var caseDisplayRepresentations: [GenderFilter: DisplayRepresentation] = [
        .all:    "Tous",
        .female: "Féminin",
        .male:   "Masculin",
        .unisex: "Mixte",
    ]
}

// MARK: — DisplayMode

enum DisplayMode: String, AppEnum {
    case nameOnly, nameAndOrigin, full

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Affichage"
    static var caseDisplayRepresentations: [DisplayMode: DisplayRepresentation] = [
        .nameOnly:      "Prénom",
        .nameAndOrigin: "Prénom + Origine",
        .full:          "Complet",
    ]
}

// MARK: — OriginAppEntity (enables multi-select from 27 origins)

struct OriginAppEntity: AppEntity {
    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id))
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Origine"
    static var defaultQuery = OriginEntityQuery()
}

struct OriginEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [OriginAppEntity] {
        identifiers.map { OriginAppEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [OriginAppEntity] {
        OriginService.shared.origins.map { OriginAppEntity(id: $0.name) }
    }
}

// MARK: — NameWidgetConfiguration

struct NameWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Personnalisez votre widget Prénomme.")

    @Parameter(title: "Genre", default: .all)
    var gender: GenderFilter

    @Parameter(title: "Affichage", default: .full)
    var displayMode: DisplayMode

    @Parameter(title: "Origines")
    var origins: [OriginAppEntity]?
}
