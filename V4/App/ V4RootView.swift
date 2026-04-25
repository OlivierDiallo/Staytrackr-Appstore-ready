import SwiftUI
import SwiftData

struct V4RootView: View {
  @Query(sort: \STProperty.name) private var properties: [STProperty]
  @Environment(V4AppSettings.self) private var settings

  var body: some View {
    Group {
      // 1. First launch: show the walkthrough tour
      if !settings.hasSeenOnboarding {
        V4PersonalizedOnboardingView()
      // 2. No properties yet: show the "add your first property" screen
      } else if properties.isEmpty {
        V4OnboardingView()
      // 3. Normal app
      } else {
        V4PreferencesProvider { prefs in
          appTabs(prefs: prefs)
        }
      }
    }
    .preferredColorScheme(settings.preferredColorScheme)
  }

  // MARK: - Tab Structure

  @ViewBuilder
  private func appTabs(prefs: V4AppPreferences) -> some View {
    if #available(iOS 18.0, *) {
      TabView {
        Tab("Dashboard", systemImage: "rectangle.grid.2x2.fill") {
          V4DashboardView(prefs: prefs)
            .onAppear { V4TelemetryManager.signal(.tabDashboard) }
        }
        Tab("Calendar", systemImage: "calendar") {
          V4CalendarView(prefs: prefs)
            .onAppear { V4TelemetryManager.signal(.tabCalendar) }
        }
        Tab("Expenses", systemImage: "creditcard") {
          V4ExpensesView(prefs: prefs)
            .onAppear { V4TelemetryManager.signal(.tabExpenses) }
        }
        Tab("Totals", systemImage: "chart.bar") {
          V4TotalsView(prefs: prefs)
            .onAppear { V4TelemetryManager.signal(.tabTotals) }
        }
        Tab("Profile", systemImage: "person.crop.circle.fill") {
          NavigationStack {
            V4UserProfileView()
          }
          .onAppear { V4TelemetryManager.signal(.tabProfile) }
        }
        Tab("Guests", systemImage: "person.2.fill") {
          V4GuestsView(prefs: prefs)
            .onAppear { V4TelemetryManager.signal(.tabGuests) }
        }
        Tab("More", systemImage: "ellipsis") {
          NavigationStack {
            V4SettingsView(prefs: prefs)
          }
          .onAppear { V4TelemetryManager.signal(.tabSettings) }
        }
      }
      .tabViewStyle(.sidebarAdaptable)
      .tint(V4Theme.Brand.primary)
    } else {
      TabView {
        V4DashboardView(prefs: prefs)
          .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2.fill") }
          .onAppear { V4TelemetryManager.signal(.tabDashboard) }
        V4CalendarView(prefs: prefs)
          .tabItem { Label("Calendar", systemImage: "calendar") }
          .onAppear { V4TelemetryManager.signal(.tabCalendar) }
        V4ExpensesView(prefs: prefs)
          .tabItem { Label("Expenses", systemImage: "creditcard") }
          .onAppear { V4TelemetryManager.signal(.tabExpenses) }
        V4TotalsView(prefs: prefs)
          .tabItem { Label("Totals", systemImage: "chart.bar") }
          .onAppear { V4TelemetryManager.signal(.tabTotals) }
        NavigationStack { V4UserProfileView() }
          .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
          .onAppear { V4TelemetryManager.signal(.tabProfile) }
        V4GuestsView(prefs: prefs)
          .tabItem { Label("Guests", systemImage: "person.2.fill") }
          .onAppear { V4TelemetryManager.signal(.tabGuests) }
        NavigationStack { V4SettingsView(prefs: prefs) }
          .tabItem { Label("More", systemImage: "ellipsis") }
          .onAppear { V4TelemetryManager.signal(.tabSettings) }
      }
      .tint(V4Theme.Brand.primary)
    }
  }
}

// MARK: - Onboarding

private struct V4OnboardingView: View {
  @State private var showAddProperty = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 40) {
          Spacer(minLength: 40)

          // App icon
          ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [V4Theme.Brand.primary, V4Theme.Brand.primary.opacity(0.7)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 100, height: 100)
              .shadow(color: V4Theme.Brand.primary.opacity(0.4), radius: 16, y: 6)
            Image(systemName: "house.fill")
              .font(.system(size: 46))
              .foregroundStyle(.white)
          }

          // Headlines
          VStack(spacing: 10) {
            Text("Welcome to StayTrackr")
              .font(.largeTitle.weight(.bold))
              .multilineTextAlignment(.center)
            Text("Track bookings, income and expenses\nfor your rental properties — all in one place.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          // Feature highlights
          VStack(spacing: 16) {
            featureRow(
              icon: "calendar.badge.plus",
              color: .blue,
              title: "Booking calendar",
              subtitle: "Visualise arrivals, departures and occupancy at a glance."
            )
            featureRow(
              icon: "creditcard.fill",
              color: .orange,
              title: "Expense tracking",
              subtitle: "Log and categorise costs per property with multi-currency support."
            )
            featureRow(
              icon: "chart.bar.fill",
              color: V4Theme.Brand.primary,
              title: "Revenue totals",
              subtitle: "See gross revenue, net income and occupancy by month, year or all-time."
            )
          }
          .padding(.horizontal, 8)

          // CTA
          Button {
            showAddProperty = true
          } label: {
            Label("Add Your First Property", systemImage: "plus")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(V4Theme.Brand.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .padding(.horizontal, 24)

          Spacer(minLength: 40)
        }
        .padding(.horizontal, 24)
      }
      .navigationTitle("StayTrackr")
      .navigationBarTitleDisplayMode(.inline)
    }
    .sheet(isPresented: $showAddProperty) {
      V4PropertyEditorSheet(mode: .add, propertyToEdit: nil)
    }
  }

  private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(color.opacity(0.12))
          .frame(width: 42, height: 42)
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(color)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
    }
  }
}
