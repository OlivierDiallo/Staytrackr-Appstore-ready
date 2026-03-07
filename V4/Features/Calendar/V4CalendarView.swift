import SwiftUI
import SwiftData

// MARK: - Calendar View

struct V4CalendarView: View {
  let prefs: V4AppPreferences

  @Environment(\.modelContext) private var context
  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STGuest.name) private var guests: [STGuest]
  @Query(sort: \STBooking.checkIn) private var bookings: [STBooking]

  @State private var displayedMonth: Date = .now
  @State private var selectedDay: Date? = nil
  @State private var showAdd = false
  @State private var bookingToEdit: STBooking? = nil
  /// Drives the "create booking pre-filled with tapped date" sheet.
  @State private var showAddForDay = false
  @State private var pendingCheckInDate: Date? = nil

  private let cal = Calendar.current

  // MARK: - Derived

  private var selectedProperty: STProperty? {
    guard let id = prefs.selectedPropertyID else { return nil }
    return properties.first { $0.id == id }
  }

  private var filteredBookings: [STBooking] {
    guard let p = selectedProperty else { return Array(bookings) }
    return bookings.filter { $0.property.id == p.id }
  }

  /// All day slots for the displayed month (nil = empty leading/trailing padding cell)
  private var calendarDays: [Date?] {
    guard
      let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
      let range = cal.range(of: .day, in: .month, for: displayedMonth)
    else { return [] }

    let firstWeekday = cal.component(.weekday, from: monthStart)
    let leading = (firstWeekday - cal.firstWeekday + 7) % 7

    var days: [Date?] = Array(repeating: nil, count: leading)
    for offset in 0 ..< range.count {
      days.append(cal.date(byAdding: .day, value: offset, to: monthStart))
    }
    let trailing = (7 - days.count % 7) % 7
    if trailing < 7 { days += Array(repeating: nil as Date?, count: trailing) }
    return days
  }

  /// Locale-aware weekday header labels (Mon Tue … or Sun Mon …)
  private var weekdaySymbols: [String] {
    let syms = cal.veryShortStandaloneWeekdaySymbols
    let offset = cal.firstWeekday - 1
    return Array(syms[offset...] + syms[..<offset])
  }

  /// Bookings shown below the grid — filtered to selected day or whole displayed month
  private var bookingsToDisplay: [STBooking] {
    if let day = selectedDay {
      let dayStart = cal.startOfDay(for: day)
      let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
      return filteredBookings
        .filter { $0.checkIn < dayEnd && $0.checkOut > dayStart }
        .sorted { $0.checkIn < $1.checkIn }
    } else {
      guard
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
        let end   = cal.date(byAdding: .month, value: 1, to: start)
      else { return [] }
      return filteredBookings
        .filter { $0.checkIn < end && $0.checkOut > start }
        .sorted { $0.checkIn < $1.checkIn }
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      List {

        // Property picker
        Section {
          propertyMenu
        }

        // Month grid (full-width, no list row chrome)
        Section {
          monthGridView
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }

        // Bookings list
        Section {
          if bookingsToDisplay.isEmpty {
            Text(selectedDay != nil
                 ? "No bookings on this day."
                 : "No bookings this month.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(bookingsToDisplay) { b in
              Button { bookingToEdit = b } label: { bookingRow(b) }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  Button(role: .destructive) { deleteBooking(b) } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                  Button {
                    b.isPaid.toggle()
                    try? context.save()
                  } label: {
                    Label(
                      b.isPaid ? "Mark Unpaid" : "Mark Paid",
                      systemImage: b.isPaid ? "xmark.circle" : "checkmark.circle.fill"
                    )
                  }
                  .tint(b.isPaid ? .orange : .green)
                }
            }
          }
        } header: {
          if let day = selectedDay {
            HStack(spacing: 10) {
              Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
              Spacer()
              // Tap the "+" to open BookingEditorSheet pre-filled with this date
              Button {
                pendingCheckInDate = day
                showAddForDay = true
              } label: {
                Image(systemName: "plus.circle.fill")
                  .imageScale(.medium)
                  .foregroundStyle(V4Theme.Brand.primary)
              }
              Button("Show All") {
                withAnimation(.easeInOut(duration: 0.15)) { selectedDay = nil }
              }
              .font(.caption)
            }
          } else {
            Text("Bookings")
          }
        } footer: {
          if !bookingsToDisplay.isEmpty {
            let totalNights = bookingsToDisplay.reduce(0) { $0 + V4Finance.nights($1.checkIn, $1.checkOut) }
            let count = bookingsToDisplay.count
            Text("\(count) booking\(count == 1 ? "" : "s") · \(totalNights) night\(totalNights == 1 ? "" : "s")")
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Calendar")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Today") {
            withAnimation(.easeInOut(duration: 0.2)) {
              displayedMonth = .now
              selectedDay = nil
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { showAdd = true } label: { Image(systemName: "plus") }
        }
      }
      .sheet(isPresented: $showAdd) {
        V4BookingEditorSheet(
          _properties: _properties,
          _guests: _guests,
          mode: .add(initialProperty: selectedProperty)
        )
      }
      .sheet(item: $bookingToEdit) { b in
        V4BookingEditorSheet(
          _properties: _properties,
          _guests: _guests,
          mode: .edit(booking: b)
        )
      }
      // Calendar date-tap: open editor pre-filled with the tapped date
      .sheet(isPresented: $showAddForDay) {
        V4BookingEditorSheet(
          _properties: _properties,
          _guests: _guests,
          mode: .add(initialProperty: selectedProperty),
          initialCheckIn: pendingCheckInDate
        )
      }
    }
  }

  // MARK: - Property Picker

  private var propertyMenu: some View {
    Menu {
      Button("All Properties", systemImage: "square.grid.2x2") {
        prefs.selectedPropertyID = nil
      }
      Divider()
      ForEach(properties) { p in
        Button("\(p.emoji) \(p.name)") { prefs.selectedPropertyID = p.id }
      }
    } label: {
      HStack(spacing: 8) {
        Text(selectedProperty?.emoji ?? "🏘️")
        Text(selectedProperty?.name ?? "All Properties").lineLimit(1)
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Month Grid

  private var gridColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
  }

  private var monthGridView: some View {
    VStack(spacing: 0) {

      // Month navigation row
      HStack {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            selectedDay = nil
          }
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Spacer()

        Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
          .font(.headline)

        Spacer()

        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            selectedDay = nil
          }
        } label: {
          Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 4)

      // Weekday header row
      LazyVGrid(columns: gridColumns, spacing: 0) {
        ForEach(weekdaySymbols, id: \.self) { sym in
          Text(sym)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
      }
      .padding(.horizontal, 8)

      Divider()
        .padding(.horizontal, 8)
        .opacity(0.4)

      // Day cells
      LazyVGrid(columns: gridColumns, spacing: 2) {
        ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, optDay in
          if let day = optDay {
            DayCellView(
              day: day,
              isSelected: selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false,
              isToday: cal.isDateInToday(day),
              hasArrival: filteredBookings.contains { cal.isDate($0.checkIn, inSameDayAs: day) },
              hasDeparture: filteredBookings.contains { cal.isDate($0.checkOut, inSameDayAs: day) },
              occupantColor: occupantColor(on: day)
            )
            .onTapGesture {
              withAnimation(.easeInOut(duration: 0.15)) {
                if let sel = selectedDay, cal.isDate(sel, inSameDayAs: day) {
                  selectedDay = nil   // tap same day again → deselect
                } else {
                  selectedDay = day
                }
              }
            }
          } else {
            Color.clear.frame(height: 52)
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 10)
    }
  }

  // MARK: - Day Status Helpers

  /// Returns the property color for the booking that occupies the given night, if any.
  private func occupantColor(on day: Date) -> Color? {
    let dayStart = cal.startOfDay(for: day)
    let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
    guard let first = filteredBookings.first(where: {
      cal.startOfDay(for: $0.checkIn) <= dayStart &&
      cal.startOfDay(for: $0.checkOut) >= dayEnd
    }) else { return nil }
    return V4Color.hex(first.property.colorHex)
  }

  // MARK: - Booking Row

  @ViewBuilder
  private func bookingRow(_ b: STBooking) -> some View {
    let nights = V4Finance.nights(b.checkIn, b.checkOut)
    let gross  = Double(nights) * b.nightlyRate
    let status = b.status

    HStack(spacing: 10) {
      // Property color stripe
      RoundedRectangle(cornerRadius: 2)
        .fill(V4Color.hex(b.property.colorHex))
        .frame(width: 4)
        .padding(.vertical, 2)

      VStack(alignment: .leading, spacing: 4) {
        // Top row: guest name + status + paid badges
        HStack(alignment: .center, spacing: 6) {
          Text(b.guest.name)
            .font(.subheadline.weight(.semibold))
          Spacer()
          // Status badge
          statusBadge(status)
          // Paid badge
          Text(b.isPaid ? "Paid" : "Unpaid")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(b.isPaid ? .white : V4Theme.Brand.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
              b.isPaid
                ? AnyShapeStyle(V4Theme.Brand.primary)
                : AnyShapeStyle(V4Theme.Brand.primary.opacity(0.12)),
              in: Capsule()
            )
        }

        // Middle row: property + nights
        Text("\(b.property.emoji) \(b.property.name)  ·  \(nights) night\(nights == 1 ? "" : "s")")
          .font(.caption)
          .foregroundStyle(.secondary)

        // Notes (if present)
        if let note = b.note, !note.isEmpty {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        // Bottom row: dates + amount
        HStack {
          Text("\(b.checkIn.formatted(date: .abbreviated, time: .omitted)) → \(b.checkOut.formatted(date: .abbreviated, time: .omitted))")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text(V4Currency.format(gross, code: b.property.currencyCode))
            .font(.caption.weight(.semibold))
        }
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private func statusBadge(_ status: STBookingStatus) -> some View {
    let (label, color): (String, Color) = {
      switch status {
      case .upcoming:  return ("Upcoming", .blue)
      case .active:    return ("Active",   V4Theme.Brand.primary)
      case .completed: return ("Done",     .secondary)
      }
    }()
    Text(label)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(color.opacity(0.12), in: Capsule())
  }

  // MARK: - Delete

  private func deleteBooking(_ b: STBooking) {
    context.delete(b)
    do { try context.save() }
    catch { print("Delete booking failed: \(error)") }
  }
}

// MARK: - Day Cell View

private struct DayCellView: View {
  let day: Date
  let isSelected: Bool
  let isToday: Bool
  let hasArrival: Bool
  let hasDeparture: Bool
  let occupantColor: Color?

  var body: some View {
    VStack(spacing: 2) {

      // Day number in circle
      ZStack {
        if isSelected {
          Circle().fill(V4Theme.Brand.primary)
        } else if isToday {
          Circle().strokeBorder(V4Theme.Brand.primary, lineWidth: 1.5)
        }
        Text("\(Calendar.current.component(.day, from: day))")
          .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
          .foregroundStyle(
            isSelected ? Color.white :
            isToday    ? V4Theme.Brand.primary :
                         Color.primary
          )
      }
      .frame(width: 28, height: 28)

      // Arrival (blue) / Departure (orange) dots
      HStack(spacing: 3) {
        Circle()
          .fill(Color.accentColor)
          .frame(width: 4, height: 4)
          .opacity(hasArrival ? 1 : 0)
        Circle()
          .fill(Color.orange)
          .frame(width: 4, height: 4)
          .opacity(hasDeparture ? 1 : 0)
        // Always reserve space so cells have equal height
        if !hasArrival && !hasDeparture {
          Color.clear.frame(width: 4, height: 4)
        }
      }
      .frame(height: 5)

      // Occupancy bar (property accent color)
      RoundedRectangle(cornerRadius: 1.5)
        .fill(occupantColor ?? Color.clear)
        .frame(height: 3)
        .padding(.horizontal, 4)
    }
    .padding(.vertical, 3)
    .frame(maxWidth: .infinity)
    .background(
      isSelected ? V4Theme.Brand.primary.opacity(0.08) : Color.clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    .contentShape(Rectangle())
  }
}
