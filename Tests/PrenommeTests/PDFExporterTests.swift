import XCTest
@testable import Prenomme

final class PDFExporterTests: XCTestCase {

    private let exporter = PDFExporter.shared

    // MARK: — Helpers

    private func makeName(id: Int, name: String, gender: Gender = .female, rankFR: Int? = nil, rankUS: Int? = nil) -> FirstName {
        FirstName(id: id, name: name, gender: gender, origin: "Latin", originLocale: nil,
                  meaning: "belle signification", syllables: 2,
                  popularityRankFR: rankFR, popularityRankUS: rankUS,
                  themes: [], phonetic: nil)
    }

    private func sampleNames(_ count: Int) -> [FirstName] {
        (1...count).map { makeName(id: $0, name: "Prénom\($0)", rankFR: $0) }
    }

    // MARK: — Output validity

    func testGeneratesNonEmptyData() {
        let data = exporter.generate(names: sampleNames(1))
        XCTAssertFalse(data.isEmpty)
    }

    func testOutputStartsWithPDFHeader() {
        let data = exporter.generate(names: sampleNames(1))
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    func testEmptyNamesProducesValidPDF() {
        let data = exporter.generate(names: [])
        XCTAssertFalse(data.isEmpty)
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    // MARK: — Pagination

    func testPaginateEmptyReturnsOnePage() {
        let pages = exporter.paginate([])
        XCTAssertEqual(pages.count, 1)
        XCTAssertTrue(pages[0].isEmpty)
    }

    func testPaginateOneName() {
        let pages = exporter.paginate(sampleNames(1))
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].count, 1)
    }

    func testPaginateThreeNamesOnePage() {
        let pages = exporter.paginate(sampleNames(3))
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].count, 3)
    }

    func testPaginateFourNamesTwoPages() {
        // Page 1 capacity = 3 (intro block), page 2 = 1
        let pages = exporter.paginate(sampleNames(4))
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].count, 3)
        XCTAssertEqual(pages[1].count, 1)
    }

    func testPaginateSevenNamesTwoPages() {
        // Page 1 = 3, page 2 = 4
        let pages = exporter.paginate(sampleNames(7))
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].count, 3)
        XCTAssertEqual(pages[1].count, 4)
    }

    func testPaginateTwelveNamesThreePages() {
        // Page 1 = 3, page 2 = 4, page 3 = 4, page 4 = 1
        let pages = exporter.paginate(sampleNames(12))
        XCTAssertEqual(pages.count, 4)
        XCTAssertEqual(pages[0].count, 3)
        XCTAssertEqual(pages[1].count, 4)
        XCTAssertEqual(pages[2].count, 4)
        XCTAssertEqual(pages[3].count, 1)
    }

    func testPaginatePreservesAllNames() {
        let names = sampleNames(11)
        let pages = exporter.paginate(names)
        let flat = pages.flatMap { $0 }
        XCTAssertEqual(flat.count, names.count)
        XCTAssertEqual(flat.map { $0.id }, names.map { $0.id })
    }

    // MARK: — Edge cases

    func testNamesWithBothRanks() {
        let name = makeName(id: 1, name: "Emma", rankFR: 1, rankUS: 3)
        let data = exporter.generate(names: [name])
        XCTAssertFalse(data.isEmpty)
    }

    func testNamesWithNoRanks() {
        let name = makeName(id: 1, name: "Zara")
        let data = exporter.generate(names: [name])
        XCTAssertFalse(data.isEmpty)
    }

    func testAllGenders() {
        let names = [
            makeName(id: 1, name: "Emma", gender: .female),
            makeName(id: 2, name: "Luca", gender: .male),
            makeName(id: 3, name: "Alex", gender: .unisex),
        ]
        let data = exporter.generate(names: names)
        XCTAssertFalse(data.isEmpty)
    }

    func testFiftyNamesGeneratesValidPDF() {
        let data = exporter.generate(names: sampleNames(50))
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }
}
