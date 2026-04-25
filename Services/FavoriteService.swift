import SwiftData
import Foundation

/// Encapsulates favorite add/remove logic with the free-tier 10-favorite limit.
struct FavoriteService {

    static let freeLimit = 10

    let context: ModelContext

    // MARK: — Queries

    func isFavorite(nameId: Int) -> Bool {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.nameId == nameId }
        )
        return (try? context.fetchCount(descriptor) ?? 0) ?? 0 > 0
    }

    func favoriteCount() -> Int {
        let descriptor = FetchDescriptor<Favorite>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: — Mutations

    /// Returns `true` on success, `false` when the free limit is reached.
    @discardableResult
    func add(nameId: Int, isPro: Bool) -> AddResult {
        guard !isFavorite(nameId: nameId) else { return .alreadyAdded }
        if !isPro && favoriteCount() >= Self.freeLimit {
            return .limitReached
        }
        let fav = Favorite(nameId: nameId)
        context.insert(fav)
        try? context.save()
        return .added
    }

    func remove(nameId: Int) {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.nameId == nameId }
        )
        guard let fav = try? context.fetch(descriptor).first else { return }
        context.delete(fav)
        try? context.save()
    }

    func toggle(nameId: Int, isPro: Bool) -> AddResult {
        if isFavorite(nameId: nameId) {
            remove(nameId: nameId)
            return .removed
        }
        return add(nameId: nameId, isPro: isPro)
    }

    enum AddResult {
        case added
        case removed
        case alreadyAdded
        case limitReached
    }
}
