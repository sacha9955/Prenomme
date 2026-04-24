import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "Aucun favori",
                        systemImage: "heart",
                        description: Text("Ajoutez des prénoms depuis l'onglet Découvrir.")
                    )
                } else {
                    List(favorites) { fav in
                        Text("ID \(fav.nameId)")
                    }
                }
            }
            .navigationTitle("Favoris")
        }
    }
}
