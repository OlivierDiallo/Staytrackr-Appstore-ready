import SwiftUI
import SwiftData

struct V4ExpensesView: View {
  let prefs: V4AppPreferences

  @Environment(\.modelContext) private var context

  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STExpense.date, order: .reverse) private var expenses: [STExpense]

  @State private var showAdd = false
  @State private var expenseToEdit: STExpense?

  // Date filter
  @State private var filterMode: ExpenseDateFilter = .allTime
  @State private var referenceDate: Date = .now

  private let cal = Calendar.current

  // MARK: - Filter

  enum ExpenseDateFilter: String, CaseIterable {
    case allTime  = "All Time"
    case monthly  = "Month"
    case yearly   = "Year"

    var label: LocalizedStringKey { LocalizedStringKey(rawValue) }
  }

  private var periodRange: (start: Date, end: Date)? {
    switch filterMode {
    case .allTime: return nil
    case .monthly:
      guard let start = cal.date(from: cal.dateComponents([.year, .month], from: referenceDate)),
            let end   = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
      return (start, end)
    case .yearly:
      guard let start = cal.date(from: cal.dateComponents([.year], from: referenceDate)),
            let end   = cal.date(byAdding: .year, value: 1, to: start) else { return nil }
      return (start, end)
    }
  }

  private var periodLabel: String {
    switch filterMode {
    case .allTime: return String(localized: "All Time")
    case .monthly: return referenceDate.formatted(.dateTime.month(.wide).year())
    case .yearly:  return referenceDate.formatted(.dateTime.year())
    }
  }

  private func stepBack() {
    switch filterMode {
    case .allTime: break
    case .monthly: referenceDate = cal.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
    case .yearly:  referenceDate = cal.date(byAdding: .year,  value: -1, to: referenceDate) ?? referenceDate
    }
  }

  private func stepForward() {
    switch filterMode {
    case .allTime: break
    case .monthly: referenceDate = cal.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
    case .yearly:  referenceDate = cal.date(byAdding: .year,  value: 1, to: referenceDate) ?? referenceDate
    }
  }

  // MARK: - Data

  private var selectedProperty: STProperty? {
    guard let id = prefs.selectedPropertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  private func effectiveCurrencyCode(for e: STExpense) -> String {
    let code = e.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
    return code.isEmpty ? e.property.currencyCode : code
  }

  private var filteredExpenses: [STExpense] {
    var result: [STExpense] = expenses

    // Property filter
    if let p = selectedProperty {
      result = result.filter { $0.property.id == p.id }
    }

    // Date range filter
    if let range = periodRange {
      result = result.filter { $0.date >= range.start && $0.date < range.end }
    }

    return result
  }

  private var totalsByCurrency: [(code: String, total: Double)] {
    var dict: [String: Double] = [:]
    for e in filteredExpenses {
      let code = effectiveCurrencyCode(for: e)
      dict[code, default: 0] += e.amount
    }
    return dict.keys.sorted().map { ($0, dict[$0] ?? 0) }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      List {
        // Property filter
        Section {
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
              Text(selectedProperty.map { $0.name } ?? String(localized: "All Properties"))
                .lineLimit(1)
              Spacer()
              Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }

        // Date range filter
        Section {
          Picker("Period", selection: $filterMode) {
            ForEach(ExpenseDateFilter.allCases, id: \.self) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

          if filterMode != .allTime {
            HStack {
              Button {
                withAnimation(.easeInOut(duration: 0.15)) { stepBack() }
              } label: {
                Image(systemName: "chevron.left")
                  .font(.system(size: 13, weight: .semibold))
                  .frame(width: 30, height: 30)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)

              Spacer()
              Text(periodLabel)
                .font(.subheadline.weight(.semibold))
              Spacer()

              Button {
                withAnimation(.easeInOut(duration: 0.15)) { stepForward() }
              } label: {
                Image(systemName: "chevron.right")
                  .font(.system(size: 13, weight: .semibold))
                  .frame(width: 30, height: 30)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
        }

        // Total
        Section {
          HStack {
            Text("Total")
              .foregroundStyle(.secondary)
            Spacer()
            if totalsByCurrency.isEmpty {
              Text("—").foregroundStyle(.secondary)
            } else if totalsByCurrency.count == 1, let t = totalsByCurrency.first {
              Text(V4Currency.format(t.total, code: t.code))
                .font(.headline)
            } else {
              VStack(alignment: .trailing, spacing: 4) {
                ForEach(totalsByCurrency, id: \.code) { t in
                  Text(V4Currency.format(t.total, code: t.code))
                    .font(.headline)
                }
              }
            }
          }
        }

        // Expenses list
        Section {
          if filteredExpenses.isEmpty {
            HStack(spacing: 14) {
              Image(systemName: filterMode == .allTime ? "creditcard.slash" : "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 3) {
                Text(filterMode == .allTime ? "No expenses yet" : "No expenses")
                  .font(.subheadline.weight(.medium))
                Text(filterMode == .allTime
                     ? "Tap + to log your first expense."
                     : "No expenses recorded in this period.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
          } else {
            ForEach(filteredExpenses) { e in
              Button {
                expenseToEdit = e
              } label: {
                expenseRow(e)
              }
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                  deleteExpense(e)
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .refreshable {
        // SwiftData @Query auto-updates; reset reference date to today on pull
        withAnimation { referenceDate = .now }
      }
      .navigationTitle("Expenses")
      .toolbar {
        if filterMode != .allTime {
          ToolbarItem(placement: .topBarLeading) {
            Button("Today") {
              withAnimation { referenceDate = .now }
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { showAdd = true } label: { Image(systemName: "plus") }
        }
      }
      .sheet(isPresented: $showAdd) {
        V4ExpenseEditorSheet(mode: .add(initialProperty: selectedProperty))
      }
      .sheet(item: $expenseToEdit) { e in
        V4ExpenseEditorSheet(mode: .edit(expense: e))
      }
    }
  }

  // MARK: - Row

  private func expenseRow(_ e: STExpense) -> some View {
    let code = effectiveCurrencyCode(for: e)
    return HStack {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(e.category.displayName)
            .font(.subheadline.weight(.semibold))
          if e.receiptData != nil {
            Image(systemName: "camera.fill")
              .font(.caption2)
              .foregroundStyle(V4Theme.Brand.primary)
          }
        }
        Text(e.property.name)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let note = e.note, !note.isEmpty {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(V4Currency.format(e.amount, code: code))
          .font(.subheadline.weight(.semibold))
        Text(e.date.formatted(date: .numeric, time: .omitted))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: - Delete

  private func deleteExpense(_ e: STExpense) {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    context.delete(e)
    do { try context.save() }
    catch { print("Delete expense save failed: \(error)") }
  }
}
