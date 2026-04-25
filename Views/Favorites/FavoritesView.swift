import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]
    @Environment(\.modelContext) private var context
    @State private var namesById: [Int: FirstName] = [:]
    @State private var sortOrder: FavoriteSort = .dateAdded
    @State private var showPaywall = false
    @State private var showComparator = false
    @State private var isGeneratingPDF = false
    @State private var pdfURL: IdentifiableURL?

    private let purchase = PurchaseManager.shared
    private var favoriteService: FavoriteService { FavoriteService(context: context) }

    private var sorted: [Favorite] {
        switch sortOrder {
        case .dateAdded: favorites
        case .alphabetical:
            favorites.sorted {
                let a = namesById[$0.nameId]?.name ?? ""
                let b = namesById[$1.nameId]?.name ?? ""
                return a < b
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Favoris")
            .navigationDestination(for: FirstName.self) { name in
                NameDetailView(name: name)
            }
            .toolbar {
                if !favorites.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if purchase.isPro {
                                showComparator = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Label("Comparer", systemImage: "rectangle.split.3x1")
                        }
                        .proGated(!purchase.isPro, mode: .teaser, title: "Comparer — Pro",
                                  teaser: "Comparez vos favoris côte à côte.")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Trier", selection: $sortOrder) {
                                ForEach(FavoriteSort.allCases) { order in
                                    Label(order.label, systemImage: order.icon).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showComparator) {
                ComparatorView(names: Array(sorted.compactMap { namesById[$0.nameId] }.prefix(4)))
            }
            .sheet(item: $pdfURL) { wrapped in
                ShareLink(
                    item: wrapped.url,
                    preview: SharePreview(
                        "Ma sélection de prénoms",
                        image: Image(systemName: "doc.richtext")
                    )
                )
                .presentationDetents([.medium])
            }
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Génération du PDF…")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .task {
                await loadNames()
            }
            .onChange(of: favorites) {
                Task { await loadNames() }
            }
        }
    }

    // MARK: — List

    private var list: some View {
        List {
            ForEach(sorted) { fav in
                if let name = namesById[fav.nameId] {
                    NavigationLink(value: name) {
                        NameRow(name: name)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                favoriteService.remove(nameId: fav.nameId)
                            }
                        } label: {
                            Label("Retirer", systemImage: "heart.slash")
                        }
                    }
                }
            }
            pdfExportRow
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sorted.map(\.id))
    }

    @ViewBuilder
    private var pdfExportRow: some View {
        Section {
            Button {
                if purchase.isPro {
                    exportPDF()
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Exporter en PDF", systemImage: "square.and.arrow.up")
                    .foregroundStyle(purchase.isPro ? .primary : .secondary)
            }
            .proGated(!purchase.isPro, mode: .teaser, title: "Export PDF — Pro",
                      teaser: "Exportez votre liste de favoris en PDF.")
        }
    }

    // MARK: — Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            VStack(spacing: 8) {
                Text("Aucun favori")
                    .font(.headline)
                Text("Parcourez les prénoms et appuyez sur ♡ pour les sauvegarder ici.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Helpers

    private func loadNames() async {
        var result: [Int: FirstName] = [:]
        for fav in favorites {
            if let name = try? NameDatabase.shared.byId(fav.nameId) {
                result[fav.nameId] = name
            }
        }
        namesById = result
    }

    private func exportPDF() {
        let names = sorted.compactMap { namesById[$0.nameId] }
        guard !names.isEmpty else { return }
        isGeneratingPDF = true
        Task.detached(priority: .userInitiated) {
            let data = PDFExporter.shared.generate(names: names)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("prenoms-\(Int(Date().timeIntervalSince1970)).pdf")
            try? data.write(to: url)
            await MainActor.run {
                isGeneratingPDF = false
                pdfURL = IdentifiableURL(url: url)
            }
        }
    }
}

// MARK: — Helpers

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: — Sort

enum FavoriteSort: String, CaseIterable, Identifiable {
    case dateAdded
    case alphabetical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAdded: "Date d'ajout"
        case .alphabetical: "Alphabétique"
        }
    }

    var icon: String {
        switch self {
        case .dateAdded: "clock"
        case .alphabetical: "textformat.abc"
        }
    }
}
