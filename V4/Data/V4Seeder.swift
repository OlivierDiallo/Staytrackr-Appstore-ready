//
//  V4Seeder.swift
//  StayTrackr V3 (V4)
//
//  Seeds rich demo data for development / TestFlight / App Store review.
//  Guarded at the call site with #if DEBUG.
//

import Foundation
import SwiftData

enum V4Seeder {

  @MainActor
  static func seed(into context: ModelContext) {

    let cal = Calendar.current
    let now = Date()

    // Start-of-month anchors (relative so the calendar always looks live)
    let m0 = cal.date(from: cal.dateComponents([.year, .month], from: now))!       // this month
    let m1 = cal.date(byAdding: .month, value: -1, to: m0)!                        // last month
    let m2 = cal.date(byAdding: .month, value: -2, to: m0)!                        // 2 months ago
    let m3 = cal.date(byAdding: .month, value: -3, to: m0)!                        // 3 months ago
    let mN = cal.date(byAdding: .month, value:  1, to: m0)!                        // next month

    func d(_ base: Date, _ days: Int) -> Date {
      cal.date(byAdding: .day, value: days, to: base)!
    }

    // MARK: - Properties

    let p1 = STProperty(
      id: UUID(),
      name: "Casa Azul",
      purchasePrice: 285_000,
      mortgageAPR: 0.034,
      mortgageYears: 20,
      commissionPct: 0.12,
      emoji: "🏖️",
      colorHex: "#1FB86E",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "EUR"
    )

    let p2 = STProperty(
      id: UUID(),
      name: "Mountain Retreat",
      purchasePrice: 198_000,
      mortgageAPR: 0.038,
      mortgageYears: 25,
      commissionPct: 0.10,
      emoji: "🏔️",
      colorHex: "#5856D6",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "EUR"
    )

    let p3 = STProperty(
      id: UUID(),
      name: "Old Town Flat",
      purchasePrice: 5_200_000,
      mortgageAPR: 0.042,
      mortgageYears: 20,
      commissionPct: 0.15,
      emoji: "🏙️",
      colorHex: "#FF9500",
      isArchived: false,
      trackMortgage: true,
      currencyCode: "CZK"
    )

    context.insert(p1)
    context.insert(p2)
    context.insert(p3)

    // MARK: - Guests

    let g1 = STGuest(id: UUID(), name: "Sophie Laurent",  email: "sophie@example.com",  phone: "+33 6 12 34 56 78")
    let g2 = STGuest(id: UUID(), name: "James Wilson",    email: "james@example.com",   phone: "+44 7700 900 123")
    let g3 = STGuest(id: UUID(), name: "Maria Gomez",     email: "maria@example.com",   phone: "+34 611 234 567")
    let g4 = STGuest(id: UUID(), name: "Lukas Novak",     email: "lukas@example.com",   phone: "+420 777 123 456")
    let g5 = STGuest(id: UUID(), name: "Emma Thompson",   email: "emma@example.com",    phone: "+44 7911 123 456")
    let g6 = STGuest(id: UUID(), name: "Carlos Rivera",   email: "carlos@example.com",  phone: "+34 622 345 678")

    context.insert(g1)
    context.insert(g2)
    context.insert(g3)
    context.insert(g4)
    context.insert(g5)
    context.insert(g6)

    // MARK: - Bookings
    // Casa Azul — EUR, ~€130–175/night

    let bookings: [STBooking] = [

      // ── Casa Azul past bookings (paid) ──────────────────────────────

      STBooking(id: UUID(), property: p1, guest: g1,
                checkIn: d(m3, 5),  checkOut: d(m3, 11),
                nightlyRate: 125, platformFeePct: 0.14, isPaid: true,
                note: "Late arrival, key in lockbox"),

      STBooking(id: UUID(), property: p1, guest: g2,
                checkIn: d(m3, 18), checkOut: d(m3, 24),
                nightlyRate: 128, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g5,
                checkIn: d(m2, 2),  checkOut: d(m2, 8),
                nightlyRate: 133, platformFeePct: 0.14, isPaid: true,
                note: "Anniversary trip — leave welcome card"),

      STBooking(id: UUID(), property: p1, guest: g3,
                checkIn: d(m2, 15), checkOut: d(m2, 21),
                nightlyRate: 138, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g6,
                checkIn: d(m1, 3),  checkOut: d(m1, 9),
                nightlyRate: 145, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g1,
                checkIn: d(m1, 14), checkOut: d(m1, 20),
                nightlyRate: 152, platformFeePct: 0.14, isPaid: true,
                note: "Returning guest — upgrade towels"),

      STBooking(id: UUID(), property: p1, guest: g2,
                checkIn: d(m0, 1),  checkOut: d(m0, 7),
                nightlyRate: 160, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g5,
                checkIn: d(m0, 10), checkOut: d(m0, 16),
                nightlyRate: 165, platformFeePct: 0.14, isPaid: true),

      STBooking(id: UUID(), property: p1, guest: g3,
                checkIn: d(m0, 20), checkOut: d(m0, 26),
                nightlyRate: 170, platformFeePct: 0.14, isPaid: false,
                note: "Arrives 3pm, early check-in requested"),

      STBooking(id: UUID(), property: p1, guest: g4,
                checkIn: d(mN, 4),  checkOut: d(mN, 10),
                nightlyRate: 175, platformFeePct: 0.14, isPaid: false),

      // ── Mountain Retreat past bookings (paid) ───────────────────────

      STBooking(id: UUID(), property: p2, guest: g6,
                checkIn: d(m3, 6),  checkOut: d(m3, 11),
                nightlyRate: 90, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p2, guest: g4,
                checkIn: d(m2, 4),  checkOut: d(m2, 9),
                nightlyRate: 95, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p2, guest: g5,
                checkIn: d(m1, 6),  checkOut: d(m1, 12),
                nightlyRate: 100, platformFeePct: 0.12, isPaid: true,
                note: "Business traveller — needs desk workspace"),

      STBooking(id: UUID(), property: p2, guest: g2,
                checkIn: d(m1, 21), checkOut: d(m1, 26),
                nightlyRate: 108, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p2, guest: g1,
                checkIn: d(m0, 3),  checkOut: d(m0, 9),
                nightlyRate: 115, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p2, guest: g3,
                checkIn: d(m0, 18), checkOut: d(m0, 24),
                nightlyRate: 120, platformFeePct: 0.12, isPaid: false),

      STBooking(id: UUID(), property: p2, guest: g6,
                checkIn: d(mN, 2),  checkOut: d(mN, 7),
                nightlyRate: 125, platformFeePct: 0.12, isPaid: false),

      // ── Old Town Flat past bookings — CZK ───────────────────────────

      STBooking(id: UUID(), property: p3, guest: g1,
                checkIn: d(m3, 8),  checkOut: d(m3, 13),
                nightlyRate: 2_400, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p3, guest: g6,
                checkIn: d(m2, 7),  checkOut: d(m2, 13),
                nightlyRate: 2_600, platformFeePct: 0.12, isPaid: true,
                note: "Celebrating New Year — champagne requested"),

      STBooking(id: UUID(), property: p3, guest: g5,
                checkIn: d(m1, 5),  checkOut: d(m1, 11),
                nightlyRate: 2_900, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p3, guest: g2,
                checkIn: d(m1, 18), checkOut: d(m1, 24),
                nightlyRate: 3_100, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p3, guest: g4,
                checkIn: d(m0, 6),  checkOut: d(m0, 12),
                nightlyRate: 3_200, platformFeePct: 0.12, isPaid: true),

      STBooking(id: UUID(), property: p3, guest: g3,
                checkIn: d(m0, 20), checkOut: d(m0, 26),
                nightlyRate: 3_500, platformFeePct: 0.12, isPaid: false,
                note: "Birthday trip — late check-out if possible"),

      STBooking(id: UUID(), property: p3, guest: g1,
                checkIn: d(mN, 1),  checkOut: d(mN, 7),
                nightlyRate: 3_800, platformFeePct: 0.12, isPaid: false),
    ]

    bookings.forEach { context.insert($0) }

    // MARK: - Expenses

    let expenses: [STExpense] = [

      // ── Casa Azul — EUR ─────────────────────────────────────────────

      STExpense(id: UUID(), property: p1, date: d(m3, 2),  amount: 60,  category: .cleaning,  note: "Post-checkout turnover"),
      STExpense(id: UUID(), property: p1, date: d(m3, 16), amount: 65,  category: .cleaning,  note: "Mid-month deep clean"),
      STExpense(id: UUID(), property: p1, date: d(m3, 10), amount: 122, category: .utilities, note: "Electricity & water"),
      STExpense(id: UUID(), property: p1, date: d(m2, 3),  amount: 60,  category: .cleaning,  note: "Post-checkout turnover"),
      STExpense(id: UUID(), property: p1, date: d(m2, 16), amount: 62,  category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p1, date: d(m2, 12), amount: 118, category: .utilities, note: "Electricity & water"),
      STExpense(id: UUID(), property: p1, date: d(m1, 4),  amount: 60,  category: .cleaning,  note: "Post-checkout"),
      STExpense(id: UUID(), property: p1, date: d(m1, 15), amount: 65,  category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p1, date: d(m1, 10), amount: 125, category: .utilities, note: "Monthly electricity"),
      STExpense(id: UUID(), property: p1, date: d(m1, 22), amount: 240, category: .repairs,   note: "Pool pump service"),
      STExpense(id: UUID(), property: p1, date: d(m0, 2),  amount: 60,  category: .cleaning,  note: "Post-checkout"),
      STExpense(id: UUID(), property: p1, date: d(m0, 11), amount: 65,  category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p1, date: d(m0, 8),  amount: 128, category: .utilities, note: "Monthly electricity"),

      // ── Mountain Retreat — EUR ───────────────────────────────────────

      STExpense(id: UUID(), property: p2, date: d(m3, 7),  amount: 45,  category: .cleaning,  note: "Post-stay clean"),
      STExpense(id: UUID(), property: p2, date: d(m3, 10), amount: 82,  category: .utilities, note: "Gas & electricity"),
      STExpense(id: UUID(), property: p2, date: d(m2, 5),  amount: 45,  category: .cleaning,  note: "Turnover"),
      STExpense(id: UUID(), property: p2, date: d(m2, 10), amount: 78,  category: .utilities, note: "Monthly gas"),
      STExpense(id: UUID(), property: p2, date: d(m1, 7),  amount: 50,  category: .cleaning,  note: "Post-checkout"),
      STExpense(id: UUID(), property: p2, date: d(m1, 11), amount: 85,  category: .utilities, note: "Gas & electricity"),
      STExpense(id: UUID(), property: p2, date: d(m1, 14), amount: 165, category: .repairs,   note: "Boiler service"),
      STExpense(id: UUID(), property: p2, date: d(m0, 4),  amount: 45,  category: .cleaning,  note: "Post-checkout"),
      STExpense(id: UUID(), property: p2, date: d(m0, 10), amount: 88,  category: .utilities, note: "Monthly gas"),
      STExpense(id: UUID(), property: p2, date: d(m0, 6),  amount: 38,  category: .supplies,  note: "Toiletries & welcome kit"),

      // ── Old Town Flat — CZK ─────────────────────────────────────────

      STExpense(id: UUID(), property: p3, date: d(m3, 9),  amount: 750,   category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p3, date: d(m3, 12), amount: 2_350, category: .utilities, note: "Electricity & heating"),
      STExpense(id: UUID(), property: p3, date: d(m2, 8),  amount: 780,   category: .cleaning,  note: "Deep clean"),
      STExpense(id: UUID(), property: p3, date: d(m2, 11), amount: 2_400, category: .utilities, note: "Electricity & heating"),
      STExpense(id: UUID(), property: p3, date: d(m1, 6),  amount: 800,   category: .cleaning,  note: "Post-checkout"),
      STExpense(id: UUID(), property: p3, date: d(m1, 10), amount: 2_450, category: .utilities, note: "Electricity & heating"),
      STExpense(id: UUID(), property: p3, date: d(m1, 19), amount: 1_800, category: .repairs,   note: "Window seal replacement"),
      STExpense(id: UUID(), property: p3, date: d(m0, 7),  amount: 820,   category: .cleaning,  note: "Turnover clean"),
      STExpense(id: UUID(), property: p3, date: d(m0, 10), amount: 2_500, category: .utilities, note: "Electricity & heating"),
      STExpense(id: UUID(), property: p3, date: d(m0, 14), amount: 950,   category: .supplies,  note: "Bed linen replacement"),
    ]

    expenses.forEach { context.insert($0) }

    // MARK: - Recurring Bills

    let bills: [STRecurringBill] = [

      // Casa Azul
      STRecurringBill(id: UUID(), property: p1, name: "Electricity",       amount: 125,   category: .utilities, dayOfMonth: 1,  note: nil,               isActive: true),
      STRecurringBill(id: UUID(), property: p1, name: "Internet",          amount: 45,    category: .utilities, dayOfMonth: 5,  note: "Fibre 500Mbps",   isActive: true),
      STRecurringBill(id: UUID(), property: p1, name: "Cleaning Service",  amount: 60,    category: .cleaning,  dayOfMonth: 1,  note: "After each stay", isActive: true),
      STRecurringBill(id: UUID(), property: p1, name: "Property Insurance",amount: 95,    category: .management,dayOfMonth: 15, note: nil,               isActive: true),

      // Mountain Retreat
      STRecurringBill(id: UUID(), property: p2, name: "Gas & Electricity", amount: 85,    category: .utilities, dayOfMonth: 1,  note: nil,               isActive: true),
      STRecurringBill(id: UUID(), property: p2, name: "Internet",          amount: 35,    category: .utilities, dayOfMonth: 5,  note: "DSL backup",      isActive: true),
      STRecurringBill(id: UUID(), property: p2, name: "Cleaning",          amount: 48,    category: .cleaning,  dayOfMonth: 1,  note: nil,               isActive: true),

      // Old Town Flat
      STRecurringBill(id: UUID(), property: p3, name: "Electricity",       amount: 2_500, category: .utilities, dayOfMonth: 1,  note: nil,               isActive: true),
      STRecurringBill(id: UUID(), property: p3, name: "Internet",          amount: 1_200, category: .utilities, dayOfMonth: 5,  note: "Fiber",           isActive: true),
      STRecurringBill(id: UUID(), property: p3, name: "Cleaning Service",  amount: 850,   category: .cleaning,  dayOfMonth: 1,  note: nil,               isActive: true),
    ]

    bills.forEach { context.insert($0) }

    // MARK: - FX Rates

    let fx = STFXRate(id: UUID(), fromCode: "EUR", toCode: "CZK", rate: 25.30)
    context.insert(fx)
  }
}
