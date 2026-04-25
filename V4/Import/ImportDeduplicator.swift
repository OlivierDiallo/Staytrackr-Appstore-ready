import Foundation
import SwiftData

// Classifies a batch of ImportedBooking values against existing STBooking records.
// Matching priority:
//   1. Exact platformID match (confirmation code / reservation ID)
//   2. Same check-in AND check-out date (within ±1 day tolerance, same property scope)
// A cancelled imported booking is always dropped before deduplication.

struct ImportDeduplicator {

    enum Outcome {
        case insert(ImportedBooking)
        case skip(ImportedBooking, existing: STBooking)
        case update(ImportedBooking, existing: STBooking)    // dates shifted on a known booking
    }

    struct Result {
        var toInsert: [ImportedBooking]          = []
        var toUpdate: [(ImportedBooking, STBooking)] = []
        var skippedCount: Int                    = 0
    }

    // `existing` should be the full list of bookings for the relevant property scope.
    func deduplicate(_ imported: [ImportedBooking], against existing: [STBooking]) -> Result {
        var result = Result()
        for booking in imported {
            guard booking.status != .cancelled else { continue }
            switch classify(booking, against: existing) {
            case .insert(let b):
                result.toInsert.append(b)
            case .skip:
                result.skippedCount += 1
            case .update(let b, let e):
                result.toUpdate.append((b, e))
            }
        }
        return result
    }

    // MARK: - Classification

    private func classify(_ imported: ImportedBooking, against existing: [STBooking]) -> Outcome {
        // 1. Platform ID exact match
        if let pid = imported.platformID, !pid.isEmpty {
            if let match = existing.first(where: { $0.platformID == pid }) {
                return hasDateChanged(imported, existing: match)
                    ? .update(imported, existing: match)
                    : .skip(imported, existing: match)
            }
        }

        // 2. Date-match fallback (same check-in and check-out, ±1 day)
        if let match = existing.first(where: { dateMatch(imported, existing: $0) }) {
            return .skip(imported, existing: match)
        }

        return .insert(imported)
    }

    private func hasDateChanged(_ imported: ImportedBooking, existing: STBooking) -> Bool {
        !Calendar.current.isDate(imported.checkIn,  equalTo: existing.checkIn,  toGranularity: .day) ||
        !Calendar.current.isDate(imported.checkOut, equalTo: existing.checkOut, toGranularity: .day)
    }

    private func dateMatch(_ imported: ImportedBooking, existing: STBooking) -> Bool {
        Calendar.current.isDate(imported.checkIn,  equalTo: existing.checkIn,  toGranularity: .day) &&
        Calendar.current.isDate(imported.checkOut, equalTo: existing.checkOut, toGranularity: .day)
    }
}

// MARK: - Commit helpers (called from V4ImportView after deduplication)

extension ImportDeduplicator {

    /// Inserts and updates bookings returned by `deduplicate` into the SwiftData context.
    /// Returns (inserted, updated) counts.
    @discardableResult
    static func commit(
        result: Result,
        property: STProperty,
        context: ModelContext
    ) -> (inserted: Int, updated: Int) {
        var inserted = 0
        var updated  = 0

        for imported in result.toInsert {
            let guest = findOrCreateGuest(name: imported.guestName ?? "Guest", context: context)
            let nights = max(1, Calendar(identifier: .gregorian)
                .dateComponents([.day], from: imported.checkIn, to: imported.checkOut).day ?? 1)
            let rate: Double = {
                guard let amt = imported.amount else { return 0 }
                return (Double(truncating: amt as NSDecimalNumber)) / Double(nights)
            }()

            let booking = STBooking(
                id: UUID(),
                property: property,
                guest: guest,
                checkIn: imported.checkIn,
                checkOut: imported.checkOut,
                nightlyRate: rate,
                platformFeePct: 0,
                isPaid: imported.status == .confirmed
            )
            booking.platformID     = imported.platformID
            booking.platformSource = imported.platform.rawValue
            context.insert(booking)
            inserted += 1
        }

        for (imported, existing) in result.toUpdate {
            existing.checkIn  = imported.checkIn
            existing.checkOut = imported.checkOut
            updated += 1
        }

        return (inserted, updated)
    }

    private static func findOrCreateGuest(name: String, context: ModelContext) -> STGuest {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<STGuest>()
        let all = (try? context.fetch(descriptor)) ?? []
        if let existing = all.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return existing
        }
        let guest = STGuest(id: UUID(), name: trimmed)
        context.insert(guest)
        return guest
    }
}
