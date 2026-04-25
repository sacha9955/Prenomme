import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var trending: [FirstName] = []
    @State private var nameOfDay: FirstName? = nil
    @State private var suggestions: [SuggestionService.Suggestion] = []
    @State private var showPaywall = false
    @State private var favoriteNames: [FirstName] = []

    @Query(sort: \Favorite.addedAt, order: .reverse)
    private var favorites: [Favorite]

    private let originService = OriginService.shared
    private let purchase = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
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
                                    colors: [Color(red: 0.92, green: 0.76, blue: 0.68), Color(red: 0.72, green: 0.82, blue: 0.72)],
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
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
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
        .proGated(!purchase.isPro)
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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Trending

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Tendances", subtitle: "Les plus populaires en France")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trending) { name in
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
        trending = Array(allNames.prefix(10))
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male: Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.45, green: 0.68, blue: 0.45)
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var genderColor: Color {
        switch suggestion.name.gender {
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male:   Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.45, green: 0.68, blue: 0.45)
        }
    }
}
