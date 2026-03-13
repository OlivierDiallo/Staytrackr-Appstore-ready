import Foundation
import GoogleMobileAds

// MARK: - V4AdManager
//
// Manages Google AdMob integration for the free tier.
// • Non-personalised ads only — no ATT (App Tracking Transparency) dialog is shown.
//   The `npa=1` parameter is added to every ad request in V4AdBannerView.
// • Ads are shown only when `store.isPremium == false` (see V4DashboardView).
//
// ⚠️  SETUP REQUIRED BEFORE BUILDING:
//   1. Add the Google Mobile Ads SPM package in Xcode:
//      File > Add Package Dependencies…
//      URL: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
//      Choose "Up to Next Major Version" from 11.0.0
//   2. In project.pbxproj (or Xcode Build Settings), replace the placeholder App ID with
//      your real AdMob App ID from the AdMob console (for the Release config).
//   3. Create a banner ad unit in the AdMob console and replace `bannerAdUnitID` below.

@Observable
final class V4AdManager {

  // MARK: - Ad Unit IDs

  #if DEBUG
  /// Google's official test banner unit — safe to use in any Simulator/debug build.
  let bannerAdUnitID: String = "ca-app-pub-3940256099942544/2934735716"
  #else
  /// ⚠️  Replace with your real banner ad unit ID from the AdMob console.
  let bannerAdUnitID: String = "ca-app-pub-REPLACE_WITH_REAL/BANNER_UNIT_ID"
  #endif

  // MARK: - Lifecycle

  /// Call once at app launch (from StayTrackrV4App.task) to initialise the SDK.
  /// NPA configuration is handled per-request in V4AdBannerView — no extra work needed here.
  func start() {
    GADMobileAds.sharedInstance().start(completionHandler: nil)
  }
}
