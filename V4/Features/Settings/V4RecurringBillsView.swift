import SwiftUI
import SwiftData

// MARK: - Recurring Bills List

struct V4RecurringBillsView: View {
  @Environment(\.modelContext) private var context
  @Environment(STStoreManager.self) private var store

  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Query(sort: \STRecurringBill.name) private var bills: [STRecurringBill]

  @State private var showAdd = false
  @State private var showPaywall = false
  @State private var billToEdit: STRecurringBill?
  @State private var billToApply: STRecurringBill?
  @State private var showApplyAlert = false

  var body: some View {
    Group {
      if store.isPremium {
        List { listContent }
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button { showAdd = true } label: { Image(systemName: "plus") }
            }
          }
          .sheet(isPresented: $showAdd) { V4RecurringBillEditorSheet(mode: .add) }
          .sheet(item: $billToEdit) { V4RecurringBillEditorSheet(mode: .edit($0)) }
          .alert("Add as Expense?", isPresented: $showApplyAlert, presenting: billToApply) { bill in
            Button("Add Expense") { applyBill(bill) }
            Button("Cancel", role: .cancel) { billToApply = nil }
          } message: { bill in
            Text(applyAlertMessage(for: bill))
          }
      } else {
        VStack(spacing: 24) {
          Spacer()
          Image(systemName: "repeat.circle.fill")
            .font(.system(size: 52))
            .foregroundStyle(V4Theme.Brand.primary.opacity(0.4))
          VStack(spacing: 8) {
            Text("Recurring Bills")
              .font(.title3.weight(.semibold))
            Text("Set up monthly bills that auto-apply\nas expenses. Available with Premium.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }
          Button {
            showPaywall = true
          } label: {
            Label("Unlock with Premium", systemImage: "lock.open.fill")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(V4Theme.Brand.primary,
                          in: RoundedRectangle(cornerRadius: 14, style: .continuous))
              .padding(.horizontal, 40)
          }
          Spacer()
        }
      }
    }
    .navigationTitle("Recurring Bills")
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
  }

  @ViewBuilder
  private var listContent: some View {
    if bills.isEmpty {
      Section {
        Text("No recurring bills yet. Tap + to add one.")
          .foregroundStyle(.secondary)
      }
    } else {
      ForEach(properties.filter { p in bills.contains(where: { $0.property.id == p.id }) }) { p in
        let propBills = bills.filter { $0.property.id == p.id }
        Section("\(p.emoji) \(p.name)") {
          ForEach(propBills) { b in
            billListRow(b, property: p)
          }
        }
      }
    }
  }

  private func billListRow(_ b: STRecurringBill, property p: STProperty) -> some View {
    Button { billToEdit = b } label: { billRow(b, currency: p.currencyCode) }
      .buttonStyle(.plain)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) { deleteBill(b) } label: {
          Label("Delete", systemImage: "trash")
        }
        Button {
          billToApply = b
          showApplyAlert = true
        } label: {
          Label("Apply", systemImage: "plus.circle.fill")
        }
        .tint(.teal)
      }
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        Button {
          b.isActive.toggle()
          try? context.save()
        } label: {
          Label(b.isActive ? "Disable" : "Enable",
                systemImage: b.isActive ? "pause.circle" : "play.circle")
        }
        .tint(b.isActive ? .orange : .green)
      }
  }

  private func billRow(_ b: STRecurringBill, currency: String) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(b.name)
            .font(.subheadline.weight(.semibold))
          if !b.isActive {
            Text("Inactive")
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .overlay(Capsule().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
          }
        }
        (Text(b.category.displayName) + Text(" · ") + Text("Day \(b.dayOfMonth)"))
          .font(.caption)
          .foregroundStyle(.secondary)
        if let note = b.note, !note.isEmpty {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Text(V4Currency.format(b.amount, code: currency))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(b.isActive ? .primary : .secondary)
    }
    .padding(.vertical, 4)
    .opacity(b.isActive ? 1 : 0.6)
  }

  private func deleteBill(_ b: STRecurringBill) {
    context.delete(b)
    do { try context.save() }
    catch { print("Delete recurring bill failed: \(error)") }
  }

  private func applyAlertMessage(for b: STRecurringBill) -> String {
    let cal = Calendar.current
    let now = Date()
    let lastDay = (cal.range(of: .day, in: .month, for: now)?.upperBound ?? 29) - 1
    let day = min(b.dayOfMonth, lastDay)
    let comps = DateComponents(
      year: cal.component(.year, from: now),
      month: cal.component(.month, from: now),
      day: day
    )
    let dateStr = (cal.date(from: comps) ?? now).formatted(date: .abbreviated, time: .omitted)
    let amount = V4Currency.format(b.amount, code: b.property.currencyCode)
    return String(localized: "Create a \(b.category.localizedName) expense of \(amount) for \(b.property.emoji) \(b.property.name), dated \(dateStr)?")
  }

  private func applyBill(_ b: STRecurringBill) {
    let cal = Calendar.current
    let now = Date()
    let lastDay = (cal.range(of: .day, in: .month, for: now)?.upperBound ?? 29) - 1
    let day = min(b.dayOfMonth, lastDay)
    let comps = DateComponents(
      year: cal.component(.year, from: now),
      month: cal.component(.month, from: now),
      day: day
    )
    let expenseDate = cal.date(from: comps) ?? now

    let expense = STExpense(
      id: UUID(),
      property: b.property,
      date: expenseDate,
      amount: b.amount,
      category: b.category,
      note: b.name,
      currencyCode: b.property.currencyCode
    )
    context.insert(expense)
    do {
      try context.save()
      billToApply = nil
    } catch {
      print("Apply bill as expense failed: \(error)")
    }
  }
}

// MARK: - Recurring Bill Editor Sheet

struct V4RecurringBillEditorSheet: View {
  enum Mode {
    case add
    case edit(STRecurringBill)

    var title: LocalizedStringKey {
      switch self { case .add: "Add Bill"; case .edit: "Edit Bill" }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context

  @Query(sort: \STProperty.name) private var properties: [STProperty]

  let mode: Mode

  @State private var propertyID: UUID?
  @State private var name: String = ""
  @State private var amountText: String = ""
  @State private var category: STExpenseCategory = .utilities
  @State private var dayOfMonth: Int = 1
  @State private var note: String = ""
  @State private var isActive: Bool = true

  @State private var showAlert = false
  @State private var alertMsg = ""

  private var selectedProperty: STProperty? {
    guard let id = propertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Property") {
          Picker("Property", selection: Binding(
            get: { propertyID ?? properties.first?.id },
            set: { propertyID = $0 }
          )) {
            ForEach(properties.filter { !$0.isArchived }) { p in
              Text("\(p.emoji) \(p.name)").tag(Optional(p.id))
            }
          }
        }

        Section("Details") {
          TextField("Bill name (e.g. Electricity)", text: $name)

          Picker("Category", selection: $category) {
            ForEach(STExpenseCategory.allCases) { c in
              Text(c.displayName).tag(c)
            }
          }

          HStack {
            Text("Amount")
            Spacer()
            TextField("0", text: $amountText)
              .multilineTextAlignment(.trailing)
              .keyboardType(.decimalPad)
          }

          if let p = selectedProperty {
            HStack {
              Text("Currency")
              Spacer()
              Text(p.currencyCode)
                .foregroundStyle(.secondary)
            }
          }

          Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)
        }

        Section("Note") {
          TextField("Optional", text: $note, axis: .vertical)
            .lineLimit(2...4)
        }

        Section {
          Toggle("Active", isOn: $isActive)
        }

        if case .edit(let b) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(b)
              try? context.save()
              dismiss()
            } label: { Text("Delete Bill") }
          }
        }
      }
      .navigationTitle(mode.title)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .font(.headline)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || properties.isEmpty)
        }
      }
      .onAppear { hydrate() }
      .alert("Cannot Save", isPresented: $showAlert) {
        Button("OK", role: .cancel) {}
      } message: { Text(alertMsg) }
    }
  }

  private func hydrate() {
    switch mode {
    case .add:
      propertyID = properties.first?.id
    case .edit(let b):
      propertyID = b.property.id
      name = b.name
      amountText = V4Format.plainNumber(b.amount)
      category = b.category
      dayOfMonth = b.dayOfMonth
      note = b.note ?? ""
      isActive = b.isActive
    }
  }

  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else { fail("Please enter a bill name."); return }
    guard let p = selectedProperty else { fail("Please select a property."); return }
    guard let amount = V4Format.parseNumber(amountText), amount > 0 else {
      fail("Please enter a valid amount.")
      return
    }

    let cleanNote: String? = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)

    switch mode {
    case .add:
      let b = STRecurringBill(
        id: UUID(), property: p, name: cleanName, amount: amount,
        category: category, dayOfMonth: dayOfMonth, note: cleanNote, isActive: isActive
      )
      context.insert(b)

    case .edit(let b):
      b.property = p
      b.name = cleanName
      b.amount = amount
      b.category = category
      b.dayOfMonth = dayOfMonth
      b.note = cleanNote
      b.isActive = isActive
    }

    do {
      try context.save()
      dismiss()
    } catch {
      fail("Save failed: \(error.localizedDescription)")
    }
  }

  private func fail(_ msg: String) { alertMsg = msg; showAlert = true }
}
