//
//  V4Seeder.swift
//  StayTrackr V3 (V4)
//
//  Seeds demo data once for development/TestFlight.
//

import Foundation
import SwiftData

enum V4Seeder {
  @MainActor
  static func seed(into context: ModelContext) {

    // MARK: - Properties (with per-property currency)

    let p1 = STProperty(
      id: UUID(),
      name: "Costa Adeje",
      purchasePrice: 240_000,
      mortgageAPR: 0.035,
      mortgageYears: 20,
      commissionPct: 0.10,
      emoji: "🏖️",
      colorHex: "#34C759",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "EUR"
    )

    let p2 = STProperty(
      id: UUID(),
      name: "Prague Old Town",
      purchasePrice: 310_000,
      mortgageAPR: 0.039,
      mortgageYears: 25,
      commissionPct: 0.12,
      emoji: "🏙️",
      colorHex: "#007AFF",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "CZK"
    )

    context.insert(p1)
    context.insert(p2)

    // MARK: - Guests

    let g1 = STGuest(id: UUID(), name: "Jason Smith", email: "jason@example.com", phone: "+44 123 456 789")
    let g2 = STGuest(id: UUID(), name: "Maria Gomez", email: "maria@example.com", phone: "+34 987 654 321")

    context.insert(g1)
    context.insert(g2)

    // MARK: - Bookings

    let cal = Calendar.current
    let now = Date()

    let b1 = STBooking(
      id: UUID(),
      property: p1,
      guest: g1,
      checkIn: cal.date(byAdding: .day, value: 2, to: now)!,
      checkOut: cal.date(byAdding: .day, value: 6, to: now)!,
      nightlyRate: 120,            // EUR
      platformFeePct: 0.14,
      isPaid: true
    )

    let b2 = STBooking(
      id: UUID(),
      property: p1,
      guest: g2,
      checkIn: cal.date(byAdding: .day, value: 6, to: now)!,
      checkOut: cal.date(byAdding: .day, value: 9, to: now)!,
      nightlyRate: 140,            // EUR
      platformFeePct: 0.14,
      isPaid: false
    )

    let b3 = STBooking(
      id: UUID(),
      property: p2,
      guest: g2,
      checkIn: cal.date(byAdding: .day, value: 12, to: now)!,
      checkOut: cal.date(byAdding: .day, value: 15, to: now)!,
      nightlyRate: 2_800,          // CZK (example)
      platformFeePct: 0.12,
      isPaid: false
    )

    context.insert(b1)
    context.insert(b2)
    context.insert(b3)

    // MARK: - Expenses
    // NOTE: currencyCode auto-defaults to property.currencyCode (see STExpense init).

    let e1 = STExpense(
      id: UUID(),
      property: p1,
      date: now,
      amount: 60,                  // EUR
      category: .cleaning,
      note: "Turnover"
    )

    let e2 = STExpense(
      id: UUID(),
      property: p1,
      date: now,
      amount: 120,                 // EUR
      category: .utilities,
      note: "Electricity"
    )

    let e3 = STExpense(
      id: UUID(),
      property: p2,
      date: now,
      amount: 1_900,               // CZK (example)
      category: .repairs,
      note: "Door handle"
    )

    context.insert(e1)
    context.insert(e2)
    context.insert(e3)

    // MARK: - Recurring bills

    let r1 = STRecurringBill(
      id: UUID(),
      property: p1,
      name: "Electricity",
      amount: 120,                 // EUR
      category: .utilities,
      dayOfMonth: 10,
      note: nil,
      isActive: true
    )

    let r2 = STRecurringBill(
      id: UUID(),
      property: p1,
      name: "Water",
      amount: 35,                  // EUR
      category: .utilities,
      dayOfMonth: 15,
      note: nil,
      isActive: true
    )

    let r3 = STRecurringBill(
      id: UUID(),
      property: p2,
      name: "Internet",
      amount: 650,                 // CZK (example)
      category: .utilities,
      dayOfMonth: 12,
      note: "Fiber",
      isActive: true
    )

    context.insert(r1)
    context.insert(r2)
    context.insert(r3)
  }
}
