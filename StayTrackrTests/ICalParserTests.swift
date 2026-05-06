import XCTest
@testable import StayTrackr_V3

final class ICalParserTests: XCTestCase {

    private let parser = ICalParser.shared

    // MARK: - Helpers

    private func utcDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func makeICS(summary: String, description: String = "") -> String {
        """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250901
        DTEND;VALUE=DATE:20250905
        SUMMARY:\(summary)
        DESCRIPTION:\(description)
        END:VEVENT
        END:VCALENDAR
        """
    }

    // MARK: - Airbnb parsing

    func testAirbnbBasicBooking() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:HMCX47JY4K@airbnb.com
        DTSTART;VALUE=DATE:20250601
        DTEND;VALUE=DATE:20250608
        SUMMARY:John Smith (Confirmed)
        END:VEVENT
        END:VCALENDAR
        """
        let bookings = parser.parse(icsText: ics, platform: .airbnb)
        XCTAssertEqual(bookings.count, 1)
        let b = bookings[0]
        XCTAssertEqual(b.guestName, "John Smith")
        XCTAssertEqual(b.platformID, "HMCX47JY4K")
        XCTAssertEqual(b.status, .confirmed)
        XCTAssertEqual(b.checkIn, utcDate(year: 2025, month: 6, day: 1))
        XCTAssertEqual(b.checkOut, utcDate(year: 2025, month: 6, day: 8))
    }

    func testAirbnbGuestWithNoParens() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:ABC@airbnb.com
        DTSTART;VALUE=DATE:20250101
        DTEND;VALUE=DATE:20250105
        SUMMARY:Jane Doe
        END:VEVENT
        END:VCALENDAR
        """
        let b = parser.parse(icsText: ics, platform: .airbnb)[0]
        XCTAssertEqual(b.guestName, "Jane Doe")
    }

    // MARK: - Booking.com parsing

    func testBookingComGuestNameFromDescription() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250701
        DTEND;VALUE=DATE:20250705
        SUMMARY:Booking.com Reservation
        DESCRIPTION:Guest name: Maria Fernandez\\nBooking ID: BK-9876
        END:VEVENT
        END:VCALENDAR
        """
        let b = parser.parse(icsText: ics, platform: .bookingCom)[0]
        XCTAssertEqual(b.guestName, "Maria Fernandez")
        XCTAssertEqual(b.platformID, "BK-9876")
    }

    // MARK: - Filter rules

    func testFiltersNotAvailable() {
        XCTAssertTrue(parser.parse(icsText: makeICS(summary: "Not available"), platform: .airbnb).isEmpty)
    }

    func testFiltersAirbnbNotAvailable() {
        XCTAssertTrue(parser.parse(icsText: makeICS(summary: "Airbnb (Not available)"), platform: .airbnb).isEmpty)
    }

    func testFiltersClosedBlocks() {
        XCTAssertTrue(parser.parse(icsText: makeICS(summary: "Closed"), platform: .bookingCom).isEmpty)
    }

    func testFiltersUnavailable() {
        XCTAssertTrue(parser.parse(icsText: makeICS(summary: "Unavailable"), platform: .airbnb).isEmpty)
    }

    // MARK: - Status detection

    func testCancelledStatus() {
        let b = parser.parse(icsText: makeICS(summary: "Reservation - Cancelled"), platform: .airbnb)[0]
        XCTAssertEqual(b.status, .cancelled)
    }

    func testPendingStatus() {
        let b = parser.parse(icsText: makeICS(summary: "Bob Jones (pending)"), platform: .airbnb)[0]
        XCTAssertEqual(b.status, .pending)
    }

    func testDefaultConfirmedStatus() {
        let b = parser.parse(icsText: makeICS(summary: "Alice Green (Confirmed)"), platform: .airbnb)[0]
        XCTAssertEqual(b.status, .confirmed)
    }

    // MARK: - Date formats

    func testDateOnlyFormat() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250615
        DTEND;VALUE=DATE:20250620
        SUMMARY:Date-only format
        END:VEVENT
        END:VCALENDAR
        """
        let bookings = parser.parse(icsText: ics, platform: .manual)
        XCTAssertEqual(bookings.count, 1)
        XCTAssertEqual(bookings[0].checkIn, utcDate(year: 2025, month: 6, day: 15))
    }

    func testDateTimeUTCFormat() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART:20250615T120000Z
        DTEND:20250620T120000Z
        SUMMARY:UTC datetime format
        END:VEVENT
        END:VCALENDAR
        """
        XCTAssertEqual(parser.parse(icsText: ics, platform: .manual).count, 1)
    }

    // MARK: - RFC 5545 line folding

    func testLineFoldingCRLFSpace() {
        let ics = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20250601\r\nDTEND;VALUE\r\n =DATE:20250608\r\nSUMMARY:Test Guest\r\nEND:VEVENT\r\nEND:VCALENDAR"
        let bookings = parser.parse(icsText: ics, platform: .manual)
        XCTAssertEqual(bookings.count, 1)
        XCTAssertEqual(bookings[0].checkOut, utcDate(year: 2025, month: 6, day: 8))
    }

    // MARK: - Edge cases

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(parser.parse(icsText: "", platform: .airbnb).isEmpty)
    }

    func testMultipleEventsAllParsed() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250601
        DTEND;VALUE=DATE:20250605
        SUMMARY:Alice
        END:VEVENT
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250610
        DTEND;VALUE=DATE:20250615
        SUMMARY:Bob
        END:VEVENT
        END:VCALENDAR
        """
        XCTAssertEqual(parser.parse(icsText: ics, platform: .manual).count, 2)
    }

    func testEventWithoutDatesSkipped() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:No dates here
        END:VEVENT
        END:VCALENDAR
        """
        XCTAssertTrue(parser.parse(icsText: ics, platform: .airbnb).isEmpty)
    }

    func testConfirmationCodeFromDescription() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20250801
        DTEND;VALUE=DATE:20250805
        SUMMARY:Guest Name
        DESCRIPTION:Confirmation code: HMCX47JY4K
        END:VEVENT
        END:VCALENDAR
        """
        let b = parser.parse(icsText: ics, platform: .airbnb)[0]
        XCTAssertEqual(b.platformID, "HMCX47JY4K")
    }
}
