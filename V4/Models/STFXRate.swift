//
//  STFXRate.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 01.03.2026.
//
import Foundation
import SwiftData

@Model
final class STFXRate {

  @Attribute(.unique) var id: UUID

  /// Base currency code, e.g. "EUR"
  var fromCode: String

  /// Quote currency code, e.g. "CZK"
  var toCode: String

  /// “1 fromCode = rate toCode”
  var rate: Double

  /// Optional metadata
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    fromCode: String,
    toCode: String,
    rate: Double,
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.fromCode = fromCode.uppercased()
    self.toCode = toCode.uppercased()
    self.rate = rate
    self.updatedAt = updatedAt
  }
}
