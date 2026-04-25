import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Personalized Onboarding

struct V4PersonalizedOnboardingView: View {

  @Environment(V4AppSettings.self) private var settings
  @Environment(\.modelContext)     private var context

  // MARK: - Step

  enum Step: Int {
    case welcome, portfolioSize, currency, platform, addProperty, addGuest, addBooking, allDone
  }

  @State private var step: Step = .welcome

  // MARK: - Answers

  enum PortfolioSize: String, CaseIterable {
    case one      = "Just starting out (1)"
    case few      = "Small portfolio (2–5)"
    case growing  = "Growing portfolio (6–20)"
    case large    = "Large portfolio (20+)"
    var icon: String {
      switch self {
      case .one:     return "🏠"
      case .few:     return "🏘️"
      case .growing: return "🏙️"
      case .large:   return "🏢"
      }
    }
  }

  @State private var portfolioSize: PortfolioSize = .one
  @State private var currencyCode: String = "EUR"
  @State private var selectedPlatforms: Set<String> = []

  // Property
  @State private var propertyName: String = ""
  @State private var propertyEmoji: String = "🏠"

  // Guest
  @State private var guestName: String  = ""
  @State private var guestEmail: String = ""
  @State private var guestPhone: String = ""

  // Booking
  @State private var bookingGuestName: String = ""
  @State private var checkIn: Date  = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
  @State private var checkOut: Date = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
  @State private var nightlyRate: String = ""

  // Created objects
  @State private var createdProperty: STProperty? = nil
  @State private var createdGuest: STGuest? = nil

  // Restore flow
  @State private var showRestoreError = false
  @State private var restoreErrorMessage = ""

  // MARK: - Constants

  private let commonCurrencies = ["EUR","CZK","USD","GBP","CHF","PLN","SEK","NOK","DKK","HUF"]
  private let platforms        = ["Airbnb","Booking.com","VRBO","Direct bookings","Multiple platforms"]
  private let emojiOptions     = ["🏠","🏖️","🏔️","🏙️","🏡","🌴","🏢","🏰","🗺️","🏗️"]

  // MARK: - Body

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()

      VStack(spacing: 0) {
        if step != .welcome && step != .allDone {
          progressDots.padding(.top, 20)
        }

        Group {
          switch step {
          case .welcome:       welcomeView
          case .portfolioSize: portfolioSizeView
          case .currency:      currencyView
          case .platform:      platformView
          case .addProperty:   addPropertyView
          case .addGuest:      addGuestView
          case .addBooking:    addBookingView
          case .allDone:       allDoneView
          }
        }
        .transition(.asymmetric(
          insertion:  .move(edge: .trailing).combined(with: .opacity),
          removal:    .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.28), value: step)
      }
    }
  }

  // MARK: - Progress Dots

  private var progressDots: some View {
    HStack(spacing: 7) {
      ForEach(1...6, id: \.self) { i in
        Capsule()
          .fill(step.rawValue >= i ? V4Theme.Brand.primary : Color.secondary.opacity(0.25))
          .frame(width: step.rawValue == i ? 20 : 7, height: 7)
          .animation(.easeInOut(duration: 0.2), value: step)
      }
    }
  }

  // MARK: - Welcome

  private var welcomeView: some View {
    VStack(spacing: 0) {
      Spacer()
      VStack(spacing: 28) {
        ZStack {
          RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(LinearGradient(
              colors: [V4Theme.Brand.primary, V4Theme.Brand.primary.opacity(0.65)],
              startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: 110, height: 110)
            .shadow(color: V4Theme.Brand.primary.opacity(0.4), radius: 24, y: 10)
          Image(systemName: "house.fill")
            .font(.system(size: 50))
            .foregroundStyle(.white)
        }

        VStack(spacing: 10) {
          Text("Welcome to StayTrackr")
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
          Text("Let's personalise your workspace\nin just a few steps.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      Spacer()
      VStack(spacing: 12) {
        primaryButton("Get Started") { advance() }

        SignInWithAppleButton(.signIn) { request in
          request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
          handleRestore(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color(.separator), lineWidth: 1)
        )

        Text("Already have an account? Sign in to restore your data.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 48)
      .alert("Sign In Error", isPresented: $showRestoreError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(restoreErrorMessage)
      }
    }
  }

  // MARK: - Restore Handler

  private func handleRestore(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let auth):
      if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
        settings.appleUserID = credential.user
        UserDefaults.standard.set(true, forKey: "v4_didSeed")
        // Delay the root-view transition so the Sign in with Apple sheet can
        // fully dismiss first — avoids the app freezing on iPad (Apple review 2.1(a)).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          withAnimation { settings.hasSeenOnboarding = true }
        }
      }
    case .failure(let error):
      if (error as? ASAuthorizationError)?.code != .canceled {
        restoreErrorMessage = error.localizedDescription
        showRestoreError = true
      }
    }
  }

  // MARK: - Portfolio Size

  private var portfolioSizeView: some View {
    VStack(spacing: 28) {
      questionHeader("How many properties\ndo you manage?")

      VStack(spacing: 10) {
        ForEach(PortfolioSize.allCases, id: \.self) { size in
          selectionCard(icon: size.icon, label: size.rawValue, isSelected: portfolioSize == size) {
            portfolioSize = size
          }
        }
      }
      .padding(.horizontal, 24)

      Spacer()
      primaryButton("Next") { advance() }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
    .padding(.top, 28)
  }

  // MARK: - Currency

  private var currencyView: some View {
    VStack(spacing: 28) {
      questionHeader("What's your main\ncurrency?")

      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
        ForEach(commonCurrencies, id: \.self) { code in
          currencyCard(code: code, isSelected: currencyCode == code) {
            currencyCode = code
          }
        }
      }
      .padding(.horizontal, 24)

      Spacer()
      primaryButton("Next") {
        settings.reportingCurrencyCode = currencyCode
        advance()
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 48)
    }
    .padding(.top, 28)
  }

  // MARK: - Platform

  private var platformView: some View {
    VStack(spacing: 28) {
      questionHeader("Where do you list\nyour properties?")

      VStack(spacing: 10) {
        ForEach(platforms, id: \.self) { platform in
          selectionCard(
            icon: platformIcon(platform),
            label: platform,
            isSelected: selectedPlatforms.contains(platform)
          ) {
            if selectedPlatforms.contains(platform) {
              selectedPlatforms.remove(platform)
            } else {
              selectedPlatforms.insert(platform)
            }
          }
        }
      }
      .padding(.horizontal, 24)

      Spacer()
      primaryButton("Next") { advance() }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
    .padding(.top, 28)
  }

  // MARK: - Add Property

  private var addPropertyView: some View {
    ScrollView {
      VStack(spacing: 28) {
        questionHeader("Let's add your\nfirst property")

        VStack(alignment: .leading, spacing: 18) {

          VStack(alignment: .leading, spacing: 8) {
            Text("Property name")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.secondary)
            TextField("e.g. Casa Azul, Beach House…", text: $propertyName)
              .padding(14)
              .background(Color(.secondarySystemGroupedBackground),
                          in: RoundedRectangle(cornerRadius: 12))
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Pick an icon")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
              ForEach(emojiOptions, id: \.self) { emoji in
                Button { propertyEmoji = emoji } label: {
                  Text(emoji)
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                      propertyEmoji == emoji
                        ? V4Theme.Brand.primary.opacity(0.12)
                        : Color(.secondarySystemGroupedBackground),
                      in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(propertyEmoji == emoji ? V4Theme.Brand.primary : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .padding(.horizontal, 24)

        primaryButton("Continue") {
          let trimmed = propertyName.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          let prop = STProperty(
            id: UUID(),
            name: trimmed,
            purchasePrice: 0,
            mortgageAPR: 0,
            mortgageYears: 0,
            commissionPct: platformCommission,
            emoji: propertyEmoji,
            colorHex: "#1FB86E",
            isArchived: false,
            trackMortgage: false,
            currencyCode: currencyCode
          )
          context.insert(prop)
          createdProperty = prop
          advance()
        }
        .disabled(propertyName.trimmingCharacters(in: .whitespaces).isEmpty)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
      }
      .padding(.top, 28)
    }
  }

  // MARK: - Add Guest

  private var addGuestView: some View {
    ScrollView {
      VStack(spacing: 28) {
        VStack(spacing: 8) {
          questionHeader("Add your first guest")
          Text("You can skip this and add guests later.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 10) {
          TextField("Guest name", text: $guestName)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

          TextField("Email (optional)", text: $guestEmail)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

          TextField("Phone (optional)", text: $guestPhone)
            .keyboardType(.phonePad)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)

        VStack(spacing: 12) {
          primaryButton("Add Guest") {
            let trimmed = guestName.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
              let guest = STGuest(
                id: UUID(),
                name: trimmed,
                email: guestEmail.isEmpty ? nil : guestEmail,
                phone: guestPhone.isEmpty ? nil : guestPhone
              )
              context.insert(guest)
              createdGuest = guest
              bookingGuestName = trimmed
            }
            advance()
          }
          skipButton { advance() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
      }
      .padding(.top, 28)
    }
  }

  // MARK: - Add Booking

  private var addBookingView: some View {
    ScrollView {
      VStack(spacing: 28) {
        VStack(spacing: 8) {
          questionHeader("Add an upcoming\nbooking")
          Text("You can skip this and add bookings later.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 10) {
          // Guest name
          if createdGuest != nil {
            HStack(spacing: 10) {
              Image(systemName: "person.fill").foregroundStyle(V4Theme.Brand.primary)
              Text(bookingGuestName).font(.subheadline.weight(.medium))
              Spacer()
              Image(systemName: "checkmark.circle.fill").foregroundStyle(V4Theme.Brand.primary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
          } else {
            TextField("Guest name", text: $bookingGuestName)
              .padding(14)
              .background(Color(.secondarySystemGroupedBackground),
                          in: RoundedRectangle(cornerRadius: 12))
          }

          // Dates
          DatePicker("Check-in", selection: $checkIn, displayedComponents: .date)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

          DatePicker("Check-out", selection: $checkOut, in: checkIn..., displayedComponents: .date)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

          // Nightly rate
          HStack {
            Text(currencyCode)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(width: 46)
            TextField("Nightly rate", text: $nightlyRate)
              .keyboardType(.decimalPad)
          }
          .padding(14)
          .background(Color(.secondarySystemGroupedBackground),
                      in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)

        VStack(spacing: 12) {
          primaryButton("Add Booking") {
            if let prop = createdProperty,
               let rate = Double(nightlyRate.replacingOccurrences(of: ",", with: ".")),
               rate > 0 {
              let guest = createdGuest ?? {
                let gName = bookingGuestName.trimmingCharacters(in: .whitespaces)
                let g = STGuest(id: UUID(), name: gName.isEmpty ? "Guest" : gName, email: nil, phone: nil)
                context.insert(g)
                return g
              }()
              let booking = STBooking(
                id: UUID(),
                property: prop,
                guest: guest,
                checkIn: checkIn,
                checkOut: checkOut,
                nightlyRate: rate,
                platformFeePct: platformCommission,
                isPaid: false
              )
              context.insert(booking)
            }
            step = .allDone
          }
          skipButton { step = .allDone }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
      }
      .padding(.top, 28)
    }
  }

  // MARK: - All Done

  private var allDoneView: some View {
    VStack(spacing: 0) {
      Spacer()
      VStack(spacing: 28) {
        ZStack {
          Circle()
            .fill(V4Theme.Brand.primary.opacity(0.1))
            .frame(width: 110, height: 110)
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(V4Theme.Brand.primary)
        }

        VStack(spacing: 10) {
          Text("You're all set!")
            .font(.largeTitle.weight(.bold))
          Text(doneMessage)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }

        // Summary chips
        VStack(spacing: 8) {
          if let prop = createdProperty {
            summaryChip(icon: "house.fill", label: prop.emoji + " " + prop.name)
          }
          if let guest = createdGuest {
            summaryChip(icon: "person.fill", label: guest.name)
          }
        }
      }
      Spacer()
      primaryButton("Go to Dashboard") { finish() }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
  }

  // MARK: - Helpers

  private var platformCommission: Double {
    if selectedPlatforms.contains("Airbnb")       { return 0.14 }
    if selectedPlatforms.contains("Booking.com")  { return 0.15 }
    if selectedPlatforms.contains("VRBO")         { return 0.05 }
    return 0.0
  }

  private var doneMessage: String {
    switch portfolioSize {
    case .one:
      return "Your first property is ready.\nStart adding bookings and track your revenue."
    case .few:
      return "Your workspace is set up.\nAdd your remaining properties to get the full picture."
    case .growing:
      return "Your workspace is ready.\nUpgrade to Premium to manage all your properties."
    case .large:
      return "Your workspace is ready.\nUpgrade to Premium to unlock unlimited properties and charts."
    }
  }

  private func advance() {
    withAnimation(.easeInOut(duration: 0.28)) {
      switch step {
      case .welcome:       step = .portfolioSize
      case .portfolioSize: step = .currency
      case .currency:      step = .platform
      case .platform:      step = .addProperty
      case .addProperty:   step = .addGuest
      case .addGuest:      step = .addBooking
      case .addBooking:    step = .allDone
      case .allDone:       finish()
      }
    }
  }

  private func finish() {
    try? context.save()
    // Prevent DEBUG seeder from running after onboarding
    UserDefaults.standard.set(true, forKey: "v4_didSeed")
    withAnimation { settings.hasSeenOnboarding = true }
  }

  // MARK: - Reusable UI

  private func questionHeader(_ title: LocalizedStringKey) -> some View {
    Text(title)
      .font(.title2.weight(.bold))
      .multilineTextAlignment(.center)
      .padding(.horizontal, 24)
  }

  private func primaryButton(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(V4Theme.Brand.primary,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func skipButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text("Skip for now")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private func selectionCard(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Text(icon).font(.title3)
        Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? V4Theme.Brand.primary : .secondary)
      }
      .padding(14)
      .background(
        isSelected ? V4Theme.Brand.primary.opacity(0.08) : Color(.secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .strokeBorder(isSelected ? V4Theme.Brand.primary : .clear, lineWidth: 2)
      )
    }
    .buttonStyle(.plain)
  }

  private func currencyCard(code: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(code)
        .font(.headline)
        .foregroundStyle(isSelected ? V4Theme.Brand.primary : .primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          isSelected ? V4Theme.Brand.primary.opacity(0.10) : Color(.secondarySystemGroupedBackground),
          in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? V4Theme.Brand.primary : .clear, lineWidth: 2)
        )
    }
    .buttonStyle(.plain)
  }

  private func summaryChip(icon: String, label: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon).foregroundStyle(V4Theme.Brand.primary)
      Text(label).font(.subheadline.weight(.medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(V4Theme.Brand.primary.opacity(0.08), in: Capsule())
  }

  private func platformIcon(_ platform: String) -> String {
    switch platform {
    case "Airbnb":            return "🏠"
    case "Booking.com":       return "🔵"
    case "VRBO":              return "🏡"
    case "Direct bookings":   return "🤝"
    default:                  return "📱"
    }
  }
}
