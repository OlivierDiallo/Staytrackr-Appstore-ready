//
//  V4PropertyEditorSheet.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 12.01.2026.
//
import SwiftUI
import SwiftData
import PhotosUI

struct V4PropertyEditorSheet: View {
  enum Mode { case add, edit }

  let mode: Mode
  let propertyToEdit: STProperty?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context

  // Basic
  @State private var name: String = ""
  @State private var emoji: String = "🏠"
  @State private var colorHex: String = "#007AFF"
  @State private var currencyCode: String = "EUR"
  @State private var isArchived: Bool = false

  // Finance
  @State private var commissionPct: Double = 0.10
  @State private var purchasePrice: Double = 0
  @State private var trackMortgage: Bool = true
  @State private var mortgageAPR: Double = 0.04
  @State private var mortgageYears: Int = 20

  // Photo
  @State private var photoData: Data? = nil
  @State private var photoItem: PhotosPickerItem? = nil

  private let currencyOptions = ["EUR", "CZK", "USD", "GBP", "CHF", "PLN", "SEK", "NOK", "DKK"]
  private let emojiOptions = ["🏖️","🏙️","🏠","🏡","🗝️","🌴","⛰️","🏢"]
  private let colorOptions: [String] = [
    "#007AFF", "#34C759", "#FF9500", "#FF2D55",
    "#AF52DE", "#5AC8FA", "#8E8E93", "#FFD60A",
    "#FF6B6B", "#4ECDC4", "#FF8C00", "#30D158"
  ]

  var body: some View {
    NavigationStack {
      Form {

        // ── Photo ──────────────────────────────────────────────────────
        Section("Photo") {
          PhotosPicker(selection: $photoItem, matching: .images) {
            if let data = photoData, let uiImage = UIImage(data: data) {
              Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
              Label("Choose Photo", systemImage: "photo.badge.plus")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
          }
          .buttonStyle(.plain)

          if photoData != nil {
            Button("Remove Photo", role: .destructive) {
              photoData = nil
              photoItem = nil
            }
          }
        }
        .onChange(of: photoItem) { _, newItem in
          Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
              // Compress to JPEG to keep storage small
              if let uiImage = UIImage(data: data),
                 let jpeg = uiImage.jpegData(compressionQuality: 0.7) {
                photoData = jpeg
              } else {
                photoData = data
              }
            }
          }
        }

        Section("Basics") {
          TextField("Name", text: $name)

          // ── Emoji swatch grid ──────────────────────────────────────────
          VStack(alignment: .leading, spacing: 6) {
            Text("Icon")
              .font(.footnote)
              .foregroundStyle(.secondary)
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
              spacing: 8
            ) {
              ForEach(emojiOptions, id: \.self) { e in
                Button { emoji = e } label: {
                  ZStack {
                    RoundedRectangle(cornerRadius: 8)
                      .fill(emoji == e
                        ? V4Theme.Brand.primary.opacity(0.15)
                        : Color(.systemFill))
                      .frame(width: 36, height: 36)
                    if emoji == e {
                      RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(V4Theme.Brand.primary, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                    }
                    Text(e).font(.system(size: 20))
                  }
                }
                .buttonStyle(.plain)
              }
            }
          }
          .padding(.vertical, 4)

          // ── Color swatch grid ──────────────────────────────────────────
          VStack(alignment: .leading, spacing: 6) {
            Text("Color")
              .font(.footnote)
              .foregroundStyle(.secondary)
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
              spacing: 8
            ) {
              ForEach(colorOptions, id: \.self) { hex in
                Button { colorHex = hex } label: {
                  ZStack {
                    Circle()
                      .fill(V4Color.hex(hex))
                      .frame(width: 34, height: 34)
                    if colorHex == hex {
                      Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                        .frame(width: 34, height: 34)
                      Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    }
                  }
                }
                .buttonStyle(.plain)
              }
            }
          }
          .padding(.vertical, 4)

          Picker("Currency", selection: $currencyCode) {
            ForEach(currencyOptions, id: \.self) { c in
              Text(c).tag(c)
            }
          }

          Toggle("Archived", isOn: $isArchived)
        }

        Section("Business") {
          HStack {
            Text("Commission")
            Spacer()
            Text("\(Int(round(commissionPct * 100)))%")
              .foregroundStyle(.secondary)
          }
          Slider(value: $commissionPct, in: 0...0.30, step: 0.005)
        }

        Section("Mortgage") {
          Toggle("Track mortgage", isOn: $trackMortgage)

          TextField("Purchase price", value: $purchasePrice, format: .number)
            .keyboardType(.decimalPad)

          if trackMortgage {
            TextField("APR (e.g. 0.04)", value: $mortgageAPR, format: .number)
              .keyboardType(.decimalPad)

            Stepper("Years: \(mortgageYears)", value: $mortgageYears, in: 1...40)
          }
        }
      }
      .navigationTitle(mode == .add ? "New Property" : "Edit Property")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(mode == .add ? "Add" : "Save") {
            save()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear { hydrate() }
    }
  }

  private func hydrate() {
    guard let p = propertyToEdit else {
      // Add defaults
      name = ""
      emoji = "🏠"
      colorHex = "#007AFF"
      currencyCode = "EUR"
      isArchived = false
      commissionPct = 0.10
      purchasePrice = 0
      trackMortgage = true
      mortgageAPR = 0.04
      mortgageYears = 20
      photoData = nil
      return
    }

    // Edit existing
    name = p.name
    emoji = p.emoji
    colorHex = p.colorHex
    currencyCode = p.currencyCode
    isArchived = p.isArchived

    commissionPct = p.commissionPct
    purchasePrice = p.purchasePrice
    trackMortgage = p.trackMortgage
    mortgageAPR = p.mortgageAPR
    mortgageYears = p.mortgageYears

    photoData = p.photoData
  }

  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else { return }

    switch mode {
    case .add:
      let p = STProperty(
        id: UUID(),
        name: cleanName,
        purchasePrice: purchasePrice,
        mortgageAPR: mortgageAPR,
        mortgageYears: mortgageYears,
        commissionPct: commissionPct,
        emoji: emoji,
        colorHex: colorHex,
        isArchived: isArchived,
        trackMortgage: trackMortgage,
        currencyCode: currencyCode,
        photoData: photoData
      )
      context.insert(p)

    case .edit:
      guard let p = propertyToEdit else { return }
      p.name = cleanName
      p.emoji = emoji
      p.colorHex = colorHex
      p.currencyCode = currencyCode
      p.isArchived = isArchived

      p.commissionPct = commissionPct
      p.purchasePrice = purchasePrice
      p.trackMortgage = trackMortgage
      p.mortgageAPR = mortgageAPR
      p.mortgageYears = mortgageYears

      p.photoData = photoData
    }

    do {
      try context.save()
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } catch {
      print("Property save failed: \(error)")
    }
    dismiss()
  }
}
