import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var context

    private var settings: UserSettings {
        if let existing = settingsList.first { return existing }
        let s = UserSettings()
        context.insert(s)
        return s
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Famille") {
                    TextField("Nom de famille", text: Binding(
                        get: { settings.familyName },
                        set: { settings.familyName = $0 }
                    ))
                }
                Section("Version") {
                    LabeledContent("App", value: "1.0.0")
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
