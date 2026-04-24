import SwiftUI

struct HomeView: View {
    @State private var trending: [FirstName] = []
    @State private var nameOfDay: FirstName? = nil
    private let originService = OriginService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let nameOfDay {
                        nameOfDayCard(nameOfDay)
                    }
                    trendingSection
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
            .task {
                await loadData()
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
            SectionTitle(title: "Parcourir par origine", subtitle: "\(originService.origins.count) origines")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(originService.origins) { origin in
                        NavigationLink(value: origin) {
                            OriginCard(origin: origin)
                        }
                        .buttonStyle(.plain)
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
