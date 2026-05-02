import SwiftUI
import SwiftData

struct SwipeView: View {
    @State private var deck: [FirstName] = []
    @State private var dragOffset: CGSize = .zero
    @State private var genderFilter: Gender? = nil
    @State private var showPaywall = false
    @State private var showLimitAlert = false
    @State private var counter = SwipeCounter()
    @Environment(\.modelContext) private var context

    private let purchase = PurchaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            genderBar
                .padding(.vertical, 12)
            if deck.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                Spacer()
                cardStack
                    .padding(.horizontal, 20)
                Spacer()
                actionRow
                    .padding(.bottom, 16)
                if !purchase.isPro {
                    counterLabel
                        .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Limite quotidienne atteinte", isPresented: $showLimitAlert) {
            Button("Découvrir Pro") { showPaywall = true }
            Button("Plus tard", role: .cancel) {}
        } message: {
            Text("Vous avez utilisé vos 20 swipes gratuits aujourd'hui. Revenez demain ou passez à Pro pour des swipes illimités.")
        }
        .task(id: genderFilter) { await loadDeck() }
    }

    // MARK: — Gender bar

    private var genderBar: some View {
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
            genderFilter = gender
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(genderFilter == gender ? chipColor(gender) : Color(.systemGray5))
                .foregroundStyle(genderFilter == gender ? .white : .primary)
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

    // MARK: — Card stack

    private var cardStack: some View {
        ZStack {
            ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { idx, name in
                if idx == 0 {
                    SwipeCardView(name: name, dragOffset: dragOffset, isPro: purchase.isPro)
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 22))
                        .gesture(dragGesture)
                        .zIndex(Double(100 - idx))
                } else {
                    SwipeCardView(name: name, dragOffset: .zero, isPro: purchase.isPro)
                        .scaleEffect(1.0 - CGFloat(idx) * 0.04)
                        .offset(y: CGFloat(idx) * 10)
                        .zIndex(Double(100 - idx))
                }
            }
        }
        .frame(height: 460)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                dragOffset = v.translation
            }
            .onEnded { v in
                if v.translation.width > 90 {
                    performSwipe(right: true)
                } else if v.translation.width < -90 {
                    performSwipe(right: false)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: — Action buttons

    private var actionRow: some View {
        HStack(spacing: 48) {
            actionButton(systemImage: "xmark", color: .red) {
                performSwipe(right: false)
            }
            actionButton(systemImage: "heart.fill", color: Color.genderFemale) {
                performSwipe(right: true)
            }
        }
    }

    private func actionButton(systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.45), radius: 14, y: 4)
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: — Counter

    private var counterLabel: some View {
        Text("\(counter.remaining) swipe\(counter.remaining > 1 ? "s" : "") gratuit\(counter.remaining > 1 ? "s" : "") aujourd'hui")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: — Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Plus de prénoms à découvrir")
                .font(.title3.weight(.semibold))
            Text("Changez le filtre ou revenez plus tard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Recharger") {
                Task { await loadDeck() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: — Swipe logic

    private func performSwipe(right: Bool) {
        guard !deck.isEmpty else { return }

        if !purchase.isPro && !counter.hasSwipesRemaining {
            showLimitAlert = true
            return
        }

        let name = deck[0]
        counter.increment()

        if right {
            FavoriteService(context: context).add(nameId: name.id, isPro: purchase.isPro)
        }

        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: right ? 600 : -600, height: 60)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // Retire la carte ET reset l'offset SANS animation, sinon le modifier
            // `.animation(value: dragOffset)` ligne 104 fait revenir la nouvelle carte
            // depuis (600,60) vers .zero en spring → flicker "revient puis passe vite".
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if !deck.isEmpty { deck.removeFirst() }
                dragOffset = .zero
            }
        }
    }

    private func loadDeck() async {
        var filter = NameFilter()
        filter.gender = genderFilter
        guard !Task.isCancelled else { return }
        do {
            let names = try NameDatabase.shared.filtered(filter)
            guard !Task.isCancelled else { return }
            deck = names.shuffled()
        } catch {
            // Keep existing deck on DB error
        }
    }
}

// MARK: — SwipeWithFavoritesView

struct SwipeWithFavoritesView: View {
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            Group {
                if selectedSegment == 0 {
                    SwipeView()
                } else {
                    FavoritesView()
                }
            }
            .navigationTitle(selectedSegment == 0 ? "Swiper" : "Favoris")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedSegment) {
                        Text("Swiper").tag(0)
                        Text("Favoris").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
        }
    }
}

// MARK: — SwipeCardView

private struct SwipeCardView: View {
    let name: FirstName
    let dragOffset: CGSize
    let isPro: Bool

    private var likeOpacity: Double { min(1, max(0, Double(dragOffset.width) / 70)) }
    private var nopeOpacity: Double { min(1, max(0, Double(-dragOffset.width) / 70)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.appSurfaceElevated)
                .shadow(color: .black.opacity(0.30), radius: 18, y: 6)

            VStack(alignment: .leading, spacing: 0) {
                heroHeader
                cardInfo
            }

            feedbackOverlay
        }
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 0.5)
        )
    }

    private var heroHeader: some View {
        ZStack(alignment: .center) {
            // Gradient adouci avec un point central plus chaud
            LinearGradient(
                colors: genderGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Initiale géante en watermark décoratif (déborde volontairement)
            Text(String(name.name.prefix(1).uppercased()))
                .font(.system(size: 280, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.14))
                .offset(x: -60, y: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Bloc texte central
            VStack(spacing: 10) {
                Spacer()
                Text(name.name)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.30), radius: 6, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let rank = name.popularityRankFR {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2.weight(.bold))
                        Text("#\(rank) en France")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.22), in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 260)
        .clipped()
    }

    private var cardInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Badges row
            HStack(spacing: 8) {
                badge(name.origin, color: genderColor, systemImage: "globe")
                badge(name.gender.label, color: .secondary, systemImage: nil)
                Spacer()
            }

            // Stats compactes : Lettres / Syllabes / Rang — presque toujours remplies
            statsRow

            // Texte principal : meaning prioritaire, fallback sur etymology (99,99% rempli)
            primaryTextBlock

            // Themes (tags) si dispo
            if !name.themes.isEmpty {
                themesRow
            }

            Spacer(minLength: 0)

            // Hints visuels swipe
            HStack(spacing: 0) {
                Label("Pas pour nous", systemImage: "arrow.left")
                    .foregroundStyle(.red.opacity(0.75))
                Spacer()
                Label("Coup de cœur", systemImage: "arrow.right")
                    .foregroundStyle(Color.genderFemale)
                    .labelStyle(TrailingIconLabelStyle())
            }
            .font(.caption2.weight(.semibold))
        }
        .padding(20)
    }

    // Grille stats — Lettres / Syllabes / Rang FR
    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(name.name.count)", label: "Lettres")
            statTile(value: "\(name.syllables)", label: name.syllables > 1 ? "Syllabes" : "Syllabe")
            statTile(
                value: name.popularityRankFR.map { "#\($0)" } ?? "—",
                label: "Rang FR"
            )
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Texte principal de la fiche.
    /// - Free : affiche `meaning` si rempli, sinon rien (étymologie réservée Pro).
    /// - Pro  : affiche `meaning` si rempli, sinon fallback sur `etymology` (99,99% rempli).
    @ViewBuilder
    private var primaryTextBlock: some View {
        let trimmedMeaning = name.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEtymology = (name.etymology ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedMeaning.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("SIGNIFICATION")
                Text(trimmedMeaning)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if isPro && !trimmedEtymology.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("ÉTYMOLOGIE")
                Text(trimmedEtymology)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if !isPro && !trimmedEtymology.isEmpty {
            // Teaser Pro discret : on signale qu'une étymologie existe mais on la verrouille.
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                Text("Étymologie complète avec Pro")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.brand)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.brand.opacity(0.12), in: Capsule())
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
            .tracking(0.6)
    }

    private var themesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(name.themes.prefix(4), id: \.self) { theme in
                    Text(theme)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(genderColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(genderColor)
                }
            }
        }
    }

    private func badge(_ text: String, color: Color, systemImage: String?) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    private var feedbackOverlay: some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green)
                .rotationEffect(.degrees(-18))
                .opacity(likeOpacity)
                .padding(20)
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.red)
                .rotationEffect(.degrees(18))
                .opacity(nopeOpacity)
                .padding(20)
        }
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color.genderFemale
        case .male:   Color.genderMale
        case .unisex: Color.genderUnisex
        }
    }

    private var genderGradient: [Color] {
        switch name.gender {
        case .female: [Color.genderFemale, Color.genderFemale.opacity(0.65)]
        case .male:   [Color.genderMale,   Color.genderMale.opacity(0.65)]
        case .unisex: [Color.genderUnisex, Color.genderUnisex.opacity(0.65)]
        }
    }
}

// Petit helper pour afficher icône à droite du texte (pour le hint coup de cœur)
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
