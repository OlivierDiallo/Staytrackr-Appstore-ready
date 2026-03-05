//
//  Currency.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 08.01.2026.
//
import Foundation

enum V4Currency {
  /// Formats a value using a specific ISO 4217 currency code (e.g., "EUR", "CZK").
  static func format(_ value: Double, code: String) -> String {
    // Prefer Swift’s modern formatting if available
    if #available(iOS 15.0, *) {
      return value.formatted(.currency(code: code))
    } else {
      let nf = NumberFormatter()
      nf.numberStyle = .currency
      nf.currencyCode = code
      nf.maximumFractionDigits = 2
      nf.minimumFractionDigits = 2
      return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
  }
}
