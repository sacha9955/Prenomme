import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var purchase = PurchaseManager.shared
    @State private var selectedPlan: Plan = .yearly
    @State private var shouldPurchaseAfterLoad = false

    private let accentColor = Color(red: 0.79, green: 0.48, blue: 0.39)
    private let privacyURL  = URL(string: "https://raw.githack.com/sacha9955/Prenomme-legal/main/privacy.html")!
    private let termsURL    = URL(string: "https://raw.githack.com/sacha9955/Prenomme-legal/main/terms.html")!

    private func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featureTable
                    planPicker
                    purchaseSection
                    restoreButton
                    legalFooter
                }
            }
            closeButton
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: purchase.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: — Background & hero

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
                            colors: [accentColor, Color(red: 0.61, green: 0.69, blue: 0.53)],
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
        .padding(.bottom, 28)
    }

    // MARK: — Feature table

    private var featureTable: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Feature.all) { feature in
                FeatureRow(feature: feature, accentColor: accentColor)
                if feature.id != Feature.all.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }

    private var tableHeader: some View {
        HStack {
            Spacer()
            columnLabel("Gratuit", icon: "person")
            columnLabel("Pro", icon: "star.fill", accent: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.08),
                    in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
    }

    private func columnLabel(_ text: String, icon: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(accent ? accentColor : .secondary)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(accent ? accentColor : .secondary)
        }
        .frame(width: 60)
    }

    // MARK: — Plan picker (3 cards)

    private var planPicker: some View {
        VStack(spacing: 10) {
            PlanCard(
                plan: .yearly,
                title: "Annuel",
                subtitle: "Le meilleur rapport qualité-prix",
                price: priceForPlan(.yearly),
                detail: "Renouvellement annuel · résiliable à tout moment",
                badge: "ÉCONOMISEZ 44%",
                isSelected: selectedPlan == .yearly,
                accentColor: accentColor,
                action: { selectedPlan = .yearly }
            )
            PlanCard(
                plan: .monthly,
                title: "Mensuel",
                subtitle: "Engagement souple",
                price: priceForPlan(.monthly),
                detail: "Renouvellement mensuel · résiliable à tout moment",
                badge: nil,
                isSelected: selectedPlan == .monthly,
                accentColor: accentColor,
                action: { selectedPlan = .monthly }
            )
            PlanCard(
                plan: .lifetime,
                title: "À vie",
                subtitle: "Paiement unique, pas d'abonnement",
                price: priceForPlan(.lifetime),
                detail: "Une seule fois · accès permanent",
                badge: "ZÉRO ABONNEMENT",
                isSelected: selectedPlan == .lifetime,
                accentColor: accentColor,
                action: { selectedPlan = .lifetime }
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func priceForPlan(_ plan: Plan) -> String {
        switch plan {
        case .yearly:
            return purchase.yearlyProduct?.displayPrice.priceWithEuro ?? PurchaseManager.fallbackYearlyPrice + " /an"
        case .monthly:
            return purchase.monthlyProduct?.displayPrice.priceWithEuro ?? PurchaseManager.fallbackMonthlyPrice + " /mois"
        case .lifetime:
            return purchase.lifetimeProduct?.displayPrice.priceWithEuro ?? PurchaseManager.fallbackLifetimePrice
        }
    }

    // MARK: — Purchase

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            if purchase.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Chargement…")
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
        Button {
            startPurchase()
        } label: {
            buyButtonLabel
        }
    }

    private func startPurchase() {
        let product: Product? = {
            switch selectedPlan {
            case .yearly:   return purchase.yearlyProduct
            case .monthly:  return purchase.monthlyProduct
            case .lifetime: return purchase.lifetimeProduct
            }
        }()
        if let product {
            Task { await purchase.purchase(product, confirmIn: activeScene()) }
            return
        }
        // Fallback when products haven't loaded
        #if DEBUG
        purchase.setDebugForcePro(true)
        #else
        shouldPurchaseAfterLoad = true
        purchase.retryLoadProducts()
        #endif
    }

    private var buyButtonLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill").font(.body.bold())
            Text(buyButtonText).font(.title3.bold())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            LinearGradient(
                colors: [accentColor, Color(red: 0.65, green: 0.38, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .shadow(color: accentColor.opacity(0.55), radius: 16, y: 6)
    }

    private var buyButtonText: String {
        switch selectedPlan {
        case .yearly:   return "Démarrer (\(priceForPlan(.yearly)))"
        case .monthly:  return "Démarrer (\(priceForPlan(.monthly)))"
        case .lifetime: return "Acheter (\(priceForPlan(.lifetime)))"
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await purchase.restore() }
        } label: {
            Text("Restaurer les achats")
                .font(.subheadline)
                .foregroundStyle(accentColor)
        }
        .padding(.top, 10)
    }

    // MARK: — Legal footer (auto-renewable disclosure required by Apple)

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedPlan != .lifetime {
                Text(legalSubscriptionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Paiement unique. Pas d'abonnement.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 4) {
                Link("Politique de confidentialité", destination: privacyURL)
                Text("·").foregroundStyle(.tertiary)
                Link("Conditions d'utilisation", destination: termsURL)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 40)
    }

    private var legalSubscriptionText: String {
        """
        Le paiement sera prélevé sur votre compte Apple ID à la confirmation de l'achat. \
        L'abonnement se renouvelle automatiquement, sauf désactivation au moins 24 heures avant la fin de la période en cours. \
        Le compte sera débité du renouvellement dans les 24 heures précédant la fin de la période en cours. \
        Vous pouvez gérer ou résilier votre abonnement dans Réglages → Apple ID → Abonnements.
        """
    }

    // MARK: — Close

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

// MARK: — Plan model

extension PaywallView {
    enum Plan { case monthly, yearly, lifetime }
}

private struct PlanCard: View {
    let plan: PaywallView.Plan
    let title: String
    let subtitle: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(price)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? accentColor : .primary)
                }
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor, in: Capsule())
                }
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor.opacity(0.12) : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? accentColor : Color.gray.opacity(0.18),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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
        Feature(id: 11, icon: "book.closed",
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

private struct FeatureRow: View {
    let feature: Feature
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.callout)
                .foregroundStyle(accentColor)
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
                .foregroundStyle(isPro ? accentColor : .secondary)
        case .no:
            Image(systemName: "minus.circle")
                .foregroundStyle(.quaternary)
        case .text(let s):
            Text(s)
                .font(.caption.bold())
                .foregroundStyle(isPro ? accentColor : .secondary)
        }
    }
}

private extension String {
    /// Adds the euro sign if missing (StoreKit returns "29,99" sans symbol in some sandbox cases).
    var priceWithEuro: String {
        contains("€") || contains("$") || contains("£") ? self : self + " €"
    }
}
