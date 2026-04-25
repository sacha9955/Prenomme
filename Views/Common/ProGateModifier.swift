import SwiftUI

enum ProGateMode {
    case blur
    case teaser
}

struct ProGateModifier: ViewModifier {

    let isActive: Bool
    let mode: ProGateMode
    let title: String
    let teaser: String?

    @State private var showPaywall = false
    private let purchase = PurchaseManager.shared

    func body(content: Content) -> some View {
        Group {
            if purchase.isPro || !isActive {
                content
            } else if mode == .blur {
                content
                    .blur(radius: 8)
                    .disabled(true)
                    .overlay(blurOverlay)
            } else {
                teaserPlaceholder
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // Mode A — blur + lock overlay on top of visible content
    private var blurOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Button {
                    showPaywall = true
                } label: {
                    Text("Découvrir Pro")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.79, green: 0.48, blue: 0.39), in: Capsule())
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // Mode B — replace content entirely with a teaser card
    private var teaserPlaceholder: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let teaser {
                        Text(teaser)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.79, green: 0.48, blue: 0.39),
                                     Color(red: 0.72, green: 0.43, blue: 0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

extension View {
    func proGated(
        _ isActive: Bool = true,
        mode: ProGateMode = .blur,
        title: String = "Fonctionnalité Pro",
        teaser: String? = nil
    ) -> some View {
        modifier(ProGateModifier(isActive: isActive, mode: mode, title: title, teaser: teaser))
    }
}

// MARK: — Badge (kept for standalone use)

struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.79, green: 0.48, blue: 0.39),
                                     Color(red: 0.72, green: 0.43, blue: 0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
    }
}
