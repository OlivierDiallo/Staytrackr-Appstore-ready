//
//  V4PropertiesListView.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 12.01.2026.
//
import SwiftUI
import SwiftData

// MARK: - Properties List

struct V4PropertiesListView: View {
  let prefs: V4AppPreferences

  @Environment(\.modelContext) private var context
  @Environment(STStoreManager.self) private var store
  @Query(sort: \STProperty.name) private var properties: [STProperty]

  @State private var showingAdd = false
  @State private var showPaywall = false
  @State private var showProLimit = false
  @State private var propertyToDelete: STProperty?
  @State private var showDeleteConfirmation = false

  var body: some View {
    List {
      Section {
        if properties.isEmpty {
          Text("No properties yet. Tap + to add one.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(properties, id: \.id) { p in
            NavigationLink {
              V4PropertyDetailView(property: p, prefs: prefs)
            } label: {
              HStack(spacing: 10) {
                Circle()
                  .fill(V4Color.hex(p.colorHex))
                  .frame(width: 10, height: 10)
                Text("\(p.emoji) \(p.name)")
                  .font(.headline)
                Spacer()
                Text(p.currencyCode)
                  .foregroundStyle(.secondary)
                if p.isArchived {
                  Text("Archived")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                }
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                propertyToDelete = p
                showDeleteConfirmation = true
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
              Button {
                p.isArchived.toggle()
                if p.isArchived, prefs.selectedPropertyID == p.id {
                  prefs.selectedPropertyID = nil
                }
                do { try context.save() }
                catch { print("Archive toggle save failed: \(error)") }
              } label: {
                Label(p.isArchived ? "Unarchive" : "Archive",
                      systemImage: p.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
              }
              .tint(p.isArchived ? .green : .orange)
            }
          }
        }
      } header: {
        Text("Properties")
      } footer: {
        Text("Archiving hides a property from pickers and dashboards without deleting its data.")
      }
    }
    .navigationTitle("Properties")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          if properties.count >= 1 && !store.isPremium {
            showPaywall = true
          } else if properties.count >= 20 && store.isPremium {
            showProLimit = true
          } else {
            showingAdd = true
          }
        } label: { Image(systemName: "plus") }
          .accessibilityLabel("Add property")
      }
    }
    .sheet(isPresented: $showingAdd) {
      V4PropertyEditorSheet(mode: .add, propertyToEdit: nil)
    }
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
    .alert("Property Limit Reached", isPresented: $showProLimit) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("Premium supports up to 20 properties. A Pro plan with unlimited properties is coming soon.")
    }
    .alert("Delete Property?", isPresented: $showDeleteConfirmation, presenting: propertyToDelete) { p in
      Button("Delete", role: .destructive) { confirmDelete(p) }
      Button("Cancel", role: .cancel) { propertyToDelete = nil }
    } message: { p in
      let bookings = p.bookings.count
      let expenses = p.expenses.count
      let bills    = p.recurringBills.count
      let parts: [String] = [
        bookings > 0 ? String(localized: "\(bookings) bookings") : nil,
        expenses > 0 ? String(localized: "\(expenses) expenses") : nil,
        bills    > 0 ? String(localized: "\(bills) recurring bills") : nil
      ].compactMap { $0 }

      if parts.isEmpty {
        Text("\"\(p.emoji) \(p.name)\" has no associated data and will be permanently removed.")
      } else {
        Text("\"\(p.emoji) \(p.name)\" will be permanently deleted along with \(parts.joined(separator: ", ")).")
      }
    }
  }

  private func confirmDelete(_ p: STProperty) {
    if prefs.selectedPropertyID == p.id { prefs.selectedPropertyID = nil }
    context.delete(p)
    do { try context.save() }
    catch { print("Delete property save failed: \(error)") }
    propertyToDelete = nil
  }
}

// MARK: - Property Detail View

struct V4PropertyDetailView: View {
  let property: STProperty
  let prefs: V4AppPreferences

  @State private var showEdit = false

  private var sortedBookings: [STBooking] {
    property.bookings.sorted { $0.checkIn > $1.checkIn }
  }

  private var sortedExpenses: [STExpense] {
    property.expenses.sorted { $0.date > $1.date }
  }

  private var totalNights: Int {
    sortedBookings.reduce(0) { $0 + V4Finance.nights($1.checkIn, $1.checkOut) }
  }

  private var grossRevenue: Double {
    sortedBookings.reduce(0) { acc, b in
      acc + Double(V4Finance.nights(b.checkIn, b.checkOut)) * b.nightlyRate
    }
  }

  private var totalExpenses: Double {
    sortedExpenses
      .filter { $0.currencyCode == property.currencyCode }
      .reduce(0) { $0 + $1.amount }
  }

  /// Standard fixed-rate mortgage monthly payment (PMT).
  private var monthlyMortgagePayment: Double {
    let p = property.purchasePrice
    let apr = property.mortgageAPR
    let years = property.mortgageYears
    guard p > 0, apr > 0, years > 0 else { return 0 }
    let r = apr / 12
    let n = Double(years * 12)
    return p * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
  }

  private var totalInterestPaid: Double {
    let monthly = monthlyMortgagePayment
    guard monthly > 0 else { return 0 }
    return monthly * Double(property.mortgageYears * 12) - property.purchasePrice
  }

  private var netReturn: Double { grossRevenue - totalExpenses }

  private var netReturnPct: Double {
    guard property.purchasePrice > 0 else { return 0 }
    return netReturn / property.purchasePrice * 100
  }

  var body: some View {
    List {

      // Summary card
      Section {
        summaryCard
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }

      // Mortgage
      if property.trackMortgage && property.purchasePrice > 0 {
        Section {
          detailRow("Purchase price",
                    V4Currency.format(property.purchasePrice, code: property.currencyCode))
          detailRow("Monthly payment",
                    V4Currency.format(monthlyMortgagePayment, code: property.currencyCode),
                    bold: true)
          detailRow("APR", String(format: "%.2f%%", property.mortgageAPR * 100))
          detailRow("Term", String(localized: "\(property.mortgageYears) years"))
          detailRow("Total interest",
                    V4Currency.format(totalInterestPaid, code: property.currencyCode),
                    color: .red)
        } header: {
          Label("Mortgage", systemImage: "house.circle")
        }
      }

      // Return on investment
      if property.purchasePrice > 0 {
        Section {
          detailRow("Purchase price",
                    V4Currency.format(property.purchasePrice, code: property.currencyCode))
          detailRow("All-time net",
                    V4Currency.format(netReturn, code: property.currencyCode),
                    color: netReturn >= 0 ? V4Theme.Brand.primary : .red)
          detailRow("Net ROI",
                    String(format: "%.1f%%", netReturnPct),
                    color: netReturnPct >= 0 ? V4Theme.Brand.primary : .red,
                    bold: true)
          detailRow("Commission", "\(Int(round(property.commissionPct * 100)))%")
        } header: {
          Label("Return", systemImage: "chart.line.uptrend.xyaxis")
        } footer: {
          Text("ROI = all-time net revenue ÷ purchase price. Not annualised.")
            .font(.caption2)
        }
      }

      // Bookings
      Section("Bookings (\(sortedBookings.count))") {
        if sortedBookings.isEmpty {
          Text("No bookings yet.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(sortedBookings) { b in
            bookingRow(b)
          }
        }
      }

      // Expenses
      Section("Expenses (\(sortedExpenses.count))") {
        if sortedExpenses.isEmpty {
          Text("No expenses yet.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(sortedExpenses) { e in
            expenseRow(e)
          }
        }
      }
    }
    .navigationTitle("\(property.emoji) \(property.name)")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") { showEdit = true }
      }
    }
    .sheet(isPresented: $showEdit) {
      V4PropertyEditorSheet(mode: .edit, propertyToEdit: property)
    }
  }

  // MARK: Summary Card

  private var summaryCard: some View {
    V4Card {
      VStack(spacing: 10) {
        // Property header
        HStack(spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(V4Color.hex(property.colorHex).opacity(0.15))
              .frame(width: 46, height: 46)
            Text(property.emoji)
              .font(.title2)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(property.name)
              .font(.headline)
            HStack(spacing: 8) {
              Text(property.currencyCode)
                .font(.caption)
                .foregroundStyle(.secondary)
              if property.isArchived {
                Text("Archived")
                  .font(.caption2.weight(.medium))
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 2)
                  .overlay(Capsule().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
              }
            }
          }
          Spacer()
          Circle()
            .fill(V4Color.hex(property.colorHex))
            .frame(width: 14, height: 14)
        }

        Divider().opacity(0.4)

        // Financial metrics
        metricRow(title: "Revenue",
                  value: V4Currency.format(grossRevenue, code: property.currencyCode),
                  color: V4Theme.Brand.primary)
        metricRow(title: "Expenses",
                  value: V4Currency.format(totalExpenses, code: property.currencyCode),
                  color: .red)
        Divider().opacity(0.3)
        let net = grossRevenue - totalExpenses
        metricRow(title: "Net",
                  value: V4Currency.format(net, code: property.currencyCode),
                  color: net >= 0 ? V4Theme.Brand.primary : .red)

        Divider().opacity(0.25)

        HStack {
          Text("Bookings").foregroundStyle(.secondary)
          Spacer()
          Text("\(sortedBookings.count)").font(.headline)
        }
        HStack {
          Text("Total nights").foregroundStyle(.secondary)
          Spacer()
          Text("\(totalNights)").font(.headline)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  private func metricRow(title: LocalizedStringKey, value: String, color: Color) -> some View {
    HStack {
      Text(title).foregroundStyle(.secondary)
      Spacer()
      Text(value).font(.headline).foregroundStyle(color)
    }
  }

  /// Plain key-value row used in Mortgage and Return sections.
  private func detailRow(_ label: LocalizedStringKey, _ value: String,
                          color: Color = .primary, bold: Bool = false) -> some View {
    HStack {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(bold ? .subheadline.weight(.semibold) : .subheadline)
        .foregroundStyle(color)
    }
  }

  // MARK: Booking Row

  private func bookingRow(_ b: STBooking) -> some View {
    let nights = V4Finance.nights(b.checkIn, b.checkOut)
    let gross  = Double(nights) * b.nightlyRate

    return HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(b.guest.name)
          .font(.subheadline.weight(.semibold))
        Text("\(b.checkIn.formatted(date: .abbreviated, time: .omitted)) → \(b.checkOut.formatted(date: .abbreviated, time: .omitted))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(V4Currency.format(gross, code: property.currencyCode))
          .font(.subheadline.weight(.semibold))
        Text(b.isPaid ? "Paid" : "Unpaid")
          .font(.caption2.weight(.medium))
          .foregroundStyle(b.isPaid ? V4Theme.Brand.primary : .orange)
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: Expense Row

  private func expenseRow(_ e: STExpense) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(e.category.displayName)
          .font(.subheadline.weight(.semibold))
        if let note = e.note, !note.isEmpty {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(V4Currency.format(e.amount, code: e.currencyCode))
          .font(.subheadline.weight(.semibold))
        Text(e.date.formatted(date: .numeric, time: .omitted))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}
