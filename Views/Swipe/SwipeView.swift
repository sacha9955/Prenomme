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
        NavigationStack {
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
            .navigationTitle("Swiper")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Limite quotidienne atteinte", isPresented: $showLimitAlert) {
                Button("Découvrir Pro") { showPaywall = true }
                Button("Plus tard", role: .cancel) {}
            } message: {
                Text("Vous avez utilisé vos 30 swipes gratuits aujourd'hui. Revenez demain ou passez à Pro pour des swipes illimités.")
            }
            .task(id: genderFilter) { await loadDeck() }
        }
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
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male:   Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.45, green: 0.68, blue: 0.45)
        case nil:     Color.accentColor
        }
    }

    // MARK: — Card stack

    private var cardStack: some View {
        ZStack {
            ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { idx, name in
                if idx == 0 {
                    SwipeCardView(name: name, dragOffset: dragOffset)
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 22))
                        .gesture(dragGesture)
                        .zIndex(Double(100 - idx))
                } else {
                    SwipeCardView(name: name, dragOffset: .zero)
                        .scaleEffect(1.0 - CGFloat(idx) * 0.04)
                        .offset(y: CGFloat(idx) * 10)
                        .zIndex(Double(100 - idx))
                }
            }
        }
        .frame(height: 420)
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
            actionButton(systemImage: "heart.fill", color: Color(red: 0.85, green: 0.40, blue: 0.55)) {
                performSwipe(right: true)
            }
        }
    }

    private func actionButton(systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title.bold())
                .foregroundStyle(color)
                .frame(width: 68, height: 68)
                .background(color.opacity(0.12))
                .clipShape(Circle())
                .shadow(color: color.opacity(0.20), radius: 8, y: 3)
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
            if !deck.isEmpty { deck.removeFirst() }
            dragOffset = .zero
        }
    }

    private func loadDeck() async {
        var filter = NameFilter()
        filter.gender = genderFilter
        let names = (try? NameDatabase.shared.filtered(filter)) ?? []
        deck = names.shuffled()
    }
}

// MARK: — SwipeCardView

private struct SwipeCardView: View {
    let name: FirstName
    let dragOffset: CGSize

    private var likeOpacity: Double { min(1, max(0, Double(dragOffset.width) / 70)) }
    private var nopeOpacity: Double { min(1, max(0, Double(-dragOffset.width) / 70)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 4)

            VStack(alignment: .leading, spacing: 0) {
                heroHeader
                cardInfo
            }

            feedbackOverlay
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: genderGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
                Text(name.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 210)
    }

    private var cardInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                badge(name.origin, color: genderColor)
                badge(name.gender.label, color: .secondary)
                Spacer()
                if let rank = name.popularityRankFR {
                    Text("#\(rank)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(name.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(16)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var feedbackOverlay: some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.green)
                .rotationEffect(.degrees(-18))
                .opacity(likeOpacity)
                .padding(18)
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.red)
                .rotationEffect(.degrees(18))
                .opacity(nopeOpacity)
                .padding(18)
        }
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color(red: 0.85, green: 0.45, blue: 0.55)
        case .male:   Color(red: 0.35, green: 0.55, blue: 0.85)
        case .unisex: Color(red: 0.45, green: 0.68, blue: 0.45)
        }
    }

    private var genderGradient: [Color] {
        switch name.gender {
        case .female: [Color(red: 0.82, green: 0.38, blue: 0.52), Color(red: 0.93, green: 0.62, blue: 0.68)]
        case .male:   [Color(red: 0.28, green: 0.48, blue: 0.82), Color(red: 0.50, green: 0.68, blue: 0.88)]
        case .unisex: [Color(red: 0.38, green: 0.62, blue: 0.40), Color(red: 0.60, green: 0.78, blue: 0.52)]
        }
    }
}
