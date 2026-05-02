import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var familyName = ""

    var body: some View {
        TabView(selection: $page) {
            WelcomeScreen().tag(0)
            FeaturesScreen().tag(1)
            FamilyNameScreen(familyName: $familyName, onDone: finish).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
        .animation(.easeInOut, value: page)
    }

    private func finish() {
        if !familyName.trimmingCharacters(in: .whitespaces).isEmpty {
            saveFamilyName()
        }
        withAnimation { hasSeenOnboarding = true }
    }

    private func saveFamilyName() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? context.fetch(descriptor).first {
            settings.familyName = familyName
        } else {
            let settings = UserSettings()
            settings.familyName = familyName
            context.insert(settings)
        }
        try? context.save()
    }
}

// MARK: — Screen 1: Welcome

private struct WelcomeScreen: View {
    private let accentColor = Color.brand
    private let greenColor = Color.brandSage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBeige, greenColor],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                Text("P")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 140)
                    .background(
                        LinearGradient(
                            colors: [accentColor, greenColor],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)

                VStack(spacing: 12) {
                    Text("Prénomme")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("Trouvez le prénom\nqui lui ressemble déjà")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("Glissez pour continuer →")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: — Screen 2: Features

private struct FeaturesScreen: View {
    private let accentColor = Color.brand

    private let features: [(String, String, String)] = [
        ("magnifyingglass", "Recherche intelligente", "Filtrez par genre, origine, initiale ou nombre de syllabes."),
        ("heart.fill", "Vos favoris", "Sauvegardez et comparez vos coups de cœur."),
        ("square.grid.2x2.fill", "Par origine", "Découvrez les prénoms hébreux, nordiques, japonais, etc."),
        ("sparkles", "Suggestions intelligentes", "Laissez-vous inspirer par des recommandations personnalisées."),
    ]

    private var nameCountLabel: String {
        let count = NameDatabase.shared.totalNamesCount
        guard count > 0 else { return "Une vaste base de prénoms à explorer" }
        // Round down to the nearest hundred for a cleaner marketing display
        let rounded = (count / 100) * 100
        return "\(rounded)+ prénoms à explorer"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text("Tout ce qu'il vous faut")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(nameCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(features, id: \.0) { icon, title, desc in
                        FeatureRow(icon: icon, title: title, description: desc, accentColor: accentColor)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: — Screen 3: Family name + Premium

private struct FamilyNameScreen: View {
    @Binding var familyName: String
    let onDone: () -> Void
    @FocusState private var focused: Bool
    @State private var showPaywall = false
    @State private var teaserDismissed = false

    private let accentColor = Color.brand
    private let greenColor = Color.brandSage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [greenColor, Color.brandBeige],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Section 1: Family Name input
                VStack(spacing: 12) {
                    Text("Votre nom de famille")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Optionnel — pour vérifier la\ncompatibilité phonétique des prénoms.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.textSecondary)
                }

                TextField("Ex: Dupont", text: $familyName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.appSurfaceElevated.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused)
                    .padding(.horizontal, 32)
                    .submitLabel(.done)
                    .onSubmit(onDone)

                Spacer()

                // Section 2: Premium teaser (hidden if user tapped "Plus tard")
                if !teaserDismissed {
                    PremiumTeaserCard(
                        accentColor: accentColor,
                        showPaywall: $showPaywall,
                        onDismiss: { withAnimation { teaserDismissed = true } }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer()

                // Main CTA
                Button(action: onDone) {
                    Text("Commencer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [accentColor, greenColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .onAppear { focused = true }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: — Premium teaser card (on Family Name screen)

private struct PremiumTeaserCard: View {
    let accentColor: Color
    @Binding var showPaywall: Bool
    let onDismiss: () -> Void

    private let premiumFeatures = [
        ("sparkles", "Suggestions intelligentes", "Trouvez vos prénoms préférés"),
        ("book.closed", "Étymologie complète", "Découvrez l'histoire de chaque prénom"),
        ("arrow.left.arrow.right", "Swipes illimités", "Explorez sans limite quotidienne"),
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("Déverrouillez Prénomme Pro")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(premiumFeatures, id: \.0) { icon, title, subtitle in
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 10) {
                Button {
                    showPaywall = true
                } label: {
                    Text("Découvrir Pro")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: onDismiss) {
                    Text("Plus tard")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(Color.appSurfaceElevated.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }
}
