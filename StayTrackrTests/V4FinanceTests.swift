import XCTest
@testable import StayTrackr_V3

final class V4FinanceTests: XCTestCase {

    // MARK: - nights(_:_:)

    func testNightsBetweenDates() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2025, month: 6, day: 8))!
        XCTAssertEqual(V4Finance.nights(start, end), 7)
    }

    func testNightsSameDate() {
        let d = Date()
        XCTAssertEqual(V4Finance.nights(d, d), 0)
    }

    func testNightsInvertedDatesReturnsZero() {
        let cal = Calendar.current
        let later   = cal.date(from: DateComponents(year: 2025, month: 6, day: 8))!
        let earlier = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        XCTAssertEqual(V4Finance.nights(later, earlier), 0)
    }

    func testNightsSingleNight() {
        let cal = Calendar.current
        let d1 = cal.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertEqual(V4Finance.nights(d1, d2), 1)
    }

    // MARK: - netRevenue(gross:platform:commission:)

    func testNetRevenueZeroFees() {
        XCTAssertEqual(V4Finance.netRevenue(gross: 1000, platform: 0, commission: 0), 1000, accuracy: 0.001)
    }

    func testNetRevenuePlatformFeeOnly() {
        // 1000 * (1 - 0.03) = 970
        XCTAssertEqual(V4Finance.netRevenue(gross: 1000, platform: 0.03, commission: 0), 970, accuracy: 0.001)
    }

    func testNetRevenueBothFees() {
        // (1000 * 0.97) * 0.90 = 873
        XCTAssertEqual(V4Finance.netRevenue(gross: 1000, platform: 0.03, commission: 0.10), 873, accuracy: 0.001)
    }

    func testNetRevenueFull100PctPlatformFee() {
        XCTAssertEqual(V4Finance.netRevenue(gross: 1000, platform: 1.0, commission: 0), 0, accuracy: 0.001)
    }

    func testNetRevenueZeroGross() {
        XCTAssertEqual(V4Finance.netRevenue(gross: 0, platform: 0.03, commission: 0.10), 0, accuracy: 0.001)
    }

    // MARK: - mortgageMonthly(price:apr:years:)

    func testMortgageZeroAPREqualsEqualInstalments() {
        // 120,000 / 120 months = 1000/month
        XCTAssertEqual(V4Finance.mortgageMonthly(price: 120_000, apr: 0, years: 10), 1000, accuracy: 0.01)
    }

    func testMortgageZeroYearsReturnsZero() {
        XCTAssertEqual(V4Finance.mortgageMonthly(price: 200_000, apr: 0.05, years: 0), 0, accuracy: 0.01)
    }

    func testMortgageStandardAmortisation() {
        // $200,000 at 5% APR over 30 years ≈ $1,073.64/mo
        XCTAssertEqual(V4Finance.mortgageMonthly(price: 200_000, apr: 0.05, years: 30), 1073.64, accuracy: 1.0)
    }

    func testMortgageHighAPR() {
        // $100,000 at 12% over 10 years ≈ $1,434.71/mo
        XCTAssertEqual(V4Finance.mortgageMonthly(price: 100_000, apr: 0.12, years: 10), 1434.71, accuracy: 1.0)
    }
}
