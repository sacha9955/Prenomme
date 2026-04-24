import SwiftUI

struct BrowseView: View {
    @State private var filter = NameFilter()
    @State private var names: [FirstName] = []
    @State private var showFilter = false

    var body: some View {
        NavigationStack {
            List(names) { name in
                NavigationLink(value: name) {
                    NameRow(name: name)
                }
            }
            .navigationTitle("Explorer")
            .navigationDestination(for: FirstName.self) { name in
                NameDetailView(name: name)
            }
            .searchable(text: $filter.searchQuery, prompt: "Rechercher un prénom…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                FilterSheet(filter: $filter)
                    .presentationDetents([.large])
            }
            .task(id: filter) {
                await loadNames()
            }
        }
    }

    private func loadNames() async {
        names = (try? NameDatabase.shared.filtered(filter)) ?? []
    }
}

// MARK: — Row

struct NameRow: View {
    let name: FirstName

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.name)
                    .font(.headline)
                Text(name.origin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rank = name.popularityRankFR {
                Text("#\(rank)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male: Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.55, green: 0.72, blue: 0.55)
        }
    }
}
