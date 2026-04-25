import Foundation

@Observable
final class NavigationRouter {
    static let shared = NavigationRouter()
    private init() {}

    var pendingNameId: Int?
    var showPaywall = false
    var pendingTab: Int?
}
