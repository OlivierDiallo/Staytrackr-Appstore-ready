//
//  V4Finance.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 06.01.2026.
//
import Foundation

enum V4Finance {
  static func nights(_ a: Date, _ b: Date) -> Int {
    max(0, Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0)
  }

  static func netRevenue(gross: Double, platform pct: Double, commission hostPct: Double) -> Double {
    (gross * (1 - pct)) * (1 - hostPct)
  }

  static func mortgageMonthly(price: Double, apr: Double, years: Int) -> Double {
    let r = apr / 12
    let n = Double(years * 12)
    guard r > 0, n > 0 else { return n > 0 ? price / n : 0 }
    return price * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
  }
}
