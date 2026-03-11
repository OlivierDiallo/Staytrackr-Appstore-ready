//
//  STModels.swift
//  StayTrackr V3 (V4)
//
//  SwiftData models (local on-device persistence).
//  iOS 17+
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Expense Category

enum STExpenseCategory: String, CaseIterable, Codable, Identifiable {
  case cleaning, repairs, utilities, management, supplies, other
  var id: String { rawValue }

  /// Localized display name for SwiftUI `Text` — use instead of `.rawValue.capitalized`.
  var displayName: LocalizedStringKey {
    switch self {
    case .cleaning:   return "Cleaning"
    case .repairs:    return "Repairs"
    case .utilities:  return "Utilities"
    case .management: return "Management"
    case .supplies:   return "Supplies"
    case .other:      return "Other"
    }
  }

  /// Localized name as a plain `String` — use in alert messages and other non-SwiftUI contexts.
  var localizedName: String {
    switch self {
    case .cleaning:   return String(localized: "Cleaning")
    case .repairs:    return String(localized: "Repairs")
    case .utilities:  return String(localized: "Utilities")
    case .management: return String(localized: "Management")
    case .supplies:   return String(localized: "Supplies")
    case .other:      return String(localized: "Other")
    }
  }
}

// MARK: - Booking Status

/// Computed booking lifecycle state — derived from dates, not stored.
enum STBookingStatus {
  case upcoming, active, completed

  var label: LocalizedStringKey {
    switch self {
    case .upcoming:  return "Upcoming"
    case .active:    return "Active"
    case .completed: return "Completed"
    }
  }

  var systemImage: String {
    switch self {
    case .upcoming:  return "clock"
    case .active:    return "person.fill"
    case .completed: return "checkmark.circle"
    }
  }
}

// MARK: - Property

@Model
final class STProperty {
  var id: UUID

  // Basics
  var name: String
  var purchasePrice: Double
  var mortgageAPR: Double
  var mortgageYears: Int
  var commissionPct: Double

  // UI
  var emoji: String
  var colorHex: String
  var isArchived: Bool
  var trackMortgage: Bool

  // Currency per property (e.g., "EUR", "CZK")
  var currencyCode: String

  // Photo (stored as raw JPEG data, optional)
  var photoData: Data?

  // Relationships
  @Relationship(deleteRule: .cascade, inverse: \STBooking.property)
  var bookings: [STBooking] = []

  @Relationship(deleteRule: .cascade, inverse: \STExpense.property)
  var expenses: [STExpense] = []

  @Relationship(deleteRule: .cascade, inverse: \STRecurringBill.property)
  var recurringBills: [STRecurringBill] = []

  init(
    id: UUID,
    name: String,
    purchasePrice: Double,
    mortgageAPR: Double,
    mortgageYears: Int,
    commissionPct: Double,
    emoji: String,
    colorHex: String,
    isArchived: Bool,
    trackMortgage: Bool,
    currencyCode: String = "EUR",
    photoData: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.purchasePrice = purchasePrice
    self.mortgageAPR = mortgageAPR
    self.mortgageYears = mortgageYears
    self.commissionPct = commissionPct
    self.emoji = emoji
    self.colorHex = colorHex
    self.isArchived = isArchived
    self.trackMortgage = trackMortgage
    self.currencyCode = currencyCode
    self.photoData = photoData
  }
}

// MARK: - Guest

@Model
final class STGuest {
  var id: UUID

  var name: String
  var email: String?
  var phone: String?

  // Relationships
  @Relationship(deleteRule: .nullify, inverse: \STBooking.guest)
  var bookings: [STBooking] = []

  init(
    id: UUID,
    name: String,
    email: String? = nil,
    phone: String? = nil
  ) {
    self.id = id
    self.name = name
    self.email = email
    self.phone = phone
  }
}

// MARK: - Booking

@Model
final class STBooking {
  var id: UUID

  // Relationships
  var property: STProperty
  var guest: STGuest

  // Dates
  var checkIn: Date
  var checkOut: Date

  // Financials
  var nightlyRate: Double
  var platformFeePct: Double
  var isPaid: Bool

  // Notes (host instructions, cleaning notes, etc.)
  var note: String?

  init(
    id: UUID,
    property: STProperty,
    guest: STGuest,
    checkIn: Date,
    checkOut: Date,
    nightlyRate: Double,
    platformFeePct: Double,
    isPaid: Bool,
    note: String? = nil
  ) {
    self.id = id
    self.property = property
    self.guest = guest
    self.checkIn = checkIn
    self.checkOut = checkOut
    self.nightlyRate = nightlyRate
    self.platformFeePct = platformFeePct
    self.isPaid = isPaid
    self.note = note
  }

  /// Computed lifecycle status — derived from dates, not stored.
  var status: STBookingStatus {
    let now = Date()
    if checkIn > now  { return .upcoming }
    if checkOut > now { return .active }
    return .completed
  }
}

// MARK: - Expense

@Model
final class STExpense {
  var id: UUID

  // Relationships
  var property: STProperty

  // Data
  var date: Date
  var amount: Double
  var category: STExpenseCategory
  var note: String?

  // Receipt photo (JPEG compressed, optional)
  var receiptData: Data?

  // Currency on each expense (defaults to property currency)
  var currencyCode: String

  init(
    id: UUID,
    property: STProperty,
    date: Date,
    amount: Double,
    category: STExpenseCategory,
    note: String? = nil,
    receiptData: Data? = nil,
    currencyCode: String? = nil
  ) {
    self.id = id
    self.property = property
    self.date = date
    self.amount = amount
    self.category = category
    self.note = note
    self.receiptData = receiptData
    self.currencyCode = currencyCode ?? property.currencyCode
  }
}

// MARK: - Recurring Bill

@Model
final class STRecurringBill {
  var id: UUID

  // Relationship
  var property: STProperty

  // Data
  var name: String
  var amount: Double
  var category: STExpenseCategory
  var dayOfMonth: Int
  var note: String?
  var isActive: Bool

  init(
    id: UUID,
    property: STProperty,
    name: String,
    amount: Double,
    category: STExpenseCategory,
    dayOfMonth: Int,
    note: String? = nil,
    isActive: Bool = true
  ) {
    self.id = id
    self.property = property
    self.name = name
    self.amount = amount
    self.category = category
    self.dayOfMonth = dayOfMonth
    self.note = note
    self.isActive = isActive
  }
}
