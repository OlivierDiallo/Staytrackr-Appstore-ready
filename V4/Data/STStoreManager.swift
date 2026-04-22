import Foundation
import Observation
import StoreKit

// MARK: - Store Manager

@Observable
final class STStoreManager {

  // MARK: - Product IDs

  static let monthlyID = "com.olivierdiallo.staytrackrv3.premium.monthlyy"
  static let annualID  = "com.olivierdiallo.staytrackrv3.premium.annual.v1"

  // MARK: - State

  /// Products fetched from StoreKit, ordered monthly → annual.
  var products: [Product] = []

  /// True when the user holds an active, verified entitlement.
  /// Derived exclusively from StoreKit — never from UserDefaults.
  var isPremium: Bool = false

  /// Non-nil when a purchase or restore attempt fails.
  var purchaseError: String? = nil

  /// True while a purchase or restore is in-flight.
  var isPurchasing: Bool = false

  /// True when the user is eligible for a free introductory trial (checked after products load).
  var isEligibleForTrial: Bool = false

  /// True while the initial product fetch is in progress.
  var isLoadingProducts: Bool = false

  /// True when product fetch has completed but returned no products (e.g. Paid Apps Agreement not active).
  var loadFailed: Bool = false

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

  /// Maximum number of automatic retries when product fetch returns empty or throws.
  private static let maxRetries = 3
  /// Delay in seconds between retries (doubles each attempt).
  private static let baseRetryDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds

  @MainActor
  func loadProducts() async {
    isLoadingProducts = true
    loadFailed = false
    defer { isLoadingProducts = false }

    let ids: Set<String> = [Self.monthlyID, Self.annualID]
    let order = [Self.monthlyID, Self.annualID]

    for attempt in 0 ..< Self.maxRetries {
      do {
        let fetched = try await Product.products(for: ids)
        if !fetched.isEmpty {
          products = fetched.sorted {
            (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
          }
          loadFailed = false
          print("[STStoreManager] Loaded \(products.count) product(s) on attempt \(attempt + 1)")
          await checkTrialEligibility()
          return
        }
        print("[STStoreManager] Attempt \(attempt + 1): products empty, retrying...")
      } catch {
        print("[STStoreManager] Attempt \(attempt + 1) failed: \(error)")
      }

      // Exponential back-off: 2s, 4s, 8s …
      let delay = Self.baseRetryDelay << attempt
      try? await Task.sleep(nanoseconds: delay)
    }

    // All retries exhausted.
    print("[STStoreManager] All \(Self.maxRetries) attempts failed. Product IDs requested: \(ids)")
    loadFailed = true
  }

  // MARK: - Premium Status

  @MainActor
  func updatePremiumStatus() async {
    // Step 1: Check current entitlements (covers active subscriptions and free trials).
    var active = false
    for await result in Transaction.currentEntitlements {
      if case .verified(let tx) = result,
         (tx.productID == Self.monthlyID || tx.productID == Self.annualID),
         tx.revocationDate == nil {
        active = true
        break
      }
    }

    // Step 2: If no active entitlement, check subscription status for
    // billing retry / grace period — the user should keep access.
    if !active {
      active = await isInBillingRetryOrGracePeriod()
    }

    isPremium = active
  }

  /// Returns `true` when the subscription is in billing retry or a grace period.
  /// Apple recommends keeping the user's access during these states so they don't
  /// lose data or functionality while Apple retries the charge.
  @MainActor
  private func isInBillingRetryOrGracePeriod() async -> Bool {
    let ids = [Self.monthlyID, Self.annualID]
    for id in ids {
      guard let product = products.first(where: { $0.id == id }),
            let subscription = product.subscription else { continue }
      do {
        let statuses = try await subscription.status
        for status in statuses {
          switch status.state {
          case .inBillingRetryPeriod, .inGracePeriod:
            // Verify the transaction is legit before granting access.
            if case .verified = status.transaction {
              print("[STStoreManager] \(id): granting access during \(status.state)")
              return true
            }
          default:
            continue
          }
        }
      } catch {
        print("[STStoreManager] Failed to check status for \(id): \(error)")
      }
    }
    return false
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
          purchaseError = String(localized: "Purchase could not be verified. Please try again.")
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
        purchaseError = String(localized: "No active subscription found.")
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
    case .week:  return count == 1 ? String(localized: "1 week free")  : String(localized: "\(count) weeks free")
    case .day:   return count == 1 ? String(localized: "1 day free")   : String(localized: "\(count) days free")
    case .month: return count == 1 ? String(localized: "1 month free") : String(localized: "\(count) months free")
    default:     return String(localized: "Free trial")
    }
  }

  /// Percentage saved buying annual vs. 12 × monthly, formatted as "37%".
  var annualSavingsPercent: String? {
    guard let m = monthlyProduct, let a = annualProduct else { return nil }
    let monthlyEquivalent = NSDecimalNumber(decimal: m.price).doubleValue * 12.0
    let annualPrice = NSDecimalNumber(decimal: a.price).doubleValue
    guard monthlyEquivalent > 0 else { return nil }
    let pct = ((monthlyEquivalent - annualPrice) / monthlyEquivalent) * 100.0
    guard pct > 0 else { return nil }
    return "\(Int(pct.rounded()))%"
  }
}
