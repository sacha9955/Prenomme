import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var purchase = PurchaseManager.shared
    @State private var shouldPurchaseAfterLoad = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featureTable
                    purchaseSection
                    restoreButton
                    legalFooter
                }
            }
            closeButton
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: purchase.proProduct) { _, product in
            guard let product, shouldPurchaseAfterLoad else { return }
            shouldPurchaseAfterLoad = false
            Task { await purchase.purchase(product) }
        }
    }

    // MARK: — Hero

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.96, blue: 0.94),
                Color(red: 0.97, green: 0.93, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.79, green: 0.48, blue: 0.39),
                                     Color(red: 0.61, green: 0.69, blue: 0.53)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                Text("P")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
            }
            VStack(spacing: 6) {
                Text("Prénomme Pro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Le meilleur prénom pour votre enfant, sans limite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: — Feature table

    private var featureTable: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Feature.all) { feature in
                FeatureRow(feature: feature)
                if feature.id != Feature.all.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private var tableHeader: some View {
        HStack {
            Spacer()
            columnLabel("Gratuit", icon: "person")
            columnLabel("Pro", icon: "star.fill", accent: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(red: 0.79, green: 0.48, blue: 0.39).opacity(0.08),
                    in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
    }

    private func columnLabel(_ text: String, icon: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(accent ? Color(red: 0.79, green: 0.48, blue: 0.39) : .secondary)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(accent ? Color(red: 0.79, green: 0.48, blue: 0.39) : .secondary)
        }
        .frame(width: 60)
    }

    // MARK: — Purchase section

    private let accentColor = Color(red: 0.79, green: 0.48, blue: 0.39)

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            if purchase.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Chargement du prix…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 58)
            } else if purchase.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            } else {
                buyButton
            }

            if let errorMsg = purchase.purchaseError {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var buyButton: some View {
        if let product = purchase.proProduct {
            Button {
                Task { await purchase.purchase(product) }
            } label: {
                buyButtonLabel(price: product.displayPrice)
            }
        } else {
            // StoreKit unavailable — show fallback price, tap retries loading then auto-purchases
            VStack(spacing: 8) {
                Button {
                    shouldPurchaseAfterLoad = true
                    purchase.retryLoadProducts()
                } label: {
                    buyButtonLabel(price: PurchaseManager.fallbackPriceDisplay)
                        .opacity(0.65)
                }
                Text("Prix indicatif — connexion requise pour confirmer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func buyButtonLabel(price: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill").font(.callout)
            Text("Débloquer Pro — \(price)").font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            LinearGradient(
                colors: [accentColor, Color(red: 0.72, green: 0.43, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: accentColor.opacity(0.35), radius: 10, y: 4)
    }

    private var restoreButton: some View {
        Button {
            Task { await purchase.restore() }
        } label: {
            Text("Restaurer les achats")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
        }
        .padding(.top, 10)
    }

    private var legalFooter: some View {
        Text("Paiement unique. Pas d'abonnement. Partageable avec la famille.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 40)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.top, 56)
        .padding(.trailing, 20)
    }
}

// MARK: — Feature model

private struct Feature: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let free: FeatureValue
    let pro: FeatureValue

    enum FeatureValue {
        case yes
        case no
        case text(String)
    }

    static let all: [Feature] = [
        Feature(id: 1, icon: "heart",
                title: "Favoris",
                free: .text("10 max"),
                pro: .text("Illimité")),
        Feature(id: 2, icon: "arrow.left.arrow.right",
                title: "Swipes / jour",
                free: .text("20"),
                pro: .text("Illimité")),
        Feature(id: 3, icon: "globe",
                title: "Origine & signification",
                free: .yes,
                pro: .yes),
        Feature(id: 3, icon: "book.closed",
                title: "Étymologie complète",
                free: .no,
                pro: .yes),
        Feature(id: 4, icon: "waveform",
                title: "Prononciation audio",
                free: .no,
                pro: .yes),
        Feature(id: 5, icon: "sparkles",
                title: "Suggestions intelligentes",
                free: .no,
                pro: .yes),
        Feature(id: 6, icon: "doc.text",
                title: "Export PDF",
                free: .no,
                pro: .yes),
        Feature(id: 7, icon: "chart.bar",
                title: "Stats popularité",
                free: .no,
                pro: .yes),
        Feature(id: 8, icon: "applewatch",
                title: "Widget prénom du jour — Pro",
                free: .no,
                pro: .yes),
        Feature(id: 9, icon: "magnifyingglass",
                title: "Filtres avancés",
                free: .no,
                pro: .yes),
        Feature(id: 10, icon: "arrow.counterclockwise",
                title: "Historique des swipes",
                free: .no,
                pro: .yes),
    ]
}

// MARK: — Feature row

private struct FeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.callout)
                .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                .frame(width: 24)
            Text(feature.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            valueView(feature.free)
                .frame(width: 60)
            valueView(feature.pro, isPro: true)
                .frame(width: 60)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func valueView(_ value: Feature.FeatureValue, isPro: Bool = false) -> some View {
        switch value {
        case .yes:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(isPro ? Color(red: 0.79, green: 0.48, blue: 0.39) : .secondary)
        case .no:
            Image(systemName: "minus.circle")
                .foregroundStyle(.quaternary)
        case .text(let s):
            Text(s)
                .font(.caption.bold())
                .foregroundStyle(isPro ? Color(red: 0.79, green: 0.48, blue: 0.39) : .secondary)
        }
    }
}
