# Contributing to StayTrackr

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<short-description>` | `feature/add-booking-calendar` |
| Bug fix | `fix/<short-description>` | `fix/rent-calculation-overflow` |
| Hotfix | `hotfix/<short-description>` | `hotfix/crash-on-property-delete` |
| Chore/tooling | `chore/<short-description>` | `chore/update-swiftlint` |
| Release | `release/<version>` | `release/7.0.0` |

- Lowercase, hyphens only
- Branch from `main`; hotfixes also target `main`
- Keep branches short-lived (< 2 weeks)

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `style`, `perf`, `ci`  
**Scope:** component or module (e.g. `BookingView`, `PropertyModel`, `auth`, `ci`)

Examples:
```
feat(BookingCalendar): add multi-night range selection
fix(auth): handle nil token on logout
chore(ci): add SwiftLint to GitHub Actions
```

---

## Pull Request Process

1. Self-review your diff before opening a PR.
2. All PRs target `main`.
3. PR title: same format as a commit message.
4. Fill in the PR description template.
5. CI must pass (SwiftLint + build) before requesting review.
6. One approval required.
7. Squash-merge to keep history clean.

### PR Size Guidelines

| Lines changed | Expectation |
|---------------|-------------|
| < 200 | Normal |
| 200–500 | Add extra context in description |
| > 500 | Split into smaller PRs unless unavoidable |

---

## Code Review Checklist

### Reviewer

- [ ] Does the code do what the PR description says?
- [ ] Are force-unwraps (`!`) and `try!` justified or replaced?
- [ ] Are async operations using `async/await` over callbacks?
- [ ] Are side-effects in `View` bodies avoided (moved to `ViewModel`)?
- [ ] Are new model properties `Codable`/`Equatable` where needed?
- [ ] Does UI handle empty state, loading, and error states?
- [ ] Are magic numbers extracted to named constants?

### Author before requesting review

- [ ] CI is green
- [ ] SwiftLint reports zero errors (`swiftlint lint`)
- [ ] Manually tested on a device or relevant simulator
- [ ] No debug `print()` left in production paths
- [ ] No `TODO:` left in ship-blocking code paths
- [ ] Accessibility labels added for new interactive elements

---

## Code Style

SwiftLint enforces most rules automatically. Key conventions:

- **MVVM** — Views are dumb; logic lives in `ViewModel` or `Model` types
- **SwiftUI** — Prefer SwiftUI views; UIKit only where no SwiftUI equivalent exists
- **Concurrency** — `async/await` and `Task` for new code
- **Access control** — Default to the most restrictive level; widen only when needed
- **Naming** — Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): clarity at the call site
