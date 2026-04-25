import SwiftUI
import SwiftData

struct NameDetailView: View {
    let name: FirstName

    @Environment(\.modelContext) private var context
    @State private var isFavorite = false
    @State private var showPaywall = false

    private var favoriteService: FavoriteService { FavoriteService(context: context) }
    private let purchase = PurchaseManager.shared
    private let tts = PronunciationService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().padding(.horizontal)
                infoSection
                if name.etymology != nil {
                    etymologySection
                }
                popularitySection
                if name.phonetic != nil || !name.themes.isEmpty {
                    phoneticSection
                }
                similarNamesSection
            }
        }
        .navigationTitle(name.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color(red: 0.85, green: 0.45, blue: 0.55) : .primary)
                        .symbolEffect(.bounce, value: isFavorite)
                }
            }
        }
        .onAppear {
            isFavorite = favoriteService.isFavorite(nameId: name.id)
        }
    }

    // MARK: — Header

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(genderGradient)
                    .frame(width: 100, height: 100)
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)

            VStack(spacing: 4) {
                Text(name.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                HStack(spacing: 8) {
                    genderBadge
                    Text(name.origin)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            speakButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal)
    }

    private var speakButton: some View {
        Button {
            if tts.isSpeaking {
                tts.stop()
            } else {
                tts.speak(name.name, locale: name.originLocale)
            }
        } label: {
            Label(
                tts.isSpeaking ? "Arrêter" : "Écouter",
                systemImage: tts.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill"
            )
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: — Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Signification")
            Text(name.meaning)
                .padding(.horizontal)
                .padding(.bottom, 20)

            InfoRow(label: "Syllabes", value: syllablesLabel)
            InfoRow(label: "Genre", value: name.gender.displayName)
        }
        .padding(.top, 20)
    }

    // MARK: — Etymology (Pro-gated)

    @ViewBuilder
    private var etymologySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Étymologie complète")
            if let etymology = name.etymology {
                Text(etymology)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .padding(.top, 8)
        .proGated(!purchase.isPro, mode: .teaser, title: "Étymologie complète — Pro",
                  teaser: "Découvrez l'origine et le sens profond de ce prénom.")
    }

    private var syllablesLabel: String {
        switch name.syllables {
        case 1: "1 syllabe"
        default: "\(name.syllables) syllabes"
        }
    }

    // MARK: — Popularity

    private var popularitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Popularité")
            HStack(spacing: 16) {
                PopularityCard(country: "🇫🇷 France", rank: name.popularityRankFR)
                PopularityCard(country: "🇺🇸 États-Unis", rank: name.popularityRankUS)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 8)
    }

    // MARK: — Phonetics (Pro-gated)

    @ViewBuilder
    private var phoneticSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Phonétique & Thèmes")
            VStack(alignment: .leading, spacing: 12) {
                if let phonetic = name.phonetic {
                    HStack {
                        Text("Phonétique").foregroundStyle(.secondary)
                        Spacer()
                        Text(phonetic).fontWeight(.medium)
                    }
                }
                if !name.themes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thèmes").foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(name.themes, id: \.self) { theme in
                                Text(theme)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .proGated(!purchase.isPro, mode: .blur, title: "Étymologie Pro")
        }
        .padding(.top, 8)
    }

    // MARK: — Similar Names (Pro-gated)

    private var similarNamesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Prénoms similaires")
            SimilarNamesContent(name: name)
                .proGated(!purchase.isPro, mode: .blur, title: "Prénoms similaires Pro")
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
        .padding(.top, 8)
    }

    // MARK: — Helpers

    private var shareText: String {
        "J'aime le prénom \(name.name) — \(name.meaning) (origine : \(name.origin))"
    }

    private var genderGradient: LinearGradient {
        switch name.gender {
        case .female:
            LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.72), Color(red: 0.80, green: 0.40, blue: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .male:
            LinearGradient(colors: [Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.30, green: 0.50, blue: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unisex:
            LinearGradient(colors: [Color(red: 0.75, green: 0.88, blue: 0.75), Color(red: 0.45, green: 0.68, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var genderBadge: some View {
        Text(name.gender.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(genderBadgeColor.opacity(0.15))
            .foregroundStyle(genderBadgeColor)
            .clipShape(Capsule())
    }

    private var genderBadgeColor: Color {
        switch name.gender {
        case .female: Color(red: 0.85, green: 0.35, blue: 0.50)
        case .male: Color(red: 0.30, green: 0.50, blue: 0.80)
        case .unisex: Color(red: 0.35, green: 0.60, blue: 0.35)
        }
    }

    private func toggleFavorite() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        let result = favoriteService.toggle(nameId: name.id, isPro: purchase.isPro)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            switch result {
            case .added: isFavorite = true
            case .removed: isFavorite = false
            case .limitReached: showPaywall = true
            case .alreadyAdded: break
            }
        }
    }
}

// MARK: — Sub-views

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

private struct PopularityCard: View {
    let country: String
    let rank: Int?
    var body: some View {
        VStack(spacing: 4) {
            Text(country).font(.caption).foregroundStyle(.secondary)
            if let rank {
                Text("#\(rank)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
            } else {
                Text("—").font(.title2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SimilarNamesContent: View {
    let name: FirstName
    @State private var similar: [FirstName] = []

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(similar) { n in
                NavigationLink(value: n) {
                    Text(n.name)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            let filter = NameFilter(
                gender: name.gender,
                origins: [name.origin],
                syllables: name.syllables,
                sortByPopularity: true
            )
            let candidates = (try? NameDatabase.shared.filtered(filter)) ?? []
            similar = Array(candidates.filter { $0.id != name.id }.prefix(8))
        }
    }
}

// MARK: — Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > width && rowX > 0 {
                height += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowX = bounds.minX
        var rowY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX && rowX > bounds.minX {
                rowY += rowHeight + spacing
                rowX = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: — Gender display

private extension Gender {
    var displayName: String {
        switch self {
        case .female: "Féminin"
        case .male: "Masculin"
        case .unisex: "Mixte"
        }
    }
}
