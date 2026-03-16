import SwiftUI

// MARK: - V4ScreenshotView
//
// Generates polished App Store screenshots for iPhone 16 Pro Max (6.9").
//
// HOW TO USE:
//   1. In Xcode, open this file and use the Preview canvas, OR
//      run the app on the iPhone 16 Pro Max Simulator.
//   2. Set the scene using the picker at the bottom.
//   3. Hide the picker (set showPicker = false) and take each screenshot
//      with Cmd+S in the Simulator.
//   4. Upload the 5 PNGs to App Store Connect.

struct V4ScreenshotView: View {

  @State private var scene: Scene = .dashboard
  @State private var showPicker = true

  var body: some View {
    ZStack(alignment: .bottom) {
      // Full-bleed gradient background
      scene.background.ignoresSafeArea()

      VStack(spacing: 0) {
        // Marketing headline block
        VStack(spacing: 10) {
          Text(scene.headline)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)

          Text(scene.subtitle)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.top, 68)
        .padding(.bottom, 28)

        // Phone frame + app content
        SSPhoneFrame {
          scene.content
        }
        .padding(.horizontal, 20)

        Spacer()
      }

      // Scene picker — tap the eye button to hide for clean screenshots
      VStack(spacing: 0) {
        if showPicker {
          Picker("Scene", selection: $scene) {
            ForEach(Scene.allCases) { s in
              Text(s.pickerLabel).tag(s)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, 12)
          .padding(.top, 10)
        }
        Button {
          showPicker.toggle()
        } label: {
          Image(systemName: showPicker ? "eye.slash" : "eye")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(8)
        }
      }
      .background(.ultraThinMaterial.opacity(showPicker ? 1 : 0))
    }
  }
}

// MARK: - Scenes

extension V4ScreenshotView {

  enum Scene: String, CaseIterable, Identifiable {
    case dashboard, calendar, expenses, totals, properties
    var id: String { rawValue }

    var pickerLabel: String {
      switch self {
      case .dashboard:  return "1"
      case .calendar:   return "2"
      case .expenses:   return "3"
      case .totals:     return "4"
      case .properties: return "5"
      }
    }

    var headline: String {
      switch self {
      case .dashboard:  return "Your rentals,\nfully under control"
      case .calendar:   return "Never miss\na check-in"
      case .expenses:   return "Every cost,\ncategorised"
      case .totals:     return "Know exactly\nwhat you earn"
      case .properties: return "One app for\nall your properties"
      }
    }

    var subtitle: String {
      switch self {
      case .dashboard:  return "Revenue · Net profit · Occupancy — at a glance"
      case .calendar:   return "Visual booking calendar with smart arrival alerts"
      case .expenses:   return "Cleaning, repairs, utilities & more — per property"
      case .totals:     return "Monthly, yearly or all-time financial breakdowns"
      case .properties: return "Unlimited properties with iCloud sync & FX rates"
      }
    }

    @ViewBuilder var content: some View {
      switch self {
      case .dashboard:  SSDashboardScreen()
      case .calendar:   SSCalendarScreen()
      case .expenses:   SSExpensesScreen()
      case .totals:     SSTotalsScreen()
      case .properties: SSPropertiesScreen()
      }
    }

    var background: LinearGradient {
      switch self {
      case .dashboard:
        return LinearGradient(
          colors: [Color(hex: "#0A1628"), Color(hex: "#1FB86E")],
          startPoint: .top, endPoint: .bottomTrailing)
      case .calendar:
        return LinearGradient(
          colors: [Color(hex: "#0D0D2B"), Color(hex: "#4338CA")],
          startPoint: .top, endPoint: .bottomTrailing)
      case .expenses:
        return LinearGradient(
          colors: [Color(hex: "#1A0A00"), Color(hex: "#EA580C")],
          startPoint: .top, endPoint: .bottomTrailing)
      case .totals:
        return LinearGradient(
          colors: [Color(hex: "#001A1A"), Color(hex: "#0D9488")],
          startPoint: .top, endPoint: .bottomTrailing)
      case .properties:
        return LinearGradient(
          colors: [Color(hex: "#160A24"), Color(hex: "#7C3AED")],
          startPoint: .top, endPoint: .bottomTrailing)
      }
    }
  }
}

// MARK: - Phone Frame

private struct SSPhoneFrame<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      // Phone body
      RoundedRectangle(cornerRadius: 52, style: .continuous)
        .fill(Color(hex: "#1C1C1E"))
        .shadow(color: .black.opacity(0.55), radius: 40, x: 0, y: 24)

      // Screen content
      content
        .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
        .padding(9)

      // Bezel highlight
      RoundedRectangle(cornerRadius: 52, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [.white.opacity(0.25), .white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1.5
        )

      // Dynamic Island
      VStack {
        Capsule()
          .fill(Color(hex: "#1C1C1E"))
          .frame(width: 116, height: 34)
          .padding(.top, 14)
        Spacer()
      }
    }
    .aspectRatio(9 / 19.5, contentMode: .fit)
  }
}

// MARK: - Mock Screen 1: Dashboard

private struct SSDashboardScreen: View {
  var body: some View {
    ZStack {
      Color(hex: "#F2F2F7").ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          // Nav bar
          HStack {
            Text("Dashboard")
              .font(.system(size: 20, weight: .bold))
            Spacer()
            Text("Today")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(Color(hex: "#1FB86E"))
          }
          .padding(.horizontal, 16)
          .padding(.top, 52)
          .padding(.bottom, 4)

          // Property pill
          HStack(spacing: 6) {
            Text("🏖️")
            Text("Casa Azul")
              .font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
          .padding(.horizontal, 12)

          // Month nav card
          SSCard {
            HStack {
              Image(systemName: "chevron.left")
                .foregroundStyle(Color(hex: "#1FB86E"))
              Spacer()
              Text("March 2026")
                .font(.system(size: 15, weight: .semibold))
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundStyle(Color(hex: "#1FB86E"))
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
              SSStatBox(label: "Gross", value: "€4,850", color: Color(hex: "#1FB86E"))
              Divider().frame(height: 40)
              SSStatBox(label: "Expenses", value: "€640", color: .orange)
              Divider().frame(height: 40)
              SSStatBox(label: "Net", value: "€4,210", color: .blue)
            }
          }

          // Occupancy card
          SSCard {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Occupancy")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(.secondary)
                Text("78%")
                  .font(.system(size: 26, weight: .bold))
              }
              Spacer()
              ZStack {
                Circle()
                  .stroke(Color(hex: "#1FB86E").opacity(0.2), lineWidth: 8)
                  .frame(width: 56, height: 56)
                Circle()
                  .trim(from: 0, to: 0.78)
                  .stroke(Color(hex: "#1FB86E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                  .rotationEffect(.degrees(-90))
                  .frame(width: 56, height: 56)
                Text("78%")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(Color(hex: "#1FB86E"))
              }
            }
            .padding(.vertical, 2)
          }

          // YTD card
          SSCard {
            VStack(alignment: .leading, spacing: 6) {
              Text("Year to Date · 2026")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
              Text("€18,420")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#1FB86E"))
              Text("gross revenue · 3 bookings")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
          }

          Spacer(minLength: 40)
        }
      }
    }
  }
}

// MARK: - Mock Screen 2: Calendar

private struct SSCalendarScreen: View {
  private let days = Array(1...31)
  private let bookedRanges: Set<Int> = [12,13,14,15,16,17,18,19, 22,23,24,25,26,27]
  private let firstWeekday = 0 // March 2026 starts Sunday

  var body: some View {
    ZStack {
      Color(hex: "#F2F2F7").ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          // Nav
          HStack {
            Text("Calendar")
              .font(.system(size: 20, weight: .bold))
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.top, 52)
          .padding(.bottom, 4)

          // Month header
          SSCard {
            HStack {
              Image(systemName: "chevron.left").foregroundStyle(Color(hex: "#1FB86E"))
              Spacer()
              Text("March 2026").font(.system(size: 15, weight: .semibold))
              Spacer()
              Image(systemName: "chevron.right").foregroundStyle(Color(hex: "#1FB86E"))
            }
            .padding(.bottom, 10)

            // Day labels
            HStack(spacing: 0) {
              ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                Text(d)
                  .font(.system(size: 10, weight: .medium))
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity)
              }
            }
            .padding(.bottom, 6)

            // Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
              ForEach(0..<firstWeekday, id: \.self) { _ in Color.clear.frame(height: 28) }
              ForEach(days, id: \.self) { day in
                ZStack {
                  if bookedRanges.contains(day) {
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color(hex: "#1FB86E").opacity(0.18))
                  }
                  Text("\(day)")
                    .font(.system(size: 12, weight: bookedRanges.contains(day) ? .semibold : .regular))
                    .foregroundStyle(bookedRanges.contains(day) ? Color(hex: "#1FB86E") : .primary)
                }
                .frame(height: 28)
              }
            }
          }

          // Booking rows
          SSCard {
            Text("Bookings")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)
              .padding(.bottom, 6)

            SSBookingRow(name: "John S.", dates: "Mar 12 – 19", amount: "€595", status: "Upcoming", color: .blue)
            Divider().padding(.vertical, 6)
            SSBookingRow(name: "Emma K.", dates: "Mar 22 – 27", amount: "€425", status: "Upcoming", color: .blue)
          }

          Spacer(minLength: 40)
        }
      }
    }
  }
}

// MARK: - Mock Screen 3: Expenses

private struct SSExpensesScreen: View {
  var body: some View {
    ZStack {
      Color(hex: "#F2F2F7").ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          HStack {
            Text("Expenses")
              .font(.system(size: 20, weight: .bold))
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.top, 52)
          .padding(.bottom, 4)

          // Filter pills
          HStack(spacing: 8) {
            SSPill(label: "All Props", active: true)
            SSPill(label: "Month", active: false)
            Spacer()
          }
          .padding(.horizontal, 12)

          // Expense list
          SSCard {
            VStack(spacing: 0) {
              SSExpenseRow(icon: "🧹", cat: "Cleaning",   date: "Mar 5",  amount: "€150", prop: "Casa Azul")
              Divider().padding(.vertical, 8)
              SSExpenseRow(icon: "🔧", cat: "Repairs",    date: "Mar 3",  amount: "€320", prop: "Casa Azul")
              Divider().padding(.vertical, 8)
              SSExpenseRow(icon: "💡", cat: "Utilities",  date: "Mar 1",  amount: "€95",  prop: "Mountain Lodge")
              Divider().padding(.vertical, 8)
              SSExpenseRow(icon: "🏠", cat: "Management", date: "Feb 28", amount: "€200", prop: "City Flat")
            }
          }

          // Total card
          SSCard {
            HStack {
              Text("Total · March 2026")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
              Spacer()
              Text("€765")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.orange)
            }
          }

          Spacer(minLength: 40)
        }
      }
    }
  }
}

// MARK: - Mock Screen 4: Totals

private struct SSTotalsScreen: View {
  var body: some View {
    ZStack {
      Color(hex: "#F2F2F7").ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          HStack {
            Text("Totals")
              .font(.system(size: 20, weight: .bold))
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.top, 52)
          .padding(.bottom, 4)

          // Scope pills
          HStack(spacing: 8) {
            SSPill(label: "Monthly", active: false)
            SSPill(label: "Yearly",  active: true)
            SSPill(label: "All Time", active: false)
            Spacer()
          }
          .padding(.horizontal, 12)

          SSPropertyTotalsCard(
            emoji: "🏖️", name: "Casa Azul",
            gross: "€22,400", net: "€18,640",
            nights: "156 nights", occ: "71%", occVal: 0.71
          )

          SSPropertyTotalsCard(
            emoji: "🏔️", name: "Mountain Lodge",
            gross: "€15,800", net: "€13,200",
            nights: "118 nights", occ: "64%", occVal: 0.64
          )

          SSPropertyTotalsCard(
            emoji: "🏙️", name: "City Flat",
            gross: "€9,200", net: "€7,850",
            nights: "84 nights", occ: "58%", occVal: 0.58
          )

          Spacer(minLength: 40)
        }
      }
    }
  }
}

// MARK: - Mock Screen 5: Properties

private struct SSPropertiesScreen: View {
  var body: some View {
    ZStack {
      Color(hex: "#F2F2F7").ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          HStack {
            Text("Properties")
              .font(.system(size: 20, weight: .bold))
            Spacer()
            Image(systemName: "plus")
              .foregroundStyle(Color(hex: "#1FB86E"))
              .font(.system(size: 16, weight: .semibold))
          }
          .padding(.horizontal, 16)
          .padding(.top, 52)
          .padding(.bottom, 4)

          SSCard {
            VStack(spacing: 0) {
              SSPropertyRow(emoji: "🏖️", name: "Casa Azul",       location: "Lisbon, Portugal",   color: Color(hex: "#1FB86E"))
              Divider().padding(.vertical, 10)
              SSPropertyRow(emoji: "🏔️", name: "Mountain Lodge",  location: "Porto, Portugal",    color: .indigo)
              Divider().padding(.vertical, 10)
              SSPropertyRow(emoji: "🏙️", name: "City Flat",       location: "Madrid, Spain",      color: .orange)
            }
          }

          // iCloud banner
          SSCard {
            HStack(spacing: 12) {
              Image(systemName: "icloud.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "#1FB86E"))
              VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Sync Active")
                  .font(.system(size: 14, weight: .semibold))
                Text("All data backed up & synced across devices")
                  .font(.system(size: 12))
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
          }

          // FX Rates card
          SSCard {
            HStack(spacing: 12) {
              Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
              VStack(alignment: .leading, spacing: 2) {
                Text("Multi-Currency Support")
                  .font(.system(size: 14, weight: .semibold))
                Text("EUR · GBP · USD · and more")
                  .font(.system(size: 12))
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
          }

          Spacer(minLength: 40)
        }
      }
    }
  }
}

// MARK: - Shared Sub-Components

private struct SSCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0) { content }
      .padding(14)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .padding(.horizontal, 12)
  }
}

private struct SSStatBox: View {
  let label: String
  let value: String
  let color: Color
  var body: some View {
    VStack(spacing: 3) {
      Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
      Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct SSPill: View {
  let label: String
  let active: Bool
  var body: some View {
    Text(label)
      .font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(active ? Color(hex: "#1FB86E") : Color.secondary.opacity(0.15),
                  in: Capsule())
      .foregroundStyle(active ? .white : .primary)
  }
}

private struct SSBookingRow: View {
  let name: String; let dates: String; let amount: String
  let status: String; let color: Color
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.system(size: 13, weight: .semibold))
        Text(dates).font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(amount).font(.system(size: 13, weight: .bold))
        Text(status)
          .font(.system(size: 10, weight: .medium))
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(color.opacity(0.15), in: Capsule())
          .foregroundStyle(color)
      }
    }
  }
}

private struct SSExpenseRow: View {
  let icon: String; let cat: String; let date: String
  let amount: String; let prop: String
  var body: some View {
    HStack(spacing: 10) {
      Text(icon).font(.system(size: 22))
      VStack(alignment: .leading, spacing: 2) {
        Text(cat).font(.system(size: 13, weight: .semibold))
        Text("\(date) · \(prop)").font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Spacer()
      Text(amount).font(.system(size: 13, weight: .bold)).foregroundStyle(.orange)
    }
  }
}

private struct SSPropertyTotalsCard: View {
  let emoji: String; let name: String
  let gross: String; let net: String
  let nights: String; let occ: String; let occVal: Double
  var body: some View {
    SSCard {
      HStack {
        Text(emoji).font(.system(size: 24))
        Text(name).font(.system(size: 15, weight: .bold))
        Spacer()
        ZStack {
          Circle()
            .stroke(Color(hex: "#1FB86E").opacity(0.2), lineWidth: 5)
            .frame(width: 40, height: 40)
          Circle()
            .trim(from: 0, to: occVal)
            .stroke(Color(hex: "#1FB86E"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 40, height: 40)
          Text(occ).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: "#1FB86E"))
        }
      }
      .padding(.bottom, 8)

      HStack(spacing: 0) {
        SSStatBox(label: "Gross",  value: gross, color: Color(hex: "#1FB86E"))
        Divider().frame(height: 36)
        SSStatBox(label: "Net",    value: net,   color: .blue)
        Divider().frame(height: 36)
        SSStatBox(label: "Nights", value: nights.components(separatedBy: " ").first ?? nights, color: .secondary)
      }
    }
  }
}

private struct SSPropertyRow: View {
  let emoji: String; let name: String; let location: String; let color: Color
  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(color.opacity(0.15))
          .frame(width: 40, height: 40)
        Text(emoji).font(.system(size: 20))
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.system(size: 14, weight: .semibold))
        Text(location).font(.system(size: 12)).foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Preview

#Preview("App Store Screenshots") {
  V4ScreenshotView()
}
