import SwiftUI

struct BrowseView: View {
    @State private var filter = NameFilter()
    @State private var names: [FirstName] = []
    @State private var showFilter = false
    @State private var showPaywall = false
    @State private var navigationPath: [FirstName] = []

    private let router = NavigationRouter.shared
    private let purchase = PurchaseManager.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(names) { name in
                        NavigationLink(value: name) {
                            NameRow(name: name)
                                .padding(14)
                                .background(
                                    Color.appSurfaceElevated,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.appHairline, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Explorer")
            .navigationDestination(for: FirstName.self) { name in
                NameDetailView(name: name)
            }
            .searchable(text: $filter.searchQuery, prompt: "Rechercher un prénom…")
            .refreshable { await loadNames() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if purchase.isPro {
                            showFilter = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                            .symbolEffect(.bounce, value: filter.isActive)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                FilterSheet(filter: $filter)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task(id: filter) {
                await loadNames()
            }
            .onChange(of: router.pendingNameId) { _, id in
                guard let id else { return }
                Task {
                    if let name = try? NameDatabase.shared.byId(id) {
                        navigationPath.append(name)
                    }
                    router.pendingNameId = nil
                }
            }
        }
    }

    private static let freeSearchLimit = 50

    private func loadNames() async {
        var results = (try? NameDatabase.shared.filtered(filter)) ?? []
        if !purchase.isPro && results.count > Self.freeSearchLimit {
            results = Array(results.prefix(Self.freeSearchLimit))
        }
        names = results
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
                HStack(spacing: 3) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 9, weight: .bold))
                    Text("#\(rank)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(genderColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(genderColor.opacity(0.14), in: Capsule())
            }
        }
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color.genderFemale
        case .male: Color.genderMale
        case .unisex: Color.genderUnisex
        }
    }
}
