import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @State private var purchase = PurchaseManager.shared
    @State private var restoreAlert: RestoreAlert?
    @State private var showPaywall = false

    private var settings: UserSettings {
        if let existing = settingsList.first { return existing }
        let s = UserSettings()
        context.insert(s)
        return s
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                purchaseSection
                aboutSection
                legalSection
                #if DEBUG
                Section("Debug") {
                    NavigationLink("Debug Settings") {
                        DebugSettingsView()
                    }
                }
                #endif
            }
            .navigationTitle("Réglages")
            .alert(item: $restoreAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: — Sections

    private var purchaseSection: some View {
        Section("Achats") {
            if purchase.isPro {
                Label("Prénomme Pro — Activé", systemImage: "star.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("Version gratuite", systemImage: "star")
                    .foregroundStyle(.secondary)
                Button {
                    showPaywall = true
                } label: {
                    Label("Passer à Pro", systemImage: "star.fill")
                        .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                }
            }
            Button("Restaurer les achats") {
                Task { await restorePurchases() }
            }
            .disabled(purchase.isLoading)
        }
    }

    private var aboutSection: some View {
        Section("À propos") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            LabeledContent("Données", value: "INSEE · SSA · Wikidata")
            Button {
                requestReview()
            } label: {
                Label("Évaluer Prénomme", systemImage: "star.bubble")
            }
        }
    }

    private var legalSection: some View {
        Section("Légal") {
            Link(destination: URL(string: "https://sacha9955.github.io/prenomme-legal/privacy.html")!) {
                Label("Politique de confidentialité", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://sacha9955.github.io/prenomme-legal/terms.html")!) {
                Label("Conditions d'utilisation", systemImage: "doc.text")
            }
            Link(destination: URL(string: "mailto:sacha.ochmiansky@gmail.com?subject=Prénomme%20Support")!) {
                Label("Contact / Support", systemImage: "envelope")
            }
        }
    }

    // MARK: — Actions

    private func restorePurchases() async {
        await purchase.restore()
        if let error = purchase.purchaseError {
            restoreAlert = RestoreAlert(
                title: "Erreur",
                message: error
            )
        } else if purchase.isPro {
            restoreAlert = RestoreAlert(
                title: "Achats restaurés",
                message: "Prénomme Pro est maintenant actif."
            )
        } else {
            restoreAlert = RestoreAlert(
                title: "Aucun achat trouvé",
                message: "Aucun achat Pro associé à ce compte Apple."
            )
        }
    }
}

private struct RestoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
