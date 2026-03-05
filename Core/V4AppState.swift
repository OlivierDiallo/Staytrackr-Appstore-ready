//
//  V4AppState.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 06.01.2026.
//
import Foundation
import Observation

/// Transient (in-memory only) cross-screen state.
/// Persisted preferences live in V4AppPreferences (SwiftData).
@Observable
final class V4AppState {
  /// The property the user most recently tapped into — used for
  /// coordinating navigation (e.g. Calendar → Property Detail deep-links).
  var lastVisitedPropertyID: UUID? = nil

  /// Set to true while a background migration / seed operation is in flight,
  /// so views can show a progress indicator if needed.
  var isMigrating: Bool = false
}
