import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Découvrir", systemImage: "sparkles")
                }
            FavoritesView()
                .tabItem {
                    Label("Favoris", systemImage: "heart")
                }
            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape")
                }
        }
    }
}
