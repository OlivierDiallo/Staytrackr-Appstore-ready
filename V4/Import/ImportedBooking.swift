import Foundation

// MARK: - Normalized booking model shared by iCal and CSV parsers

struct ImportedBooking: Identifiable, Hashable {
    let id: UUID
    let platformID: String?       // Airbnb confirmation code or Booking reservation ID
    let platform: Platform
    let propertyID: String?       // listing name from CSV, matched to STProperty by name
    let guestName: String?
    let checkIn: Date
    let checkOut: Date
    let amount: Decimal?          // payout amount (CSV only — not in iCal)
    let currency: String?
    let status: BookingStatus
    let rawSource: String         // original line/block for debugging

    init(
        platformID: String? = nil,
        platform: Platform,
        propertyID: String? = nil,
        guestName: String? = nil,
        checkIn: Date,
        checkOut: Date,
        amount: Decimal? = nil,
        currency: String? = nil,
        status: BookingStatus = .confirmed,
        rawSource: String = ""
    ) {
        self.id = UUID()
        self.platformID = platformID
        self.platform = platform
        self.propertyID = propertyID
        self.guestName = guestName
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.amount = amount
        self.currency = currency
        self.status = status
        self.rawSource = rawSource
    }

    enum Platform: String, CaseIterable {
        case airbnb = "Airbnb"
        case bookingCom = "Booking.com"
        case manual = "Manual"
    }

    enum BookingStatus: String {
        case confirmed = "confirmed"
        case cancelled = "cancelled"
        case pending   = "pending"
    }
}
