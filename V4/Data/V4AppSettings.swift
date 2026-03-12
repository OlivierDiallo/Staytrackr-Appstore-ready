import Foundation
import Observation
import SwiftUI

@Observable
final class V4AppSettings {
  private static let reportingKey           = "v4_reportingCurrencyCode"
  private static let colorSchemeKey         = "v4_colorScheme"
  private static let multiCurrencyBannerKey = "v4_showMultiCurrencyBanner"
  private static let notifEnabledKey        = "v4_notificationsEnabled"
  private static let arrivalNoticeKey       = "v4_arrivalNoticeHours"
  private static let departureNoticeKey     = "v4_departureNoticeHours"
  private static let onboardingKey          = "v4_hasSeenOnboarding"
  private static let appleUserIDKey         = "v4_appleUserID"

  // MARK: - Reporting currency

  var reportingCurrencyCode: String {
    didSet { UserDefaults.standard.set(reportingCurrencyCode, forKey: Self.reportingKey) }
  }

  // MARK: - Appearance

  var colorSchemeRaw: String {
    didSet { UserDefaults.standard.set(colorSchemeRaw, forKey: Self.colorSchemeKey) }
  }

  var preferredColorScheme: ColorScheme? {
    switch colorSchemeRaw {
    case "light": return .light
    case "dark":  return .dark
    default:      return nil
    }
  }

  // MARK: - Dashboard

  /// Controls the multi-currency info banner in the Dashboard.
  var showMultiCurrencyBanner: Bool {
    didSet { UserDefaults.standard.set(showMultiCurrencyBanner, forKey: Self.multiCurrencyBannerKey) }
  }

  // MARK: - Onboarding

  /// Set to true after the user completes the first-launch tour.
  var hasSeenOnboarding: Bool {
    didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.onboardingKey) }
  }

  // MARK: - Sign in with Apple

  /// Stores the Apple User ID after a successful Sign in with Apple.
  var appleUserID: String? {
    didSet { UserDefaults.standard.set(appleUserID, forKey: Self.appleUserIDKey) }
  }

  // MARK: - Notifications

  var notificationsEnabled: Bool {
    didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notifEnabledKey) }
  }

  /// Hours before "9 AM on check-in day" to fire the arrival notification.
  /// 0 = morning of arrival, 24 = morning of the day before, 168 = 1 week before.
  var arrivalNoticeHours: Int {
    didSet { UserDefaults.standard.set(arrivalNoticeHours, forKey: Self.arrivalNoticeKey) }
  }

  /// Hours before "9 AM on check-out day" to fire the departure notification.
  var departureNoticeHours: Int {
    didSet { UserDefaults.standard.set(departureNoticeHours, forKey: Self.departureNoticeKey) }
  }

  /// Shared advance-notice options used in Settings pickers.
  static let noticeOptions: [(hours: Int, label: LocalizedStringKey)] = [
    (0,   "Morning of"),
    (2,   "2 hours before"),
    (6,   "6 hours before"),
    (12,  "12 hours before"),
    (24,  "1 day before"),
    (48,  "2 days before"),
    (72,  "3 days before"),
    (168, "1 week before"),
  ]

  // MARK: - Init

  init() {
    // Currency
    let saved = UserDefaults.standard.string(forKey: Self.reportingKey) ?? "EUR"
    let normalized = saved.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    self.reportingCurrencyCode = normalized.isEmpty ? "EUR" : normalized

    // Appearance
    let savedScheme = UserDefaults.standard.string(forKey: Self.colorSchemeKey) ?? "system"
    self.colorSchemeRaw = ["system", "light", "dark"].contains(savedScheme) ? savedScheme : "system"

    // Dashboard banner (default: visible)
    let bannerDefault = UserDefaults.standard.object(forKey: Self.multiCurrencyBannerKey) as? Bool
    self.showMultiCurrencyBanner = bannerDefault ?? true

    // Notifications (defaults: enabled, 24h before arrival, 2h before departure)
    let notifDefault = UserDefaults.standard.object(forKey: Self.notifEnabledKey) as? Bool
    self.notificationsEnabled = notifDefault ?? true

    let arrivalDefault = UserDefaults.standard.object(forKey: Self.arrivalNoticeKey) as? Int
    self.arrivalNoticeHours = arrivalDefault ?? 24

    let departureDefault = UserDefaults.standard.object(forKey: Self.departureNoticeKey) as? Int
    self.departureNoticeHours = departureDefault ?? 2

    // Onboarding (default: not seen)
    let onboardingDefault = UserDefaults.standard.object(forKey: Self.onboardingKey) as? Bool
    self.hasSeenOnboarding = onboardingDefault ?? false

    // Sign in with Apple
    self.appleUserID = UserDefaults.standard.string(forKey: Self.appleUserIDKey)
  }
}
