import Foundation
import Observation
import StoreKit

// MARK: - Store Manager

@Observable
final class STStoreManager {

  // MARK: - Product IDs

  static let monthlyID = "com.olivierdiallo.staytrackrv3.premium.monthly"
  static let annualID  = "com.olivierdiallo.staytrackrv3.premium.annual"

  // MARK: - State

  /// Products fetched from StoreKit, ordered monthly → annual.
  var products: [Product] = []

  /// True when the user holds an active, verified entitlement.
  /// Derived exclusively from StoreKit — never from UserDefaults.
  #if DEBUG
  var isPremium: Bool = true
  #else
  var isPremium: Bool = false
  #endif

  /// Non-nil when a purchase or restore attempt fails.
  var purchaseError: String? = nil

  /// True while a purchase or restore is in-flight.
  var isPurchasing: Bool = false

  /// True when the user is eligible for a free introductory trial (checked after products load).
  var isEligibleForTrial: Bool = false

  // MARK: - Init

  init() {
    Task { await loadProducts() }
    Task { await updatePremiumStatus() }
    // Background listener for renewals, revocations, and billing-retry recoveries.
    Task {
      for await _ in Transaction.updates {
        await updatePremiumStatus()
      }
    }
  }

  // MARK: - Load Products

  @MainActor
  func loadProducts() async {
    do {
      let fetched = try await Product.products(for: [Self.monthlyID, Self.annualID])
      let order = [Self.monthlyID, Self.annualID]
      products = fetched.sorted {
        (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
      }
      await checkTrialEligibility()
    } catch {
      // No StoreKit config in scheme, or network unavailable.
      // products stays empty; paywall shows a loading state.
      print("[STStoreManager] loadProducts failed: \(error)")
    }
  }

  // MARK: - Premium Status

  @MainActor
  func updatePremiumStatus() async {
    var active = false
    for await result in Transaction.currentEntitlements {
      if case .verified(let tx) = result,
         (tx.productID == Self.monthlyID || tx.productID == Self.annualID),
         tx.revocationDate == nil {
        active = true
        break
      }
    }
    isPremium = active
  }

  // MARK: - Purchase

  @MainActor
  func purchase(_ product: Product) async {
    purchaseError = nil
    isPurchasing = true
    defer { isPurchasing = false }

    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verificationResult):
        if case .verified(let tx) = verificationResult {
          await tx.finish()
          await updatePremiumStatus()
        } else {
          purchaseError = "Purchase could not be verified. Please try again."
        }
      case .pending:
        // Ask-to-Buy or deferred — will arrive via Transaction.updates.
        break
      case .userCancelled:
        break
      @unknown default:
        break
      }
    } catch StoreKitError.userCancelled {
      // User dismissed the system sheet — no error to surface.
    } catch {
      purchaseError = error.localizedDescription
    }
  }

  // MARK: - Restore

  @MainActor
  func restorePurchases() async {
    purchaseError = nil
    isPurchasing = true
    defer { isPurchasing = false }

    do {
      try await AppStore.sync()
      await updatePremiumStatus()
      if !isPremium {
        purchaseError = "No active subscription found."
      }
    } catch {
      purchaseError = error.localizedDescription
    }
  }

  // MARK: - Helpers

  var monthlyProduct: Product? { products.first(where: { $0.id == Self.monthlyID }) }
  var annualProduct:  Product? { products.first(where: { $0.id == Self.annualID }) }

  // MARK: - Trial

  /// Checks whether the user is eligible for an introductory free trial.
  /// Uses any product in the subscription group — eligibility is group-scoped in StoreKit.
  @MainActor
  func checkTrialEligibility() async {
    guard let firstProduct = products.first else {
      isEligibleForTrial = false
      return
    }
    isEligibleForTrial = await firstProduct.subscription?.isEligibleForIntroOffer ?? false
  }

  /// Returns a human-readable trial label like "7 days free", or nil if the product has
  /// no free-trial introductory offer.
  func trialLabel(for product: Product) -> String? {
    guard let offer = product.subscription?.introductoryOffer,
          offer.paymentMode == .freeTrial else { return nil }
    let count = offer.period.value
    switch offer.period.unit {
    case .week:  return count == 1 ? "1 week free"  : "\(count) weeks free"
    case .day:   return count == 1 ? "1 day free"   : "\(count) days free"
    case .month: return count == 1 ? "1 month free" : "\(count) months free"
    default:     return "Free trial"
    }
  }

  /// Percentage saved buying annual vs. 12 × monthly, formatted as "33%".
  var annualSavingsPercent: String? {
    guard let m = monthlyProduct, let a = annualProduct else { return nil }
    let equivalent = m.price * 12
    guard equivalent > 0 else { return nil }
    let pct = (equivalent - a.price) / equivalent * 100
    guard pct > 0 else { return nil }
    return "\(Int(truncating: pct as NSDecimalNumber))%"
  }
}
