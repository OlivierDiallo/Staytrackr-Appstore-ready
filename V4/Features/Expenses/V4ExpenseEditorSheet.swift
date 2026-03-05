import SwiftUI
import SwiftData

struct V4ExpenseEditorSheet: View {

  // MARK: - Mode

  enum Mode: Equatable {
    case add(initialProperty: STProperty?)
    case edit(expense: STExpense)

    var title: String {
      switch self {
      case .add: return "Add Expense"
      case .edit: return "Edit Expense"
      }
    }
  }

  // MARK: - Environment

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Environment(V4AppSettings.self) private var settings

  @Query(sort: \STProperty.name) private var properties: [STProperty]

  let mode: Mode

  // MARK: - Form state

  @State private var propertyID: UUID?
  @State private var date: Date = Date()
  @State private var category: STExpenseCategory = .utilities
  @State private var amountText: String = ""
  @State private var note: String = ""

  /// Optional override. If empty, we fall back to property currency.
  @State private var currencyCode: String = ""

  @State private var showValidationAlert: Bool = false
  @State private var validationMessage: String = ""

  // MARK: - Derived

  private var selectedProperty: STProperty? {
    guard let id = propertyID else { return nil }
    return properties.first(where: { $0.id == id })
  }

  private var finalCurrency: String {
    let trimmed = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed.uppercased() }
    if let p = selectedProperty { return p.currencyCode }
    return settings.reportingCurrencyCode
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      Form {

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

        Section("Details") {
          DatePicker("Date", selection: $date, displayedComponents: .date)

          Picker("Category", selection: $category) {
            ForEach(STExpenseCategory.allCases, id: \.self) { c in
              Text(c.rawValue.capitalized).tag(c)
            }
          }

          HStack {
            Text("Amount")
            Spacer()
            TextField("0", text: $amountText)
              .multilineTextAlignment(.trailing)
              .keyboardType(.decimalPad)
          }

          HStack {
            Text("Currency")
            Spacer()
            TextField(finalCurrency, text: $currencyCode)
              .multilineTextAlignment(.trailing)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .foregroundStyle(.secondary)
              .frame(maxWidth: 120)
          }

          Text("Leave currency empty to use the property currency.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Note") {
          TextField("Optional", text: $note, axis: .vertical)
            .lineLimit(3...6)
        }

        if case .edit(let e) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(e)
              try? context.save()
              dismiss()
            } label: {
              Text("Delete Expense")
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
        }
      }
      .onAppear { hydrateFromMode() }
      .alert("Cannot Save", isPresented: $showValidationAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text(validationMessage)
      }
    }
  }

  // MARK: - Hydrate

  private func hydrateFromMode() {
    switch mode {
    case .add(let initialProperty):
      propertyID = initialProperty?.id ?? properties.first?.id
      date = Date()
      category = .utilities
      amountText = ""
      note = ""
      currencyCode = "" // empty => default to property currency

    case .edit(let e):
      propertyID = e.property.id
      date = e.date
      category = e.category
      amountText = V4Format.plainNumber(e.amount)
      note = e.note ?? ""
      currencyCode = e.currencyCode // keep original currency visible/editable
    }
  }

  // MARK: - Save

  private func save() {
    guard let p = selectedProperty else {
      fail("Please select a property.")
      return
    }

    guard let amount = V4Format.parseNumber(amountText), amount > 0 else {
      fail("Please enter a valid amount.")
      return
    }

    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let finalNote: String? = trimmedNote.isEmpty ? nil : trimmedNote

    switch mode {
    case .add:
      let e = STExpense(
        id: UUID(),
        property: p,
        date: date,
        amount: amount,
        category: category,
        note: finalNote, currencyCode: finalCurrency
      )
      context.insert(e)

    case .edit(let e):
      e.property = p
      e.date = date
      e.amount = amount
      e.category = category
      e.currencyCode = finalCurrency
      e.note = finalNote
    }

    do {
      try context.save()
      dismiss()
    } catch {
      fail("Save failed: \(error.localizedDescription)")
    }
  }

  private func fail(_ msg: String) {
    validationMessage = msg
    showValidationAlert = true
  }
}
