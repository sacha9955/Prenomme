import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @Bindable private var router = NavigationRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Découvrir", systemImage: "sparkles") }
                .tag(0)
            BrowseView()
                .tabItem { Label("Explorer", systemImage: "magnifyingglass") }
                .tag(1)
            SwipeView()
                .tabItem { Label("Swiper", systemImage: "arrow.left.arrow.right") }
                .tag(2)
            FavoritesView()
                .tabItem { Label("Favoris", systemImage: "heart") }
                .tag(3)
            CompatibilityView()
                .tabItem { Label("Compatibilité", systemImage: "waveform.path.ecg") }
                .tag(4)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(5)
        }
        .onChange(of: router.pendingNameId) { _, id in
            if id != nil { selectedTab = 1 }
        }
        .onChange(of: router.pendingTab) { _, tab in
            if let tab {
                selectedTab = tab
                router.pendingTab = nil
            }
        }
        .sheet(isPresented: $router.showPaywall) {
            PaywallView()
        }
    }
}
