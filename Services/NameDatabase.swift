import Foundation
import GRDB

// MARK: — GRDB row mapping

extension FirstName: FetchableRecord {
    init(row: Row) throws {
        id            = row["id"]
        name          = row["name"]
        let genderRaw: String = row["gender"] ?? "unisex"
        gender        = Gender(rawValue: genderRaw) ?? .unisex
        origin        = row["origin"] ?? ""
        originLocale  = row["origin_locale"]
        meaning       = row["meaning"] ?? ""
        syllables     = row["syllables"] ?? 1
        popularityRankFR = row["popularity_rank_fr"]
        popularityRankUS = row["popularity_rank_us"]
        let themesJSON: String? = row["themes"]
        themes        = Self.parseThemes(themesJSON)
        phonetic      = row["phonetic"]
        etymology     = row["etymology"]
    }

    private static func parseThemes(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: — NameDatabase singleton

final class NameDatabase: @unchecked Sendable {
    static let shared = NameDatabase()

    private let db: DatabaseQueue

    private init() {
        // Search bundle of the class first (works in tests), then main bundle.
        let bundle = Bundle(for: NameDatabase.self)
        let url = bundle.url(forResource: "names", withExtension: "sqlite")
            ?? Bundle.main.url(forResource: "names", withExtension: "sqlite")

        if let url, let queue = try? DatabaseQueue(path: url.path, configuration: Self.readOnlyConfig()) {
            db = queue
        } else {
            // Fallback: empty in-memory DB for CI / early development.
            let queue = try! DatabaseQueue()
            try! queue.write { db in
                try db.execute(sql: Self.createTableSQL)
            }
            db = queue
        }
    }

    private static let createTableSQL = """
        CREATE TABLE IF NOT EXISTS names (
            id                  INTEGER PRIMARY KEY,
            name                TEXT NOT NULL,
            gender              TEXT CHECK(gender IN ('male','female','unisex')),
            origin              TEXT,
            origin_locale       TEXT,
            meaning             TEXT,
            syllables           INTEGER,
            popularity_rank_fr  INTEGER,
            popularity_rank_us  INTEGER,
            themes              TEXT,
            phonetic            TEXT,
            etymology           TEXT
        );
        """

    private static func readOnlyConfig() -> Configuration {
        var config = Configuration()
        config.readonly = true
        return config
    }

    // MARK: — Queries

    func all(gender: Gender? = nil, origin: String? = nil) throws -> [FirstName] {
        try db.read { db in
            var sql = "SELECT * FROM names WHERE 1=1"
            var args: [DatabaseValueConvertible] = []
            if let gender {
                sql += " AND gender = ?"
                args.append(gender.rawValue)
            }
            if let origin {
                sql += " AND origin = ?"
                args.append(origin)
            }
            sql += " ORDER BY popularity_rank_fr ASC NULLS LAST, name ASC"
            return try FirstName.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    func search(_ query: String) throws -> [FirstName] {
        try db.read { db in
            try FirstName.fetchAll(db,
                sql: "SELECT * FROM names WHERE name LIKE ? ORDER BY popularity_rank_fr ASC NULLS LAST LIMIT 100",
                arguments: ["%\(query)%"])
        }
    }

    func byId(_ id: Int) throws -> FirstName? {
        try db.read { db in
            try FirstName.fetchOne(db, sql: "SELECT * FROM names WHERE id = ?", arguments: [id])
        }
    }

    func random(gender: Gender? = nil) throws -> FirstName? {
        try db.read { db in
            var sql = "SELECT * FROM names"
            var args: [DatabaseValueConvertible] = []
            if let gender {
                sql += " WHERE gender = ?"
                args.append(gender.rawValue)
            }
            sql += " ORDER BY RANDOM() LIMIT 1"
            return try FirstName.fetchOne(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    func nameForDate(_ date: Date) throws -> FirstName? {
        try db.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM names") ?? 0
            guard count > 0 else { return nil }
            let daysSinceReference = Int(date.timeIntervalSinceReferenceDate / 86400)
            let index = ((daysSinceReference % count) + count) % count
            return try FirstName.fetchOne(db,
                sql: "SELECT * FROM names LIMIT 1 OFFSET ?",
                arguments: [index])
        }
    }

    var allOrigins: [String] {
        (try? db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT origin FROM names WHERE origin IS NOT NULL ORDER BY origin")
            return rows.compactMap { $0["origin"] as String? }
        }) ?? []
    }

    func filtered(_ filter: NameFilter) throws -> [FirstName] {
        try db.read { db in
            var sql = "SELECT * FROM names WHERE 1=1"
            var args: [DatabaseValueConvertible] = []

            if let gender = filter.gender {
                sql += " AND gender = ?"
                args.append(gender.rawValue)
            }
            if !filter.origins.isEmpty {
                let placeholders = filter.origins.map { _ in "?" }.joined(separator: ", ")
                sql += " AND origin IN (\(placeholders))"
                args.append(contentsOf: filter.origins)
            }
            if let syllables = filter.syllables {
                if syllables >= 5 {
                    sql += " AND syllables >= ?"
                    args.append(syllables)
                } else {
                    sql += " AND syllables = ?"
                    args.append(syllables)
                }
            }
            if let letter = filter.initialLetter {
                sql += " AND name LIKE ?"
                args.append("\(letter)%")
            }
            if !filter.searchQuery.isEmpty {
                sql += " AND name LIKE ?"
                args.append("%\(filter.searchQuery)%")
            }

            if filter.sortByPopularity {
                sql += " ORDER BY popularity_rank_fr ASC NULLS LAST, name ASC"
            } else {
                sql += " ORDER BY name ASC"
            }

            return try FirstName.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    func countByOrigin() -> [String: Int] {
        (try? db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT origin, COUNT(*) as cnt FROM names WHERE origin IS NOT NULL GROUP BY origin")
            var result: [String: Int] = [:]
            for row in rows {
                if let origin = row["origin"] as String?, let count = row["cnt"] as Int? {
                    result[origin] = count
                }
            }
            return result
        }) ?? [:]
    }
}
