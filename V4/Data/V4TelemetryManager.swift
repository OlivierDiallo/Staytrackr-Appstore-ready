import Foundation
import TelemetryDeck

// MARK: - V4TelemetryManager
//
// Thin wrapper around TelemetryDeck providing typed signal names.
// Privacy-first: TelemetryDeck hashes all identifiers — no personal data
// is ever transmitted. NSPrivacyTracking stays false, no ATT dialog needed.
//
// ⚠️  SETUP:
//   1. Add the TelemetryDeck SPM package in Xcode:
//      File > Add Package Dependencies…
//      URL: https://github.com/TelemetryDeck/SwiftSDK.git
//      Choose "Up to Next Major Version" from 2.0.0
//   2. Sign up at telemetrydeck.com, create an app, and replace the
//      placeholder App ID below with your real one.

enum V4TelemetryManager {

  // MARK: - App ID

  /// ⚠️  Replace with your TelemetryDeck App ID from the dashboard.
  private static let appID = "YOUR_TELEMETRYDECK_APP_ID"

  // MARK: - Configure

  /// Call once at app launch (StayTrackrV4App.init) before any views appear.
  static func configure() {
    let config = TelemetryDeck.Config(appID: appID)
    TelemetryDeck.initialize(config: config)
  }

  // MARK: - Signals

  enum Signal: String {
    // Lifecycle
    case appLaunched            = "app.launched"

    // Tab navigation — which features are actually used
    case tabDashboard           = "tab.dashboard"
    case tabCalendar            = "tab.calendar"
    case tabExpenses            = "tab.expenses"
    case tabTotals              = "tab.totals"
    case tabGuests              = "tab.guests"
    case tabProfile             = "tab.profile"
    case tabSettings            = "tab.settings"

    // Core actions
    case bookingCreated         = "booking.created"
    case expenseCreated         = "expense.created"
    case propertyCreated        = "property.created"
    case guestCreated           = "guest.created"

    // Premium funnel
    case paywallViewed          = "paywall.viewed"
    case premiumPurchased       = "premium.purchased"
    case premiumRestored        = "premium.restored"

    // Features
    case exportUsed             = "export.used"
    case recurringBillApplied   = "recurringbill.applied"
    case fxRateUpdated          = "fxrate.updated"
    case notificationsEnabled   = "notifications.enabled"
    case notificationsDisabled  = "notifications.disabled"
  }

  // MARK: - Send

  static func signal(_ signal: Signal, parameters: [String: String] = [:]) {
    TelemetryDeck.signal(signal.rawValue, parameters: parameters)
  }
}
