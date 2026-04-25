import WidgetKit
import SwiftUI
import AppIntents

// MARK: — Timeline entry

struct ProNameEntry: TimelineEntry {
    let date: Date
    let firstName: FirstName
    let isPro: Bool
    let displayMode: DisplayMode
}

// MARK: — Provider

struct ProNameProvider: AppIntentTimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme")

    func placeholder(in context: Context) -> ProNameEntry {
        ProNameEntry(date: .now, firstName: fallback, isPro: false, displayMode: .full)
    }

    func snapshot(for configuration: NameWidgetConfiguration, in context: Context) async -> ProNameEntry {
        ProNameEntry(
            date: .now,
            firstName: pick(for: configuration),
            isPro: isPro,
            displayMode: configuration.displayMode
        )
    }

    func timeline(for configuration: NameWidgetConfiguration, in context: Context) async -> Timeline<ProNameEntry> {
        let entry = ProNameEntry(
            date: .now,
            firstName: pick(for: configuration),
            isPro: isPro,
            displayMode: configuration.displayMode
        )
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        return Timeline(entries: [entry], policy: .after(midnight))
    }

    // MARK: — Helpers

    private var isPro: Bool {
        sharedDefaults?.bool(forKey: "isPro") ?? false
    }

    private var fallback: FirstName {
        (try? NameDatabase.shared.nameForDate(.now))
            ?? FirstName(id: 0, name: "Emma", gender: .female, origin: "Latin",
                         originLocale: nil, meaning: "entière, universelle",
                         syllables: 2, popularityRankFR: 1, popularityRankUS: nil,
                         themes: [], phonetic: nil, etymology: nil)
    }

    private func pick(for configuration: NameWidgetConfiguration) -> FirstName {
        guard var pool = try? NameDatabase.shared.all(), !pool.isEmpty else {
            return fallback
        }
        if configuration.gender != .all {
            if let g = Gender(rawValue: configuration.gender.rawValue) {
                pool = pool.filter { $0.gender == g || $0.gender == .unisex }
            }
        }
        if let originEntities = configuration.origins, !originEntities.isEmpty {
            let ids = Set(originEntities.map { $0.id })
            let filtered = pool.filter { ids.contains($0.origin) }
            if !filtered.isEmpty { pool = filtered }
        }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return pool[day % pool.count]
    }
}

// MARK: — Widget view

struct ProNameWidgetView: View {
    let entry: ProNameEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            content
            if !entry.isPro { proOverlay }
        }
        .containerBackground(.regularMaterial, for: .widget)
        .widgetURL(entry.isPro
            ? URL(string: "prenomme://name/\(entry.firstName.id)")
            : URL(string: "prenomme://paywall"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium: mediumView
        case .systemLarge:  largeView
        default:            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Pro", systemImage: "sparkles")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(sage)
            Text(entry.firstName.name)
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if entry.displayMode != .nameOnly {
                Text(entry.firstName.origin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if entry.displayMode == .full {
                Text(entry.firstName.meaning)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(String(entry.firstName.name.prefix(1)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("Prénomme Pro", systemImage: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(sage)
                Text(entry.firstName.name)
                    .font(.title.bold())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if entry.displayMode != .nameOnly {
                    Text(entry.firstName.origin)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if entry.displayMode == .full {
                    Text(entry.firstName.meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Prénomme Pro", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(sage)
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Text(String(entry.firstName.name.prefix(1)))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            Text(entry.firstName.name)
                .font(.largeTitle.bold())
            if entry.displayMode != .nameOnly {
                Text(entry.firstName.origin)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            if entry.displayMode == .full {
                Text(entry.firstName.meaning)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                if let rank = entry.firstName.popularityRankFR {
                    Text("Rang FR : #\(rank)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(genderColor.opacity(0.8))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var proOverlay: some View {
        ZStack {
            Color(red: 0.59, green: 0.69, blue: 0.49).opacity(0.82)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                Text("Personnalisez avec\nPrénomme Pro")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var genderColor: Color {
        switch entry.firstName.gender {
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male:   Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.45, green: 0.68, blue: 0.45)
        }
    }

    private var sage: Color { Color(red: 0.59, green: 0.69, blue: 0.49) }
}

// MARK: — Widget definition

struct ProNameWidget: Widget {
    let kind = "ProNameWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NameWidgetConfiguration.self,
            provider: ProNameProvider()
        ) { entry in
            ProNameWidgetView(entry: entry)
        }
        .configurationDisplayName("Prénomme Pro")
        .description("Un prénom personnalisé selon vos critères.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
