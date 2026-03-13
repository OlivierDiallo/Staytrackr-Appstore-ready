import SwiftUI
import AuthenticationServices

// MARK: - User Profile Tab

struct V4UserProfileView: View {
  @Environment(V4AppSettings.self) private var settings
  @Environment(STStoreManager.self) private var store

  @State private var showPaywall = false
  @State private var showSignInError = false
  @State private var signInErrorMessage = ""

  var body: some View {
    NavigationStack {
      List {

        // MARK: — Profile Header
        profileHeaderSection

        // MARK: — Account & iCloud
        accountSection

        // MARK: — Premium
        premiumSection

      }
      .listStyle(.insetGrouped)
      .navigationTitle("Profile")
    }
    .sheet(isPresented: $showPaywall) {
      V4PaywallView().environment(store)
    }
    .alert("Sign In Error", isPresented: $showSignInError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(signInErrorMessage)
    }
  }

  // MARK: - Profile Header

  @ViewBuilder
  private var profileHeaderSection: some View {
    Section {
      HStack(spacing: 16) {
        // Avatar circle
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [V4Theme.Brand.primary, V4Theme.Brand.primary.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 60, height: 60)
            .shadow(color: V4Theme.Brand.primary.opacity(0.3), radius: 8, y: 3)
          Image(systemName: "person.fill")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white.opacity(settings.appleUserID != nil ? 1.0 : 0.75))
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(settings.appleUserID != nil ? "Apple Account" : "Guest")
            .font(.headline)
          Text(settings.appleUserID != nil ? "Signed in with Apple" : "Not signed in")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if settings.appleUserID != nil {
          Image(systemName: "checkmark.seal.fill")
            .font(.title3)
            .foregroundStyle(V4Theme.Brand.primary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Account Section

  @ViewBuilder
  private var accountSection: some View {
    Section {
      if let userID = settings.appleUserID {

        // Apple ID row
        HStack(spacing: 12) {
          iconBadge(systemName: "applelogo", fill: Color(.systemFill), tint: .primary)
          VStack(alignment: .leading, spacing: 2) {
            Text("Apple ID")
              .font(.subheadline.weight(.medium))
            Text(verbatim: "\(String(userID.prefix(12)))...")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(V4Theme.Brand.primary)
        }
        .padding(.vertical, 2)

        // iCloud sync row
        HStack(spacing: 12) {
          iconBadge(systemName: "icloud.fill", fill: Color.blue.opacity(0.1), tint: .blue)
          VStack(alignment: .leading, spacing: 2) {
            Text("iCloud Sync")
              .font(.subheadline.weight(.medium))
            Text("Your data syncs automatically to iCloud.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 2)

        // Sign out
        Button(role: .destructive) {
          settings.appleUserID = nil
        } label: {
          HStack(spacing: 12) {
            iconBadge(systemName: "rectangle.portrait.and.arrow.right", fill: Color.red.opacity(0.1), tint: .red)
            Text("Sign Out")
              .font(.subheadline)
              .foregroundStyle(.red)
          }
        }
        .buttonStyle(.plain)

      } else {
        // Not signed in — description + button
        VStack(alignment: .leading, spacing: 8) {
          Text("Sync across your devices")
            .font(.subheadline.weight(.medium))
          Text("Sign in with Apple to keep your data backed up and in sync across all your devices via iCloud.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        SignInWithAppleButtonView { result in
          handleSignIn(result)
        }
        .frame(height: 44)
        .padding(.vertical, 4)
      }
    } header: {
      sectionHeader("Account & iCloud")
    } footer: {
      if settings.appleUserID == nil {
        Text("Your data is already stored in iCloud when you have iCloud Drive enabled. Sign in with Apple lets StayTrackr identify your account securely across reinstalls.")
          .font(.caption)
      }
    }
  }

  // MARK: - Premium Section

  @ViewBuilder
  private var premiumSection: some View {
    Section {
      if store.isPremium {
        // Active subscription
        HStack(spacing: 14) {
          ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(V4Theme.Brand.primary.opacity(0.12))
              .frame(width: 44, height: 44)
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 22))
              .foregroundStyle(V4Theme.Brand.primary)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text("StayTrackr Premium")
              .font(.subheadline.weight(.semibold))
            Text("Active subscription")
              .font(.caption)
              .foregroundStyle(V4Theme.Brand.primary)
          }
          Spacer()
          if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            Link("Manage", destination: url)
              .font(.subheadline)
              .foregroundStyle(V4Theme.Brand.primary)
          }
        }
        .padding(.vertical, 4)
      } else {
        // Upgrade CTA
        Button {
          showPaywall = true
        } label: {
          HStack(spacing: 14) {
            ZStack {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(V4Theme.Brand.primary.opacity(0.12))
                .frame(width: 44, height: 44)
              Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(V4Theme.Brand.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text("Upgrade to Premium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
              Text("Unlimited properties, charts, export & more")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
      }
    } header: {
      sectionHeader("StayTrackr Premium")
    }
  }

  // MARK: - Sign In Handler

  private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let authorization):
      if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
        settings.appleUserID = credential.user
      }
    case .failure(let error):
      if (error as? ASAuthorizationError)?.code != .canceled {
        signInErrorMessage = error.localizedDescription
        showSignInError = true
      }
    }
  }

  // MARK: - Helpers

  private func iconBadge(systemName: String, fill: Color, tint: Color) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(fill)
        .frame(width: 32, height: 32)
      Image(systemName: systemName)
        .font(.system(size: 15))
        .foregroundStyle(tint)
    }
  }

  private func sectionHeader(_ title: LocalizedStringKey) -> some View {
    Text(title)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
  }
}

// MARK: - Sign In With Apple Button (UIViewRepresentable)

/// Wraps ASAuthorizationAppleIDButton for use in SwiftUI.
/// Adapts its style automatically to light/dark mode.
private struct SignInWithAppleButtonView: UIViewRepresentable {
  var onCompletion: (Result<ASAuthorization, Error>) -> Void

  @Environment(\.colorScheme) private var colorScheme

  func makeCoordinator() -> Coordinator { Coordinator(onCompletion: onCompletion) }

  func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
    let style: ASAuthorizationAppleIDButton.Style = colorScheme == .dark ? .white : .black
    let button = ASAuthorizationAppleIDButton(type: .signIn, style: style)
    button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
    return button
  }

  func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
    uiView.backgroundColor = colorScheme == .dark ? .white : .black
    uiView.tintColor       = colorScheme == .dark ? .black : .white
  }

  // MARK: Coordinator

  final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
      self.onCompletion = onCompletion
    }

    @objc func handleTap() {
      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
      onCompletion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
      onCompletion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      // Avoids deprecated UIWindow() / ASPresentationAnchor() no-arg init (iOS 26).
      // Sign In with Apple is only triggered from a visible UI, so a window always exists.
      let allWindows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
      return allWindows.first(where: { $0.isKeyWindow }) ?? allWindows.first!
    }
  }
}
