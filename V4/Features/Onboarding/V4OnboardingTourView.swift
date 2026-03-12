import SwiftUI

// MARK: - First-Launch Tour

/// A full-screen, 4-step walkthrough shown exactly once when the user
/// first opens the app. Each step fills the screen with an illustration,
/// headline, and body copy. A paging TabView handles the swipe gesture.
/// After the final step the user taps "Get Started" and the app moves on.
struct V4OnboardingTourView: View {

  @Environment(V4AppSettings.self) private var settings

  /// Fires when the tour is complete so the parent can update state.
  var onComplete: () -> Void

  @State private var currentPage: Int = 0

  private let pages: [TourPage] = TourPage.all

  var body: some View {
    ZStack(alignment: .bottom) {
      // Background gradient that subtly shifts per page
      LinearGradient(
        colors: [pages[currentPage].accentColor.opacity(0.12), Color(.systemBackground)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      .animation(.easeInOut(duration: 0.5), value: currentPage)

      // Paging tab view
      TabView(selection: $currentPage) {
        ForEach(pages.indices, id: \.self) { i in
          TourPageView(page: pages[i])
            .tag(i)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.easeInOut, value: currentPage)

      // Bottom controls
      VStack(spacing: 20) {
        // Page dots
        HStack(spacing: 8) {
          ForEach(pages.indices, id: \.self) { i in
            Capsule()
              .fill(i == currentPage ? V4Theme.Brand.primary : Color.secondary.opacity(0.3))
              .frame(width: i == currentPage ? 24 : 8, height: 8)
              .animation(.spring(response: 0.3), value: currentPage)
          }
        }

        // Action button
        if currentPage < pages.count - 1 {
          HStack(spacing: 16) {
            Button {
              // Skip straight to the end
              finishTour()
            } label: {
              Text("Skip")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
              withAnimation {
                currentPage += 1
              }
            } label: {
              Label("Next", systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(V4Theme.Brand.primary,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
          }
        } else {
          Button {
            finishTour()
          } label: {
            Text("Get Started")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(V4Theme.Brand.primary,
                          in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 48)
    }
  }

  private func finishTour() {
    settings.hasSeenOnboarding = true
    onComplete()
  }
}

// MARK: - Tour Page Model

private struct TourPage {
  let icon: String
  let accentColor: Color
  let title: LocalizedStringKey
  let body: LocalizedStringKey

  static let all: [TourPage] = [
    TourPage(
      icon: "house.fill",
      accentColor: V4Theme.Brand.primary,
      title: "Welcome to StayTrackr",
      body: "Your all-in-one rental property manager. Track bookings, income and expenses — across as many properties as you own."
    ),
    TourPage(
      icon: "calendar.badge.plus",
      accentColor: .blue,
      title: "Visual Booking Calendar",
      body: "See every arrival and departure at a glance. Tap any day to add a booking, and track occupancy month by month."
    ),
    TourPage(
      icon: "chart.bar.fill",
      accentColor: .orange,
      title: "Revenue & Expense Totals",
      body: "Monitor gross revenue, net income, commission and costs per property. Filter by month, year, or all-time — with multi-currency FX support."
    ),
    TourPage(
      icon: "star.fill",
      accentColor: V4Theme.Brand.primary,
      title: "Unlock Premium",
      body: "Upgrade for unlimited properties, CSV export, recurring bills, revenue charts and more. Try free for 7 days — cancel anytime."
    ),
  ]
}

// MARK: - Tour Page View

private struct TourPageView: View {
  let page: TourPage

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      // Icon
      ZStack {
        Circle()
          .fill(page.accentColor.opacity(0.12))
          .frame(width: 140, height: 140)
        Image(systemName: page.icon)
          .font(.system(size: 64, weight: .medium))
          .foregroundStyle(page.accentColor)
      }
      .padding(.bottom, 8)

      // Text
      VStack(spacing: 14) {
        Text(page.title)
          .font(.largeTitle.weight(.bold))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        Text(page.body)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 8)
      }

      Spacer()
      Spacer()
    }
    .padding(.horizontal, 28)
  }
}
