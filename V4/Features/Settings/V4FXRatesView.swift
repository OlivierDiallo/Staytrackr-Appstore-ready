import SwiftUI
import SwiftData

struct V4FXRatesView: View {
  @Environment(\.modelContext) private var context

  @Query(sort: \STFXRate.fromCode) private var rates: [STFXRate]

  @State private var showAdd = false
  @State private var editRate: STFXRate? = nil
  @State private var isRefreshing = false
  @State private var refreshError: String? = nil
  @State private var lastRefreshCount: Int? = nil

  private var lastSynced: Date? {
    rates.map(\.updatedAt).max()
  }

  var body: some View {
    List {
      // Live rates banner
      if !rates.isEmpty {
        Section {
          HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
              .foregroundStyle(V4Theme.Brand.primary)
              .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
              Text("Live Rates")
                .font(.subheadline.weight(.semibold))
              if let last = lastSynced {
                Text("Last synced \(last.formatted(.relative(presentation: .named)))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              } else {
                Text("Tap refresh to fetch live rates")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            if isRefreshing {
              ProgressView().scaleEffect(0.8)
            } else {
              Button {
                Task { await refreshRates() }
              } label: {
                Text("Refresh")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(V4Theme.Brand.primary)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(V4Theme.Brand.primary.opacity(0.10), in: Capsule())
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 4)
        } footer: {
          if let err = refreshError {
            Label(err, systemImage: "exclamationmark.triangle")
              .font(.caption)
              .foregroundStyle(.orange)
          } else if let count = lastRefreshCount {
            Text("\(count) rate\(count == 1 ? "" : "s") updated from ECB via frankfurter.app")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Text("Rates sourced from the European Central Bank (ECB), updated daily.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      Section("Rates") {
        if rates.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("No FX rates yet.")
              .foregroundStyle(.secondary)
            Text("Add a rate manually or tap Refresh once you have a pair added.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        } else {
          ForEach(rates) { r in
            Button {
              editRate = r
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(r.fromCode) → \(r.toCode)")
                    .font(.headline)
                  Text("1 \(r.fromCode) = \(r.rate, format: .number.precision(.fractionLength(4))) \(r.toCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(r.updatedAt, style: .date)
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
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
    .task {
      // Auto-refresh if rates are stale (older than 24 hours)
      guard !rates.isEmpty else { return }
      if let last = lastSynced, Date().timeIntervalSince(last) > 86_400 {
        await refreshRates()
      }
    }
  }

  // MARK: - Refresh

  private func refreshRates() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    refreshError = nil
    lastRefreshCount = nil
    do {
      let count = try await V4FXManager.refreshAll(in: context)
      lastRefreshCount = count
      V4TelemetryManager.signal(.fxRateUpdated)
    } catch {
      refreshError = error.localizedDescription
    }
    isRefreshing = false
  }

  private func deleteRates(_ indexSet: IndexSet) {
    for i in indexSet {
      context.delete(rates[i])
    }
    do { try context.save() }
    catch { print("Delete FX rate save failed: \(error)") }
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
              do { try context.save() }
              catch { print("Delete FX rate (inline) save failed: \(error)") }
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
