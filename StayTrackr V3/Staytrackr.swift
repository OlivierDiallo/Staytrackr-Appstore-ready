//
//  StayTrackrV3.swift
//  Single-file SwiftUI demo (iOS 17+)
//

import SwiftUI
import Observation

// MARK: - V3 Namespace

enum V3 {

  // MARK: - Helpers

  static func color(hex: String) -> Color {
    let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r = Double((v >> 16) & 0xFF) / 255
    let g = Double((v >> 8)  & 0xFF) / 255
    let b = Double(v & 0xFF)        / 255
    return Color(red: r, green: g, blue: b)
  }

  static func currency(_ x: Double, code: String = "EUR") -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .currency
    nf.currencyCode = code
    return nf.string(from: NSNumber(value: x)) ?? "€\(x)"
  }

  static func startOfMonth(_ date: Date, _ cal: Calendar = .current) -> Date {
    cal.date(from: cal.dateComponents([.year, .month], from: date))!
  }

  static func endOfMonth(_ date: Date, _ cal: Calendar = .current) -> Date {
    let s = startOfMonth(date, cal)
    return cal.date(byAdding: DateComponents(month: 1, day: -1), to: s)!
  }

  static func startOfWeek(_ date: Date, _ cal: Calendar = .current) -> Date {
    cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
  }

  // Property calendar colors (like iOS Calendar)
  struct CalendarColorOption: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
  }

  static let calendarColorOptions: [CalendarColorOption] = [
    .init(name: "Red",     hex: "#FF3B30"),
    .init(name: "Orange",  hex: "#FF9500"),
    .init(name: "Yellow",  hex: "#FFCC00"),
    .init(name: "Green",   hex: "#34C759"),
    .init(name: "Blue",    hex: "#007AFF"),
    .init(name: "Purple",  hex: "#AF52DE"),
    .init(name: "Brown",   hex: "#A2845E")
  ]

  static func autoPropertyColor(existing: [String]) -> String {
    let used = Set(existing)
    if let first = calendarColorOptions.first(where: { !used.contains($0.hex) }) {
      return first.hex
    }
    // if we run out, just cycle
    return calendarColorOptions[existing.count % calendarColorOptions.count].hex
  }

  // MARK: - Theme

  enum Brand {
    static let primary    = V3.color(hex: "#1FB86E")
    static let card       = Color(uiColor: .secondarySystemBackground)
    static let arrivalDot = Color.blue
    static let departDot  = Color.orange
    static let occupiedBG = Color.green.opacity(0.16)
    static let warning    = Color.red
  }

  // MARK: - Models

  struct Customer: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var email: String? = nil
    var phone: String? = nil
  }

  struct Booking: Identifiable, Hashable {
    var id = UUID()
    var propertyID: UUID
    var customerID: UUID
    var checkIn: Date
    var checkOut: Date
    var nightlyRate: Double
    var platformFeePct: Double
    var isPaid: Bool = false
  }

  enum ExpenseCategory: String, CaseIterable, Identifiable {
    case cleaning, repairs, utilities, management, supplies, other
    var id: String { rawValue }
  }

  struct Expense: Identifiable, Hashable {
    var id = UUID()
    var propertyID: UUID
    var date: Date
    var amount: Double
    var category: ExpenseCategory
    var note: String? = nil
  }

  struct Property: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var purchasePrice: Double
    var mortgageAPR: Double
    var mortgageYears: Int
    var commissionPct: Double
    var emoji: String = "🏠"
    var colorHex: String = "#34C759"
    var isArchived: Bool = false
    var trackMortgage: Bool = true
  }

  struct RecurringBill: Identifiable, Hashable {
    var id = UUID()
    var propertyID: UUID
    var name: String
    var amount: Double
    var category: ExpenseCategory
    var dayOfMonth: Int
    var note: String? = nil
    var isActive: Bool = true
  }

  // Scope for totals tab (must be before Finance.range)
  enum TotalsScope: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    var id: String { rawValue }
  }

  // MARK: - App State

  @Observable
  final class AppState {
    var properties: [Property] = []
    var customers: [Customer] = []
    var bookings: [Booking] = []
    var expenses: [Expense] = []
    var recurring: [RecurringBill] = []
    var turnoverBufferHours: Int = 0 // >0 => cleaning buffer

    var activeProperties: [Property] {
      properties.filter { !$0.isArchived }
    }

    init() { seed() }

    private func seed() {
      let p1 = Property(
        name: "Costa Adeje",
        purchasePrice: 240_000,
        mortgageAPR: 0.035,
        mortgageYears: 20,
        commissionPct: 0.10,
        emoji: "🏖️",
        colorHex: calendarColorOptions[3].hex,
        isArchived: false,
        trackMortgage: true
      )
      let p2 = Property(
        name: "Prague Old Town",
        purchasePrice: 310_000,
        mortgageAPR: 0.039,
        mortgageYears: 25,
        commissionPct: 0.12,
        emoji: "🏙️",
        colorHex: calendarColorOptions[4].hex,
        isArchived: false,
        trackMortgage: true
      )
      properties = [p1, p2]

      let c1 = Customer(name: "Jason Smith", email: "jason@example.com", phone: "+44 123 456 789")
      let c2 = Customer(name: "Maria Gomez", email: "maria@example.com", phone: "+34 987 654 321")
      customers = [c1, c2]

      let now = Date()
      let cal = Calendar.current
      bookings = [
        Booking(propertyID: p1.id, customerID: c1.id,
                checkIn: cal.date(byAdding: .day, value: 2, to: now)!,
                checkOut: cal.date(byAdding: .day, value: 6, to: now)!,
                nightlyRate: 120, platformFeePct: 0.14, isPaid: true),
        Booking(propertyID: p1.id, customerID: c2.id,
                checkIn: cal.date(byAdding: .day, value: 6, to: now)!,
                checkOut: cal.date(byAdding: .day, value: 9, to: now)!,
                nightlyRate: 140, platformFeePct: 0.14, isPaid: false),
        Booking(propertyID: p2.id, customerID: c2.id,
                checkIn: cal.date(byAdding: .day, value: 12, to: now)!,
                checkOut: cal.date(byAdding: .day, value: 15, to: now)!,
                nightlyRate: 110, platformFeePct: 0.12, isPaid: false)
      ]

      expenses = [
        Expense(propertyID: p1.id, date: now, amount: 60,  category: .cleaning,  note: "Turnover"),
        Expense(propertyID: p1.id, date: now, amount: 120, category: .utilities, note: "Electricity"),
        Expense(propertyID: p2.id, date: now, amount: 85,  category: .repairs,   note: "Door handle")
      ]

      recurring = [
        RecurringBill(propertyID: p1.id, name: "Electricity", amount: 120, category: .utilities, dayOfMonth: 10),
        RecurringBill(propertyID: p1.id, name: "Water",       amount: 35,  category: .utilities, dayOfMonth: 15),
        RecurringBill(propertyID: p2.id, name: "Internet",    amount: 25,  category: .utilities, dayOfMonth: 12, note: "Fiber")
      ]
    }

    // Lookups
    func bookings(for propertyID: UUID) -> [Booking] { bookings.filter { $0.propertyID == propertyID } }
    func expenses(for propertyID: UUID) -> [Expense] { expenses.filter { $0.propertyID == propertyID } }
    func recurring(for propertyID: UUID) -> [RecurringBill] { recurring.filter { $0.propertyID == propertyID } }
    func customer(by id: UUID) -> Customer? { customers.first(where: { $0.id == id }) }
    func totalBookings(for customerID: UUID) -> Int { bookings.filter { $0.customerID == customerID }.count }

    // Mutations

    func addExpense(propertyID: UUID, amount: Double, category: ExpenseCategory, note: String?, date: Date = Date()) {
      expenses.append(Expense(propertyID: propertyID, date: date, amount: amount, category: category, note: note))
    }

    func updateExpense(_ e: Expense, amount: Double, category: ExpenseCategory, note: String?, date: Date) {
      if let i = expenses.firstIndex(where: { $0.id == e.id }) {
        expenses[i].amount = amount
        expenses[i].category = category
        expenses[i].note = note
        expenses[i].date = date
      }
    }

    func deleteExpense(_ e: Expense) {
      expenses.removeAll { $0.id == e.id }
    }

    func addCustomer(name: String, email: String?, phone: String?) -> Customer {
      let c = Customer(name: name, email: email, phone: phone)
      customers.append(c)
      return c
    }

    func updateCustomer(_ updated: Customer) {
      if let idx = customers.firstIndex(where: { $0.id == updated.id }) {
        customers[idx] = updated
      }
    }

    func addBooking(_ b: Booking) {
      bookings.append(b)
    }

    func updateBooking(_ updated: Booking) {
      if let idx = bookings.firstIndex(where: { $0.id == updated.id }) {
        bookings[idx] = updated
      }
    }

    func deleteBooking(_ b: Booking) {
      bookings.removeAll { $0.id == b.id }
    }

    func addRecurring(propertyID: UUID, name: String, amount: Double, category: ExpenseCategory, dayOfMonth: Int, note: String?, isActive: Bool) {
      recurring.append(RecurringBill(propertyID: propertyID, name: name, amount: amount, category: category, dayOfMonth: dayOfMonth, note: note, isActive: isActive))
    }

    func updateRecurring(_ r: RecurringBill) {
      if let i = recurring.firstIndex(where: { $0.id == r.id }) { recurring[i] = r }
    }

    func deleteRecurring(_ r: RecurringBill) {
      recurring.removeAll { $0.id == r.id }
    }

    func postRecurringForCurrentMonth(propertyID: UUID) {
      let cal = Calendar.current
      let now = Date()
      let start = V3.startOfMonth(now, cal)
      let lastDay = cal.range(of: .day, in: .month, for: now)!.count
      for bill in recurring(for: propertyID).filter({ $0.isActive }) {
        let day = min(max(1, bill.dayOfMonth), lastDay)
        let due = cal.date(byAdding: .day, value: day - 1, to: start)!
        let exists = expenses.contains {
          $0.propertyID == propertyID &&
          $0.category == bill.category &&
          cal.isDate($0.date, inSameDayAs: due) &&
          abs($0.amount - bill.amount) < 0.01
        }
        if !exists {
          addExpense(propertyID: propertyID, amount: bill.amount, category: bill.category, note: bill.name, date: due)
        }
      }
    }

    // Property management

    @discardableResult
    func addProperty(name: String,
                     emoji: String,
                     colorHex: String?,
                     purchasePrice: Double,
                     mortgageAPR: Double,
                     mortgageYears: Int,
                     commissionPct: Double,
                     trackMortgage: Bool) -> Property {

      let chosenColor = colorHex ?? V3.autoPropertyColor(existing: properties.map(\.colorHex))
      let p = Property(
        name: name,
        purchasePrice: purchasePrice,
        mortgageAPR: mortgageAPR,
        mortgageYears: mortgageYears,
        commissionPct: commissionPct,
        emoji: emoji.isEmpty ? "🏠" : emoji,
        colorHex: chosenColor,
        isArchived: false,
        trackMortgage: trackMortgage
      )
      properties.append(p)
      return p
    }

    func updateProperty(_ updated: Property) {
      if let idx = properties.firstIndex(where: { $0.id == updated.id }) {
        properties[idx] = updated
      }
    }

    func archiveProperty(_ p: Property) {
      if let idx = properties.firstIndex(where: { $0.id == p.id }) {
        properties[idx].isArchived = true
      }
    }

    func unarchiveProperty(_ p: Property) {
      if let idx = properties.firstIndex(where: { $0.id == p.id }) {
        properties[idx].isArchived = false
      }
    }

    func deleteProperty(_ p: Property) {
      properties.removeAll { $0.id == p.id }
      bookings.removeAll { $0.propertyID == p.id }
      expenses.removeAll { $0.propertyID == p.id }
      recurring.removeAll { $0.propertyID == p.id }
    }
  }

  // MARK: - Finance

  enum Finance {
    static func nights(_ a: Date, _ b: Date) -> Int {
      max(0, Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    static func netRevenue(gross: Double, platform pct: Double, commission hostPct: Double) -> Double {
      (gross * (1 - pct)) * (1 - hostPct)
    }

    static func monthRollup(property: Property, month: Date, bookings: [Booking], expenses: [Expense]) -> (gross: Double, net: Double, exp: Double, occ: Double) {
      let cal = Calendar.current
      let start = V3.startOfMonth(month, cal)
      let end   = cal.date(byAdding: .month, value: 1, to: start)!
      let days  = Double(cal.range(of: .day, in: .month, for: month)!.count)

      let propBookings = bookings.filter { $0.propertyID == property.id }
      var occupied = 0.0, gross = 0.0, net = 0.0
      for b in propBookings {
        let s = max(b.checkIn, start), e = min(b.checkOut, end)
        if s < e {
          let n = Double(nights(s, e))
          let g = n * b.nightlyRate
          gross += g
          net   += netRevenue(gross: g, platform: b.platformFeePct, commission: property.commissionPct)
          occupied += n
        }
      }
      let exp = expenses
        .filter { $0.propertyID == property.id && $0.date >= start && $0.date < end }
        .map(\.amount).reduce(0,+)
      return (gross, net - exp, exp, occupied / days * 100)
    }

    static func range(for scope: TotalsScope, around date: Date) -> (Date, Date) {
      let cal = Calendar.current
      switch scope {
      case .weekly:
        let start = V3.startOfWeek(date, cal)
        return (start, cal.date(byAdding: .day, value: 7, to: start)!)
      case .monthly:
        let start = V3.startOfMonth(date, cal)
        return (start, cal.date(byAdding: .month, value: 1, to: start)!)
      case .yearly:
        let start = cal.date(from: DateComponents(year: cal.component(.year, from: date)))!
        return (start, cal.date(byAdding: .year, value: 1, to: start)!)
      }
    }

    // Mortgage amortization
    static func mortgageMonthly(price: Double, apr: Double, years: Int) -> Double {
      let r = apr / 12
      let n = Double(years * 12)
      guard r > 0, n > 0 else { return n > 0 ? price / n : 0 }
      return price * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
    }

    // Recurring bills monthly total
    static func recurringMonthlyTotal(for property: Property, in app: AppState) -> Double {
      app.recurring(for: property.id)
        .filter { $0.isActive }
        .map(\.amount)
        .reduce(0,+)
    }
  }

  // MARK: - Shared UI

  struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
      content()
        .padding(16)
        .background(Brand.card)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
  }

  struct MetricChip: View {
    var title: String
    var value: String
    var positive: Bool = true
    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.system(.title3, weight: .bold))
          .foregroundStyle(positive ? Brand.primary : .red)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Calendar colors (for bookings, per customer)

  private static let bookingPalette: [Color] = [
    V3.color(hex:"#4F46E5"), V3.color(hex:"#06B6D4"), V3.color(hex:"#22C55E"),
    V3.color(hex:"#F59E0B"), V3.color(hex:"#EF4444"), V3.color(hex:"#8B5CF6"),
    V3.color(hex:"#14B8A6"), V3.color(hex:"#E11D48"), V3.color(hex:"#0EA5E9"),
    V3.color(hex:"#84CC16"), V3.color(hex:"#D946EF")
  ]

  private static func colorForCustomer(_ customerID: UUID, avoidAdjacent: Bool = false, previousIndex: Int? = nil) -> (color: Color, index: Int) {
    var idx = Int(abs(customerID.hashValue)) % bookingPalette.count
    if avoidAdjacent, let p = previousIndex, p == idx { idx = (idx + 1) % bookingPalette.count }
    return (bookingPalette[idx], idx)
  }

  // MARK: - Calendar Day Cell (monthly grid)

  struct DayCell2: View {
    let date: Date
    let month: Date
    let items: [BarFragment]
    let showDots: (arrival: Bool, departure: Bool)

    struct BarFragment: Identifiable {
      var id = UUID()
      var color: Color
      var isStart: Bool
      var isEnd: Bool
      var label: String
      var isPaid: Bool
    }

    var body: some View {
      VStack(spacing: 2) {
        Text("\(Calendar.current.component(.day, from: date))")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 2) {
          ForEach(items.prefix(3)) { frag in
            RoundedRectangle(cornerRadius: 6)
              .fill(frag.color.opacity(0.18))
              .overlay(
                HStack(spacing: 4) {
                  if frag.isStart {
                    Circle().fill(frag.color).frame(width: 6, height: 6)
                  }
                  Text(frag.label)
                    .lineLimit(1)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(frag.color)
                  if frag.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                      .font(.caption2)
                      .foregroundStyle(.green)
                  }
                  Spacer(minLength: 0)
                  if frag.isEnd {
                    Circle().fill(frag.color).frame(width: 6, height: 6)
                  }
                }
                .padding(.horizontal, 6)
              )
              .frame(height: 16)
          }
        }
        .frame(maxWidth: .infinity)

        HStack(spacing: 4) {
          if showDots.arrival   { Circle().fill(Brand.arrivalDot).frame(width: 5, height: 5) }
          if showDots.departure { Circle().fill(Brand.departDot).frame(width: 5, height: 5) }
          Spacer()
        }
      }
      .padding(6)
      .background(items.isEmpty ? Color.clear : Brand.occupiedBG)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(items.isEmpty ? Color.gray.opacity(0.15) : Brand.primary.opacity(0.6), lineWidth: items.isEmpty ? 1 : 1.2)
      )
      .cornerRadius(10)
    }
  }

  // MARK: - Month Grid

  struct MonthGrid: View {
    @Environment(V3.AppState.self) private var app
    let month: Date
    let property: Property? // nil => all properties

    @State private var tappedDate: Date? = nil

    var body: some View {
      let cal = Calendar.current
      let monthStart = V3.startOfMonth(month, cal)
      let dayCount   = cal.range(of: .day, in: .month, for: month)!.count
      let days       = (0..<dayCount).map { cal.date(byAdding: .day, value: $0, to: monthStart)! }

      let visibleBookings: [Booking] = {
        if let p = property { return app.bookings(for: p.id) }
        return app.bookings
      }()

      // Fragments per day
      let fragments: [Date: [DayCell2.BarFragment]] = {
        var map: [Date: [DayCell2.BarFragment]] = [:]
        var previousColorIndexByDay: [Date: Int] = [:]

        let monthEndNext = cal.date(byAdding: .day, value: 1, to: V3.endOfMonth(month, cal))!

        for b in visibleBookings {
          let start = max(monthStart, cal.startOfDay(for: b.checkIn))
          let end   = min(cal.startOfDay(for: b.checkOut), monthEndNext)
          guard start < end else { continue }

          var d = start
          while d < end {
            let day = cal.startOfDay(for: d)

            let pair = V3.colorForCustomer(b.customerID, avoidAdjacent: true, previousIndex: previousColorIndexByDay[day])
            previousColorIndexByDay[day] = pair.index

            let isStart = cal.isDate(day, inSameDayAs: start)
            let lastDay = cal.date(byAdding: .day, value: -1, to: end)!
            let isEnd   = cal.isDate(day, inSameDayAs: lastDay)

            let guest = app.customer(by: b.customerID)?.name.split(separator: " ").first.map(String.init) ?? "Guest"
            let label: String = {
              if property == nil {
                let emoji = app.properties.first(where: { $0.id == b.propertyID })?.emoji ?? ""
                return "\(guest) · \(emoji)"
              } else { return guest }
            }()

            let frag = DayCell2.BarFragment(
              color: pair.color,
              isStart: isStart,
              isEnd: isEnd,
              label: label,
              isPaid: b.isPaid
            )
            map[day, default: []].append(frag)

            d = cal.date(byAdding: .day, value: 1, to: day)!
          }
        }
        return map
      }()

      func dots(for day: Date) -> (arrival: Bool, departure: Bool) {
        let a = visibleBookings.contains { cal.isDate($0.checkIn,  inSameDayAs: day) }
        let d = visibleBookings.contains { cal.isDate($0.checkOut, inSameDayAs: day) }
        return (a, d)
      }

      return VStack(spacing: 8) {
        HStack {
          ForEach(cal.shortWeekdaySymbols, id: \.self) {
            Text($0).font(.caption).frame(maxWidth: .infinity)
          }
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
          ForEach(days, id: \.self) { day in
            DayCell2(date: day, month: month, items: fragments[day] ?? [], showDots: dots(for: day))
              .onTapGesture { tappedDate = day }
          }
        }
      }
      .sheet(item: Binding(
        get: { tappedDate.map(IdentifiedDate.init(date:)) },
        set: { tappedDate = $0?.date })
      ) { wrapper in
        DayDetailSheet(date: wrapper.date, property: property)
          .environment(app)
      }
    }

    struct IdentifiedDate: Identifiable { let id = UUID(); let date: Date }
  }

  // MARK: - Day Detail + Manage Booking

  struct DayDetailSheet: View {
    @Environment(V3.AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let property: Property?
    @State private var selectedBooking: Booking? = nil

    var filtered: [Booking] {
      let target = Calendar.current.startOfDay(for: date)
      return (property == nil ? app.bookings : app.bookings(for: property!.id))
        .filter {
          target >= Calendar.current.startOfDay(for: $0.checkIn) &&
          target <  Calendar.current.startOfDay(for: $0.checkOut)
        }
        .sorted { $0.checkIn < $1.checkIn }
    }

    var body: some View {
      NavigationStack {
        List {
          Section(date.formatted(date: .complete, time: .omitted)) {
            ForEach(filtered) { b in
              Button {
                selectedBooking = b
              } label: {
                let cust = app.customer(by: b.customerID)?.name ?? "Guest"
                let propEmoji = app.properties.first(where: { $0.id == b.propertyID })?.emoji ?? ""
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Text("\(cust) \(propEmoji)").font(.headline)
                    Spacer()
                    if b.isPaid {
                      Text("Paid").font(.caption2).foregroundStyle(.green)
                    } else {
                      Text("Unpaid").font(.caption2).foregroundStyle(.red)
                    }
                  }
                  Text("Check-in \(b.checkIn.formatted(date:.abbreviated,time:.omitted)) • Check-out \(b.checkOut.formatted(date:.abbreviated,time:.omitted))")
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        .navigationTitle("Day")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
        .sheet(item: $selectedBooking) { booking in
          EditBookingSheet(booking: booking, onFinished: { dismiss() })
            .environment(app)
        }
      }
    }
  }

  // MARK: - Overlap guard

  static func overlappingBookings(in app: AppState,
                                  propertyID: UUID,
                                  checkIn: Date,
                                  checkOut: Date,
                                  ignore bookingID: UUID? = nil,
                                  bufferHours: Int) -> [Booking] {
    let buf = TimeInterval(bufferHours * 3600)
    let newStart = checkIn.addingTimeInterval(-buf)
    let newEnd   = checkOut.addingTimeInterval(buf)
    return app.bookings(for: propertyID).filter { existing in
      if let id = bookingID, existing.id == id { return false }
      return newStart < existing.checkOut && newEnd > existing.checkIn &&
             !(checkIn == existing.checkOut && bufferHours == 0)
    }
  }

  // MARK: - Dashboard

  enum ScopeChip: String, CaseIterable, Identifiable {
    case weekly = "W", monthly = "M", quarterly = "Q", yearly = "Y"
    var id: String { rawValue }
  }

  struct DashboardView: View {
    @Environment(V3.AppState.self) private var app
    @State private var month = Date()
    @State private var selectedPropertyID: UUID? = nil
    @State private var scope: ScopeChip = .monthly

    private var selectedProperty: Property? {
      app.activeProperties.first(where: { $0.id == selectedPropertyID }) ?? app.activeProperties.first
    }

    private func totalsForMonth() -> (gross: Double, net: Double, exp: Double, occ: Double) {
      if let p = selectedProperty {
        let r = Finance.monthRollup(property: p, month: month, bookings: app.bookings, expenses: app.expenses)
        return (r.gross, r.net, r.exp, r.occ)
      } else {
        var g = 0.0, n = 0.0, e = 0.0, o = 0.0
        for p in app.activeProperties {
          let r = Finance.monthRollup(property: p, month: month, bookings: app.bookings, expenses: app.expenses)
          g += r.gross; n += r.net; e += r.exp; o += r.occ
        }
        let avgOcc = app.activeProperties.isEmpty ? 0 : o / Double(app.activeProperties.count)
        return (g,n,e,avgOcc)
      }
    }

    var body: some View {
      let t = totalsForMonth()
      ScrollView {
        VStack(spacing: 16) {
          // Property selection + scope
          HStack(spacing: 12) {
            Menu {
              Button("All Properties", systemImage: "square.grid.2x2") {
                selectedPropertyID = nil
              }
              Divider()
              ForEach(app.activeProperties) { p in
                Button("\(p.emoji) \(p.name)") { selectedPropertyID = p.id }
              }
            } label: {
              HStack(spacing: 6) {
                Text(selectedProperty?.emoji ?? "🏘️")
                Text(selectedProperty?.name ?? "All Properties")
                  .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                  .font(.caption2)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            HStack(spacing: 8) {
              ForEach(ScopeChip.allCases) { chip in
                Text(chip.rawValue)
                  .font(.footnote.weight(.semibold))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(
                    chip == scope ?
                      Brand.primary.opacity(0.15) :
                      Color.gray.opacity(0.12),
                    in: Capsule()
                  )
                  .overlay(
                    Capsule().stroke(
                      chip == scope ? Brand.primary : .clear,
                      lineWidth: 1
                    )
                  )
                  .onTapGesture { scope = chip }
              }
            }
          }

          // Global metrics
          Card {
            HStack(alignment: .center, spacing: 16) {
              ZStack {
                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 12)
                Circle()
                  .trim(from: 0, to: CGFloat(max(0,min(1,t.occ/100))))
                  .stroke(Brand.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                  .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                  Text("\(Int(round(t.occ)))%")
                    .font(.system(size: 28, weight: .bold))
                  Text("Occupancy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .frame(width: 110, height: 110)

              VStack(spacing: 10) {
                HStack(spacing: 12) {
                  MetricChip(title: "Gross", value: V3.currency(r.gross))
                  MetricChip(title: "Net",   value: V3.currency(r.net))
                }

                HStack(spacing: 12) {
                  if p.trackMortgage {
                    MetricChip(title: "Mortgage", value: V3.currency(mortgage), positive: false)
                  }
                  MetricChip(title: "Bills",    value: V3.currency(bills),    positive: false)
                }
              }
            }
          }

          // Per-property cards
          ForEach(app.activeProperties) { p in
            Card {
              let r = Finance.monthRollup(property: p, month: month, bookings: app.bookings, expenses: app.expenses)
              let mortgage = p.trackMortgage ? Finance.mortgageMonthly(price: p.purchasePrice, apr: p.mortgageAPR, years: p.mortgageYears) : 0
              let bills    = Finance.recurringMonthlyTotal(for: p, in: app)

              VStack(alignment:.leading, spacing: 10) {
                HStack {
                  Circle()
                    .fill(V3.color(hex: p.colorHex))
                    .frame(width: 8, height: 8)
                  Text("\(p.emoji) \(p.name)")
                    .font(.headline)
                  Spacer()
                  Text(String(format:"%.0f%%", r.occ))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                  MetricChip(title: "Gross", value: V3.currency(r.gross))
                  MetricChip(title: "Net",   value: V3.currency(r.net))
                }

                HStack(spacing: 12) {
                  if p.trackMortgage {
                    MetricChip(title: "Mortgage", value: V3.currency(mortgage), positive: false)
                  }
                  MetricChip(title: "Bills",    value: V3.currency(bills),    positive: false)
                }
              }
            }
          }
        }
        .padding(16)
      }
    }
  }

  // MARK: - Calendar Tab (Week / Month / Year)

  enum CalendarViewScope: String, CaseIterable, Identifiable {
    case weekly = "Week", monthly = "Month", yearly = "Year"
    var id: String { rawValue }
  }

  struct CalendarTab: View {
    @Environment(V3.AppState.self) private var app
    @State private var anchorDate = Date()
    @State private var selectedPropertyID: UUID? = nil
    @State private var scope: CalendarViewScope = .monthly
    @State private var showAdd = false
    @State private var todayTrigger: Int = 0

    private var selectedProperty: Property? {
      app.activeProperties.first(where: { $0.id == selectedPropertyID })
    }

    private var periodTitle: String {
      let cal = Calendar.current
      switch scope {
      case .weekly:
        let start = V3.startOfWeek(anchorDate, cal)
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
      case .monthly:
        return anchorDate.formatted(.dateTime.month().year())
      case .yearly:
        return String(cal.component(.year, from: anchorDate))
      }
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 12) {
          // Property selection + scope
          HStack(spacing: 12) {
            Menu {
              Button("All Properties", systemImage: "square.grid.2x2") {
                selectedPropertyID = nil
              }
              Divider()
              ForEach(app.activeProperties) { p in
                Button("\(p.emoji) \(p.name)") { selectedPropertyID = p.id }
              }
            } label: {
              HStack(spacing: 6) {
                Text(selectedProperty?.emoji ?? "🏘️")
                Text(selectedProperty?.name ?? "All Properties")
                  .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                  .font(.caption2)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            Picker("Scope", selection: $scope) {
              ForEach(CalendarViewScope.allCases) { s in
                Text(s.rawValue).tag(s)
              }
            }
            .pickerStyle(.segmented)
          }

          // Period title + navigation + Today button
          HStack {
            Button("Prev") { movePeriod(by: -1) }
            Spacer()
            Button("Today") {
              anchorDate = Date()
              todayTrigger += 1
            }
            .font(.footnote.weight(.semibold))
            Spacer()
            Button(periodTitle) { } // just label
              .font(.headline)
            Spacer()
            Button("Next") { movePeriod(by: 1) }
          }

          HStack {
            Spacer()
            Button("Today") {
              anchorDate = Date()
              todayTrigger += 1
            }
            .font(.footnote.weight(.semibold))
          }

          // Main content
          Group {
            switch scope {
            case .weekly:
              WeekListView(weekStart: V3.startOfWeek(anchorDate), property: selectedProperty)
            case .monthly:
              Card {
                MonthGrid(month: V3.startOfMonth(anchorDate), property: selectedProperty)
                  .frame(maxWidth: .infinity)
              }
            case .yearly:
              YearCalendarView(year: Calendar.current.component(.year, from: anchorDate), property: selectedProperty, todayTrigger: todayTrigger)
            }
          }

          Spacer()
        }
        .padding()
        .navigationTitle("Calendar")
        .overlay(alignment: .bottomTrailing) {
          Button { showAdd = true } label: {
            Image(systemName: "plus")
              .font(.title2.weight(.bold))
              .foregroundStyle(.white)
              .padding(18)
              .background(Brand.primary)
              .clipShape(Circle())
              .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
          }
          .padding(20)
        }
        .sheet(isPresented: $showAdd) {
          let propertyID = selectedProperty?.id ?? app.activeProperties.first?.id ?? app.properties.first!.id
          AddBookingSheet(propertyID: propertyID)
            .environment(app)
        }
      }
    }

    private func movePeriod(by step: Int) {
      let cal = Calendar.current
      switch scope {
      case .weekly:
        anchorDate = cal.date(byAdding: .day, value: 7 * step, to: anchorDate) ?? anchorDate
      case .monthly:
        anchorDate = cal.date(byAdding: .month, value: step, to: anchorDate) ?? anchorDate
      case .yearly:
        anchorDate = cal.date(byAdding: .year, value: step, to: anchorDate) ?? anchorDate
      }
    }
  }

  // Weekly list view (7 days, compact)

  struct WeekListView: View {
    @Environment(V3.AppState.self) private var app
    let weekStart: Date
    let property: Property?

    var body: some View {
      let cal = Calendar.current
      let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }

      let visibleBookings: [Booking] = {
        if let p = property { return app.bookings(for: p.id) }
        return app.bookings
      }()

      return List {
        ForEach(days, id: \.self) { day in
          let dayStart = cal.startOfDay(for: day)
          let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
          let bookingsForDay = visibleBookings.filter {
            $0.checkIn < dayEnd && $0.checkOut > dayStart
          }

          Section(
            header: Text(day.formatted(date: .abbreviated, time: .omitted))
          ) {
            if bookingsForDay.isEmpty {
              Text("No bookings")
                .foregroundStyle(.secondary)
            } else {
              ForEach(bookingsForDay) { b in
                let guest = app.customer(by: b.customerID)?.name ?? "Guest"
                let prop = app.properties.first(where: { $0.id == b.propertyID })
                let label = "\(guest) • \(prop?.emoji ?? "") \(prop?.name ?? "")"
                let color = V3.colorForCustomer(b.customerID).color

                HStack {
                  RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 6, height: 24)
                  VStack(alignment: .leading, spacing: 2) {
                    HStack {
                      Text(label)
                        .font(.subheadline)
                      if b.isPaid {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption2)
                          .foregroundStyle(.green)
                      }
                    }
                    Text("Check-in \(b.checkIn.formatted(date:.abbreviated,time:.omitted)) • Check-out \(b.checkOut.formatted(date:.abbreviated,time:.omitted))")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
    }
  }

  // Yearly view: scroll all 12 months for a given year

  struct YearCalendarView: View {
    @Environment(V3.AppState.self) private var app
    let year: Int
    let property: Property?
    let todayTrigger: Int

    var body: some View {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            ForEach(1...12, id: \.self) { monthIndex in
              let comps = DateComponents(year: year, month: monthIndex, day: 1)
              if let date = Calendar.current.date(from: comps) {
                VStack(alignment: .leading, spacing: 8) {
                  Text(date.formatted(.dateTime.month(.wide)))
                    .font(.headline)
                  Card {
                    MonthGrid(month: date, property: property)
                  }
                }
                .id(monthIndex)
              }
            }
          }
          .padding(.top, 8)
        }
        .onAppear {
          scrollToCurrentMonthIfNeeded(proxy: proxy)
        }
        .onChange(of: todayTrigger) { newValue in
          scrollToCurrentMonthIfNeeded(proxy: proxy)
        }
        .onChange(of: year) { newValue in
          scrollToCurrentMonthIfNeeded(proxy: proxy)
        }
      }
    }

    private func scrollToCurrentMonthIfNeeded(proxy: ScrollViewProxy) {
      let cal = Calendar.current
      let currentYear = cal.component(.year, from: Date())
      if year == currentYear {
        let currentMonth = cal.component(.month, from: Date())
        withAnimation { proxy.scrollTo(currentMonth, anchor: .top) }
      } else {
        withAnimation { proxy.scrollTo(1, anchor: .top) }
      }
    }
  }

  // MARK: - Add Booking Sheet

  struct AddBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app

    let propertyID: UUID
    @State private var checkIn = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var checkOut = Calendar.current.date(byAdding: .day, value: 4, to: Date())!
    @State private var nightly: Double = 120
    @State private var platformFee: Double = 0.14
    @State private var isPaid: Bool = false

    @State private var useExisting = true
    @State private var selectedCustomerID: UUID?
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var newPhone = ""

    var conflicts: [Booking] {
      V3.overlappingBookings(
        in: app,
        propertyID: propertyID,
        checkIn: checkIn,
        checkOut: checkOut,
        ignore: nil,
        bufferHours: app.turnoverBufferHours
      )
    }
    var canSave: Bool { checkOut > checkIn && conflicts.isEmpty }

    var body: some View {
      NavigationStack {
        Form {
          if !conflicts.isEmpty {
            Section {
              VStack(alignment: .leading, spacing: 6) {
                Label("Dates overlap existing bookings", systemImage: "exclamationmark.triangle.fill")
                  .foregroundStyle(Brand.warning)
                ForEach(conflicts) { b in
                  let name = app.customer(by: b.customerID)?.name ?? "Guest"
                  Text("• \(name): \(b.checkIn.formatted(date:.abbreviated,time:.omitted)) → \(b.checkOut.formatted(date:.abbreviated,time:.omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }
          }

          Section("Guest") {
            Toggle("Choose existing guest", isOn: $useExisting)
            if useExisting {
              Picker("Guest", selection: Binding(
                get: { selectedCustomerID ?? app.customers.first?.id ?? UUID() },
                set: { selectedCustomerID = $0 }
              )) {
                ForEach(app.customers) { c in
                  Text(c.name).tag(c.id)
                }
              }
            } else {
              TextField("Full name", text: $newName)
              TextField("Email (optional)", text: $newEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
              TextField("Phone (optional)", text: $newPhone)
                .keyboardType(.phonePad)
            }
          }

          Section("Dates") {
            DatePicker("Check-in", selection: $checkIn, displayedComponents: .date)
            DatePicker("Check-out", selection: $checkOut, in: checkIn.addingTimeInterval(86_400)..., displayedComponents: .date)
            if app.turnoverBufferHours > 0 {
              Text("Cleaning buffer: \(app.turnoverBufferHours)h")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Section("Pricing") {
            HStack {
              Text("Nightly rate")
              Spacer()
              TextField("€", value: $nightly, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            HStack {
              Text("Platform fee")
              Spacer()
              TextField("%", value: $platformFee, format: .percent)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Toggle("Paid", isOn: $isPaid)
          }
        }
        .navigationTitle("Add Booking")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              let cid: UUID = {
                if useExisting, let id = selectedCustomerID ?? app.customers.first?.id {
                  return id
                } else {
                  let customer = app.addCustomer(
                    name: newName.isEmpty ? "Guest" : newName,
                    email: newEmail.isEmpty ? nil : newEmail,
                    phone: newPhone.isEmpty ? nil : newPhone
                  )
                  return customer.id
                }
              }()
              let booking = Booking(propertyID: propertyID,
                                    customerID: cid,
                                    checkIn: checkIn,
                                    checkOut: checkOut,
                                    nightlyRate: nightly,
                                    platformFeePct: platformFee,
                                    isPaid: isPaid)
              app.addBooking(booking)
              dismiss()
            }
            .disabled(!canSave)
          }
        }
      }
    }
  }

  // MARK: - Edit Booking Sheet

  struct EditBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app

    let booking: Booking
    let onFinished: (() -> Void)?

    @State private var checkIn: Date
    @State private var checkOut: Date
    @State private var nightlyRate: Double
    @State private var platformFee: Double
    @State private var isPaid: Bool
    @State private var guestName: String
    @State private var guestEmail: String
    @State private var guestPhone: String

    init(booking: Booking, onFinished: (() -> Void)? = nil) {
      self.booking = booking
      self.onFinished = onFinished
      _checkIn = State(initialValue: booking.checkIn)
      _checkOut = State(initialValue: booking.checkOut)
      _nightlyRate = State(initialValue: booking.nightlyRate)
      _platformFee = State(initialValue: booking.platformFeePct)
      _isPaid = State(initialValue: booking.isPaid)

      // guest info placeholders; actual values loaded in onAppear
      _guestName = State(initialValue: "")
      _guestEmail = State(initialValue: "")
      _guestPhone = State(initialValue: "")
    }

    // guest info filled in on appear (because we can't access @Environment in init)
    private func loadGuestFields() {
      if let c = app.customer(by: booking.customerID) {
        guestName = c.name
        guestEmail = c.email ?? ""
        guestPhone = c.phone ?? ""
      } else {
        guestName = "Guest"
        guestEmail = ""
        guestPhone = ""
      }
    }

    var conflicts: [Booking] {
      V3.overlappingBookings(
        in: app,
        propertyID: booking.propertyID,
        checkIn: checkIn,
        checkOut: checkOut,
        ignore: booking.id,
        bufferHours: app.turnoverBufferHours
      )
    }

    var canSave: Bool { checkOut > checkIn && conflicts.isEmpty }

    var body: some View {
      NavigationStack {
        Form {
          if !conflicts.isEmpty {
            Section {
              VStack(alignment: .leading, spacing: 6) {
                Label("Dates overlap existing bookings", systemImage: "exclamationmark.triangle.fill")
                  .foregroundStyle(Brand.warning)
                ForEach(conflicts) { b in
                  let name = app.customer(by: b.customerID)?.name ?? "Guest"
                  Text("• \(name): \(b.checkIn.formatted(date:.abbreviated,time:.omitted)) → \(b.checkOut.formatted(date:.abbreviated,time:.omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }
          }

          Section("Guest") {
            TextField("Name", text: $guestName)
            TextField("Email (optional)", text: $guestEmail)
              .textInputAutocapitalization(.never)
              .keyboardType(.emailAddress)
            TextField("Phone (optional)", text: $guestPhone)
              .keyboardType(.phonePad)
          }

          Section("Dates") {
            DatePicker("Check-in", selection: $checkIn, displayedComponents: .date)
            DatePicker("Check-out", selection: $checkOut, in: checkIn.addingTimeInterval(86_400)..., displayedComponents: .date)
          }

          Section("Pricing") {
            HStack {
              Text("Nightly rate")
              Spacer()
              TextField("€", value: $nightlyRate, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            HStack {
              Text("Platform fee")
              Spacer()
              TextField("%", value: $platformFee, format: .percent)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Toggle("Paid", isOn: $isPaid)
          }

          Section {
            Button(role: .destructive) {
              app.deleteBooking(booking)
              dismiss()
              DispatchQueue.main.async { onFinished?() }
            } label: {
              Text("Delete Booking")
            }
          }
        }
        .navigationTitle("Edit Booking")
        .onAppear { loadGuestFields() }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              var updated = booking
              updated.checkIn = checkIn
              updated.checkOut = checkOut
              updated.nightlyRate = nightlyRate
              updated.platformFeePct = platformFee
              updated.isPaid = isPaid
              app.updateBooking(updated)

              if var c = app.customer(by: booking.customerID) {
                c.name = guestName.isEmpty ? "Guest" : guestName
                c.email = guestEmail.isEmpty ? nil : guestEmail
                c.phone = guestPhone.isEmpty ? nil : guestPhone
                app.updateCustomer(c)
              }
              // Dismiss the edit sheet first, then the day sheet
              dismiss()
              DispatchQueue.main.async { onFinished?() }
            }
            .disabled(!canSave)
          }
        }
      }
    }
  }

  // MARK: - Expenses Tab

  struct ExpensesTab: View {
    @Environment(V3.AppState.self) private var app
    @State private var selectedPropertyID: UUID?
    @State private var showAddExpense = false
    @State private var showAddRecurring = false
    @State private var editingExpense: Expense?

    private var selectedProperty: Property? {
      app.activeProperties.first(where: { $0.id == selectedPropertyID }) ?? app.activeProperties.first
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 12) {
          if app.activeProperties.isEmpty {
            Text("Add a property in Settings to begin.")
              .foregroundStyle(.secondary)
          } else {
            Picker("Property", selection: Binding(
              get: { selectedProperty?.id ?? app.activeProperties.first!.id },
              set: { selectedPropertyID = $0 }
            )) {
              ForEach(app.activeProperties) { p in
                Text("\(p.emoji) \(p.name)").tag(p.id)
              }
            }
            .pickerStyle(.segmented)

            if let prop = selectedProperty {
              List {
                Section("Recurring Bills") {
                  ForEach(app.recurring(for: prop.id)) { r in
                    NavigationLink {
                      EditRecurringView(recurring: r)
                        .environment(app)
                    } label: {
                      HStack {
                        VStack(alignment: .leading) {
                          Text(r.name).font(.headline)
                          Text("\(r.category.rawValue.capitalized) • Day \(r.dayOfMonth)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(V3.currency(r.amount)).bold()
                        if !r.isActive {
                          Text("Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                        }
                      }
                    }
                  }
                  Button { showAddRecurring = true } label: {
                    Label("Add Recurring Bill", systemImage: "repeat")
                  }
                }

                Section("Expenses") {
                  ForEach(app.expenses(for: prop.id).sorted(by: { $0.date > $1.date })) { e in
                    Button { editingExpense = e } label: {
                      HStack {
                        VStack(alignment: .leading) {
                          Text(e.category.rawValue.capitalized)
                          if let note = e.note {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                          }
                        }
                        Spacer()
                        Text(V3.currency(e.amount)).bold()
                      }
                      .badge(e.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .swipeActions {
                      Button(role: .destructive) { app.deleteExpense(e) } label: {
                        Label("Delete", systemImage: "trash")
                      }
                    }
                  }

                  Button { showAddExpense = true } label: {
                    Label("Add Expense", systemImage: "plus.circle.fill")
                  }
                }
              }
              .listStyle(.insetGrouped)
              .toolbar {
                ToolbarItem(placement: .bottomBar) {
                  Button {
                    app.postRecurringForCurrentMonth(propertyID: prop.id)
                  } label: {
                    Label("Post this month", systemImage:"calendar.badge.plus")
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal)
        .navigationTitle("Expenses")
        .sheet(isPresented: $showAddExpense) {
          let propertyID = selectedProperty?.id ?? app.activeProperties.first!.id
          AddExpenseSheet(propertyID: propertyID)
            .environment(app)
        }
        .sheet(isPresented: $showAddRecurring) {
          let propertyID = selectedProperty?.id ?? app.activeProperties.first!.id
          AddRecurringSheet(propertyID: propertyID)
            .environment(app)
        }
        .sheet(item: $editingExpense) { expense in
          EditExpenseSheet(expense: expense)
            .environment(app)
        }
      }
    }
  }

  struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app
    let propertyID: UUID
    @State private var amount: Double = 50
    @State private var category: ExpenseCategory = .cleaning
    @State private var note = ""
    @State private var date = Date()
    var body: some View {
      NavigationStack {
        Form {
          Section("Expense") {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Picker("Category", selection: $category) {
              ForEach(ExpenseCategory.allCases) { c in
                Text(c.rawValue.capitalized).tag(c)
              }
            }
            HStack {
              Text("Amount")
              Spacer()
              TextField("€", value: $amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            TextField("Note (optional)", text: $note)
          }
        }
        .navigationTitle("Add Expense")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              app.addExpense(propertyID: propertyID,
                             amount: amount,
                             category: category,
                             note: note.isEmpty ? nil : note,
                             date: date)
              dismiss()
            }
          }
        }
      }
    }
  }

  struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app
    let expense: Expense
    @State private var amount: Double
    @State private var category: ExpenseCategory
    @State private var note: String
    @State private var date: Date
    init(expense: Expense) {
      self.expense = expense
      _amount = State(initialValue: expense.amount)
      _category = State(initialValue: expense.category)
      _note = State(initialValue: expense.note ?? "")
      _date = State(initialValue: expense.date)
    }
    var body: some View {
      NavigationStack {
        Form {
          Section("Edit Expense") {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Picker("Category", selection: $category) {
              ForEach(ExpenseCategory.allCases) { c in
                Text(c.rawValue.capitalized).tag(c)
              }
            }
            HStack {
              Text("Amount")
              Spacer()
              TextField("€", value: $amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            TextField("Note", text: $note)
          }
        }
        .navigationTitle("Edit Expense")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              app.updateExpense(expense,
                                amount: amount,
                                category: category,
                                note: note.isEmpty ? nil : note,
                                date: date)
              dismiss()
            }
          }
        }
      }
    }
  }

  struct AddRecurringSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app
    let propertyID: UUID
    @State private var name = "Electricity"
    @State private var amount: Double = 50
    @State private var category: ExpenseCategory = .utilities
    @State private var dayOfMonth: Int = 10
    @State private var note = ""
    @State private var isActive = true
    var body: some View {
      NavigationStack {
        Form {
          Section("Bill") {
            TextField("Name", text: $name)
            HStack {
              Text("Amount")
              Spacer()
              TextField("€", value: $amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Picker("Category", selection: $category) {
              ForEach(ExpenseCategory.allCases) { c in
                Text(c.rawValue.capitalized).tag(c)
              }
            }
            Stepper(value: $dayOfMonth, in: 1...31) {
              Text("Day of month: \(dayOfMonth)")
            }
            TextField("Note (optional)", text: $note)
            Toggle("Active", isOn: $isActive)
          }
        }
        .navigationTitle("Add Recurring Bill")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              app.addRecurring(propertyID: propertyID,
                               name: name,
                               amount: amount,
                               category: category,
                               dayOfMonth: dayOfMonth,
                               note: note.isEmpty ? nil : note,
                               isActive: isActive)
              dismiss()
            }
          }
        }
      }
    }
  }

  struct EditRecurringView: View {
    @Environment(V3.AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State var recurring: RecurringBill
    var body: some View {
      Form {
        Section("Bill") {
          TextField("Name", text: $recurring.name)
          HStack {
            Text("Amount")
            Spacer()
            TextField("€", value: $recurring.amount, format: .number)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          Picker("Category", selection: $recurring.category) {
            ForEach(ExpenseCategory.allCases) { c in
              Text(c.rawValue.capitalized).tag(c)
            }
          }
          Stepper(value: $recurring.dayOfMonth, in: 1...31) {
            Text("Day of month: \(recurring.dayOfMonth)")
          }
          TextField(
            "Note (optional)",
            text: Binding(
              get: { recurring.note ?? "" },
              set: { recurring.note = $0.isEmpty ? nil : $0 }
            )
          )
          Toggle("Active", isOn: $recurring.isActive)
        }
        Section {
          Button(role:.destructive) {
            app.deleteRecurring(recurring)
            dismiss()
          } label: {
            Text("Delete Recurring Bill")
          }
        }
      }
      .navigationTitle("Edit Recurring")
      .toolbar {
        ToolbarItem(placement:.confirmationAction) {
          Button("Save") {
            app.updateRecurring(recurring)
            dismiss()
          }
        }
      }
    }
  }

  // MARK: - Totals Tab

  struct TotalsTab: View {
    @Environment(V3.AppState.self) private var app
    @State private var scope: TotalsScope = .monthly
    @State private var anchorDate = Date()

    var body: some View {
      let (start, end) = Finance.range(for: scope, around: anchorDate)
      NavigationStack {
        VStack(spacing: 16) {
          Picker("Scope", selection: $scope) {
            ForEach(TotalsScope.allCases) { s in
              Text(s.rawValue).tag(s)
            }
          }
          .pickerStyle(.segmented)

          let totals = totalsBetween(start: start, end: end)
          Card {
            HStack(spacing: 16) {
              MetricChip(title: "Revenue",  value: V3.currency(totals.gross))
              MetricChip(title: "Expenses", value: V3.currency(totals.exp), positive: false)
              MetricChip(title: "Net",      value: V3.currency(totals.net))
            }
          }

          List {
            Section("Properties") {
              ForEach(app.properties) { p in
                let per = totalsForProperty(p, start: start, end: end)
                HStack {
                  Text("\(p.emoji) \(p.name)")
                  Spacer()
                  Text(V3.currency(per.net)).bold()
                }
                .badge(V3.currency(per.gross))
              }
            }
          }
        }
        .padding()
        .navigationTitle("Totals")
      }
    }

    private func totalsBetween(start: Date, end: Date) -> (gross: Double, exp: Double, net: Double) {
      var gross = 0.0, net = 0.0
      let map = Dictionary(uniqueKeysWithValues: app.properties.map { ($0.id, $0) })
      for b in app.bookings {
        let s = max(b.checkIn, start), e = min(b.checkOut, end)
        if s < e, let prop = map[b.propertyID] {
          let n = Double(Finance.nights(s, e))
          let g = n * b.nightlyRate
          gross += g
          net += Finance.netRevenue(gross: g, platform: b.platformFeePct, commission: prop.commissionPct)
        }
      }
      let exp = app.expenses.filter { $0.date >= start && $0.date < end }.map(\.amount).reduce(0,+)
      net -= exp
      return (gross, exp, net)
    }

    private func totalsForProperty(_ p: Property, start: Date, end: Date) -> (gross: Double, net: Double) {
      var g = 0.0, n = 0.0
      for b in app.bookings where b.propertyID == p.id {
        let s = max(b.checkIn, start), e = min(b.checkOut, end)
        if s < e {
          let nights = Double(Finance.nights(s, e))
          let gross  = nights * b.nightlyRate
          g += gross
          n += Finance.netRevenue(gross: gross, platform: b.platformFeePct, commission: p.commissionPct)
        }
      }
      let exp = app.expenses
        .filter { $0.propertyID == p.id && $0.date >= start && $0.date < end }
        .map(\.amount)
        .reduce(0,+)
      n -= exp
      return (g, n)
    }
  }

  // MARK: - Customers (CRM)

  struct CustomersTab: View {
    @Environment(V3.AppState.self) private var app
    var body: some View {
      NavigationStack {
        List {
          ForEach(app.customers) { c in
            NavigationLink {
              CustomerDetailView(customer: c)
                .environment(app)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(c.name).font(.headline)
                  if let email = c.email, !email.isEmpty {
                    Text(email).font(.caption).foregroundStyle(.secondary)
                  }
                  if let phone = c.phone, !phone.isEmpty {
                    Text(phone).font(.caption2).foregroundStyle(.secondary)
                  }
                }
                Spacer()
                Text("\(app.totalBookings(for: c.id)) stays")
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .navigationTitle("Guests")
      }
    }
  }

  struct CustomerDetailView: View {
    @Environment(V3.AppState.self) private var app
    let customer: Customer

    var body: some View {
      let upcoming = app.bookings
        .filter { $0.customerID == customer.id && $0.checkOut >= Date() }
        .sorted { $0.checkIn < $1.checkIn }

      let past = app.bookings
        .filter { $0.customerID == customer.id && $0.checkOut < Date() }
        .sorted { $0.checkIn > $1.checkIn }

      return List {
        if !upcoming.isEmpty {
          Section("Upcoming stays") {
            ForEach(upcoming) { b in
              BookingRow(b)
            }
          }
        }
        if !past.isEmpty {
          Section("Past stays") {
            ForEach(past) { b in
              BookingRow(b)
            }
          }
        }
      }
      .navigationTitle(customer.name)
    }

    @ViewBuilder
    private func BookingRow(_ b: Booking) -> some View {
      let propName = app.properties.first(where: { $0.id == b.propertyID })?.name ?? "Property"
      let emoji    = app.properties.first(where: { $0.id == b.propertyID })?.emoji ?? ""
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("\(emoji) \(propName)").font(.headline)
          Spacer()
          if b.isPaid {
            Text("Paid").font(.caption2).foregroundStyle(.green)
          } else {
            Text("Unpaid").font(.caption2).foregroundStyle(.red)
          }
        }
        Text("Check-in \(b.checkIn.formatted(date:.abbreviated,time:.omitted)) • Check-out \(b.checkOut.formatted(date:.abbreviated,time:.omitted))")
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Settings

  struct SettingsTab: View {
    @Environment(V3.AppState.self) private var app
    @State private var showAddProperty = false

    var body: some View {
      NavigationStack {
        Form {
          Section("Properties") {
            ForEach(app.properties) { p in
              NavigationLink {
                EditPropertyView(property: p)
                  .environment(app)
              } label: {
                HStack {
                  Circle()
                    .fill(V3.color(hex: p.colorHex))
                    .frame(width: 10, height: 10)
                  Text("\(p.emoji) \(p.name)")
                  Spacer()
                  if p.isArchived {
                    Text("Archived")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
            Button {
              showAddProperty = true
            } label: {
              Label("Add Property", systemImage: "plus.circle.fill")
            }
          }

          Section("Turnover Buffer") {
            Stepper(
              value: Binding(
                get: { app.turnoverBufferHours },
                set: { app.turnoverBufferHours = $0 }
              ),
              in: 0...48
            ) {
              Text("\(app.turnoverBufferHours) hours between stays")
            }
            if app.turnoverBufferHours == 0 {
              Text("No buffer between stays")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text("New bookings must respect this gap after check-out.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showAddProperty) {
          AddPropertySheet()
            .environment(app)
        }
      }
    }
  }

  struct AddPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V3.AppState.self) private var app

    @State private var name: String = ""
    @State private var emoji: String = "🏠"
    @State private var colorHex: String? = nil
    @State private var purchasePrice: Double = 200_000
    @State private var mortgageAPR: Double = 0.035
    @State private var mortgageYears: Int = 20
    @State private var commissionPct: Double = 0.10
    @State private var trackMortgage: Bool = true

    var body: some View {
      NavigationStack {
        Form {
          Section("Basic Info") {
            TextField("Name", text: $name)
            TextField("Icon", text: $emoji)
          }

          Section("Calendar Color") {
            CalendarColorPicker(selectedHex: $colorHex)
          }

          Section("Financials") {
            HStack {
              Text("Purchase Price")
              Spacer()
              TextField("€", value: $purchasePrice, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            HStack {
              Text("Mortgage APR")
              Spacer()
              TextField("%", value: $mortgageAPR, format: .percent)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Stepper("Years: \(mortgageYears)", value: $mortgageYears, in: 5...35)
            HStack {
              Text("Commission")
              Spacer()
              TextField("%", value: $commissionPct, format: .percent)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Toggle("Track mortgage", isOn: $trackMortgage)
          }
        }
        .navigationTitle("Add Property")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              _ = app.addProperty(
                name: name.isEmpty ? "New Property" : name,
                emoji: emoji,
                colorHex: colorHex,
                purchasePrice: purchasePrice,
                mortgageAPR: mortgageAPR,
                mortgageYears: mortgageYears,
                commissionPct: commissionPct,
                trackMortgage: trackMortgage
              )
              dismiss()
            }
          }
        }
      }
    }
  }

  struct EditPropertyView: View {
    @Environment(V3.AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let original: Property
    @State private var working: Property

    init(property: Property) {
      original = property
      _working = State(initialValue: property)
    }

    var body: some View {
      Form {
        Section("Basic Info") {
          TextField("Name", text: $working.name)
          TextField("Icon", text: $working.emoji)
        }

        Section("Calendar Color") {
          CalendarColorPicker(selectedHex: Binding<String?>(
            get: { working.colorHex },
            set: { working.colorHex = $0 ?? working.colorHex }
          ))
        }

        Section("Financials") {
          HStack {
            Text("Purchase Price")
            Spacer()
            TextField("€", value: $working.purchasePrice, format: .number)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          HStack {
            Text("Mortgage APR")
            Spacer()
            TextField("%", value: $working.mortgageAPR, format: .percent)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          Stepper("Years: \(working.mortgageYears)", value: $working.mortgageYears, in: 5...35)
          HStack {
            Text("Commission")
            Spacer()
            TextField("%", value: $working.commissionPct, format: .percent)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          Toggle("Track mortgage", isOn: $working.trackMortgage)
        }

        Section("Status") {
          Toggle("Archived", isOn: $working.isArchived)
        }

        Section {
          Button(role: .destructive) {
            app.deleteProperty(original)
            dismiss()
          } label: {
            Text("Delete Property")
          }
        }
      }
      .navigationTitle("Edit Property")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            app.updateProperty(working)
            dismiss()
          }
        }
      }
    }
  }

  // REPLACED: CalendarColorPicker

  struct CalendarColorPicker: View {
    @Binding var selectedHex: String?

    private let circleSize: CGFloat = 30

    var body: some View {
      let columns = [GridItem(.adaptive(minimum: circleSize, maximum: 44), spacing: 12)]
      LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
        ForEach(V3.calendarColorOptions) { option in
          let isSelected = selectedHex == option.hex
          Button {
            selectedHex = option.hex
          } label: {
            ZStack {
              Circle()
                .fill(V3.color(hex: option.hex))
                .frame(width: circleSize, height: circleSize)
                .overlay(
                  Circle()
                    .stroke(isSelected ? Color.primary.opacity(0.7) : Color.black.opacity(0.08),
                            lineWidth: isSelected ? 3 : 1)
                )
              if isSelected {
                Image(systemName: "checkmark")
                  .font(.system(size: 14, weight: .bold))
                  .foregroundStyle(.white)
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(option.name)
        }
      }
      .padding(.vertical, 4)
    }
  }
}

// MARK: - Convenience

extension Double {
  var v3Currency: String { V3.currency(self) }
}

// MARK: - App Entry

@main
struct StayTrackrV3App: App {
  @State private var appState = V3.AppState()

  var body: some Scene {
    WindowGroup {
      TabView {
        V3.DashboardView()
          .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2.fill") }

        V3.CalendarTab()
          .tabItem { Label("Calendar", systemImage: "calendar") }

        V3.ExpensesTab()
          .tabItem { Label("Expenses", systemImage: "creditcard") }

        V3.TotalsTab()
          .tabItem { Label("Totals", systemImage: "chart.bar") }

        V3.CustomersTab()
          .tabItem { Label("Guests", systemImage: "person.2.fill") }

        V3.SettingsTab()
          .tabItem { Label("Settings", systemImage: "gearshape") }
      }
      .environment(appState)
      .preferredColorScheme(.light)
      .tint(V3.Brand.primary)
    }
  }
}

