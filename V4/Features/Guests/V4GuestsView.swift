import SwiftUI
import SwiftData

// MARK: - Guest Sort Order

enum GuestSort: String, CaseIterable, Identifiable {
  case nameAZ     = "Name A–Z"
  case nameZA     = "Name Z–A"
  case mostStays  = "Most Stays"
  case byProperty = "By Property"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .nameAZ:     return "arrow.down.circle"
    case .nameZA:     return "arrow.up.circle"
    case .mostStays:  return "star.fill"
    case .byProperty: return "building.2"
    }
  }
}

// MARK: - Guests List

struct V4GuestsView: View {
  let prefs: V4AppPreferences

  @Environment(\.modelContext) private var context
  @Query(sort: \STGuest.name) private var guests: [STGuest]

  @State private var showAdd = false
  @State private var guestToEdit: STGuest?
  @State private var searchText = ""
  @State private var sortOrder: GuestSort = .nameAZ

  // MARK: Computed

  private var filteredGuests: [STGuest] {
    guard !searchText.isEmpty else { return guests }
    return guests.filter {
      $0.name.localizedCaseInsensitiveContains(searchText) ||
      ($0.email ?? "").localizedCaseInsensitiveContains(searchText)
    }
  }

  private var sortedGuests: [STGuest] {
    switch sortOrder {
    case .nameAZ:
      return filteredGuests.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
    case .nameZA:
      return filteredGuests.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
      }
    case .mostStays:
      return filteredGuests.sorted {
        if $0.bookings.count != $1.bookings.count {
          return $0.bookings.count > $1.bookings.count
        }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
    case .byProperty:
      // Flat list sorted by name; sectioned rendering handled separately
      return filteredGuests.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
    }
  }

  /// For "By Property" mode: [(propertyName, [guest])]
  private var guestsByProperty: [(propertyName: String, guests: [STGuest])] {
    var map: [String: [STGuest]] = [:]
    var unassigned: [STGuest] = []

    for g in filteredGuests {
      let propNames = Set(g.bookings.map { $0.property.name })
      if propNames.isEmpty {
        unassigned.append(g)
      } else {
        for name in propNames {
          map[name, default: []].append(g)
        }
      }
    }

    var result = map
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { (
        propertyName: $0.key,
        guests: $0.value.sorted {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
      )}

    if !unassigned.isEmpty {
      result.append((
        propertyName: "No Property",
        guests: unassigned.sorted {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
      ))
    }
    return result
  }

  // MARK: Body

  var body: some View {
    NavigationStack {
      List {
        if filteredGuests.isEmpty {
          Section {
            Text(guests.isEmpty
                 ? "No guests yet. Tap + to add one."
                 : "No results for \"\(searchText)\".")
              .foregroundStyle(.secondary)
          }
        } else if sortOrder == .byProperty {
          byPropertySections
        } else {
          flatSection
        }
      }
      .searchable(text: $searchText, prompt: "Search guests")
      .navigationTitle("Guests")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          sortMenu
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { showAdd = true } label: { Image(systemName: "plus") }
            .accessibilityLabel("Add guest")
        }
      }
      .sheet(isPresented: $showAdd) {
        V4GuestEditorSheet(mode: .add)
      }
      .sheet(item: $guestToEdit) { g in
        V4GuestEditorSheet(mode: .edit(g))
      }
    }
  }

  // MARK: Sections

  @ViewBuilder
  private var flatSection: some View {
    Section {
      ForEach(sortedGuests) { g in
        Button { guestToEdit = g } label: { guestRow(g) }
          .buttonStyle(.plain)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleteGuest(g) } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }
    } footer: {
      Text("\(guests.count) guests total")
    }
  }

  @ViewBuilder
  private var byPropertySections: some View {
    ForEach(guestsByProperty, id: \.propertyName) { group in
      Section(group.propertyName) {
        ForEach(group.guests) { g in
          Button { guestToEdit = g } label: { guestRow(g) }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) { deleteGuest(g) } label: {
                Label("Delete", systemImage: "trash")
              }
            }
        }
      }
    }
  }

  // MARK: Sort Menu

  private var sortMenu: some View {
    Menu {
      ForEach(GuestSort.allCases) { sort in
        Button {
          withAnimation { sortOrder = sort }
        } label: {
          Label(
            sort.rawValue,
            systemImage: sortOrder == sort ? "checkmark" : sort.icon
          )
        }
      }
    } label: {
      Label("Sort", systemImage: "arrow.up.arrow.down")
        .labelStyle(.iconOnly)
    }
  }

  // MARK: Guest Row

  private func guestRow(_ g: STGuest) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(V4Theme.Brand.primary.opacity(0.15))
          .frame(width: 42, height: 42)
        Text(String(g.name.prefix(1)).uppercased())
          .font(.headline)
          .foregroundStyle(V4Theme.Brand.primary)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(g.name)
          .font(.subheadline.weight(.semibold))
        if let email = g.email, !email.isEmpty {
          Text(email)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let phone = g.phone, !phone.isEmpty {
          Text(phone)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      // Stay count badge
      let count = g.bookings.count
      if count > 0 {
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(count)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(V4Theme.Brand.primary)
          Text(count == 1 ? "stay" : "stays")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: Delete

  private func deleteGuest(_ g: STGuest) {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    context.delete(g)
    do { try context.save() }
    catch { print("Delete guest failed: \(error)") }
  }
}

// MARK: - Guest Editor Sheet

struct V4GuestEditorSheet: View {
  enum Mode {
    case add
    case edit(STGuest)

    var title: LocalizedStringKey {
      switch self { case .add: "Add Guest"; case .edit: "Edit Guest" }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context

  let mode: Mode
  /// Called with the new guest's UUID after a successful add. Nil when not needed.
  var onCreated: ((UUID) -> Void)? = nil

  @State private var name: String = ""
  @State private var email: String = ""
  @State private var phone: String = ""

  @State private var showAlert = false
  @State private var alertMsg = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Name") {
          TextField("Full name", text: $name)
        }

        Section("Contact (optional)") {
          TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          TextField("Phone", text: $phone)
            .keyboardType(.phonePad)
        }

        if case .edit(let g) = mode {
          Section {
            Button(role: .destructive) {
              context.delete(g)
              do { try context.save() }
              catch { print("Delete guest save failed: \(error)") }
              dismiss()
            } label: {
              Text("Delete Guest")
            }
          }
        }
      }
      .navigationTitle(mode.title)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .font(.headline)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear { hydrate() }
      .alert("Cannot Save", isPresented: $showAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(alertMsg)
      }
    }
  }

  private func hydrate() {
    if case .edit(let g) = mode {
      name  = g.name
      email = g.email ?? ""
      phone = g.phone ?? ""
    }
  }

  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else {
      alertMsg = "Please enter a name."
      showAlert = true
      return
    }

    let trimEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

    // Basic email format check (non-empty fields only)
    if !trimEmail.isEmpty {
      let emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/
      guard trimEmail.wholeMatch(of: emailRegex) != nil else {
        alertMsg = "\"\(trimEmail)\" doesn't look like a valid email address."
        showAlert = true
        return
      }
    }

    let cleanEmail: String? = trimEmail.isEmpty ? nil : trimEmail
    let cleanPhone: String? = trimPhone.isEmpty ? nil : trimPhone

    switch mode {
    case .add:
      let newID = UUID()
      let g = STGuest(id: newID, name: cleanName, email: cleanEmail, phone: cleanPhone)
      context.insert(g)
      do {
        try context.save()
        onCreated?(newID)
        dismiss()
      } catch {
        alertMsg = "Save failed: \(error.localizedDescription)"
        showAlert = true
      }
      return

    case .edit(let g):
      g.name  = cleanName
      g.email = cleanEmail
      g.phone = cleanPhone
    }

    do {
      try context.save()
      dismiss()
    } catch {
      alertMsg = "Save failed: \(error.localizedDescription)"
      showAlert = true
    }
  }
}
