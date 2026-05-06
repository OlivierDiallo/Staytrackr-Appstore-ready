# StayTrackr — Developer Setup

## Requirements

| Tool | Required version | Install |
|------|-----------------|---------|
| macOS | 14.0 (Sonoma) or later | System update |
| Xcode | **16.2** | Mac App Store or [developer.apple.com](https://developer.apple.com/download/) |
| Xcode Command Line Tools | bundled with Xcode | `xcode-select --install` |
| Homebrew | latest | [brew.sh](https://brew.sh) |
| Ruby | 3.3+ via rbenv | `brew install rbenv ruby-build` |
| Bundler | latest | `gem install bundler` |
| SwiftLint | latest | `brew install swiftlint` |

> **Xcode version is pinned to 16.2.** CI enforces this — do not use a different version.

---

## First-Run Setup

```bash
# 1. Clone the repo
git clone https://github.com/OlivierDiallo/Staytrackr-Appstore-ready.git
cd Staytrackr-Appstore-ready

# 2. Set up xcconfig secrets
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Fill in your AviationStack API key (or leave placeholder for builds that don't need it)

# 3. Install Ruby gems (Fastlane)
bundle install

# 4. Verify SwiftLint
swiftlint lint     # should report 0 errors on a fresh clone

# 5. Open in Xcode
open "StayTrackr V3.xcodeproj"
# Select an iPhone 17-series simulator and press ▶
```

---

## Building from the Terminal

```bash
xcodebuild build \
  -project "StayTrackr V3.xcodeproj" \
  -scheme "StayTrackr V3" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  CODE_SIGNING_ALLOWED=NO \
  | xcpretty
```

---

## Code Signing (Device Builds)

For simulator builds, code signing is disabled automatically.

For device or distribution builds, use Fastlane Match:

```bash
bundle exec fastlane match development
```

Requirements:
- Apple ID with access to the `OlivierDiallo` Apple Developer team
- Access to the Match certificates repo (ask the team)
- Match passphrase (stored in 1Password under **StayTrackr Match**)

---

## Environment Variables (Fastlane / CI)

```bash
cp .env.example .env
# Fill in APPLE_ID, APPLE_TEAM_ID, ITC_TEAM_ID, MATCH_GIT_URL, MATCH_PASSWORD
```

`.env` is gitignored — never commit it.

---

## Project Structure

```
StayTrackr V3.xcodeproj   # Xcode project (scheme: "StayTrackr V3")
StayTrackr V3/            # Legacy source (pre-V4 screens still in use)
V4/                       # Current architecture (MVVM, async/await)
│   ├── App/              # Entry point, scene/app delegates
│   ├── Features/         # Feature modules
│   ├── Data/             # Repositories, network, persistence
│   ├── Models/           # Domain models
│   ├── UI/               # Shared UI components
│   └── Utils/            # Extensions, helpers
Core/                     # Shared utilities used across V3 and V4
Config/                   # Xcconfig files (Secrets.xcconfig is gitignored)
StayTrackrPremium.storekit  # StoreKit configuration for in-app purchases
fastlane/                 # Fastlane lanes (beta, release)
.github/workflows/        # GitHub Actions CI
```

---

## CI/CD Overview

| Trigger | Action |
|---------|--------|
| PR opened / updated | SwiftLint → build (via GitHub Actions) |
| Merge to `main` | Same as PR |
| Manual | `bundle exec fastlane beta` → TestFlight |
| Release | `bundle exec fastlane release` → App Store |

GitHub Actions requires these repo secrets configured in **Settings → Secrets and variables → Actions**:
`APPLE_ID`, `APPLE_TEAM_ID`, `ITC_TEAM_ID`, `MATCH_GIT_URL`, `MATCH_PASSWORD`

---

## Common Issues

| Symptom | Fix |
|---------|-----|
| Build error: missing Secrets.xcconfig | `cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig` |
| SwiftLint "command not found" | `brew install swiftlint` |
| Build error after Xcode update | Ensure you're on Xcode **16.2** exactly |
| Simulator not listed | `xcodebuild -downloadPlatform iOS` |
| Fastlane "bundle exec not found" | `bundle install` from repo root |

---

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch naming and PR conventions.
