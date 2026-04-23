import SwiftUI
import SwiftData

struct V4BookingEditorSheet: View {

  enum Mode: Equatable {
    case add(initialProperty: STProperty?)
    case edit(booking: STBooking)

    var title: LocalizedStringKey {
      switch self {
      case .add: return "Add Booking"
      case .edit: return "Edit Booking"
      }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(V4AppSettings.self) private var settings
  @Environment(STStoreManager.self) private var store
  @Environment(\.modelContext) private var context

  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STGuest.name) private var guests: [STGuest]

  let mode: Mode
  /// Pre-filled check-in date (calendar date-tap flow). Nil = use today.
  var initialCheckIn: Date? = nil

  // Form state
  @State private var propertyID: UUID?
  @State private var guestID: UUID?
  @State private var checkIn: Date = Date()
  @State private var checkOut: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
  @State private var nightlyRateText: String = ""
  @State private var platformFeePct: Double = 0.14
  @State private var isPaid: Bool = false
  @State private var noteText: String = ""

  // Flight tracking
  @State private var flightNumberText: String = ""
  @State private var isCheckingFlight: Bool = false
  @State private var flightInfo: V4FlightInfo? = nil
  @State private var flightErrorMessage: String? = nil

  @State private var showValidationAlert: Bool = false
  @State private var validationMessage: String = ""
  @State private var showAddGuest: Bool = false

  // Derived
  private var selectedProperty: STProperty? {
    guard let id = propertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  private var selectedGuest: STGuest? {
    guard let id = guestID else { return nil }
    return guests.first(where: { $0.id == id })
  }

  private var propertyCurrencyCode: String {
    selectedProperty?.currencyCode ?? settings.reportingCurrencyCode
  }

  private var nightsCount: Int {
    max(0, V4Finance.nights(checkIn, checkOut))
  }

  private var nightlyRateValue: Double? {
    V4Format.parseNumber(nightlyRateText)
  }

  private var stayGross: Double? {
    guard let r = nightlyRateValue else { return nil }
    return Double(nightsCount) * r
  }

  private var overlappingBooking: STBooking? {
    guard let p = selectedProperty, checkOut > checkIn else { return nil }
    let excludeID: UUID? = {
      if case .edit(let b) = mode { return b.id }
      return nil
    }()
    return p.bookings.first {
      (excludeID == nil || $0.id != excludeID!) &&
      checkIn < $0.checkOut && checkOut > $0.checkIn
    }
  }

  var body: some View {
    NavigationStack {
      Form {

        if properties.isEmpty {
          Section {
            Text("No properties found. Add a property first (Settings → Properties).")
              .foregroundStyle(.secondary)
          }
        } else if guests.isEmpty {
          Section {
            Text("No guests found. Add a guest first (Guests tab).")
              .foregroundStyle(.secondary)
          }
        }

        Section("Property") {
          Picker("Property", selection: Binding(
            get: { propertyID ?? properties.first?.id },
            set: { propertyID = $0 }
          )) {
            ForEach(properties) { p in
              Text("\(p.emoji) \(p.name)").tag(Optional(p.id))
            }
          }
        }

        Section {
          Picker("Guest", selection: Binding(
            get: { guestID ?? guests.first?.id },
            set: { guestID = $0 }
          )) {
            ForEach(guests) { g in
              Text(g.name).tag(Optional(g.id))
            }
          }
        } header: {
          HStack {
            Text("Guest")
            Spacer()
            Button {
              showAddGuest = true
            } label: {
              Label("New Guest", systemImage: "person.badge.plus")
                .font(.caption.weight(.medium))
                .labelStyle(.titleAndIcon)
            }
          }
        }

        Section("Dates") {
          DatePicker("Check-in", selection: $checkIn, displayedComponents: .date)
          DatePicker("Check-out", selection: $checkOut, displayedComponents: .date)
          if nightsCount > 0 {
            HStack {
              Text("Duration")
              Spacer()
              Text("\(nightsCount) nights")
                .foregroundStyle(.secondary)
            }
          }
          if let clash = overlappingBooking {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
              VStack(alignment: .leading, spacing: 2) {
                Text("Overlapping booking")
                  .font(.footnote.weight(.medium))
                Text("\(clash.guest.name) · \(clash.checkIn.formatted(date: .abbreviated, time: .omitted)) – \(clash.checkOut.formatted(date: .abbreviated, time: .omitted))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 2)
          }
        }

        Section("Pricing") {
          HStack {
            Text("Nightly rate")
            Spacer()
            TextField("0", text: $nightlyRateText)
              .multilineTextAlignment(.trailing)
              .keyboardType(.decimalPad)
          }

          HStack {
            Text("Currency")
            Spacer()
            Text(propertyCurrencyCode)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Platform fee %")
            Spacer()
            Text("\(Int(round(platformFeePct * 100)))%")
              .foregroundStyle(.secondary)
          }
          Slider(value: $platformFeePct, in: 0...0.30, step: 0.01)

          if let gross = stayGross, nightsCount > 0 {
            HStack {
              Text("Stay total")
              Spacer()
              Text(V4Currency.format(gross, code: propertyCurrencyCode))
                .foregroundStyle(.secondary)
            }
          }

          Toggle("Paid", isOn: $isPaid)
        }

        Section("Notes") {
          TextField(
            "Host instructions, cleaning notes…",
            text: $noteText,
            axis: .vertical
          )
          .lineLimit(3...6)
        }

        Section {
          HStack(spacing: 10) {
            Image(systemName: "airplane")
              .foregroundStyle(.secondary)
            TextField("BA456", text: $flightNumberText)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .onChange(of: flightNumberText) { _, _ in
                flightInfo = nil
                flightErrorMessage = nil
              }
          }

          if !flightNumberText.trimmingCharacters(in: .whitespaces).isEmpty {
            if isCheckingFlight {
              HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Checking flight status...")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            } else if let info = flightInfo {
              flightStatusInline(info)
            } else if let err = flightErrorMessage {
              Label(err, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Button {
              Task { await checkFlightStatus() }
            } label: {
              Label("Check Flight Status", systemImage: "airplane.circle")
            }
            .disabled(isCheckingFlight || !store.isPremium)

            if !store.isPremium {
              Text("Flight tracking is a Premium feature.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } header: {
          Text("Guest Flight (optional)")
        } footer: {
          Text("Enter an IATA flight number to track delays and cancellations.")
            .font(.caption)
        }

        if case .edit(let booking) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(booking)
              do { try context.save() }
              catch { print("Delete booking save failed: \(error)") }
              dismiss()
            } label: {
              Text("Delete Booking")
            }
          }
        }
      }
      .navigationTitle(mode.title)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .font(.headline)
            .disabled(properties.isEmpty || guests.isEmpty)
        }
      }
      .onAppear { hydrateFromMode() }
      .alert("Cannot Save", isPresented: $showValidationAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text(validationMessage)
      }
      .sheet(isPresented: $showAddGuest) {
        V4GuestEditorSheet(mode: .add, onCreated: { newID in
          guestID = newID
        })
      }
    }
  }

  // MARK: - Hydrate

  private func hydrateFromMode() {
    switch mode {
    case .add(let initialProperty):
      propertyID = initialProperty?.id ?? properties.first?.id
      guestID = guests.first?.id
      nightlyRateText = ""
      platformFeePct = 0.14
      isPaid = false
      noteText = ""
      flightNumberText = ""
      flightInfo = nil
      flightErrorMessage = nil
      if let initial = initialCheckIn {
        checkIn  = Calendar.current.startOfDay(for: initial)
        checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
      }

    case .edit(let b):
      propertyID = b.property.id
      guestID = b.guest.id
      checkIn = b.checkIn
      checkOut = b.checkOut
      nightlyRateText = V4Format.plainNumber(b.nightlyRate)
      platformFeePct = b.platformFeePct
      isPaid = b.isPaid
      noteText = b.note ?? ""
      flightNumberText = b.flightNumber ?? ""
    }

    if checkOut <= checkIn {
      checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
    }
  }

  // MARK: - Save

  private func save() {
    guard !properties.isEmpty else { fail("Please add a property first."); return }
    guard !guests.isEmpty else { fail("Please add a guest first."); return }

    guard let p = selectedProperty else { fail("Please select a property."); return }
    guard let g = selectedGuest else { fail("Please select a guest."); return }
    guard checkOut > checkIn else { fail("Check-out must be after check-in."); return }

    guard let rate = V4Format.parseNumber(nightlyRateText), rate > 0 else {
      fail("Please enter a valid nightly rate.")
      return
    }

    if let clash = overlappingBooking {
      let dates = "\(clash.checkIn.formatted(date: .abbreviated, time: .omitted)) – \(clash.checkOut.formatted(date: .abbreviated, time: .omitted))"
      fail("\(p.name) is already booked by \(clash.guest.name) from \(dates). Adjust the dates to avoid the overlap.")
      return
    }

    let cleanNote: String? = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? nil
      : noteText.trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanFlight: String? = flightNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? nil
      : flightNumberText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    switch mode {
    case .add:
      let new = STBooking(
        id: UUID(),
        property: p,
        guest: g,
        checkIn: checkIn,
        checkOut: checkOut,
        nightlyRate: rate,
        platformFeePct: platformFeePct,
        isPaid: isPaid,
        note: cleanNote
      )
      context.insert(new)
      new.flightNumber = cleanFlight

    case .edit(let b):
      b.property = p
      b.guest = g
      b.checkIn = checkIn
      b.checkOut = checkOut
      b.nightlyRate = rate
      b.platformFeePct = platformFeePct
      b.isPaid = isPaid
      b.note = cleanNote
      b.flightNumber = cleanFlight
    }

    do {
      try context.save()
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      if case .add = mode { V4TelemetryManager.signal(.bookingCreated) }
      dismiss()
    } catch {
      fail("Save failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Flight

  private func checkFlightStatus() async {
    let number = flightNumberText.trimmingCharacters(in: .whitespaces)
    guard !number.isEmpty else { return }
    isCheckingFlight = true
    flightErrorMessage = nil
    flightInfo = nil
    do {
      let info = try await V4FlightManager.checkFlight(number)
      flightInfo = info
    } catch {
      flightErrorMessage = error.localizedDescription
    }
    isCheckingFlight = false
  }

  @ViewBuilder
  private func flightStatusInline(_ info: V4FlightInfo) -> some View {
    HStack(spacing: 8) {
      Image(systemName: info.isCancelled ? "xmark.circle.fill" :
                        info.isLanded    ? "checkmark.circle.fill" :
                        info.isDelayed   ? "exclamationmark.triangle.fill" :
                                           "airplane.circle.fill")
        .foregroundStyle(info.isCancelled ? Color.red :
                         info.isLanded    ? Color.green :
                         info.isDelayed   ? Color.orange :
                                            Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(info.flightNumber).font(.caption.weight(.semibold))
          Text(info.statusLabel).font(.caption).foregroundStyle(.secondary)
          if info.isDelayed {
            Text(info.delayLabel)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.orange)
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.orange.opacity(0.12), in: Capsule())
          }
        }
        if !info.origin.isEmpty || !info.destination.isEmpty {
          Text("\(info.origin) -> \(info.destination)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 2)
  }

  private func fail(_ msg: String) {
    validationMessage = msg
    showValidationAlert = true
  }
}
