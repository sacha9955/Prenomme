import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var purchase = PurchaseManager.shared
    @State private var selectedPlan: Plan = .yearly

    private let accentColor = Color.brand

    /// Plans réellement achetables (au moins lifetime tant que les autres ne sont pas chargés / configurés).
    private var availablePlans: [Plan] {
        var plans: [Plan] = []
        if purchase.yearlyProduct  != nil { plans.append(.yearly) }
        if purchase.monthlyProduct != nil { plans.append(.monthly) }
        if purchase.lifetimeProduct != nil { plans.append(.lifetime) }
        // Fallback : si rien chargé encore, on affiche au moins lifetime (le seul historiquement garanti).
        return plans.isEmpty ? [.lifetime] : plans
    }
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
        .onChange(of: purchase.products.map(\.id)) { _, _ in
            ensureSelectedPlanAvailable()
        }
        .onAppear { ensureSelectedPlanAvailable() }
    }

    /// Assure que `selectedPlan` pointe sur un plan réellement disponible.
    private func ensureSelectedPlanAvailable() {
        let available = availablePlans
        if !available.contains(selectedPlan), let first = available.first {
            selectedPlan = first
        }
    }

    // MARK: — Background & hero

    private var background: some View {
        // Light: gradient beige doux. Dark: dégradé profond surface→elevated, conserve la chaleur.
        LinearGradient(
            colors: [Color.appBackground, Color.appSurface],
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
                            colors: [accentColor, Color.brandSage],
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
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
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
            ForEach([Plan.yearly, .monthly, .lifetime], id: \.self) { plan in
                PlanCard(
                    plan: plan,
                    title: title(for: plan),
                    subtitle: subtitle(for: plan),
                    price: priceForPlan(plan),
                    detail: detail(for: plan),
                    badge: badge(for: plan),
                    isSelected: selectedPlan == plan,
                    accentColor: accentColor,
                    action: { selectedPlan = plan }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func title(for plan: Plan) -> String {
        switch plan {
        case .yearly:   return "Annuel"
        case .monthly:  return "Mensuel"
        case .lifetime: return "À vie"
        }
    }

    private func subtitle(for plan: Plan) -> String {
        switch plan {
        case .yearly:   return "Le meilleur rapport qualité-prix"
        case .monthly:  return "Engagement souple"
        case .lifetime: return "Paiement unique, pas d'abonnement"
        }
    }

    private func detail(for plan: Plan) -> String {
        switch plan {
        case .yearly:   return "Renouvellement annuel · résiliable à tout moment"
        case .monthly:  return "Renouvellement mensuel · résiliable à tout moment"
        case .lifetime: return "Une seule fois · accès permanent"
        }
    }

    private func badge(for plan: Plan) -> String? {
        switch plan {
        case .yearly:   return "ÉCONOMISEZ 44%"
        case .monthly:  return nil
        case .lifetime: return nil
        }
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
        #if DEBUG
        // En DEBUG sans StoreKit (simulator sans .storekit), on bypass pour tester l'UX.
        purchase.setDebugForcePro(true)
        #else
        // En PROD : product manquant = config ASC incomplète. On affiche une erreur claire
        // au lieu de spinner indéfiniment, et on relance le chargement en arrière-plan.
        purchase.reportMissingProduct(for: selectedPlan.productID)
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
                colors: [accentColor, Color.brandDark],
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
    enum Plan: Hashable {
        case monthly, yearly, lifetime

        var productID: String {
            switch self {
            case .monthly:  return PurchaseManager.monthlyID
            case .yearly:   return PurchaseManager.yearlyID
            case .lifetime: return PurchaseManager.lifetimeID
            }
        }
    }
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
                    .fill(isSelected ? accentColor.opacity(0.12) : Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? accentColor : Color.appHairline,
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
        Feature(id: 8, icon: "square.grid.2x2.fill",
                title: "Widgets prénoms",
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
