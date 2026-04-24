import Foundation
import SwiftData

// MARK: — V1 schema (initial)
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Favorite.self,
        Note.self,
        UserSettings.self
    ]

    @Model final class Favorite {
        var id: UUID = UUID()
        var nameId: Int = 0
        var addedAt: Date = Date()

        init(nameId: Int) {
            self.nameId = nameId
        }
    }

    @Model final class Note {
        var id: UUID = UUID()
        var nameId: Int = 0
        var text: String = ""
        var updatedAt: Date = Date()

        init(nameId: Int, text: String) {
            self.nameId = nameId
            self.text = text
        }
    }

    @Model final class UserSettings {
        var id: UUID = UUID()
        var familyName: String = ""
        var onboardingDone: Bool = false
        var iCloudUnavailableToastShown: Bool = false

        init() {}
    }
}

// MARK: — Migration plan (vide en v1, prêt pour v2)
enum PrenommeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []
}

// MARK: — Type aliases (toujours pointer vers la version courante)
typealias Favorite = SchemaV1.Favorite
typealias Note = SchemaV1.Note
typealias UserSettings = SchemaV1.UserSettings
