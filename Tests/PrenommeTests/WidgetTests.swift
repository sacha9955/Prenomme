import XCTest
@testable import Prenomme

final class WidgetTests: XCTestCase {

    private func requirePopulatedDB() throws {
        let count = (try? NameDatabase.shared.all().count) ?? 0
        try XCTSkipIf(count == 0, "names.sqlite not bundled — run scripts/import_names.py first")
    }

    // MARK: — nameForDate determinism

    func testNameForDateIsDeterministicForSameDate() throws {
        try requirePopulatedDB()
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let a = try NameDatabase.shared.nameForDate(date)
        let b = try NameDatabase.shared.nameForDate(date)
        XCTAssertEqual(a?.id, b?.id)
    }

    func testNameForDateDiffersAcrossConsecutiveDays() throws {
        try requirePopulatedDB()
        let allNames = try NameDatabase.shared.all()
        guard allNames.count > 1 else { return }

        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let next = base.addingTimeInterval(86400)
        let a = try NameDatabase.shared.nameForDate(base)
        let b = try NameDatabase.shared.nameForDate(next)
        XCTAssertNotEqual(a?.id, b?.id)
    }

    func testNameForDateReturnsNonNilForArbitraryDate() throws {
        try requirePopulatedDB()
        let result = try NameDatabase.shared.nameForDate(Date())
        XCTAssertNotNil(result)
    }

    // MARK: — ProNameProvider filtering logic

    func testGenderFilterFemaleExcludesMales() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()
        guard all.contains(where: { $0.gender == .male }) else { return }

        // Replicate the pick logic: female filter keeps female + unisex
        let pool = all.filter { $0.gender == .female || $0.gender == .unisex }
        XCTAssertFalse(pool.contains { $0.gender == .male })
    }

    func testGenderFilterMaleExcludesFemales() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()
        guard all.contains(where: { $0.gender == .female }) else { return }

        let pool = all.filter { $0.gender == .male || $0.gender == .unisex }
        XCTAssertFalse(pool.contains { $0.gender == .female })
    }

    func testOriginFilterNarrowsPool() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()
        let availableOrigins = Set(all.map { $0.origin })
        guard let targetOrigin = availableOrigins.first else { return }

        let filtered = all.filter { $0.origin == targetOrigin }
        XCTAssertFalse(filtered.isEmpty)
        XCTAssertLessThanOrEqual(filtered.count, all.count)
        XCTAssertTrue(filtered.allSatisfy { $0.origin == targetOrigin })
    }

    func testOriginFilterEmptyFallsBackToFullPool() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()

        // Replicate pick logic: empty origins list → no filtering applied
        let origins: [String] = []
        let pool = origins.isEmpty ? all : all.filter { origins.contains($0.origin) }
        XCTAssertEqual(pool.count, all.count)
    }

    func testOriginFilterUnknownOriginFallsBackToFullPool() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()

        // Replicate pick logic: filtered result empty → fall back to unfiltered pool
        let unknownOrigins = Set(["__nonexistent_origin__"])
        let filtered = all.filter { unknownOrigins.contains($0.origin) }
        let pool = filtered.isEmpty ? all : filtered
        XCTAssertEqual(pool.count, all.count)
    }

    // MARK: — Timeline policy

    func testTimelinePolicyDateIsAfterMidnight() {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        XCTAssertGreaterThan(midnight, now)

        // Next midnight is strictly in the future and at most 24 h away
        let diff = midnight.timeIntervalSince(now)
        XCTAssertGreaterThan(diff, 0)
        XCTAssertLessThanOrEqual(diff, 86400)
    }

    func testTimelinePolicyMidnightIsNextDay() {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: midnight)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: — Day-index determinism

    func testDayIndexIsConsistentWithinSameDay() throws {
        try requirePopulatedDB()
        let all = try NameDatabase.shared.all()
        guard !all.isEmpty else { return }

        let day1 = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let day2 = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        XCTAssertEqual(day1 % all.count, day2 % all.count)
    }
}
