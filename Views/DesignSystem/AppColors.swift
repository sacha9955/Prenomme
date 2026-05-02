import SwiftUI

/// Design system Prénomme — couleurs adaptatives Light/Dark.
///
/// Règle : aucun écran ne doit hardcoder `Color(red:_,green:_,blue:_)` ni `Color.white/.black`
/// pour des éléments de UI. Tout passe par cette extension.
///
/// - Couleurs basées sur `Color(.systemX)` : adaptatives "gratuites" via le système.
/// - Couleurs de marque : référencées via Asset Catalog (`AppColors.xcassets`) avec
///   variantes Light/Dark définies par colorset.
extension Color {

    // MARK: — Brand (Asset Catalog : Light + Dark variants)

    /// Terracotta Prénomme — accent principal. Light: 0.79/0.48/0.39, Dark: éclairci.
    static var brand: Color { Color("BrandTerracotta", bundle: .main) }

    /// Variante terracotta plus sombre, pour gradients et hover.
    static var brandDark: Color { Color("BrandTerracottaDark", bundle: .main) }

    /// Vert sage — accent secondaire (gradients, ThankYou Pro).
    static var brandSage: Color { Color("BrandSage", bundle: .main) }

    /// Beige clair — gradient hero/onboarding (utilisé en complément du vert).
    static var brandBeige: Color { Color("BrandBeige", bundle: .main) }

    // MARK: — Gender (Asset Catalog : Light + Dark variants)

    /// Couleur "féminin" — rose, désaturée en dark mode pour rester lisible.
    static var genderFemale: Color { Color("GenderFemale", bundle: .main) }

    /// Couleur "masculin" — bleu, désaturé en dark mode.
    static var genderMale: Color { Color("GenderMale", bundle: .main) }

    /// Couleur "unisexe" — vert sauge.
    static var genderUnisex: Color { Color("GenderUnisex", bundle: .main) }

    // MARK: — Surfaces (système, adaptatives gratuit)

    /// Fond principal d'écran.
    static var appBackground: Color { Color(.systemBackground) }

    /// Surface secondaire (cards sur fond principal).
    static var appSurface: Color { Color(.secondarySystemBackground) }

    /// Surface élevée (cards sur surface secondaire — modales, drawers).
    static var appSurfaceElevated: Color { Color(.tertiarySystemBackground) }

    /// Fond de groupe (listes, tables).
    static var appGroupedBackground: Color { Color(.systemGroupedBackground) }

    /// Surface chip / pastille neutre.
    static var appChipBackground: Color { Color(.systemGray5) }

    /// Surface separator subtil (divider, hairline).
    static var appHairline: Color { Color(.separator) }

    // MARK: — Text (système, déjà adaptatif via .primary/.secondary/.tertiary)

    /// Texte principal — équivalent `.primary`.
    static var textPrimary: Color { Color(.label) }

    /// Texte secondaire — équivalent `.secondary`.
    static var textSecondary: Color { Color(.secondaryLabel) }

    /// Texte tertiaire — légendes, badges.
    static var textTertiary: Color { Color(.tertiaryLabel) }

    // MARK: — Helpers gender (compatibilité avec ancien switch)

    /// Helper pour obtenir la couleur correspondant à un genre stocké en String.
    /// `"f"`, `"female"` → female ; `"m"`, `"male"` → male ; sinon → unisex.
    static func gender(_ raw: String?) -> Color {
        switch (raw ?? "").lowercased() {
        case "f", "female": return .genderFemale
        case "m", "male":   return .genderMale
        default:            return .genderUnisex
        }
    }
}

// MARK: — Gradients réutilisables

extension LinearGradient {

    /// Gradient brand principal (terracotta → sage).
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.brand, .brandSage],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gradient brand vertical (terracotta → terracotta sombre) — pour boutons CTA.
    static var brandCTAGradient: LinearGradient {
        LinearGradient(
            colors: [.brand, .brandDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gradient hero onboarding (beige → sage).
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [.brandBeige, .brandSage],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
