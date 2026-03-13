import SwiftUI
import GoogleMobileAds

// MARK: - V4AdBannerView
//
// UIViewRepresentable wrapping GADBannerView (320×50 standard banner).
// Always loads with npa=1 (non-personalised ads) so no ATT dialog is required.
// Rendered at the bottom of V4DashboardView only for free-tier users.

struct V4AdBannerView: UIViewRepresentable {

  let adUnitID: String

  // MARK: - UIViewRepresentable

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> GADBannerView {
    let banner = GADBannerView(adSize: GADAdSizeBanner)
    banner.adUnitID = adUnitID
    banner.rootViewController = topRootViewController()
    banner.delegate = context.coordinator
    banner.load(makeNPARequest())
    return banner
  }

  func updateUIView(_ uiView: GADBannerView, context: Context) {
    // No-op: the banner manages its own ad refresh cycle.
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, GADBannerViewDelegate {
    func bannerView(
      _ bannerView: GADBannerView,
      didFailToReceiveAdWithError error: Error
    ) {
      // Silently log — a missing ad is non-fatal; the 50pt frame collapses gracefully.
      print("[V4AdBannerView] Ad load failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Helpers

  /// Creates a GADRequest tagged for non-personalised ads (npa=1).
  private func makeNPARequest() -> GADRequest {
    let request = GADRequest()
    let extras  = GADExtras()
    extras.additionalParameters = ["npa": "1"]
    request.register(extras)
    return request
  }

  /// Returns the topmost presented UIViewController to anchor the banner.
  private func topRootViewController() -> UIViewController? {
    guard
      let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
      let root = windowScene.windows.first?.rootViewController
    else { return nil }

    var top = root
    while let presented = top.presentedViewController { top = presented }
    return top
  }
}
