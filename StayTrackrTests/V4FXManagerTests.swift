import XCTest
import SwiftData
@testable import StayTrackr_V3

final class V4FXManagerTests: XCTestCase {

    // MARK: - FXError localised descriptions

    func testInvalidRequestErrorHasDescription() {
        let err = V4FXManager.FXError.invalidRequest
        XCTAssertNotNil(err.errorDescription)
        XCTAssertFalse(err.errorDescription!.isEmpty)
    }

    func testHTTPErrorHasDescription() {
        let err = V4FXManager.FXError.httpError
        XCTAssertNotNil(err.errorDescription)
        XCTAssertFalse(err.errorDescription!.isEmpty)
    }

    func testRateNotFoundDescriptionContainsBothCurrencies() {
        let err = V4FXManager.FXError.rateNotFound("EUR", "CZK")
        XCTAssertTrue(err.errorDescription?.contains("EUR") ?? false)
        XCTAssertTrue(err.errorDescription?.contains("CZK") ?? false)
    }

    // MARK: - refreshAll with empty context

    @MainActor
    func testRefreshAllEmptyContextReturnsZero() async throws {
        let schema = Schema([
            STFXRate.self, STProperty.self, STGuest.self, STBooking.self,
            STExpense.self, STRecurringBill.self, V4AppPreferences.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let count = try await V4FXManager.refreshAll(in: container.mainContext)
        XCTAssertEqual(count, 0)
    }
}
