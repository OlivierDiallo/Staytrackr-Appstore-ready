import Foundation
import UserNotifications
import Observation

// MARK: - Notification Manager

@Observable
@MainActor
final class V4NotificationManager {

  private let center = UNUserNotificationCenter.current()
  private let arrivalPrefix   = "st_arrival_"
  private let departurePrefix = "st_departure_"

  /// Whether the user has granted notification permission.
  var isAuthorized: Bool = false

  // MARK: - Authorization

  func requestAuthorization() async {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      isAuthorized = granted
    } catch {
      print("[Notifications] Authorization error: \(error.localizedDescription)")
    }
  }

  // MARK: - Schedule All

  // Snapshot value type — decouples the async Task from SwiftData model objects.
  private struct BookingSnapshot {
    let id: UUID
    let checkIn: Date
    let checkOut: Date
    let guestName: String
    let propertyEmoji: String
    let propertyName: String
  }

  /// Reschedules all arrival and departure notifications from scratch.
  /// Call this whenever bookings or notification settings change.
  func scheduleAll(bookings: [STBooking], settings: V4AppSettings) {
    guard settings.notificationsEnabled else {
      cancelAll()
      return
    }

    // Snapshot the data we need synchronously (on main actor) before the async Task.
    let now = Date()
    let snapshots = bookings
      .filter { $0.checkIn > now }          // only future arrivals
      .map { b in
        BookingSnapshot(
          id: b.id,
          checkIn: b.checkIn,
          checkOut: b.checkOut,
          guestName: b.guest.name,
          propertyEmoji: b.property.emoji,
          propertyName: b.property.name
        )
      }

    let arrivalHours   = settings.arrivalNoticeHours
    let departureHours = settings.departureNoticeHours

    Task {
      // Remove all existing StayTrackr notifications.
      let pending = await center.pendingNotificationRequests()
      let oldIDs = pending.map { $0.identifier }
        .filter { $0.hasPrefix(arrivalPrefix) || $0.hasPrefix(departurePrefix) }
      center.removePendingNotificationRequests(withIdentifiers: oldIDs)

      var requests: [UNNotificationRequest] = []

      for snap in snapshots {
        if let req = makeArrivalRequest(snap: snap, noticeHours: arrivalHours) {
          requests.append(req)
        }
        if let req = makeDepartureRequest(snap: snap, noticeHours: departureHours) {
          requests.append(req)
        }
      }

      // iOS limits us to 64 pending notifications. Sort by nearest fire date and take first 60.
      let sorted = requests.sorted {
        let t1 = ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        let t2 = ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        return t1 < t2
      }

      for req in sorted.prefix(60) {
        do {
          try await center.add(req)
        } catch {
          print("[Notifications] Failed to schedule \(req.identifier): \(error.localizedDescription)")
        }
      }
    }
  }

  // MARK: - Cancel All

  func cancelAll() {
    Task {
      let pending = await center.pendingNotificationRequests()
      let ids = pending.map { $0.identifier }
        .filter { $0.hasPrefix(arrivalPrefix) || $0.hasPrefix(departurePrefix) }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  // MARK: - Request Builders

  private func makeArrivalRequest(snap: BookingSnapshot, noticeHours: Int) -> UNNotificationRequest? {
    let fireDate = noticeFireDate(eventDay: snap.checkIn, noticeHours: noticeHours)
    guard fireDate > Date() else { return nil }

    let content = UNMutableNotificationContent()
    content.title = arrivalTitle(noticeHours: noticeHours)
    content.body  = "\(snap.guestName) arrives at \(snap.propertyEmoji) \(snap.propertyName)"
    content.sound = .default

    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    return UNNotificationRequest(
      identifier: "\(arrivalPrefix)\(snap.id)",
      content: content,
      trigger: trigger
    )
  }

  private func makeDepartureRequest(snap: BookingSnapshot, noticeHours: Int) -> UNNotificationRequest? {
    let fireDate = noticeFireDate(eventDay: snap.checkOut, noticeHours: noticeHours)
    guard fireDate > Date() else { return nil }

    let content = UNMutableNotificationContent()
    content.title = departureTitle(noticeHours: noticeHours)
    content.body  = "\(snap.guestName) checks out from \(snap.propertyEmoji) \(snap.propertyName)"
    content.sound = .default

    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    return UNNotificationRequest(
      identifier: "\(departurePrefix)\(snap.id)",
      content: content,
      trigger: trigger
    )
  }

  // MARK: - Helpers

  /// Fire date = 9:00 AM on event day, minus noticeHours.
  /// e.g. 24h notice → fires at 9 AM the day before; 0h → fires at 9 AM same day.
  private func noticeFireDate(eventDay: Date, noticeHours: Int) -> Date {
    let cal  = Calendar.current
    let base = cal.date(bySettingHour: 9, minute: 0, second: 0, of: eventDay) ?? eventDay
    return cal.date(byAdding: .hour, value: -noticeHours, to: base) ?? base
  }

  private func arrivalTitle(noticeHours: Int) -> String {
    switch noticeHours {
    case 0...6:   return "Guest arriving today 🛎️"
    case 7...30:  return "Guest arriving tomorrow 🛎️"
    default:
      let days = noticeHours / 24
      return "Upcoming arrival in \(days) day\(days == 1 ? "" : "s") 🛎️"
    }
  }

  private func departureTitle(noticeHours: Int) -> String {
    switch noticeHours {
    case 0...6:   return "Check-out today 👋"
    case 7...30:  return "Check-out tomorrow 👋"
    default:
      let days = noticeHours / 24
      return "Upcoming check-out in \(days) day\(days == 1 ? "" : "s") 👋"
    }
  }
}

