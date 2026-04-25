import SwiftUI
import SwiftData

@main
struct PrenommeApp: App {

    private let container: ModelContainer
    @State private var showICloudToast = false

    init() {
        let schema = Schema(PrenommeMigrationPlan.schemas.flatMap { $0.models })
        // Use .automatic — SwiftData handles CloudKit availability internally.
        // Never call ubiquityIdentityToken here: it makes a blocking XPC call
        // to the iCloud service on the main thread, triggering a watchdog kill.
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
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

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("iCloudToastDismissed") private var iCloudToastDismissed = false

    var body: some Scene {
        WindowGroup {
            Group {
                let skipOnboarding = CommandLine.arguments.contains("--skip-onboarding")
                if hasSeenOnboarding || skipOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(container)
                .onOpenURL { url in handleDeepLink(url) }
                .task { checkICloudToast() }
                .overlay(alignment: .top) {
                    if showICloudToast {
                        ICloudUnavailableToast {
                            iCloudToastDismissed = true
                            withAnimation { showICloudToast = false }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .zIndex(1)
                    }
                }
                .animation(.spring(duration: 0.4), value: showICloudToast)
                .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "prenomme" else { return }
        let router = NavigationRouter.shared
        switch url.host {
        case "paywall":
            router.showPaywall = true
        case "name":
            if let idStr = url.pathComponents.dropFirst().first, let id = Int(idStr) {
                router.pendingNameId = id
            }
        case "browse":
            router.pendingTab = 1
        default:
            break
        }
    }

    private func checkICloudToast() {
        Task.detached(priority: .utility) {
            let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
            await MainActor.run {
                if iCloudAvailable {
                    iCloudToastDismissed = false
                } else if !iCloudToastDismissed {
                    showICloudToast = true
                }
            }
        }
    }
}
