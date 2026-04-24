import SwiftUI

struct HomeView: View {
    @State private var names: [FirstName] = []

    var body: some View {
        NavigationStack {
            List(names) { name in
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.name)
                        .font(.headline)
                    Text(name.meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Prénomme")
            .task {
                names = (try? NameDatabase.shared.all()) ?? []
            }
        }
    }
}
