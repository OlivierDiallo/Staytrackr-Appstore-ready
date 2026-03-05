//
//  STModels.swift
//  StayTrackr V3 (V4)
//
//  SwiftData models (local on-device persistence).
//  iOS 17+
//

import Foundation
import SwiftData

// MARK: - Expense Category

enum STExpenseCategory: String, CaseIterable, Codable, Identifiable {
  case cleaning, repairs, utilities, management, supplies, other
  var id: String { rawValue }
}

// MARK: - Property

@Model
final class STProperty {
  @Attribute(.unique) var id: UUID

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

  // NEW: currency per property (e.g., "EUR", "CZK")
  var currencyCode: String

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
    currencyCode: String = "EUR"
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
  }
}

// MARK: - Guest

@Model
final class STGuest {
  @Attribute(.unique) var id: UUID

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
  @Attribute(.unique) var id: UUID

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

  init(
    id: UUID,
    property: STProperty,
    guest: STGuest,
    checkIn: Date,
    checkOut: Date,
    nightlyRate: Double,
    platformFeePct: Double,
    isPaid: Bool
  ) {
    self.id = id
    self.property = property
    self.guest = guest
    self.checkIn = checkIn
    self.checkOut = checkOut
    self.nightlyRate = nightlyRate
    self.platformFeePct = platformFeePct
    self.isPaid = isPaid
  }
}

// MARK: - Expense

@Model
final class STExpense {
  @Attribute(.unique) var id: UUID

  // Relationships
  var property: STProperty

  // Data
  var date: Date
  var amount: Double
  var category: STExpenseCategory
  var note: String?

  // NEW: currency on each expense (defaults to property currency)
  var currencyCode: String

  init(
    id: UUID,
    property: STProperty,
    date: Date,
    amount: Double,
    category: STExpenseCategory,
    note: String? = nil,
    currencyCode: String? = nil
  ) {
    self.id = id
    self.property = property
    self.date = date
    self.amount = amount
    self.category = category
    self.note = note
    self.currencyCode = currencyCode ?? property.currencyCode
  }
}

// MARK: - Recurring Bill

@Model
final class STRecurringBill {
  @Attribute(.unique) var id: UUID

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
