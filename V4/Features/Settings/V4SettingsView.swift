import SwiftUI
import SwiftData
import UserNotifications

struct V4SettingsView: View {
  let prefs: V4AppPreferences

  @Environment(V4AppSettings.self) private var settings
  @Environment(V4NotificationManager.self) private var notifManager
  @Environment(STStoreManager.self) private var store

  @State private var showPaywall = false

  private let commonCurrencies = ["EUR","CZK","USD","GBP","CHF","PLN","SEK","NOK","DKK"]

  var body: some View {
    NavigationStack {
      Form {

        // MARK: Premium Section
        Section("StayTrackr Premium") {
          if store.isPremium {
            HStack(spacing: 12) {
              ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .fill(V4Theme.Brand.primary.opacity(0.12))
                  .frame(width: 40, height: 40)
                Image(systemName: "checkmark.seal.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(V4Theme.Brand.primary)
              }
              VStack(alignment: .leading, spacing: 2) {
                Text("StayTrackr Premium")
                  .font(.subheadline.weight(.semibold))
                Text("Active subscription")
                  .font(.caption)
                  .foregroundStyle(V4Theme.Brand.primary)
              }
              Spacer()
              if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                Link("Manage", destination: url)
                  .font(.subheadline)
                  .foregroundStyle(V4Theme.Brand.primary)
              }
            }
          } else {
            Button {
              showPaywall = true
            } label: {
              HStack(spacing: 12) {
                ZStack {
                  RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(V4Theme.Brand.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                  Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(V4Theme.Brand.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                  Text("Upgrade to Premium")
                    .font(.subheadline.weight(.semibold))
                  Text("Unlimited properties, charts, export & more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
          }
        }

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
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
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

        // Arrival notice — locked for free users
        HStack {
          Picker("Arrival notice", selection: Binding(
            get: { settings.arrivalNoticeHours },
            set: { settings.arrivalNoticeHours = $0 }
          )) {
            ForEach(V4AppSettings.noticeOptions, id: \.hours) { opt in
              Text(opt.label).tag(opt.hours)
            }
          }
          .disabled(!store.isPremium)

          if !store.isPremium {
            Button { showPaywall = true } label: {
              Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(V4Theme.Brand.primary)
            }
            .buttonStyle(.plain)
          }
        }

        // Departure notice — locked for free users
        HStack {
          Picker("Departure notice", selection: Binding(
            get: { settings.departureNoticeHours },
            set: { settings.departureNoticeHours = $0 }
          )) {
            ForEach(V4AppSettings.noticeOptions, id: \.hours) { opt in
              Text(opt.label).tag(opt.hours)
            }
          }
          .disabled(!store.isPremium)

          if !store.isPremium {
            Button { showPaywall = true } label: {
              Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(V4Theme.Brand.primary)
            }
            .buttonStyle(.plain)
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
