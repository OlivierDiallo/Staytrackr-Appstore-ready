import Foundation

enum V4Format {

  // MARK: - Currency (uses ISO code)
  static func currency(_ value: Double, code: String) -> String {
    value.formatted(.currency(code: code))
  }

  // If you still want a “default” currency output (uses current locale currency if available)
  static func currency(_ value: Double) -> String {
    let code = Locale.current.currency?.identifier ?? "EUR"
    return currency(value, code: code)
  }

  // MARK: - Plain number (no currency symbol)
  static func plainNumber(_ value: Double, maxFractionDigits: Int = 2) -> String {
    let nf = NumberFormatter()
    nf.locale = .current
    nf.numberStyle = .decimal
    nf.minimumFractionDigits = 0
    nf.maximumFractionDigits = maxFractionDigits
    return nf.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  // MARK: - Parse number from TextField (supports both "." and "," decimals)
  static func parseNumber(_ text: String) -> Double? {
    let trimmed = text
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else { return nil }

    // Accept users typing comma decimals (EU) or dot decimals
    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")

    // Use a stable locale for parsing (dot decimal)
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "en_US_POSIX")
    nf.numberStyle = .decimal

    if let n = nf.number(from: normalized) {
      return n.doubleValue
    }

    // Fallback (handles simple cases)
    return Double(normalized)
  }
}
