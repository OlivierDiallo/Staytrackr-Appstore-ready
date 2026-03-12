//
//  V4FXRateEditorSheet.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 01.03.2026.
//
import SwiftUI
import SwiftData

struct V4FXRateEditorSheet: View {
  enum Mode: Equatable {
    case add
    case edit(rate: STFXRate)

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
  @State private var alertText = ""

  var body: some View {
    NavigationStack {
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
          TextField("Rate (e.g. 25.0)", text: $rateText)
            .keyboardType(.decimalPad)

          Text("Meaning: 1 FROM = RATE TO")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if case .edit(let r) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(r)
              do { try context.save() }
              catch { print("Delete FX rate (sheet) save failed: \(error)") }
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
        Text(alertText)
      }
    }
  }

  private func hydrate() {
    switch mode {
    case .add:
      break
    case .edit(let r):
      fromCode = r.fromCode
      toCode = r.toCode
      rateText = V4Format.plainNumber(r.rate, maxFractionDigits: 6)
    }
  }

  private func save() {
    let f = fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let t = toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    guard f.count == 3, t.count == 3 else {
      fail("Currency codes must be 3 letters (e.g. EUR, CZK).")
      return
    }
    guard f != t else {
      fail("FROM and TO must be different.")
      return
    }
    guard let r = V4Format.parseNumber(rateText), r > 0 else {
      fail("Rate must be a valid number greater than 0.")
      return
    }

    switch mode {
    case .add:
      let item = STFXRate(id: UUID(), fromCode: f, toCode: t, rate: r)
      context.insert(item)

    case .edit(let item):
      item.fromCode = f
      item.toCode = t
      item.rate = r
    }

    do {
      try context.save()
      dismiss()
    } catch {
      fail("Save failed: \(error.localizedDescription)")
    }
  }

  private func fail(_ msg: String) {
    alertText = msg
    showAlert = true
  }
}
