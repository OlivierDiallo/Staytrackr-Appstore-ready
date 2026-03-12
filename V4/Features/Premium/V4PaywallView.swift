import SwiftUI
import StoreKit

// MARK: - Paywall View

struct V4PaywallView: View {

  @Environment(\.dismiss) private var dismiss
  @Environment(STStoreManager.self) private var store

  // Annual is pre-selected (index 1) to highlight best value.
  @State private var selectedIndex: Int = 1
  @State private var showError = false

  // MARK: - Feature Rows

  private struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: LocalizedStringKey
    let isPremium: Bool
  }

  private let features: [FeatureItem] = [
    .init(icon: "house.fill",                label: "1 property",                        isPremium: false),
    .init(icon: "calendar",                  label: "Booking calendar",                  isPremium: false),
    .init(icon: "creditcard",                label: "Expense tracking & guests",          isPremium: false),
    .init(icon: "house.fill",                label: "Unlimited properties",              isPremium: true),
    .init(icon: "arrow.down.doc.fill",       label: "CSV export",                        isPremium: true),
    .init(icon: "chart.bar.fill",            label: "Revenue charts",                    isPremium: true),
    .init(icon: "icloud.fill",               label: "iCloud sync",                       isPremium: true),
    .init(icon: "repeat.circle.fill",        label: "Recurring bills",                   isPremium: true),
    .init(icon: "chart.line.uptrend.xyaxis", label: "Yearly & All-Time totals",          isPremium: true),
    .init(icon: "camera.fill",               label: "Receipt photos on expenses",        isPremium: true),
    .init(icon: "bell.badge.fill",           label: "Custom notification timing",        isPremium: true),
    .init(icon: "arrow.left.arrow.right",    label: "FX rates management",               isPremium: true),
  ]

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          appIconHeader
          featureList
          pricingCards
          purchaseButton
          restoreButton
          dismissLink
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 40)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .foregroundStyle(.secondary)
              .symbolRenderingMode(.hierarchical)
          }
          .accessibilityLabel("Close")
        }
      }
      .alert("Purchase Error", isPresented: $showError) {
        Button("OK", role: .cancel) { store.purchaseError = nil }
      } message: {
        Text(store.purchaseError ?? "")
      }
      .onChange(of: store.purchaseError) { _, err in
        if err != nil { showError = true }
      }
      .onChange(of: store.isPremium) { _, isPremium in
        if isPremium { dismiss() }
      }
    }
  }

  // MARK: - App Icon Header

  private var appIconHeader: some View {
    VStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(
            LinearGradient(
              colors: [V4Theme.Brand.primary, V4Theme.Brand.primary.opacity(0.7)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 88, height: 88)
          .shadow(color: V4Theme.Brand.primary.opacity(0.4), radius: 16, y: 6)
        Image(systemName: "house.fill")
          .font(.system(size: 38))
          .foregroundStyle(.white)
      }

      VStack(spacing: 6) {
        Text("StayTrackr Premium")
          .font(.title2.weight(.bold))
        if store.isEligibleForTrial {
          Text("Try free for 7 days.\nUnlock every feature, cancel anytime.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        } else {
          Text("Unlock every feature for your\nrental management workflow.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }
    }
  }

  // MARK: - Feature List

  private var featureList: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(features) { item in
        HStack(spacing: 12) {
          Image(systemName: item.isPremium ? "checkmark.circle.fill" : "checkmark.circle")
            .font(.system(size: 18))
            .foregroundStyle(item.isPremium ? V4Theme.Brand.primary : Color.secondary)
            .frame(width: 24)

          Text(item.label)
            .font(.subheadline)
            .foregroundStyle(item.isPremium ? Color.primary : Color.secondary)

          Spacer()

          if !item.isPremium {
            Text("Free")
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.12), in: Capsule())
          }
        }
      }
    }
    .padding(V4Theme.Spacing.cardPadding)
    .background(.ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous))
  }

  // MARK: - Pricing Cards

  private var pricingCards: some View {
    VStack(spacing: 10) {
      if store.products.isEmpty {
        HStack(spacing: 10) {
          ProgressView()
          Text("Loading prices...")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous))
      } else {
        ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
          pricingCard(product: product, index: index)
        }
      }
    }
  }

  private func pricingCard(product: Product, index: Int) -> some View {
    let isSelected = selectedIndex == index
    let isAnnual   = product.id == STStoreManager.annualID
    let savings    = isAnnual ? store.annualSavingsPercent : nil

    let trialText = store.isEligibleForTrial ? store.trialLabel(for: product) : nil

    return Button {
      withAnimation(.easeInOut(duration: 0.15)) {
        selectedIndex = index
      }
    } label: {
      ZStack(alignment: .topTrailing) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(isAnnual ? "Annual" : "Monthly")
              .font(.headline)
            if let trial = trialText {
              Text(trial)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(V4Theme.Brand.primary)
              Text("then " + product.displayPrice + (isAnnual ? " / year" : " / month"))
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text(product.displayPrice + (isAnnual ? " / year" : " / month"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if isAnnual, let savings {
              Text("Save \(savings) vs monthly")
                .font(.caption.weight(.medium))
                .foregroundStyle(V4Theme.Brand.primary)
            }
          }
          Spacer()
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? V4Theme.Brand.primary : Color.secondary)
        }
        .padding(V4Theme.Spacing.cardPadding)
        .background(
          RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous)
            .fill(isSelected
                  ? V4Theme.Brand.primary.opacity(0.08)
                  : Color(.secondarySystemGroupedBackground))
            .overlay(
              RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous)
                .strokeBorder(isSelected ? V4Theme.Brand.primary : Color.clear, lineWidth: 2)
            )
        )

        // "Best Value" badge on annual card
        if isAnnual {
          Text("Best Value")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(V4Theme.Brand.primary, in: Capsule())
            .offset(x: -14, y: -10)
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Purchase Button

  private var purchaseButton: some View {
    let selectedProduct: Product? = store.products.indices.contains(selectedIndex)
      ? store.products[selectedIndex]
      : nil
    let hasTrial = store.isEligibleForTrial
      && selectedProduct.flatMap { store.trialLabel(for: $0) } != nil
    let buttonLabel: String = {
      guard selectedProduct != nil else { return "Loading..." }
      return hasTrial ? "Start Free Trial" : "Subscribe Now"
    }()
    let isAnnual = selectedProduct?.id == STStoreManager.annualID
    let period   = isAnnual ? "year" : "month"

    return VStack(spacing: 10) {
      Button {
        guard let product = selectedProduct else { return }
        Task { await store.purchase(product) }
      } label: {
        ZStack {
          if store.isPurchasing {
            ProgressView().tint(.white)
          } else {
            Text(buttonLabel)
              .font(.headline)
              .foregroundStyle(.white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
          selectedProduct != nil ? V4Theme.Brand.primary : Color.secondary,
          in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
      }
      .disabled(selectedProduct == nil || store.isPurchasing)

      // Trial disclaimer
      if hasTrial, let product = selectedProduct {
        Text("7 days free, then \(product.displayPrice) / \(period). Cancel anytime.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: - Restore Button

  private var restoreButton: some View {
    Button {
      Task { await store.restorePurchases() }
    } label: {
      Text("Restore Purchases")
        .font(.subheadline)
        .foregroundStyle(V4Theme.Brand.primary)
    }
    .disabled(store.isPurchasing)
  }

  // MARK: - Dismiss Link

  private var dismissLink: some View {
    Button { dismiss() } label: {
      Text("Continue with Free")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }
}
