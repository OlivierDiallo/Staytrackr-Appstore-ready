import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Transferable CSV wrapper

/// Writes content to a temp file only when the user actually taps Share,
/// giving the file a proper .csv name so Numbers/Excel open it directly.
struct CSVFile: Transferable {
  let content: String
  let filename: String

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .commaSeparatedText) { file in
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(file.filename)
      try Data(file.content.utf8).write(to: url)
      return SentTransferredFile(url)
    }
  }
}

// MARK: - Export View

struct V4ExportView: View {
  @Query(sort: \STBooking.checkIn)  private var bookings:  [STBooking]
  @Query(sort: \STExpense.date)     private var expenses:  [STExpense]

  @Environment(STStoreManager.self) private var store
  @State private var showPaywall = false

  private static let isoDay: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f
  }()

  var body: some View {
    Group {
      if store.isPremium {
        exportForm
      } else {
        premiumLockedPlaceholder
      }
    }
    .navigationTitle("Export Data")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
  }

  // MARK: - Export Form (premium only)

  private var exportForm: some View {
    Form {
      Section {
        Text("Exports include all data currently stored on this device. Open the CSV in Numbers, Excel, or Google Sheets.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section {
        LabeledContent("Bookings", value: "\(bookings.count) rows")
        ShareLink(
          item: CSVFile(content: bookingsCSV, filename: "staytrackr_bookings.csv"),
          preview: SharePreview(
            "staytrackr_bookings.csv",
            icon: Image(systemName: "tablecells")
          )
        ) {
          Label("Export Bookings", systemImage: "square.and.arrow.up")
            .foregroundStyle(V4Theme.Brand.primary)
        }
        .simultaneousGesture(TapGesture().onEnded {
          V4TelemetryManager.signal(.exportUsed, parameters: ["type": "bookings"])
        })
      } header: {
        Text("Bookings")
      } footer: {
        Text("Columns: Property · Guest · GuestEmail · GuestPhone · CheckIn · CheckOut · Nights · NightlyRate · Currency · GrossTotal · CommissionPct · PlatformFeePct · NetRevenue · IsPaid · Status · Note")
          .font(.caption2)
      }

      Section {
        LabeledContent("Expenses", value: "\(expenses.count) rows")
        ShareLink(
          item: CSVFile(content: expensesCSV, filename: "staytrackr_expenses.csv"),
          preview: SharePreview(
            "staytrackr_expenses.csv",
            icon: Image(systemName: "tablecells")
          )
        ) {
          Label("Export Expenses", systemImage: "square.and.arrow.up")
            .foregroundStyle(V4Theme.Brand.primary)
        }
        .simultaneousGesture(TapGesture().onEnded {
          V4TelemetryManager.signal(.exportUsed, parameters: ["type": "expenses"])
        })
      } header: {
        Text("Expenses")
      } footer: {
        Text("Columns: Property · Date · Category · Amount · Currency · Note")
          .font(.caption2)
      }

      Section {
        ShareLink(
          item: CSVFile(content: combinedCSV, filename: "staytrackr_export.csv"),
          preview: SharePreview(
            "staytrackr_export.csv",
            icon: Image(systemName: "tablecells")
          )
        ) {
          Label("Export All (Single File)", systemImage: "doc.on.doc")
            .foregroundStyle(V4Theme.Brand.primary)
        }
        .simultaneousGesture(TapGesture().onEnded {
          V4TelemetryManager.signal(.exportUsed, parameters: ["type": "combined"])
        })
      } footer: {
        Text("Bookings and Expenses in one file, separated by a blank row.")
          .font(.caption2)
      }
    }
  }

  // MARK: - Locked Placeholder (free tier)

  private var premiumLockedPlaceholder: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "arrow.down.doc.fill")
        .font(.system(size: 52))
        .foregroundStyle(V4Theme.Brand.primary.opacity(0.4))
      VStack(spacing: 8) {
        Text("CSV Export")
          .font(.title3.weight(.semibold))
        Text("Export your bookings and expenses to\nspreadsheets. Available with Premium.")
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

  // MARK: - CSV builders

  private var bookingsCSV: String {
    var rows = [
      "Property,Guest,GuestEmail,GuestPhone,CheckIn,CheckOut,Nights,NightlyRate,Currency," +
      "GrossTotal,CommissionPct,PlatformFeePct,NetRevenue,IsPaid,Status,Note"
    ]
    let now = Date()
    for b in bookings {
      let nights = Calendar.current
        .dateComponents([.day], from: b.checkIn, to: b.checkOut).day ?? 0
      let gross      = Double(nights) * b.nightlyRate
      let commission = gross * b.property.commissionPct
      let platform   = gross * b.platformFeePct
      let net        = gross - commission - platform

      // Derive booking status label for CSV
      let status: String
      if now < b.checkIn {
        status = "Upcoming"
      } else if now <= b.checkOut {
        status = "Active"
      } else {
        status = "Completed"
      }

      rows.append([
        csvEscape("\(b.property.emoji) \(b.property.name)"),
        csvEscape(b.guest.name),
        csvEscape(b.guest.email ?? ""),
        csvEscape(b.guest.phone ?? ""),
        Self.isoDay.string(from: b.checkIn),
        Self.isoDay.string(from: b.checkOut),
        "\(nights)",
        fmt(b.nightlyRate),
        b.property.currencyCode,
        fmt(gross),
        fmt(b.property.commissionPct * 100),
        fmt(b.platformFeePct * 100),
        fmt(net),
        b.isPaid ? "Yes" : "No",
        status,
        csvEscape(b.note ?? "")
      ].joined(separator: ","))
    }
    return rows.joined(separator: "\n")
  }

  private var expensesCSV: String {
    var rows = ["Property,Date,Category,Amount,Currency,Note"]
    for e in expenses {
      rows.append([
        csvEscape("\(e.property.emoji) \(e.property.name)"),
        Self.isoDay.string(from: e.date),
        e.category.rawValue,
        fmt(e.amount),
        e.currencyCode,
        csvEscape(e.note ?? "")
      ].joined(separator: ","))
    }
    return rows.joined(separator: "\n")
  }

  private var combinedCSV: String {
    bookingsCSV + "\n\n" + expensesCSV
  }

  // MARK: - Helpers

  private func fmt(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  /// Wraps a field in quotes if it contains commas, quotes, or newlines.
  /// Also prefixes formula-injection characters (=, +, -, @) with a tab so
  /// Excel / Google Sheets / LibreOffice never interpret the cell as a formula.
  private func csvEscape(_ s: String) -> String {
    // Neutralise spreadsheet formula injection.
    let formulaStarters: Set<Character> = ["=", "+", "-", "@"]
    let safe = (s.first.map { formulaStarters.contains($0) } == true) ? "\t" + s : s
    guard safe.contains(",") || safe.contains("\"") || safe.contains("\n") else { return safe }
    return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
}
