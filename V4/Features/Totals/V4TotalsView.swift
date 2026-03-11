import SwiftUI
import SwiftData

// MARK: - Scope Enum

enum TotalsScope: String, CaseIterable {
  case monthly = "Monthly"
  case yearly  = "Yearly"
  case allTime = "All Time"
}

// MARK: - Totals View

struct V4TotalsView: View {
  let prefs: V4AppPreferences

  @Environment(V4AppSettings.self) private var settings
  @Environment(STStoreManager.self) private var store

  @State private var showPaywall = false

  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STBooking.checkIn) private var bookings: [STBooking]
  @Query(sort: \STExpense.date, order: .reverse) private var expenses: [STExpense]

  @State private var referenceDate: Date = .now

  private let cal = Calendar.current

  // MARK: - Scope

  private var scope: TotalsScope {
    TotalsScope(rawValue: prefs.totalsScopeRaw) ?? .monthly
  }

  /// Inclusive start / exclusive end for the current period
  private var periodRange: (start: Date, end: Date) {
    switch scope {
    case .monthly:
      let start = cal.date(from: cal.dateComponents([.year, .month], from: referenceDate))!
      let end   = cal.date(byAdding: .month, value: 1, to: start)!
      return (start, end)
    case .yearly:
      let start = cal.date(from: cal.dateComponents([.year], from: referenceDate))!
      let end   = cal.date(byAdding: .year, value: 1, to: start)!
      return (start, end)
    case .allTime:
      return (.distantPast, .distantFuture)
    }
  }

  private var periodLabel: String {
    switch scope {
    case .monthly:
      return referenceDate.formatted(.dateTime.month(.wide).year())
    case .yearly:
      return referenceDate.formatted(.dateTime.year())
    case .allTime:
      return "All Time"
    }
  }

  private func stepBack() {
    switch scope {
    case .monthly:
      referenceDate = cal.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
    case .yearly:
      referenceDate = cal.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate
    case .allTime: break
    }
  }

  private func stepForward() {
    switch scope {
    case .monthly:
      referenceDate = cal.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
    case .yearly:
      referenceDate = cal.date(byAdding: .year, value: 1, to: referenceDate) ?? referenceDate
    case .allTime: break
    }
  }

  // MARK: - Selection

  private var selectedProperty: STProperty? {
    guard let id = prefs.selectedPropertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  private var currencyCodesInUse: [String] {
    Array(Set(properties.map { $0.currencyCode })).sorted()
  }

  private var canShowAllPropertiesAsSingleTotal: Bool {
    currencyCodesInUse.count <= 1
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {

          headerCard

          if properties.isEmpty {
            V4Card {
              VStack(alignment: .leading, spacing: 8) {
                Text("No properties yet")
                  .font(.headline)
                Text("Add a property in Settings → Properties to see totals.")
                  .foregroundStyle(.secondary)
              }
            }
          } else if selectedProperty == nil && !canShowAllPropertiesAsSingleTotal {
            V4Card {
              VStack(alignment: .leading, spacing: 8) {
                Text("Multiple currencies detected")
                  .font(.headline)
                Text("All-properties totals are shown per property to avoid incorrect cross-currency sums.")
                  .foregroundStyle(.secondary)
              }
            }
            ForEach(properties.filter { !$0.isArchived }) { p in
              let totals = totalsForProperty(p, range: periodRange)
              totalsCard(title: "\(p.emoji) \(p.name)", totals: totals, currencyCode: p.currencyCode)
            }
          } else if let p = selectedProperty {
            let totals = totalsForProperty(p, range: periodRange)
            totalsCard(title: "\(p.emoji) \(p.name)", totals: totals, currencyCode: p.currencyCode)
          } else {
            let totals = totalsForAllPropertiesSingleCurrency(range: periodRange)
            let code = currencyCodesInUse.first ?? settings.reportingCurrencyCode
            totalsCard(title: "All Properties", totals: totals, currencyCode: code)
          }
        }
        .padding(16)
      }
      .navigationTitle("Totals")
      .toolbar {
        if scope != .allTime {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Today") { withAnimation { referenceDate = .now } }
          }
        }
      }
      .sheet(isPresented: $showPaywall) {
        V4PaywallView().environment(store)
      }
    }
  }

  // MARK: - Header Card

  private var headerCard: some View {
    V4Card {
      VStack(spacing: 12) {

        // Property picker
        HStack {
          Menu {
            Button("All Properties", systemImage: "square.grid.2x2") {
              prefs.selectedPropertyID = nil
            }
            Divider()
            ForEach(properties.filter { !$0.isArchived }) { p in
              Button("\(p.emoji) \(p.name)") { prefs.selectedPropertyID = p.id }
            }
          } label: {
            HStack(spacing: 8) {
              Text(selectedProperty?.emoji ?? "🏘️")
              Text(selectedProperty.map { $0.name } ?? String(localized: "All Properties"))
                .lineLimit(1)
              Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
          }
          Spacer()
        }

        // Scope picker — Yearly & All Time are Premium-only
        HStack(spacing: 0) {
          ForEach(TotalsScope.allCases, id: \.self) { s in
            let isSelected = scope == s
            let isPremiumScope = (s == .yearly || s == .allTime)
            let locked = isPremiumScope && !store.isPremium

            Button {
              if locked {
                showPaywall = true
              } else {
                prefs.totalsScopeRaw = s.rawValue
              }
            } label: {
              HStack(spacing: 4) {
                Text(s == .monthly ? "Month" : s == .yearly ? "Year" : "All Time")
                  .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if locked {
                  Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(V4Theme.Brand.primary)
                }
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 7)
              .background(
                isSelected
                  ? AnyShapeStyle(Color(.systemBackground))
                  : AnyShapeStyle(Color.clear)
              )
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
          }
        }
        .padding(3)
        .background(Color(.quaternarySystemFill),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))

        // Period navigation (hidden for All Time)
        if scope != .allTime {
          HStack {
            Button {
              withAnimation(.easeInOut(duration: 0.2)) { stepBack() }
            } label: {
              Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(periodLabel)
              .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
              withAnimation(.easeInOut(duration: 0.2)) { stepForward() }
            } label: {
              Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  // MARK: - Totals Card

  private func totalsCard(title: String,
                          totals: Totals,
                          currencyCode: String) -> some View {
    V4Card {
      VStack(alignment: .leading, spacing: 12) {
        Text(title)
          .font(.headline)

        metricRow(title: "Revenue",  value: V4Currency.format(totals.gross,    code: currencyCode), positive: true)
        metricRow(title: "Expenses", value: V4Currency.format(totals.expenses, code: currencyCode), positive: false)
        Divider().opacity(0.35)
        metricRow(title: "Net",      value: V4Currency.format(totals.net,      code: currencyCode), positive: totals.net >= 0)

        Divider().opacity(0.25)

        HStack {
          Text("Bookings").foregroundStyle(.secondary)
          Spacer()
          Text("\(totals.bookingsCount)").font(.headline)
        }

        HStack {
          Text("Nights").foregroundStyle(.secondary)
          Spacer()
          Text("\(totals.nights)").font(.headline)
        }

        if totals.bookingsCount > 0 {
          HStack {
            Text("Avg nightly rate").foregroundStyle(.secondary)
            Spacer()
            Text(V4Currency.format(totals.avgNightlyRate, code: currencyCode)).font(.headline)
          }
        }

        if totals.nights > 0 {
          HStack {
            Text("Occupancy").foregroundStyle(.secondary)
            Spacer()
            Text(totals.occupancyLabel).font(.headline)
          }
        }
      }
    }
  }

  private func metricRow(title: LocalizedStringKey, value: String, positive: Bool) -> some View {
    HStack {
      Text(title).foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.headline)
        .foregroundStyle(positive ? V4Theme.Brand.primary : .red)
    }
  }

  // MARK: - Math

  private struct Totals {
    var gross: Double
    var expenses: Double
    var net: Double
    var bookingsCount: Int
    var nights: Int
    var avgNightlyRate: Double
    var periodDays: Int       // total calendar days in the period (for occupancy)

    var occupancyLabel: String {
      guard periodDays > 0 else { return "—" }
      let pct = min(100, Int(round(Double(nights) / Double(periodDays) * 100)))
      return "\(pct)%"
    }
  }

  private func totalsForProperty(_ p: STProperty,
                                 range: (start: Date, end: Date)) -> Totals {
    let (start, end) = range
    let periodDays = daysBetween(start, end)
    let propBookings = bookings.filter { $0.property.id == p.id }

    var gross = 0.0
    var netBeforeExpenses = 0.0
    var nights = 0
    var totalNightly = 0.0
    var counted = 0

    for b in propBookings {
      // Only count nights that fall within [start, end)
      let s = max(b.checkIn, start)
      let e = min(b.checkOut, end)
      guard s < e else { continue }

      let n = V4Finance.nights(s, e)
      guard n > 0 else { continue }
      counted += 1
      nights += n
      totalNightly += Double(n) * b.nightlyRate

      let g = Double(n) * b.nightlyRate
      gross += g
      netBeforeExpenses += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: p.commissionPct)
    }

    let exp = expenses
      .filter { $0.property.id == p.id }
      .filter { $0.currencyCode == p.currencyCode }
      .filter { $0.date >= start && $0.date < end }
      .map(\.amount)
      .reduce(0, +)

    let avgRate = nights > 0 ? totalNightly / Double(nights) : 0
    return Totals(
      gross: gross,
      expenses: exp,
      net: netBeforeExpenses - exp,
      bookingsCount: counted,
      nights: nights,
      avgNightlyRate: avgRate,
      periodDays: periodDays
    )
  }

  private func totalsForAllPropertiesSingleCurrency(range: (start: Date, end: Date)) -> Totals {
    let (start, end) = range
    let periodDays = daysBetween(start, end)
    let activeProps = properties.filter { !$0.isArchived }

    var gross = 0.0
    var netBeforeExpenses = 0.0
    var nights = 0
    var totalNightly = 0.0
    var bookingsCount = 0

    for p in activeProps {
      let propBookings = bookings.filter { $0.property.id == p.id }
      for b in propBookings {
        let s = max(b.checkIn, start)
        let e = min(b.checkOut, end)
        guard s < e else { continue }

        let n = V4Finance.nights(s, e)
        guard n > 0 else { continue }
        bookingsCount += 1
        nights += n
        totalNightly += Double(n) * b.nightlyRate

        let g = Double(n) * b.nightlyRate
        gross += g
        netBeforeExpenses += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: p.commissionPct)
      }
    }

    let exp = expenses
      .filter { e in activeProps.contains(where: { $0.id == e.property.id }) }
      .filter { $0.date >= start && $0.date < end }
      .map(\.amount)
      .reduce(0, +)

    let avgRate = nights > 0 ? totalNightly / Double(nights) : 0
    return Totals(
      gross: gross,
      expenses: exp,
      net: netBeforeExpenses - exp,
      bookingsCount: bookingsCount,
      nights: nights,
      avgNightlyRate: avgRate,
      periodDays: periodDays
    )
  }

  /// Calendar days between two dates (safe for all-time = 0)
  private func daysBetween(_ a: Date, _ b: Date) -> Int {
    guard a > .distantPast, b < .distantFuture else { return 0 }
    return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
  }
}
