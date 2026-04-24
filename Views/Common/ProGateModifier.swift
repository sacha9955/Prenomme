import SwiftUI

/// Grays out and overlays a "Pro" badge on any view when the user is not Pro.
/// Tapping opens PaywallView as a sheet.
struct ProGateModifier: ViewModifier {

    let isActive: Bool
    @State private var showPaywall = false
    private let purchase = PurchaseManager.shared

    func body(content: Content) -> some View {
        Group {
            if purchase.isPro || !isActive {
                content
            } else {
                content
                    .disabled(true)
                    .overlay(proOverlay)
                    .onTapGesture { showPaywall = true }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
            }
        }
    }

    private var proOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            ProBadge()
                .padding(8)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func proGated(_ isActive: Bool = true) -> some View {
        modifier(ProGateModifier(isActive: isActive))
    }
}

// MARK: — Badge

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
