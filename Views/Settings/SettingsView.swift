import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @State private var purchase = PurchaseManager.shared
    @State private var restoreAlert: RestoreAlert?
    @State private var showPaywall = false

    // MARK: — Debug unlock (5 taps secrets sur "Version")
    @AppStorage("debugUnlocked") private var debugUnlocked = false
    @State private var versionTapCount = 0
    @State private var versionTapResetWork: DispatchWorkItem?
    @State private var showDebugCodePrompt = false
    @State private var showWrongCodeAlert = false
    @State private var debugCodeEntry = ""

    /// Code secret pour débloquer la section Debug.
    /// Centralisé ici plutôt que parsé en plusieurs endroits.
    private static let debugUnlockCode = "2024bc"
    private static let tapsRequiredToPromptCode = 5

    private let privacyURL = URL(string: "https://raw.githack.com/sacha9955/Prenomme-legal/main/privacy.html") ?? URL(fileURLWithPath: "")
    private let termsURL = URL(string: "https://raw.githack.com/sacha9955/Prenomme-legal/main/terms.html") ?? URL(fileURLWithPath: "")
    private let supportURL = URL(string: "https://raw.githack.com/sacha9955/Prenomme-legal/main/support.html") ?? URL(fileURLWithPath: "")

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
                if debugUnlocked {
                    Section("Debug") {
                        NavigationLink("Debug Settings") {
                            DebugSettingsView()
                        }
                        Button("Verrouiller Debug", role: .destructive) {
                            debugUnlocked = false
                            versionTapCount = 0
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Réglages")
            .alert(item: $restoreAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .alert("Code de déblocage", isPresented: $showDebugCodePrompt) {
                SecureField("Code", text: $debugCodeEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Valider") { validateDebugCode() }
                Button("Annuler", role: .cancel) {
                    debugCodeEntry = ""
                    versionTapCount = 0
                }
            } message: {
                Text("Entrez le code pour activer le menu Debug.")
            }
            .alert("Code incorrect", isPresented: $showWrongCodeAlert) {
                Button("OK", role: .cancel) {}
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
                        .foregroundStyle(Color.brand)
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
            // Tap secret 5× sur la row "Version" → prompt code "2024bc" → débloque section Debug.
            // onTapGesture direct (pas Button wrap) car Button + LabeledContent dans un Form
            // ne propage pas le tap fiablement à toute la ligne sur iOS 17+.
            LabeledContent("Version", value: appVersion)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleVersionTap()
                }

            LabeledContent("Build", value: buildNumber)
            LabeledContent("Données", value: "INSEE · SSA · Wikidata")
            Button {
                requestReview()
            } label: {
                Label("Évaluer Prénomme", systemImage: "star.bubble")
            }
        }
    }

    // MARK: — Debug unlock logic

    private func handleVersionTap() {
        #if DEBUG
        guard !debugUnlocked else { return }   // déjà unlock, pas la peine de re-prompter

        versionTapCount += 1

        // Haptic feedback à chaque tap : confirme que le tap est bien capté.
        // Sur le 5e tap, haptic plus fort pour signaler le déclenchement.
        if versionTapCount >= Self.tapsRequiredToPromptCode {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        // Reset le compteur après 5s d'inactivité (plus tolérant que 3s).
        versionTapResetWork?.cancel()
        let work = DispatchWorkItem { versionTapCount = 0 }
        versionTapResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)

        if versionTapCount >= Self.tapsRequiredToPromptCode {
            versionTapCount = 0
            versionTapResetWork?.cancel()
            debugCodeEntry = ""
            showDebugCodePrompt = true
        }
        #endif
    }

    private func validateDebugCode() {
        if debugCodeEntry == Self.debugUnlockCode {
            debugUnlocked = true
        } else {
            showWrongCodeAlert = true
        }
        debugCodeEntry = ""
    }

    private var legalSection: some View {
        Section("Légal") {
            Link(destination: privacyURL) {
                Label("Politique de confidentialité", systemImage: "hand.raised")
            }
            Link(destination: termsURL) {
                Label("Conditions d'utilisation", systemImage: "doc.text")
            }
            Link(destination: supportURL) {
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
        } else {
            restoreAlert = RestoreAlert(
                title: "Succès",
                message: "Vos achats ont été restaurés."
            )
        }
    }
}

// MARK: — Helper

struct RestoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
