import SwiftUI
import SwiftData
import UserNotifications

struct V4SettingsView: View {
  let prefs: V4AppPreferences

  @Environment(V4AppSettings.self) private var settings
  @Environment(V4NotificationManager.self) private var notifManager

  private let commonCurrencies = ["EUR","CZK","USD","GBP","CHF","PLN","SEK","NOK","DKK"]

  var body: some View {
    NavigationStack {
      Form {
        Section("Reporting Currency") {
          Picker("Currency", selection: Binding(
            get: { settings.reportingCurrencyCode },
            set: { settings.reportingCurrencyCode = $0 }
          )) {
            ForEach(commonCurrencies, id: \.self) { c in
              Text(c).tag(c)
            }
          }

          Text("Totals will convert bookings and expenses into \(settings.reportingCurrencyCode) using your FX rates.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("FX Rates") {
          NavigationLink {
            V4FXRatesView()
          } label: {
            Label("Manage FX Rates", systemImage: "arrow.left.arrow.right")
          }

          Text("Add rates like EUR → CZK. Inverse (CZK → EUR) is handled automatically.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Properties") {
          NavigationLink {
            V4PropertiesListView(prefs: prefs)
          } label: {
            Label("Properties", systemImage: "house")
          }

          NavigationLink {
            V4RecurringBillsView()
          } label: {
            Label("Recurring Bills", systemImage: "repeat.circle")
          }
        }

        Section("Data") {
          NavigationLink {
            V4ExportView()
          } label: {
            Label("Export CSV", systemImage: "arrow.down.doc")
          }
        }

        Section("Appearance") {
          Picker("Theme", selection: Binding(
            get: { settings.colorSchemeRaw },
            set: { settings.colorSchemeRaw = $0 }
          )) {
            Label("System", systemImage: "circle.lefthalf.filled").tag("system")
            Label("Light",  systemImage: "sun.max").tag("light")
            Label("Dark",   systemImage: "moon").tag("dark")
          }
          .pickerStyle(.segmented)
        }

        notificationsSection
      }
      .navigationTitle("Settings")
    }
  }

  // MARK: - Notifications Section

  @ViewBuilder
  private var notificationsSection: some View {
    Section {
      Toggle(isOn: Binding(
        get: { settings.notificationsEnabled },
        set: { settings.notificationsEnabled = $0 }
      )) {
        Label("Enable Notifications", systemImage: "bell.badge")
      }

      if settings.notificationsEnabled {
        if !notifManager.isAuthorized {
          // User has not granted permission yet — nudge them.
          HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
              Text("Notifications not allowed")
                .font(.footnote.weight(.medium))
              Text("Open iOS Settings → StayTrackr to enable them.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 4)
        }

        Picker("Arrival notice", selection: Binding(
          get: { settings.arrivalNoticeHours },
          set: { settings.arrivalNoticeHours = $0 }
        )) {
          ForEach(V4AppSettings.noticeOptions, id: \.hours) { opt in
            Text(opt.label).tag(opt.hours)
          }
        }

        Picker("Departure notice", selection: Binding(
          get: { settings.departureNoticeHours },
          set: { settings.departureNoticeHours = $0 }
        )) {
          ForEach(V4AppSettings.noticeOptions, id: \.hours) { opt in
            Text(opt.label).tag(opt.hours)
          }
        }
      }
    } header: {
      Text("Notifications")
    } footer: {
      if settings.notificationsEnabled {
        Text("Notifications fire at 9 AM on the selected day. \"Morning of\" sends the alert on the day of arrival or departure.")
          .font(.caption)
      }
    }
  }
}
