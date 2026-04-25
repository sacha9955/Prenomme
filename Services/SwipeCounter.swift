import Foundation

struct SwipeCounter {

    static let freeLimit = 20

    private static let dateKey  = "swipes_date"
    private static let countKey = "swipes_count"

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme") ?? .standard
    ) {
        self.defaults = defaults
    }

    var todayCount: Int {
        resetIfNewDay()
        return defaults.integer(forKey: Self.countKey)
    }

    var hasSwipesRemaining: Bool {
        todayCount < Self.freeLimit
    }

    var remaining: Int {
        max(0, Self.freeLimit - todayCount)
    }

    func increment() {
        resetIfNewDay()
        defaults.set(defaults.integer(forKey: Self.countKey) + 1, forKey: Self.countKey)
    }

    // MARK: — Private

    private func resetIfNewDay() {
        let today = Self.todayString()
        if defaults.string(forKey: Self.dateKey) != today {
            defaults.set(today,  forKey: Self.dateKey)
            defaults.set(0,      forKey: Self.countKey)
        }
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat  = "yyyy-MM-dd"
        fmt.timeZone    = .current
        return fmt.string(from: Date())
    }
}
