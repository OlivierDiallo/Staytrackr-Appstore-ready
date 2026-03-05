//
//  V4AppState.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 06.01.2026.
//

import Foundation
import SwiftData

// MARK: - Persisted UI State (Filters)

@Model
final class V4AppPreferences {
  @Attribute(.unique) var id: UUID

  // Which property is selected in UI (nil = all properties)
  var selectedPropertyID: UUID?

  // Calendar scope / tab state (store as String to keep model stable)
  var calendarScopeRaw: String

  // Totals scope (Weekly/Monthly/Yearly)
  var totalsScopeRaw: String

  init(
    id: UUID = UUID(),
    selectedPropertyID: UUID? = nil,
    calendarScopeRaw: String = "Month",
    totalsScopeRaw: String = "Monthly"
  ) {
    self.id = id
    self.selectedPropertyID = selectedPropertyID
    self.calendarScopeRaw = calendarScopeRaw
    self.totalsScopeRaw = totalsScopeRaw
  }
}

/// One place to fetch/create the single preferences row.
enum V4PreferencesStore {
  static func loadOrCreate(in context: ModelContext) -> V4AppPreferences {
    let descriptor = FetchDescriptor<V4AppPreferences>()
    if let existing = try? context.fetch(descriptor).first {
      return existing
    }
    let prefs = V4AppPreferences()
    context.insert(prefs)
    return prefs
  }
}
