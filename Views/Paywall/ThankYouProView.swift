import SwiftUI

struct ThankYouProView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brand,
                                     Color.brandSage],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
                Text("✨")
                    .font(.system(size: 46))
            }
            VStack(spacing: 12) {
                Text("Merci d'être Pro !")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Vous profitez de toutes les fonctionnalités de Prénomme, à vie. Pas d'abonnement, jamais.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            VStack(spacing: 10) {
                proFeatureRow("heart.fill", "Favoris illimités")
                proFeatureRow("arrow.left.arrow.right", "Swipes illimités")
                proFeatureRow("book.closed", "Étymologie complète")
                proFeatureRow("sparkles", "Suggestions personnalisées")
                proFeatureRow("doc.text", "Export PDF")
            }
            .padding(.horizontal, 40)
            Spacer()
            Button { dismiss() } label: {
                Text("Continuer")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brand,
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func proFeatureRow(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(Color.brand)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(Color.brand)
        }
    }
}
