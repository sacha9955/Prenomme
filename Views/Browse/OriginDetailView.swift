import SwiftUI

struct OriginDetailView: View {
    let origin: OriginMeta

    @State private var filter = NameFilter()
    @State private var names: [FirstName] = []

    init(origin: OriginMeta) {
        self.origin = origin
        _filter = State(initialValue: NameFilter(origins: [origin.name]))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                originHeader
                genderFilterBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider().padding(.horizontal)
                nameList
            }
        }
        .navigationTitle(origin.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: filter.gender) {
            await loadNames()
        }
    }

    // MARK: — Header

    private var originHeader: some View {
        ZStack {
            LinearGradient(
                colors: origin.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Text(origin.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(origin.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text("\(origin.count) prénoms")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.25))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Gender filter

    private var genderFilterBar: some View {
        HStack(spacing: 8) {
            ForEach([Gender?.none, Gender?.some(.female), Gender?.some(.male), Gender?.some(.unisex)], id: \.?.rawValue) { gender in
                let label = gender.map { $0.shortLabel } ?? "Tous"
                let selected = filter.gender == gender
                Button {
                    filter.gender = selected ? nil : gender
                } label: {
                    Text(label)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selected ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: — Name list

    private var nameList: some View {
        LazyVStack(spacing: 0) {
            ForEach(names) { name in
                NavigationLink(value: name) {
                    NameRow(name: name)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 72)
            }
        }
        .padding(.top, 8)
    }

    private func loadNames() async {
        let f = NameFilter(
            gender: filter.gender,
            origins: [origin.name],
            sortByPopularity: filter.sortByPopularity
        )
        names = (try? NameDatabase.shared.filtered(f)) ?? []
    }
}

private extension Gender {
    var shortLabel: String {
        switch self {
        case .female: "♀ Féminin"
        case .male: "♂ Masculin"
        case .unisex: "⚥ Mixte"
        }
    }
}
