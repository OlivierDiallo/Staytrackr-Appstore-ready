import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Settings / More View

struct V4SettingsView: View {
  let prefs: V4AppPreferences

  @Environment(V4AppSettings.self) private var settings
  @Environment(V4NotificationManager.self) private var notifManager
  @Environment(STStoreManager.self) private var store

  @State private var showPaywall = false
  @State private var showRestoreAlert = false
  @State private var restoreAlertMessage = ""
  @State private var isRestoring = false

  private let commonCurrencies = ["EUR","CZK","USD","GBP","CHF","PLN","SEK","NOK","DKK"]

  var body: some View {
    NavigationStack {
      List {

        // MARK: — Profile
        Section {
          NavigationLink {
            V4UserProfileView()
          } label: {
            settingsRow(icon: "person.crop.circle.fill", color: .blue, label: "Profile")
          }
        } header: {
          sectionHeader("Account")
        }

        // MARK: — Account / Premium
        premiumSection

        // MARK: — Properties & Bills
        Section {
          NavigationLink {
            V4PropertiesListView(prefs: prefs)
          } label: {
            settingsRow(icon: "house.fill", color: V4Theme.Brand.primary, label: "Properties")
          }

          NavigationLink {
            V4RecurringBillsView()
          } label: {
            settingsRow(icon: "repeat.circle.fill", color: .orange, label: "Recurring Bills")
          }
        } header: {
          sectionHeader("Properties")
        }

        // MARK: — Finance
        Section {
          NavigationLink {
            V4FXRatesView()
          } label: {
            settingsRow(icon: "arrow.left.arrow.right", color: .blue, label: "FX Rates")
          }

          // Reporting currency inline
          HStack(spacing: 12) {
            ZStack {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.purple.opacity(0.15))
                .frame(width: 32, height: 32)
              Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.purple)
            }
            Text("Reporting Currency")
            Spacer()
            Picker("", selection: Binding(
              get: { settings.reportingCurrencyCode },
              set: { settings.reportingCurrencyCode = $0 }
            )) {
              ForEach(commonCurrencies, id: \.self) { c in
                Text(c).tag(c)
              }
            }
            .pickerStyle(.menu)
            .tint(V4Theme.Brand.primary)
          }
        } header: {
          sectionHeader("Finance")
        } footer: {
          Text("Totals will convert bookings and expenses into \(settings.reportingCurrencyCode) using your FX rates.")
            .font(.caption)
        }

        // MARK: — Data & Export
        Section {
          NavigationLink {
            V4ExportView()
          } label: {
            settingsRow(icon: "arrow.down.doc.fill", color: .teal, label: "Export CSV")
          }
        } header: {
          sectionHeader("Data & Export")
        }

        // MARK: — Personalization
        Section {
          // Theme
          HStack(spacing: 12) {
            ZStack {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 32, height: 32)
              Image(systemName: "paintbrush.fill")
                .font(.system(size: 16))
                .foregroundStyle(.indigo)
            }
            Picker("Theme", selection: Binding(
              get: { settings.colorSchemeRaw },
              set: { settings.colorSchemeRaw = $0 }
            )) {
              Label("System", systemImage: "circle.lefthalf.filled").tag("system")
              Label("Light",  systemImage: "sun.max").tag("light")
              Label("Dark",   systemImage: "moon").tag("dark")
            }
            .tint(V4Theme.Brand.primary)
          }

          // Notifications inline toggle
          Toggle(isOn: Binding(
            get: { settings.notificationsEnabled },
            set: { settings.notificationsEnabled = $0 }
          )) {
            HStack(spacing: 12) {
              ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(Color.red.opacity(0.15))
                  .frame(width: 32, height: 32)
                Image(systemName: "bell.badge.fill")
                  .font(.system(size: 16))
                  .foregroundStyle(.red)
              }
              Text("Enable Notifications")
            }
          }
          .tint(V4Theme.Brand.primary)

          if settings.notificationsEnabled {
            notificationSubsection
          }
        } header: {
          sectionHeader("Personalization")
        }

        // MARK: — About
        Section {
          LabeledContent("Version") {
            Text(appVersion)
              .foregroundStyle(.secondary)
          }
          if let websiteURL = URL(string: "https://getstaytrackr.com") {
            Link(destination: websiteURL) {
              settingsRow(icon: "globe", color: .blue, label: "Website")
            }
          }
          if let privacyURL = URL(string: "https://getstaytrackr.com/privacy") {
            Link(destination: privacyURL) {
              settingsRow(icon: "hand.raised.fill", color: .gray, label: "Privacy Policy")
            }
          }
          if let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            Link(destination: eulaURL) {
              settingsRow(icon: "doc.text.fill", color: .gray, label: "Terms of Use")
            }
          }
        } header: {
          sectionHeader("About")
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("More")
    }
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
    .alert("Restore Purchases", isPresented: $showRestoreAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(restoreAlertMessage)
    }
  }

  // MARK: - Premium Section

  @ViewBuilder
  private var premiumSection: some View {
    Section {
      if store.isPremium {
        // Active subscription card
        HStack(spacing: 14) {
          ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(V4Theme.Brand.primary.opacity(0.12))
              .frame(width: 44, height: 44)
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 22))
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
        .padding(.vertical, 4)
      } else {
        // Upgrade CTA
        Button {
          showPaywall = true
        } label: {
          HStack(spacing: 14) {
            ZStack {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(V4Theme.Brand.primary.opacity(0.12))
                .frame(width: 44, height: 44)
              Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(V4Theme.Brand.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text("Upgrade to Premium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
              Text("Unlimited properties, charts, export & more")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)

        // Restore Purchases
        Button {
          Task { await restorePurchases() }
        } label: {
          HStack(spacing: 14) {
            ZStack {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 32, height: 32)
              if isRestoring {
                ProgressView()
                  .scaleEffect(0.7)
              } else {
                Image(systemName: "arrow.clockwise")
                  .font(.system(size: 15))
                  .foregroundStyle(.secondary)
              }
            }
            Text("Restore Purchases")
              .font(.subheadline)
              .foregroundStyle(V4Theme.Brand.primary)
          }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
      }
    } header: {
      sectionHeader("StayTrackr Premium")
    }
  }

  // MARK: - Notifications Subsection

  @ViewBuilder
  private var notificationSubsection: some View {
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
      .tint(V4Theme.Brand.primary)

      if !store.isPremium {
        Button { showPaywall = true } label: {
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundStyle(V4Theme.Brand.primary)
        }
        .buttonStyle(.plain)
      }
    }

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
      .tint(V4Theme.Brand.primary)

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

  // MARK: - Restore Purchases

  private func restorePurchases() async {
    isRestoring = true
    await store.restorePurchases()
    isRestoring = false
    if store.isPremium {
      restoreAlertMessage = String(localized: "Your Premium subscription has been restored.")
    } else {
      restoreAlertMessage = String(localized: "No active subscription found. If you believe this is an error, contact support.")
    }
    showRestoreAlert = true
  }

  // MARK: - Helpers

  private func settingsRow(icon: String, color: Color, label: LocalizedStringKey) -> some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(color.opacity(0.15))
          .frame(width: 32, height: 32)
        Image(systemName: icon)
          .font(.system(size: 16))
          .foregroundStyle(color)
      }
      Text(label)
        .foregroundStyle(.primary)
    }
  }

  private func sectionHeader(_ title: LocalizedStringKey) -> some View {
    Text(title)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
  }

  private var appVersion: String {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(v) (\(b))"
  }
}

