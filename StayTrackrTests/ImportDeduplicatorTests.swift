import XCTest
import SwiftData
@testable import StayTrackr_V3

@MainActor
final class ImportDeduplicatorTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var property: STProperty!

    override func setUp() async throws {
        let schema = Schema([
            STProperty.self, STGuest.self, STBooking.self,
            STExpense.self, STRecurringBill.self,
            STFXRate.self, V4AppPreferences.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        property = STProperty(
            id: UUID(), name: "Test Flat", purchasePrice: 200_000,
            mortgageAPR: 0.05, mortgageYears: 25, commissionPct: 0.10,
            emoji: "🏠", colorHex: "#FF0000", isArchived: false, trackMortgage: true
        )
        context.insert(property)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        property = nil
    }

    // MARK: - Helpers

    private func existingBooking(
        checkIn: Date,
        checkOut: Date,
        platformID: String? = nil
    ) -> STBooking {
        let guest = STGuest(id: UUID(), name: "Existing Guest")
        context.insert(guest)
        let b = STBooking(
            id: UUID(), property: property, guest: guest,
            checkIn: checkIn, checkOut: checkOut,
            nightlyRate: 100, platformFeePct: 0.03, isPaid: true
        )
        b.platformID = platformID
        context.insert(b)
        return b
    }

    private func imported(
        checkIn: Date,
        checkOut: Date,
        platformID: String? = nil,
        status: ImportedBooking.BookingStatus = .confirmed
    ) -> ImportedBooking {
        ImportedBooking(
            platformID: platformID, platform: .airbnb,
            checkIn: checkIn, checkOut: checkOut, status: status
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Deduplication logic

    func testNewBookingInserted() {
        let result = ImportDeduplicator().deduplicate(
            [imported(checkIn: date(2025, 7, 1), checkOut: date(2025, 7, 7))],
            against: []
        )
        XCTAssertEqual(result.toInsert.count, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertTrue(result.toUpdate.isEmpty)
    }

    func testExactPlatformIDSkipped() {
        let existing = existingBooking(checkIn: date(2025, 7, 1), checkOut: date(2025, 7, 7), platformID: "ABC123")
        let result = ImportDeduplicator().deduplicate(
            [imported(checkIn: date(2025, 7, 1), checkOut: date(2025, 7, 7), platformID: "ABC123")],
            against: [existing]
        )
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertTrue(result.toInsert.isEmpty)
    }

    func testDateMatchFallbackSkips() {
        let existing = existingBooking(checkIn: date(2025, 8, 10), checkOut: date(2025, 8, 15))
        let result = ImportDeduplicator().deduplicate(
            [imported(checkIn: date(2025, 8, 10), checkOut: date(2025, 8, 15))],
            against: [existing]
        )
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testPlatformIDMatchWithChangedDatesTriggersUpdate() {
        let existing = existingBooking(checkIn: date(2025, 9, 1), checkOut: date(2025, 9, 5), platformID: "XYZ999")
        let result = ImportDeduplicator().deduplicate(
            [imported(checkIn: date(2025, 9, 1), checkOut: date(2025, 9, 7), platformID: "XYZ999")],
            against: [existing]
        )
        XCTAssertEqual(result.toUpdate.count, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertTrue(result.toInsert.isEmpty)
    }

    func testCancelledImportedBookingDropped() {
        let result = ImportDeduplicator().deduplicate(
            [imported(checkIn: date(2025, 7, 1), checkOut: date(2025, 7, 7), status: .cancelled)],
            against: []
        )
        XCTAssertTrue(result.toInsert.isEmpty)
        XCTAssertEqual(result.skippedCount, 0)
    }

    func testEmptyImportedListReturnsEmptyResult() {
        let result = ImportDeduplicator().deduplicate([], against: [])
        XCTAssertTrue(result.toInsert.isEmpty)
        XCTAssertEqual(result.skippedCount, 0)
    }

    func testMixedOutcomesInBatch() {
        let e1 = existingBooking(checkIn: date(2025, 6, 1), checkOut: date(2025, 6, 5), platformID: "P1")
        let e2 = existingBooking(checkIn: date(2025, 6, 10), checkOut: date(2025, 6, 14))
        let batch: [ImportedBooking] = [
            imported(checkIn: date(2025, 6, 1),  checkOut: date(2025, 6, 5),  platformID: "P1"), // skip
            imported(checkIn: date(2025, 6, 10), checkOut: date(2025, 6, 14)),                   // skip
            imported(checkIn: date(2025, 7, 1),  checkOut: date(2025, 7, 5)),                    // insert
        ]
        let result = ImportDeduplicator().deduplicate(batch, against: [e1, e2])
        XCTAssertEqual(result.toInsert.count, 1)
        XCTAssertEqual(result.skippedCount, 2)
    }

    // MARK: - Commit

    func testCommitInsertCreatesBookingInContext() {
        let result = ImportDeduplicator.Result(
            toInsert: [imported(checkIn: date(2025, 10, 1), checkOut: date(2025, 10, 5), platformID: "NEW1")],
            toUpdate: [],
            skippedCount: 0
        )
        let counts = ImportDeduplicator.commit(result: result, property: property, context: context)
        XCTAssertEqual(counts.inserted, 1)
        XCTAssertEqual(counts.updated, 0)
    }

    func testCommitUpdateShiftsDates() {
        let old = existingBooking(checkIn: date(2025, 11, 1), checkOut: date(2025, 11, 5), platformID: "UPD1")
        let newCheckout = date(2025, 11, 8)
        let result = ImportDeduplicator.Result(
            toInsert: [],
            toUpdate: [(imported(checkIn: date(2025, 11, 1), checkOut: newCheckout, platformID: "UPD1"), old)],
            skippedCount: 0
        )
        ImportDeduplicator.commit(result: result, property: property, context: context)
        XCTAssertEqual(old.checkOut, newCheckout)
    }

    func testCommitCreatesDuplicateGuestNameCaseInsensitive() {
        let guest = STGuest(id: UUID(), name: "alice smith")
        context.insert(guest)
        let result = ImportDeduplicator.Result(
            toInsert: [ImportedBooking(platformID: "G1", platform: .airbnb, guestName: "Alice Smith",
                                      checkIn: date(2025, 12, 1), checkOut: date(2025, 12, 5))],
            toUpdate: [], skippedCount: 0
        )
        let counts = ImportDeduplicator.commit(result: result, property: property, context: context)
        XCTAssertEqual(counts.inserted, 1)
        // Guest should be reused, not duplicated
        let allGuests = (try? context.fetch(FetchDescriptor<STGuest>())) ?? []
        XCTAssertEqual(allGuests.count, 1)
    }
}
