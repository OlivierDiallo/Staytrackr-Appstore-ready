import Foundation

// Parses iCal (.ics) feeds from Airbnb and Booking.com into ImportedBooking values.
// Handles line folding (RFC 5545 §3.1), date-only and datetime stamps, and both platforms'
// SUMMARY/DESCRIPTION conventions for extracting guest name and platform ID.

// ICalParser has no mutable state — plain struct so it runs on the caller's actor
// (the @MainActor SwiftUI Task that invokes fetch), avoiding cross-actor init calls.
struct ICalParser {

    static let shared = ICalParser()

    // MARK: - Public API

    func fetch(url: URL, platform: ImportedBooking.Platform) async throws -> [ImportedBooking] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ICalError.invalidEncoding
        }
        return parse(icsText: text, platform: platform)
    }

    // MARK: - Parser

    func parse(icsText: String, platform: ImportedBooking.Platform) -> [ImportedBooking] {
        // Unfold RFC 5545 line continuations (CRLF + whitespace)
        let unfolded = icsText
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")

        var bookings: [ImportedBooking] = []
        var inEvent = false
        var fields: [String: String] = [:]

        for rawLine in unfolded.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line == "BEGIN:VEVENT" {
                inEvent = true
                fields = [:]
            } else if line == "END:VEVENT" {
                inEvent = false
                if let booking = makeBooking(from: fields, platform: platform) {
                    bookings.append(booking)
                }
            } else if inEvent, let colonRange = line.range(of: ":") {
                // Key may carry parameters: DTSTART;VALUE=DATE → key = "DTSTART"
                let rawKey = String(line[line.startIndex..<colonRange.lowerBound])
                let value  = String(line[colonRange.upperBound...])
                let key    = rawKey.components(separatedBy: ";").first?.uppercased() ?? rawKey.uppercased()
                // Don't overwrite — first occurrence wins (matches RFC)
                if fields[key] == nil { fields[key] = value }
            }
        }

        return bookings
    }

    // MARK: - Event → ImportedBooking

    private func makeBooking(from fields: [String: String], platform: ImportedBooking.Platform) -> ImportedBooking? {
        guard
            let dtstart = fields["DTSTART"],
            let dtend   = fields["DTEND"],
            let checkIn  = parseDate(dtstart),
            let checkOut = parseDate(dtend)
        else { return nil }

        let summary     = fields["SUMMARY"] ?? ""
        let description = fields["DESCRIPTION"] ?? ""
        let uid         = fields["UID"]

        // Booking.com blocks and Airbnb "Not available" closures are not real bookings
        let lcSummary = summary.lowercased()
        if lcSummary.contains("not available") || lcSummary.contains("closed") ||
           lcSummary.contains("unavailable") || lcSummary == "airbnb (not available)" {
            return nil
        }

        let guestName  = extractGuestName(summary: summary, description: description, platform: platform)
        let platformID = extractPlatformID(uid: uid, description: description, platform: platform)
        let status     = extractStatus(summary: summary, description: description)

        let raw = fields.map { "\($0.key):\($0.value)" }.joined(separator: "\n")

        return ImportedBooking(
            platformID: platformID,
            platform: platform,
            guestName: guestName,
            checkIn: checkIn,
            checkOut: checkOut,
            status: status,
            rawSource: raw
        )
    }

    // MARK: - Date parsing

    private func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // DATE-only: 20250615
        if s.count == 8, s.allSatisfy(\.isNumber) {
            return dateFmt("yyyyMMdd").date(from: s)
        }
        // DATETIME UTC: 20250615T120000Z
        if s.hasSuffix("Z") {
            return dateFmt("yyyyMMdd'T'HHmmss'Z'").date(from: s)
        }
        // DATETIME local: 20250615T120000
        return dateFmt("yyyyMMdd'T'HHmmss").date(from: s)
    }

    private func dateFmt(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    // MARK: - Field extraction

    private func extractGuestName(summary: String, description: String, platform: ImportedBooking.Platform) -> String? {
        switch platform {
        case .airbnb:
            // "John Smith (Confirmed)" → "John Smith"
            if let parenIdx = summary.firstIndex(of: "(") {
                let name = String(summary[summary.startIndex..<parenIdx]).trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? nil : name
            }
            return summary.isEmpty ? nil : summary

        case .bookingCom:
            // Description lines are "\\n"-separated (literal backslash-n in iCal text)
            for line in description.components(separatedBy: "\\n") {
                let lc = line.lowercased()
                if lc.hasPrefix("guest name:") || lc.hasPrefix("guest:") {
                    let name = line.drop(while: { $0 != ":" }).dropFirst()
                        .trimmingCharacters(in: .whitespaces)
                    return name.isEmpty ? nil : name
                }
            }
            return summary.isEmpty ? nil : summary

        case .manual:
            return summary.isEmpty ? nil : summary
        }
    }

    private func extractPlatformID(uid: String?, description: String, platform: ImportedBooking.Platform) -> String? {
        for line in description.components(separatedBy: "\\n") {
            let lc = line.lowercased()
            if lc.contains("confirmation code:") || lc.contains("reservation id:") || lc.contains("booking id:") {
                let value = line.drop(while: { $0 != ":" }).dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        // Airbnb UIDs look like: "confirmation_code@airbnb.com" — strip the domain
        if let uid, platform == .airbnb, let atIdx = uid.firstIndex(of: "@") {
            return String(uid[uid.startIndex..<atIdx])
        }
        return uid
    }

    private func extractStatus(summary: String, description: String) -> ImportedBooking.BookingStatus {
        let combined = (summary + description).lowercased()
        if combined.contains("cancelled") || combined.contains("canceled") { return .cancelled }
        if combined.contains("pending") { return .pending }
        return .confirmed
    }

    // MARK: - Errors

    enum ICalError: LocalizedError {
        case invalidEncoding
        var errorDescription: String? { "Could not decode iCal data as UTF-8." }
    }
}
