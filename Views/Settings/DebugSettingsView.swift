#if DEBUG
import SwiftUI
import SwiftData
import WidgetKit

struct DebugSettingsView: View {

    @Environment(\.modelContext) private var context
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var manager = PurchaseManager.shared
    @State private var showResetConfirmation = false

    private let appGroupDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme")

    var body: some View {
        Form {
            Section {
                Toggle("Simuler Pro", isOn: Binding(
                    get: { manager.debugForcePro },
                    set: { manager.setDebugForcePro($0) }
                ))
                Text("Active toutes les features Pro sans passer par StoreKit. N'apparaît qu'en build Debug, jamais en Release.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Mode Premium (DEBUG only)")
            }

            Section("Reset data") {
                Button("Réinitialiser onboarding") {
                    hasSeenOnboarding = false
                }
                Button("Reset compteur swipes du jour") {
                    appGroupDefaults?.removeObject(forKey: "swipes_date")
                    appGroupDefaults?.removeObject(forKey: "swipes_count")
                }
                Button("Vider tous les favoris", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .navigationTitle("Debug")
        .confirmationDialog(
            "Supprimer tous les favoris ?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                deleteAllFavorites()
            }
        }
    }

    private func deleteAllFavorites() {
        try? context.delete(model: Favorite.self)
        try? context.save()
    }
}
#endif
