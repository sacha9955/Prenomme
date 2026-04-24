import SwiftUI
import SwiftData

@main
struct PrenommeApp: App {

    private let container: ModelContainer
    @State private var showICloudToast = false

    init() {
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        let schema = Schema(PrenommeMigrationPlan.schemas.flatMap { $0.models })
        let config: ModelConfiguration

        if iCloudAvailable {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: PrenommeMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task { await checkICloudToast() }
                .overlay(alignment: .top) {
                    if showICloudToast {
                        ICloudUnavailableToast {
                            withAnimation { showICloudToast = false }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .zIndex(1)
                    }
                }
                .animation(.spring(duration: 0.4), value: showICloudToast)
        }
    }

    @MainActor
    private func checkICloudToast() async {
        guard FileManager.default.ubiquityIdentityToken == nil else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserSettings>()
        guard let settings = try? context.fetch(descriptor).first else {
            showICloudToast = true
            return
        }
        if !settings.iCloudUnavailableToastShown {
            settings.iCloudUnavailableToastShown = true
            try? context.save()
            showICloudToast = true
        }
    }
}
