import SwiftUI
import SwiftData
import Charts

struct V4DashboardView: View {
  let prefs: V4AppPreferences

  @Environment(V4AppSettings.self)          private var settings
  @Environment(V4NotificationManager.self)  private var notifManager
  @Environment(STStoreManager.self)         private var store
  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STBooking.checkIn) private var bookings: [STBooking]
  @Query(sort: \STExpense.date, order: .reverse) private var expenses: [STExpense]

  @State private var monthAnchor: Date = Date()
  @State private var showPaywall = false

  private var selectedProperty: STProperty? {
    guard let id = prefs.selectedPropertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  private var hasMultiplePropertyCurrencies: Bool {
    let codes = Set(properties.map { $0.currencyCode })
    return codes.count > 1
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {

          headerCard

          // If user selected ONE property, we can compute a correct single-currency rollup.
          if let prop = selectedProperty {
            let totals = rollupForMonthSingleCurrency(month: monthAnchor, property: prop)

            monthCard(month: monthAnchor, occupancyPct: totals.occupancyPct)
            financeCard(gross: totals.gross, expenses: totals.expenses, net: totals.net, currencyCode: prop.currencyCode)
            ytdCard(property: prop)
            revenueChartCardOrGate(property: prop)
            mortgageCard(property: prop)
            recentExpensesCard(property: prop)

          } else {
            // All properties selected: if multiple currencies exist, do not sum across currencies.
            if hasMultiplePropertyCurrencies {
              if settings.showMultiCurrencyBanner {
                multiCurrencyNoticeCard()
              }
              perPropertyRollupsCard(month: monthAnchor)
              recentExpensesCard(property: nil)
            } else {
              // Single currency across all properties -> safe to sum.
              let code = properties.first?.currencyCode ?? "EUR"
              let totals = rollupForMonthAllPropertiesSingleCurrency(month: monthAnchor)

              monthCard(month: monthAnchor, occupancyPct: totals.occupancyPct)
              financeCard(gross: totals.gross, expenses: totals.expenses, net: totals.net, currencyCode: code)
              ytdCard(property: nil)
              revenueChartCardOrGate(property: nil)
              recentExpensesCard(property: nil)
            }
          }
        }
        .padding(16)
      }
      .navigationTitle("Dashboard")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Today") { monthAnchor = Date() }
        }
      }
    }
    // MARK: - Notification scheduling
    // Re-schedules notifications whenever the booking list or notice settings change.
    // initial: true means this fires immediately on first appearance (no separate .onAppear needed).
    .onChange(of: bookings, initial: true) { _, newBookings in
      notifManager.scheduleAll(bookings: newBookings, settings: settings)
    }
    .onChange(of: settings.notificationsEnabled) { _, _ in
      notifManager.scheduleAll(bookings: bookings, settings: settings)
    }
    .onChange(of: settings.arrivalNoticeHours) { _, _ in
      notifManager.scheduleAll(bookings: bookings, settings: settings)
    }
    .onChange(of: settings.departureNoticeHours) { _, _ in
      notifManager.scheduleAll(bookings: bookings, settings: settings)
    }
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
  }

  // MARK: - Chart Gate

  @ViewBuilder
  private func revenueChartCardOrGate(property: STProperty?) -> some View {
    if store.isPremium {
      revenueChartCard(property: property)
    } else {
      revenueChartCard(property: property)
        .blur(radius: 8)
        .allowsHitTesting(false)
        .overlay(alignment: .center) {
          VStack(spacing: 10) {
            Image(systemName: "lock.fill")
              .font(.title2)
              .foregroundStyle(.white)
            Text("Revenue Charts")
              .font(.headline)
              .foregroundStyle(.white)
            Button {
              showPaywall = true
            } label: {
              Text("Premium")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(V4Theme.Brand.primary, in: Capsule())
            }
          }
          .padding(20)
          .background(.ultraThinMaterial,
                      in: RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous))
          .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { showPaywall = true }
    }
  }

  // MARK: - Header

  private var headerCard: some View {
    V4Card {
      VStack(spacing: 12) {

        HStack {
          Menu {
            Button("All Properties", systemImage: "square.grid.2x2") {
              prefs.selectedPropertyID = nil
            }
            Divider()
            ForEach(properties) { p in
              Button("\(p.emoji) \(p.name)") {
                prefs.selectedPropertyID = p.id
              }
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

        HStack {
          Button("Prev") {
            monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
          }
          Spacer()
          Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
            .font(.headline)
          Spacer()
          Button("Next") {
            monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
          }
        }
      }
    }
  }

  // MARK: - Cards

  private func monthCard(month: Date, occupancyPct: Double) -> some View {
    V4Card {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Month")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(month.formatted(.dateTime.month(.wide).year()))
            .font(.title3.weight(.semibold))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Text("Occupancy")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(Int(round(occupancyPct)))%")
            .font(.title3.weight(.semibold))
            .foregroundStyle(V4Theme.Brand.primary)
        }
      }
    }
  }

  private func financeCard(gross: Double, expenses: Double, net: Double, currencyCode: String) -> some View {
    V4Card {
      VStack(spacing: 12) {
        metricRow(title: "Revenue", value: V4Currency.format(gross, code: currencyCode), positive: true)
        metricRow(title: "Expenses", value: V4Currency.format(expenses, code: currencyCode), positive: false)
        Divider().opacity(0.4)
        metricRow(title: "Net", value: V4Currency.format(net, code: currencyCode), positive: net >= 0)
      }
    }
  }

  // MARK: - Revenue Chart Card

  private struct MonthBar: Identifiable {
    let id = UUID()
    let month: Date
    let gross: Double
  }

  private func last6MonthsBars(property: STProperty?) -> [MonthBar] {
    let cal = Calendar.current
    return (0..<6).reversed().compactMap { offset -> MonthBar? in
      guard let anchor = cal.date(byAdding: .month, value: -offset, to: monthAnchor),
            let start  = cal.date(from: cal.dateComponents([.year, .month], from: anchor)),
            let end    = cal.date(byAdding: .month, value: 1, to: start)
      else { return nil }

      var gross = 0.0
      let source = property.map { p in bookings.filter { $0.property.id == p.id } } ?? Array(bookings)
      for b in source {
        let s = max(b.checkIn, start); let e = min(b.checkOut, end)
        if s < e { gross += Double(V4Finance.nights(s, e)) * b.nightlyRate }
      }
      return MonthBar(month: start, gross: gross)
    }
  }

  private func revenueChartCard(property: STProperty?) -> some View {
    let bars = last6MonthsBars(property: property)
    let currencyCode = property?.currencyCode ?? properties.first?.currencyCode ?? "EUR"
    let maxVal = bars.map(\.gross).max() ?? 1

    return V4Card {
      VStack(alignment: .leading, spacing: 12) {
        Text("Revenue — Last 6 Months")
          .font(.headline)

        Chart(bars) { bar in
          BarMark(
            x: .value("Month", bar.month, unit: .month),
            y: .value("Revenue", bar.gross)
          )
          .foregroundStyle(V4Theme.Brand.primary.gradient)
          .cornerRadius(4)
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .month)) { val in
            AxisValueLabel(format: .dateTime.month(.abbreviated))
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading) { val in
            AxisValueLabel {
              if let d = val.as(Double.self) {
                Text(V4Currency.format(d, code: currencyCode))
                  .font(.system(size: 9))
              }
            }
          }
        }
        .chartYScale(domain: 0...(maxVal * 1.2 + 1))
        .frame(height: 160)
      }
    }
  }

  private func ytdCard(property: STProperty?) -> some View {
    let cal = Calendar.current
    let year = cal.component(.year, from: monthAnchor)
    let ytd: (gross: Double, net: Double)
    let currencyCode: String

    if let prop = property {
      ytd = ytdRollupSingleProperty(year: year, property: prop)
      currencyCode = prop.currencyCode
    } else {
      ytd = ytdRollupAllPropertiesSingleCurrency(year: year)
      currencyCode = properties.first?.currencyCode ?? "EUR"
    }

    return V4Card {
      VStack(spacing: 12) {
        HStack {
          Text("\(year) Year to Date")
            .font(.headline)
          Spacer()
        }
        metricRow(title: "Revenue", value: V4Currency.format(ytd.gross, code: currencyCode), positive: true)
        metricRow(title: "Net", value: V4Currency.format(ytd.net, code: currencyCode), positive: ytd.net >= 0)
      }
    }
  }

  private func mortgageCard(property: STProperty) -> some View {
    V4Card {
      VStack(alignment: .leading, spacing: 10) {
        Text("Selected property")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Circle()
            .fill(V4Color.hex(property.colorHex))
            .frame(width: 10, height: 10)

          Text("\(property.emoji) \(property.name)")
            .font(.headline)

          Spacer()
        }

        let mortgage = property.trackMortgage
          ? V4Finance.mortgageMonthly(price: property.purchasePrice, apr: property.mortgageAPR, years: property.mortgageYears)
          : 0

        if property.trackMortgage {
          metricRow(
            title: "Mortgage (monthly)",
            value: V4Currency.format(mortgage, code: property.currencyCode),
            positive: false
          )
        }
      }
    }
  }

  private func recentExpensesCard(property: STProperty?) -> some View {
    V4Card {
      VStack(alignment: .leading, spacing: 10) {
        Text("Recent expenses")
          .font(.headline)

        let recent = recentExpenses(limit: 5, property: property)

        if recent.isEmpty {
          Text("No expenses yet.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(recent, id: \.id) { e in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(e.category.rawValue.capitalized)
                  .font(.subheadline.weight(.semibold))
                if let note = e.note, !note.isEmpty {
                  Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              Spacer()
              Text(V4Currency.format(e.amount, code: e.currencyCode))
                .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 4)
          }
        }
      }
    }
  }

  private func multiCurrencyNoticeCard() -> some View {
    V4Card {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          Text("Financials")
            .font(.headline)
          Spacer()
          Button {
            withAnimation(.easeOut(duration: 0.2)) {
              settings.showMultiCurrencyBanner = false
            }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
              .imageScale(.medium)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Dismiss")
        }
        Text("Multiple base currencies detected. Totals are shown per property to avoid incorrect cross-currency sums.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func perPropertyRollupsCard(month: Date) -> some View {
    V4Card {
      VStack(alignment: .leading, spacing: 12) {
        Text("This month by property")
          .font(.headline)

        ForEach(properties.filter { !$0.isArchived }, id: \.id) { p in
          let t = rollupForMonthSingleCurrency(month: month, property: p)

          VStack(spacing: 6) {
            HStack {
              Text("\(p.emoji) \(p.name)")
                .font(.subheadline.weight(.semibold))
              Spacer()
              Text(V4Currency.format(t.net, code: p.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(t.net >= 0 ? V4Theme.Brand.primary : .red)
            }

            HStack {
              Text("Revenue: \(V4Currency.format(t.gross, code: p.currencyCode))")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Text("Expenses: \(V4Currency.format(t.expenses, code: p.currencyCode))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Divider().opacity(0.35)
        }
      }
    }
  }

  // MARK: - Helpers

  private func metricRow(title: LocalizedStringKey, value: String, positive: Bool) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.headline)
        .foregroundStyle(positive ? V4Theme.Brand.primary : .red)
    }
  }

  private func recentExpenses(limit: Int, property: STProperty?) -> [STExpense] {
    let filtered = expenses.filter { e in
      guard let p = property else { return true }
      return e.property.id == p.id
    }
    return Array(filtered.prefix(limit))
  }

  private func rollupForMonthSingleCurrency(month: Date, property: STProperty) -> (gross: Double, expenses: Double, net: Double, occupancyPct: Double) {
    let cal = Calendar.current
    let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
    let end = cal.date(byAdding: .month, value: 1, to: start)!

    var gross = 0.0
    var netBeforeExpenses = 0.0
    var occupiedNights = 0.0
    let daysInMonth = Double(cal.range(of: .day, in: .month, for: month)?.count ?? 30)

    let propBookings = bookings.filter { $0.property.id == property.id }
    for b in propBookings {
      let s = max(b.checkIn, start)
      let e = min(b.checkOut, end)
      if s < e {
        let nights = Double(V4Finance.nights(s, e))
        let g = nights * b.nightlyRate
        gross += g
        netBeforeExpenses += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: property.commissionPct)
        occupiedNights += nights
      }
    }

    // IMPORTANT: do not sum expenses across currencies here.
    // We only include expenses already stored in the same currency as the property.
    let exp = expenses
      .filter { $0.property.id == property.id }
      .filter { $0.date >= start && $0.date < end }
      .filter { $0.currencyCode == property.currencyCode }
      .map(\.amount)
      .reduce(0, +)

    // Include active recurring bills (assumed to be in property currency).
    let recurringTotal = property.recurringBills
      .filter { $0.isActive }
      .map(\.amount)
      .reduce(0, +)
    let totalExpenses = exp + recurringTotal

    let occ = daysInMonth > 0 ? (occupiedNights / daysInMonth * 100) : 0
    let net = netBeforeExpenses - totalExpenses
    return (gross, totalExpenses, net, occ)
  }

  private func ytdRollupSingleProperty(year: Int, property: STProperty) -> (gross: Double, net: Double) {
    let cal = Calendar.current
    var comps = DateComponents(); comps.year = year; comps.month = 1; comps.day = 1
    guard let start = cal.date(from: comps),
          let end   = cal.date(byAdding: .year, value: 1, to: start) else { return (0, 0) }

    var gross = 0.0
    var net   = 0.0
    for b in bookings where b.property.id == property.id {
      let s = max(b.checkIn, start)
      let e = min(b.checkOut, end)
      if s < e {
        let nights = Double(V4Finance.nights(s, e))
        let g = nights * b.nightlyRate
        gross += g
        net   += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: property.commissionPct)
      }
    }
    let exp = expenses
      .filter { $0.property.id == property.id && $0.date >= start && $0.date < end }
      .filter { $0.currencyCode == property.currencyCode }
      .map(\.amount).reduce(0, +)
    let recurring = property.recurringBills.filter(\.isActive).map(\.amount).reduce(0, +) * 12
    return (gross, net - exp - recurring)
  }

  private func ytdRollupAllPropertiesSingleCurrency(year: Int) -> (gross: Double, net: Double) {
    let cal = Calendar.current
    var comps = DateComponents(); comps.year = year; comps.month = 1; comps.day = 1
    guard let start = cal.date(from: comps),
          let end   = cal.date(byAdding: .year, value: 1, to: start) else { return (0, 0) }

    var gross = 0.0
    var net   = 0.0
    for p in properties {
      for b in bookings where b.property.id == p.id {
        let s = max(b.checkIn, start)
        let e = min(b.checkOut, end)
        if s < e {
          let nights = Double(V4Finance.nights(s, e))
          let g = nights * b.nightlyRate
          gross += g
          net   += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: p.commissionPct)
        }
      }
    }
    let exp = expenses.filter { $0.date >= start && $0.date < end }.map(\.amount).reduce(0, +)
    return (gross, net - exp)
  }

  private func rollupForMonthAllPropertiesSingleCurrency(month: Date) -> (gross: Double, expenses: Double, net: Double, occupancyPct: Double) {
    let cal = Calendar.current
    let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
    let end = cal.date(byAdding: .month, value: 1, to: start)!

    var gross = 0.0
    var netBeforeExpenses = 0.0
    var occupiedNights = 0.0
    var totalDays = 0.0

    for p in properties {
      let daysInMonth = Double(cal.range(of: .day, in: .month, for: month)?.count ?? 30)
      totalDays += daysInMonth

      let propBookings = bookings.filter { $0.property.id == p.id }
      for b in propBookings {
        let s = max(b.checkIn, start)
        let e = min(b.checkOut, end)
        if s < e {
          let nights = Double(V4Finance.nights(s, e))
          let g = nights * b.nightlyRate
          gross += g
          netBeforeExpenses += V4Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: p.commissionPct)
          occupiedNights += nights
        }
      }
    }

    // When all properties share a single currency, we can safely sum all expenses.
    let exp = expenses
      .filter { $0.date >= start && $0.date < end }
      .map(\.amount)
      .reduce(0, +)

    let occ = totalDays > 0 ? (occupiedNights / totalDays * 100) : 0
    let net = netBeforeExpenses - exp
    return (gross, exp, net, occ)
  }
}
