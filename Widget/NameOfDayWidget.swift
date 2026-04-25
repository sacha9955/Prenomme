import WidgetKit
import SwiftUI

// MARK: — Timeline entry

struct NameEntry: TimelineEntry {
    let date: Date
    let name: String
    let meaning: String
    let gender: String
}

// MARK: — Provider

struct NameOfDayProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme")

    func placeholder(in context: Context) -> NameEntry {
        NameEntry(date: .now, name: "Emma", meaning: "entière, universelle", gender: "female")
    }

    func getSnapshot(in context: Context, completion: @escaping (NameEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NameEntry>) -> Void) {
        let current = entry(for: .now)
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        completion(Timeline(entries: [current], policy: .after(midnight)))
    }

    private func entry(for date: Date) -> NameEntry {
        guard let firstName = try? NameDatabase.shared.nameForDate(date) else {
            return NameEntry(date: date, name: "—", meaning: "", gender: "unisex")
        }
        return NameEntry(
            date: date,
            name: firstName.name,
            meaning: firstName.meaning,
            gender: firstName.gender.rawValue
        )
    }
}

// MARK: — Widget view

struct NameOfDayWidgetView: View {
    var entry: NameEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                Text("Prénom du jour")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.name)
                .font(.title2.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(entry.meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.92), Color(red: 0.93, green: 0.97, blue: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
        .widgetURL(URL(string: "prenomme://browse"))
    }
}

// MARK: — Widget definition

struct NameOfDayWidget: Widget {
    let kind = "NameOfDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NameOfDayProvider()) { entry in
            NameOfDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Prénom du jour")
        .description("Découvrez un nouveau prénom chaque jour.")
        .supportedFamilies([.systemSmall])
    }
}
