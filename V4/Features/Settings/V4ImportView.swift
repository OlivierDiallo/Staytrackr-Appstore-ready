import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import EventKit

// Entry point for all booking imports: iCal feed sync (per-property), Airbnb CSV upload,
// and Apple Calendar (EventKit) import.
// iCal URLs are configured on each property (V4PropertyEditorSheet → "iCal Sync" section).

struct V4ImportView: View {

    @Environment(\.modelContext) private var context
    @Environment(STStoreManager.self) private var store
    @Query(sort: \STProperty.name) private var properties: [STProperty]

    // iCal / CSV state
    @State private var syncState: SyncState = .idle
    @State private var showCSVPicker = false
    @State private var result: ImportResult? = nil
    @State private var errorMessage: String? = nil

    // EventKit / Apple Calendar state
    @State private var calAuthStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var eventStore: EKEventStore? = nil
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalIDs: Set<String> = []
    @State private var calSyncState: SyncState = .idle
    @State private var showCalendarHelp = false

    var body: some View {
        List {

            // ── iCal Sync ──────────────────────────────────────────────────
            Section {
                let configured = properties.filter { $0.airbnbICalURL != nil || $0.bookingComICalURL != nil }
                if configured.isEmpty {
                    ContentUnavailableView(
                        "No iCal feeds configured",
                        systemImage: "calendar.badge.plus",
                        description: Text("Open a property in Settings → Properties and add your Airbnb or Booking.com calendar URL.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(configured) { property in
                        propertyFeedRow(property)
                    }
                    Button {
                        Task { await syncAll(properties: configured) }
                    } label: {
                        Label("Sync All Feeds", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(syncState == .running)
                }
            } header: {
                Text("iCal Sync")
            } footer: {
                Text("StayTrackr fetches each calendar URL and imports new bookings. Existing bookings are never duplicated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ── CSV Import ─────────────────────────────────────────────────
            Section {
                Button {
                    showCSVPicker = true
                } label: {
                    Label("Import Airbnb CSV", systemImage: "doc.text.badge.plus")
                }
                .disabled(syncState == .running)
            } header: {
                Text("CSV Import")
            } footer: {
                Text("Export from Airbnb → Insights → Earnings → Download CSV, then import here. Bookings are matched to properties by listing name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ── Apple Calendar Import (Premium) ───────────────────────────
            Section {
                if store.isPremium {
                    appleCalendarContent
                } else {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(V4Theme.Brand.primary.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(V4Theme.Brand.primary)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Premium Feature")
                                .font(.subheadline.weight(.semibold))
                            Text("Upgrade to import bookings directly from Apple Calendar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        NavigationLink {
                            V4PaywallView()
                                .environment(store)
                        } label: {
                            Text("Upgrade")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(V4Theme.Brand.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Apple Calendar Import")
                    Spacer()
                    if !store.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(V4Theme.Brand.primary)
                    }
                }
            } footer: {
                if store.isPremium {
                    Text("StayTrackr reads booking-type events from your selected calendars (Airbnb, Booking.com subscriptions, etc.) and skips flights and other non-booking events. Only multi-night events are imported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Result banner ──────────────────────────────────────────────
            if let r = result {
                Section {
                    resultRow(r)
                } header: {
                    Text("Last Import")
                }
            }
        }
        .navigationTitle("Import Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if syncState == .running {
                ProgressView("Syncing…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Import Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .fileImporter(
            isPresented: $showCSVPicker,
            allowedContentTypes: [.commaSeparatedText, UTType(filenameExtension: "csv") ?? .data]
        ) { result in
            handleCSV(result: result)
        }
    }

    // MARK: - Property feed row

    @ViewBuilder
    private func propertyFeedRow(_ property: STProperty) -> some View {
        HStack(spacing: 12) {
            Text(property.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .font(.subheadline.weight(.medium))
                feedTags(property)
            }
            Spacer()
            Button {
                Task { await syncOne(property: property) }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(V4Theme.Brand.primary)
            }
            .buttonStyle(.plain)
            .disabled(syncState == .running)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func feedTags(_ property: STProperty) -> some View {
        HStack(spacing: 6) {
            if property.airbnbICalURL != nil {
                tag("Airbnb", color: .pink)
            }
            if property.bookingComICalURL != nil {
                tag("Booking.com", color: .blue)
            }
        }
    }

    private func tag(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Result row

    @ViewBuilder
    private func resultRow(_ r: ImportResult) -> some View {
        HStack(spacing: 16) {
            statBadge(String(r.inserted), label: "Added",   color: .green)
            statBadge(String(r.updated),  label: "Updated", color: .orange)
            statBadge(String(r.skipped),  label: "Skipped", color: .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func statBadge(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - iCal sync

    private func syncOne(property: STProperty) async {
        await syncAll(properties: [property])
    }

    private func syncAll(properties: [STProperty]) async {
        syncState = .running
        var totalInserted = 0
        var totalUpdated  = 0
        var totalSkipped  = 0

        for property in properties {
            do {
                let existing = property.bookings

                // Airbnb feed
                if let urlString = property.airbnbICalURL,
                   let url = Self.sanitisedICalURL(urlString) {
                    let imported = try await ICalParser.shared.fetch(url: url, platform: .airbnb)
                    let dedup = ImportDeduplicator().deduplicate(imported, against: existing)
                    let (ins, upd) = ImportDeduplicator.commit(result: dedup, property: property, context: context)
                    totalInserted += ins; totalUpdated += upd; totalSkipped += dedup.skippedCount
                } else if property.airbnbICalURL != nil {
                    errorMessage = "\(property.name): Airbnb iCal URL must use https:// or webcal://"
                }

                // Booking.com feed
                if let urlString = property.bookingComICalURL,
                   let url = Self.sanitisedICalURL(urlString) {
                    let imported = try await ICalParser.shared.fetch(url: url, platform: .bookingCom)
                    let dedup = ImportDeduplicator().deduplicate(imported, against: property.bookings)
                    let (ins, upd) = ImportDeduplicator.commit(result: dedup, property: property, context: context)
                    totalInserted += ins; totalUpdated += upd; totalSkipped += dedup.skippedCount
                } else if property.bookingComICalURL != nil {
                    errorMessage = "\(property.name): Booking.com iCal URL must use https:// or webcal://"
                }

                try context.save()
            } catch {
                errorMessage = "\(property.name): \(error.localizedDescription)"
            }
        }

        result = ImportResult(inserted: totalInserted, updated: totalUpdated, skipped: totalSkipped)
        syncState = .idle
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - iCal URL validation

    /// Accepts https:// and webcal:// URLs (Airbnb/Booking.com both use webcal).
    /// webcal is rewritten to https so URLSession can fetch it.
    /// Any other scheme (file://, http://, javascript:, etc.) returns nil.
    private static func sanitisedICalURL(_ raw: String) -> URL? {
        guard var url = URL(string: raw) else { return nil }
        if url.scheme == "webcal" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            url = components?.url ?? url
        }
        guard url.scheme == "https" else { return nil }
        return url
    }

    // MARK: - CSV import

    private func handleCSV(result fileResult: Result<URL, Error>) {
        switch fileResult {
        case .failure(let err):
            errorMessage = err.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permission denied for that file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let parseResult = AirbnbCSVParser().parse(csvText: text)
                commitCSV(parseResult)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func commitCSV(_ parseResult: AirbnbCSVParser.ParseResult) {
        var totalInserted = 0
        var totalUpdated  = 0
        var totalSkipped  = parseResult.skippedRows

        // Group imported bookings by listing name, match to properties
        let byListing = Dictionary(grouping: parseResult.bookings, by: { $0.propertyID ?? "" })

        for (listingName, bookings) in byListing {
            // Fuzzy-match listing name to a property
            let property = properties.first {
                listingName.isEmpty ? false : $0.name.lowercased().contains(listingName.lowercased()) ||
                listingName.lowercased().contains($0.name.lowercased())
            } ?? properties.first   // fallback: use first property if only one

            guard let property else { totalSkipped += bookings.count; continue }

            let dedup = ImportDeduplicator().deduplicate(bookings, against: property.bookings)
            let (ins, upd) = ImportDeduplicator.commit(result: dedup, property: property, context: context)
            totalInserted += ins; totalUpdated += upd; totalSkipped += dedup.skippedCount
        }

        try? context.save()
        result = ImportResult(inserted: totalInserted, updated: totalUpdated, skipped: totalSkipped)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Apple Calendar UI

    @ViewBuilder
    private var appleCalendarContent: some View {
        switch calAuthStatus {
        case .notDetermined:
            Button {
                Task { await requestCalendarAccess() }
            } label: {
                Label("Connect Apple Calendar", systemImage: "calendar.badge.plus")
            }

        case .restricted, .denied, .writeOnly:
            // .writeOnly means we can create events but not read them — not useful for import
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar access denied")
                        .font(.subheadline.weight(.medium))
                    Text("Enable in Settings → Privacy & Security → Calendars → StayTrackr.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

        case .fullAccess:
            if availableCalendars.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading calendars…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .task { loadCalendars() }
            } else {
                let booking = availableCalendars.filter { looksLikeBookingCalendar($0) }
                let other   = availableCalendars.filter { !looksLikeBookingCalendar($0) }

                if !booking.isEmpty {
                    ForEach(booking, id: \.calendarIdentifier) { cal in
                        calendarToggleRow(cal, recommended: true)
                    }
                }
                if !other.isEmpty {
                    ForEach(other, id: \.calendarIdentifier) { cal in
                        calendarToggleRow(cal, recommended: false)
                    }
                }

                if !selectedCalIDs.isEmpty {
                    Button {
                        Task { await importFromSelectedCalendars() }
                    } label: {
                        Label("Import Selected (\(selectedCalIDs.count))", systemImage: "arrow.down.calendar")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(calSyncState == .running)
                }
            }

        @unknown default:
            EmptyView()
        }
    }

    private func calendarToggleRow(_ cal: EKCalendar, recommended: Bool) -> some View {
        Toggle(isOn: Binding(
            get: { selectedCalIDs.contains(cal.calendarIdentifier) },
            set: { on in
                if on { selectedCalIDs.insert(cal.calendarIdentifier) }
                else  { selectedCalIDs.remove(cal.calendarIdentifier) }
            }
        )) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(cgColor: cal.cgColor))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(cal.title)
                        .font(.subheadline)
                    if recommended {
                        Text("Recommended")
                            .font(.caption2)
                            .foregroundStyle(V4Theme.Brand.primary)
                    }
                }
            }
        }
        .tint(V4Theme.Brand.primary)
    }

    // MARK: - Apple Calendar Logic

    private func requestCalendarAccess() async {
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run {
                calAuthStatus = granted ? .fullAccess : .denied
                if granted {
                    eventStore = store
                    loadCalendars()
                }
            }
        } catch {
            await MainActor.run { calAuthStatus = .denied }
        }
    }

    private func loadCalendars() {
        guard let store = eventStore ?? (calAuthStatus == .fullAccess ? EKEventStore() : nil) else { return }
        if eventStore == nil { eventStore = store }
        // Show all event calendars; user can choose which to import from
        let cals = store.calendars(for: .event)
            .filter { $0.allowsContentModifications || $0.type == .subscription || $0.type == .calDAV }
            .sorted { looksLikeBookingCalendar($0) && !looksLikeBookingCalendar($1) }
        availableCalendars = cals
        // Auto-select booking-platform calendars
        for cal in cals where looksLikeBookingCalendar(cal) {
            selectedCalIDs.insert(cal.calendarIdentifier)
        }
    }

    /// Calendars that look like Airbnb/Booking.com subscriptions are flagged as recommended.
    private func looksLikeBookingCalendar(_ cal: EKCalendar) -> Bool {
        let t = cal.title.lowercased()
        let bookingKeywords = ["airbnb", "booking", "vrbo", "homeaway", "rental", "reservation", "stay", "holiday"]
        if bookingKeywords.contains(where: { t.contains($0) }) { return true }
        // Subscribed calendars from Airbnb/Booking.com have type .subscription
        if cal.type == .subscription { return true }
        return false
    }

    private func importFromSelectedCalendars() async {
        guard let store = eventStore, !properties.isEmpty else { return }
        calSyncState = .running

        // Fetch events for the next 2 years and past 1 year
        let past   = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        let future = Calendar.current.date(byAdding: .year, value:  2, to: .now) ?? .now

        let selectedCals = availableCalendars.filter { selectedCalIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: past, end: future, calendars: selectedCals)
        let events = store.events(matching: predicate)

        let bookingEvents = events.filter { isBookingEvent($0) }

        var totalInserted = 0
        var totalUpdated  = 0
        var totalSkipped  = 0

        // Match each event to a property; if only one property exists use it as fallback
        for event in bookingEvents {
            guard let imported = eventToImportedBooking(event) else { totalSkipped += 1; continue }

            // Try to match property by name in event title or calendar title
            let property = matchProperty(for: event) ?? (properties.count == 1 ? properties[0] : nil)
            guard let property else { totalSkipped += 1; continue }

            let dedup = ImportDeduplicator().deduplicate([imported], against: property.bookings)
            let (ins, upd) = ImportDeduplicator.commit(result: dedup, property: property, context: context)
            totalInserted += ins; totalUpdated += upd; totalSkipped += dedup.skippedCount
        }

        try? context.save()
        await MainActor.run {
            result = ImportResult(inserted: totalInserted, updated: totalUpdated, skipped: totalSkipped)
            calSyncState = .idle
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Returns true only for multi-night stays that don't look like flights or day events.
    private func isBookingEvent(_ event: EKEvent) -> Bool {
        let title    = (event.title ?? "").lowercased()
        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Must span at least one night (~20 h to tolerate time-zone offsets on all-day events)
        guard duration >= 20 * 3600 else { return false }

        // Reject blocked/unavailable/out-of-office placeholders
        let blockedPhrases = ["available", "unavailable", "blocked", "not available",
                              "out of office", "holiday", "vacation"]
        // Only reject exact common noise titles — don't reject "vacation rental" etc.
        if blockedPhrases.contains(where: { title == $0 }) { return false }

        // Reject flight-type events
        let flightKeywords = ["flight", "airlines", "airways", "boeing", "airbus",
                              "departs", "arrives at airport", "boarding pass", "gate ", "terminal ",
                              "layover", "connecting flight"]
        if flightKeywords.contains(where: { title.contains($0) }) { return false }

        return true
    }

    private func eventToImportedBooking(_ event: EKEvent) -> ImportedBooking? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        let cal = Calendar.current
        let checkIn  = event.isAllDay ? cal.startOfDay(for: start) : start
        let checkOut = event.isAllDay ? cal.startOfDay(for: end)   : end
        guard checkOut > checkIn else { return nil }

        // Parse guest name from common platform title formats
        // Airbnb: "John Doe" or "Reservation - John Doe (4 nights)"
        // Booking.com: "John Doe - Reservation"
        let rawTitle = event.title ?? "Guest"
        let guestName = cleanEventTitle(rawTitle)

        // Detect platform from calendar title
        let calTitle = (event.calendar?.title ?? "").lowercased()
        let platform: ImportedBooking.Platform = {
            if calTitle.contains("airbnb") { return .airbnb }
            if calTitle.contains("booking") { return .bookingCom }
            return .manual
        }()

        return ImportedBooking(
            platformID: event.eventIdentifier,
            platform: platform,
            guestName: guestName.isEmpty ? nil : guestName,
            checkIn: checkIn,
            checkOut: checkOut,
            status: .confirmed,
            rawSource: "Apple Calendar: \(event.calendar?.title ?? "")"
        )
    }

    private func cleanEventTitle(_ title: String) -> String {
        var name = title
        // Strip common platform suffixes/prefixes
        let patterns = [" - Airbnb", " (Airbnb)", " - Booking.com", " - Confirmed",
                        " - Reserved", "Reservation - ", "Booking - ", " reservation",
                        " booking", " - Guest stay"]
        for p in patterns {
            name = name.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        // Strip trailing parenthetical like " (4 nights)"
        if let range = name.range(of: #"\s*\(\d+ nights?\)"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    private func matchProperty(for event: EKEvent) -> STProperty? {
        let text = ((event.title ?? "") + " " + (event.calendar?.title ?? "") + " " + (event.location ?? "")).lowercased()
        return properties.first { p in
            text.contains(p.name.lowercased())
        }
    }

    // MARK: - State

    enum SyncState: Equatable { case idle, running }

    struct ImportResult {
        let inserted: Int
        let updated: Int
        let skipped: Int
    }
}
