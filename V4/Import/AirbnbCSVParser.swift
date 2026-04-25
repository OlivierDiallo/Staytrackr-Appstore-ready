import Foundation

// Parses the Airbnb "Reservations" CSV export into ImportedBooking values.
// Expected headers (case-insensitive):
//   Confirmation Code, Status, Guest Name, Start Date, End Date, # Nights,
//   Listing, Earnings, Currency
// Date formats handled: MM/DD/YYYY, M/D/YYYY, YYYY-MM-DD

struct AirbnbCSVParser {

    struct ParseResult {
        let bookings: [ImportedBooking]
        let skippedRows: Int
    }

    func parse(csvText: String) -> ParseResult {
        var lines = csvText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return ParseResult(bookings: [], skippedRows: 0) }

        let headers = parseRow(lines.removeFirst()).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        func col(_ name: String) -> Int? { headers.firstIndex(of: name) }

        let confirmIdx  = col("confirmation code")
        let statusIdx   = col("status")
        let guestIdx    = col("guest name")
        let startIdx    = col("start date")
        let endIdx      = col("end date")
        let earningsIdx = col("earnings")
        let currencyIdx = col("currency")
        let listingIdx  = col("listing")

        guard let startIdx, let endIdx else {
            return ParseResult(bookings: [], skippedRows: lines.count)
        }

        var bookings: [ImportedBooking] = []
        var skipped = 0

        for line in lines {
            let cols = parseRow(line)
            guard cols.count > max(startIdx, endIdx) else { skipped += 1; continue }

            guard
                let checkIn  = parseDate(cols[safe: startIdx] ?? ""),
                let checkOut = parseDate(cols[safe: endIdx]   ?? "")
            else { skipped += 1; continue }

            let statusStr = cols[safe: statusIdx].flatMap { $0 } ?? ""
            let status: ImportedBooking.BookingStatus
            switch statusStr.lowercased() {
            case "cancelled", "canceled": status = .cancelled
            case "pending":               status = .pending
            default:                      status = .confirmed
            }

            let earnings = cols[safe: earningsIdx].flatMap { parseAmount($0) }
            let currency = cols[safe: currencyIdx].flatMap { $0.isEmpty ? nil : $0 }
            let listing  = cols[safe: listingIdx].flatMap  { $0.isEmpty ? nil : $0 }
            let guest    = cols[safe: guestIdx].flatMap    { $0.isEmpty ? nil : $0 }
            let confirm  = cols[safe: confirmIdx].flatMap  { $0.isEmpty ? nil : $0 }

            bookings.append(ImportedBooking(
                platformID: confirm,
                platform: .airbnb,
                propertyID: listing,
                guestName: guest,
                checkIn: checkIn,
                checkOut: checkOut,
                amount: earnings,
                currency: currency,
                status: status,
                rawSource: line
            ))
        }

        return ParseResult(bookings: bookings, skippedRows: skipped)
    }

    // MARK: - RFC 4180-compliant CSV row parser

    private func parseRow(_ row: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                cols.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        cols.append(current.trimmingCharacters(in: .whitespaces))
        return cols
    }

    // MARK: - Date parsing

    private let dateFormats = ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy"]

    private func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        for format in dateFormats {
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Amount parsing ("$1,234.56" → Decimal)

    private func parseAmount(_ raw: String) -> Decimal? {
        let stripped = raw.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return stripped.isEmpty ? nil : Decimal(string: stripped)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let i = index, i >= 0, i < count else { return nil }
        return self[i]
    }
}
