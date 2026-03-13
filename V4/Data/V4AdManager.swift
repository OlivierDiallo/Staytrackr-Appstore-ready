import Foundation
import GoogleMobileAds

// MARK: - V4AdManager
//
// Manages Google AdMob integration for the free tier.
// • Non-personalised ads only — no ATT (App Tracking Transparency) dialog is shown.
//   The `npa=1` parameter is added to every ad request in V4AdBannerView.
// • Ads are shown only when `store.isPremium == false` (see V4DashboardView).
//
// Updated for Google Mobile Ads SDK v11 (GAD prefix removed from all types).

@Observable
final class V4AdManager {

  // MARK: - Ad Unit IDs

  #if DEBUG
  /// Google's official test banner unit — safe to use in any Simulator/debug build.
  let bannerAdUnitID: String = "ca-app-pub-3940256099942544/2934735716"
  #else
  let bannerAdUnitID: String = "ca-app-pub-8115774269132947/2625704151"
  #endif

  // MARK: - Init

  init() {
    // Initialise immediately so the SDK is ready before any BannerView renders.
    // AdMob crashes if ads are loaded before start() is called — calling it here
    // (rather than in a .task) guarantees it runs before the view hierarchy is built.
    MobileAds.shared.start(completionHandler: nil)
  }
}
