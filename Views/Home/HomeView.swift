import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var trending: [FirstName] = []
    @State private var nameOfDay: FirstName? = nil
    @State private var suggestions: [SuggestionService.Suggestion] = []
    @State private var showPaywall = false
    @State private var showThankYouPro = false
    @State private var favoriteNames: [FirstName] = []
    @State private var trendingGender: Gender? = nil

    @Query(sort: \Favorite.addedAt, order: .reverse)
    private var favorites: [Favorite]

    private let originService = OriginService.shared
    private let purchase = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if purchase.isPro {
                        proBadge
                    } else {
                        proUpsellBanner
                    }
                    if let nameOfDay {
                        nameOfDayCard(nameOfDay)
                    }
                    trendingSection
                    if !suggestions.isEmpty || purchase.isPro {
                        suggestionsSection
                    }
                    originsSection
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Prénomme")
            .navigationDestination(for: FirstName.self) { name in
                NameDetailView(name: name)
            }
            .navigationDestination(for: OriginMeta.self) { origin in
                OriginDetailView(origin: origin)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showThankYouPro) {
                ThankYouProView()
            }
            .task {
                await loadData()
            }
            .onChange(of: favorites) {
                Task { await loadSuggestions() }
            }
        }
    }

    // MARK: — Name of the Day

    private func nameOfDayCard(_ name: FirstName) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Prénom du jour", systemImage: "sun.max.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand)
            NavigationLink(value: name) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(name.meaning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandBeige, Color.brandSage],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Text(String(name.name.prefix(1)))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
                .background(Color.appSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: — Pro upsell banner

    private var proUpsellBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Passez Pro")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Favoris illimités · Swipes illimités · Étymologie")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text(PurchaseManager.fallbackPriceDisplay)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.25))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.brandSage,
                             Color.brand],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.brand.opacity(0.30),
                    radius: 10, y: 4)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }

    private var proBadge: some View {
        Button { showThankYouPro = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.brand)
                Text("Prénomme Pro ✨")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.brand.opacity(0.10))
            .clipShape(Capsule())
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Suggestions pour vous",
                         subtitle: "Basées sur vos favoris")
            if !purchase.isPro {
                proTeaser
            } else if suggestions.isEmpty {
                Text("Ajoutez des favoris pour recevoir des suggestions personnalisées.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { suggestion in
                            NavigationLink(value: suggestion.name) {
                                SuggestionCard(suggestion: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .proGated(!purchase.isPro, mode: .blur, title: "Suggestions Pro")
    }

    private var proTeaser: some View {
        Button { showPaywall = true } label: {
            HStack {
                Image(systemName: "wand.and.sparkles")
                Text("Suggestions personnalisées — Pro")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Trending

    private var filteredTrending: [FirstName] {
        let pool = trendingGender == nil ? trending : trending.filter { $0.gender == trendingGender }
        return Array(pool.prefix(10))
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Tendances", subtitle: "Les plus populaires en France")
            genderFilterChips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredTrending) { name in
                        NavigationLink(value: name) {
                            TrendingCard(name: name)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var genderFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                genderChip(nil, label: "Tous")
                ForEach(Gender.allCases, id: \.rawValue) { g in
                    genderChip(g, label: g.label)
                }
            }
            .padding(.horizontal)
        }
    }

    private func genderChip(_ gender: Gender?, label: String) -> some View {
        Button {
            trendingGender = gender
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(trendingGender == gender ? chipColor(gender) : Color(.systemGray5))
                .foregroundStyle(trendingGender == gender ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func chipColor(_ gender: Gender?) -> Color {
        switch gender {
        case .female: Color.genderFemale
        case .male:   Color.genderMale
        case .unisex: Color.genderUnisex
        case nil:     Color.accentColor
        }
    }

    // MARK: — Origins

    private var originsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Parcourir par origine", subtitle: "\(originService.publicOrigins.count) origines")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(originService.publicOrigins) { origin in
                        NavigationLink(value: origin) {
                            OriginCard(origin: origin)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: — Data

    private func loadData() async {
        nameOfDay = try? NameDatabase.shared.nameForDate(Date())
        let allNames = (try? NameDatabase.shared.all()) ?? []
        trending = Array(allNames.prefix(200))
        await loadSuggestions()
    }

    private func loadSuggestions() async {
        guard purchase.isPro else { return }
        var loaded: [FirstName] = []
        for fav in favorites {
            if let name = try? NameDatabase.shared.byId(fav.nameId) {
                loaded.append(name)
            }
        }
        favoriteNames = loaded
        guard !loaded.isEmpty else { suggestions = []; return }
        let allNames = (try? NameDatabase.shared.all()) ?? []
        suggestions = SuggestionService.shared.suggest(from: allNames, favorites: loaded, count: 10)
    }
}

// MARK: — Sub-views

private struct SectionTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

private struct TrendingCard: View {
    let name: FirstName
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            Text(name.name)
                .font(.headline)
            Text(name.origin)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let rank = name.popularityRankFR {
                Text("#\(rank)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(genderColor.opacity(0.7))
            }
        }
        .frame(width: 110)
        .padding(14)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color.genderFemale
        case .male: Color.genderMale
        case .unisex: Color.genderUnisex
        }
    }
}

private struct OriginCard: View {
    let origin: OriginMeta
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: origin.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(origin.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(origin.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(12)
        }
        .frame(width: 140, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

private struct SuggestionCard: View {
    let suggestion: SuggestionService.Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Text(String(suggestion.name.name.prefix(1)))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            Text(suggestion.name.name)
                .font(.headline)
            Text(suggestion.name.origin)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(suggestion.matchPercent)% match")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(genderColor.opacity(0.8))
        }
        .frame(width: 110)
        .padding(14)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var genderColor: Color {
        switch suggestion.name.gender {
        case .female: Color.genderFemale
        case .male:   Color.genderMale
        case .unisex: Color.genderUnisex
        }
    }
}
