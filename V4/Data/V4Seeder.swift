//
//  V4Seeder.swift
//  StayTrackr V3 (V4)
//
//  Seeds minimal demo data for development / TestFlight / App Store review.
//  Guarded at the call site with #if DEBUG.
//

import Foundation
import SwiftData

enum V4Seeder {

  @MainActor
  static func seed(into context: ModelContext) {

    let cal = Calendar.current
    let now = Date()

    let m0 = cal.date(from: cal.dateComponents([.year, .month], from: now))!   // this month
    let m1 = cal.date(byAdding: .month, value: -1, to: m0)!                    // last month
    let mN = cal.date(byAdding: .month, value:  1, to: m0)!                    // next month

    func d(_ base: Date, _ days: Int) -> Date {
      cal.date(byAdding: .day, value: days, to: base)!
    }

    // MARK: - Property (1)

    let p1 = STProperty(
      id: UUID(),
      name: "Casa Azul",
      purchasePrice: 285_000,
      mortgageAPR: 0.034,
      mortgageYears: 20,
      commissionPct: 0.14,
      emoji: "🏖️",
      colorHex: "#1FB86E",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "EUR"
    )

    context.insert(p1)

    // MARK: - Guests (2)

    let g1 = STGuest(id: UUID(), name: "Sophie Laurent", email: "sophie@example.com", phone: "+33 6 12 34 56 78")
    let g2 = STGuest(id: UUID(), name: "James Wilson",   email: "james@example.com",  phone: "+44 7700 900 123")

    context.insert(g1)
    context.insert(g2)

    // MARK: - Bookings (4)
    // 1 completed last month, 1 current month paid, 1 current month upcoming, 1 next month

    let bookings: [STBooking] = [
      STBooking(id: UUID(), property: p1, guest: g1,
                checkIn: d(m1, 10), checkOut: d(m1, 16),
                nightlyRate: 145, platformFeePct: 0.14, isPaid: true,
                note: "Late arrival, key in lockbox"),

      STBooking(id: UUID(), property: p1, guest: g2,
                checkIn: d(m0, 3),  checkOut: d(m0, 8),
                nightlyRate: 155, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g1,
                checkIn: d(m0, 18), checkOut: d(m0, 23),
                nightlyRate: 160, platformFeePct: 0.14, isPaid: false,
                note: "Arrives 3pm, early check-in requested"),

      STBooking(id: UUID(), property: p1, guest: g2,
                checkIn: d(mN, 5),  checkOut: d(mN, 11),
                nightlyRate: 170, platformFeePct: 0.14, isPaid: false),
    ]

    bookings.forEach { context.insert($0) }

    // MARK: - Expenses (4)

    let expenses: [STExpense] = [
      STExpense(id: UUID(), property: p1, date: d(m1, 12), amount: 65,  category: .cleaning,  note: "Post-checkout turnover"),
      STExpense(id: UUID(), property: p1, date: d(m1, 10), amount: 120, category: .utilities, note: "Electricity & water"),
      STExpense(id: UUID(), property: p1, date: d(m0, 4),  amount: 65,  category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p1, date: d(m0, 8),  amount: 240, category: .repairs,   note: "Pool pump service"),
    ]

    expenses.forEach { context.insert($0) }

    // MARK: - Recurring Bills (2)

    let bills: [STRecurringBill] = [
      STRecurringBill(id: UUID(), property: p1, name: "Electricity",      amount: 125, category: .utilities, dayOfMonth: 1,  note: nil,             isActive: true),
      STRecurringBill(id: UUID(), property: p1, name: "Cleaning Service", amount: 65,  category: .cleaning,  dayOfMonth: 1,  note: "After each stay", isActive: true),
    ]

    bills.forEach { context.insert($0) }
  }
}
