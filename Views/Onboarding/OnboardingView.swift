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
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.76, blue: 0.68), Color(red: 0.72, green: 0.82, blue: 0.72)],
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
                            colors: [Color(red: 0.79, green: 0.48, blue: 0.39), Color(red: 0.55, green: 0.72, blue: 0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)

                VStack(spacing: 12) {
                    Text("Prénomme")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.20, blue: 0.18))
                    Text("Trouvez le prénom parfait\npour votre futur enfant.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.32))
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
    private let features: [(String, String, String)] = [
        ("magnifyingglass", "500+ prénoms", "Explorez par origine, genre, initiale ou nombre de syllabes."),
        ("heart.fill", "Vos favoris", "Sauvegardez et comparez vos coups de cœur."),
        ("speaker.wave.2.fill", "Écoute audio", "Entendez la prononciation exacte en un tap."),
        ("square.grid.2x2.fill", "Par origine", "Découvrez les prénoms hébreux, nordiques, japonais…"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                Text("Tout ce qu'il vous faut")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.20, blue: 0.18))
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    ForEach(features, id: \.0) { icon, title, desc in
                        FeatureRow(icon: icon, title: title, description: desc)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
                Spacer()
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: — Screen 3: Family name

private struct FamilyNameScreen: View {
    @Binding var familyName: String
    let onDone: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.72, green: 0.82, blue: 0.72), Color(red: 0.92, green: 0.76, blue: 0.68)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 12) {
                    Text("Votre nom de famille")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.20, blue: 0.18))
                        .multilineTextAlignment(.center)
                    Text("Optionnel — pour vérifier la\ncompatibilité phonétique des prénoms.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.32))
                }

                TextField("Ex: Dupont", text: $familyName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused)
                    .padding(.horizontal, 32)
                    .submitLabel(.done)
                    .onSubmit(onDone)

                Button(action: onDone) {
                    Text("Commencer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.79, green: 0.48, blue: 0.39), Color(red: 0.55, green: 0.72, blue: 0.55)],
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
    }
}
