import SwiftUI
import SwiftData

struct V4FXRatesView: View {
  @Environment(\.modelContext) private var context

  @Query(sort: \STFXRate.fromCode) private var rates: [STFXRate]

  @State private var showAdd = false
  @State private var editRate: STFXRate? = nil

  var body: some View {
    List {
      Section("Rates") {
        if rates.isEmpty {
          Text("No FX rates yet.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(rates) { r in
            Button {
              editRate = r
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(r.fromCode) → \(r.toCode)")
                    .font(.headline)
                  Text("1 \(r.fromCode) = \(r.rate, format: .number.precision(.fractionLength(6))) \(r.toCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(r.updatedAt, style: .date)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
          }
          .onDelete(perform: deleteRates)
        }
      }
    }
    .navigationTitle("FX Rates")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showAdd = true } label: { Image(systemName: "plus") }
      }
    }
    .sheet(isPresented: $showAdd) {
      NavigationStack {
        FXRateEditor(mode: .add)
      }
      .presentationDetents([.medium])
    }
    .sheet(item: $editRate) { rate in
      NavigationStack {
        FXRateEditor(mode: .edit(rate))
      }
      .presentationDetents([.medium])
    }
  }

  private func deleteRates(_ indexSet: IndexSet) {
    for i in indexSet {
      context.delete(rates[i])
    }
    try? context.save()
  }

  // MARK: - Editor

  private struct FXRateEditor: View {
    enum Mode {
      case add
      case edit(STFXRate)

      var title: String {
        switch self {
        case .add: return "Add FX Rate"
        case .edit: return "Edit FX Rate"
        }
      }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let mode: Mode

    @State private var fromCode: String = "EUR"
    @State private var toCode: String = "CZK"
    @State private var rateText: String = "25.0"
    @State private var showAlert = false
    @State private var alertMsg = ""

    var body: some View {
      Form {
        Section("Pair") {
          TextField("From (e.g. EUR)", text: $fromCode)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()

          TextField("To (e.g. CZK)", text: $toCode)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        }

        Section("Rate") {
          TextField("Rate", text: $rateText)
            .keyboardType(.decimalPad)
          Text("Meaning: 1 FROM = RATE TO")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if case .edit(let existing) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(existing)
              try? context.save()
              dismiss()
            } label: {
              Text("Delete Rate")
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
      .onAppear { hydrate() }
      .alert("Cannot Save", isPresented: $showAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(alertMsg)
      }
    }

    private func hydrate() {
      switch mode {
      case .add:
        break
      case .edit(let r):
        fromCode = r.fromCode
        toCode = r.toCode
        rateText = String(r.rate)
      }
    }

    private func save() {
      let from = fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      let to = toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

      guard from.count == 3, to.count == 3 else {
        fail("Currency codes must be 3 letters (EUR, CZK, USD...).")
        return
      }

      let cleaned = rateText.replacingOccurrences(of: ",", with: ".")
      guard let rate = Double(cleaned), rate > 0 else {
        fail("Enter a valid positive number for the rate.")
        return
      }

      switch mode {
      case .add:
        let r = STFXRate(fromCode: from, toCode: to, rate: rate)
        context.insert(r)

      case .edit(let existing):
        existing.fromCode = from
        existing.toCode = to
        existing.rate = rate
        existing.updatedAt = Date()
      }

      do {
        try context.save()
        dismiss()
      } catch {
        fail("Save failed: \(error.localizedDescription)")
      }
    }

    private func fail(_ msg: String) {
      alertMsg = msg
      showAlert = true
    }
  }
}
