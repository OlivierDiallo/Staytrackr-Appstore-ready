//
//  V4FlightManager.swift
//  StayTrackr V3 (V4)
//
//  Fetches live flight status from AviationStack.
//  Free tier uses HTTP (100 calls/month). Replace apiKey with your key.
//

import Foundation
import SwiftData

// MARK: - Flight Info

struct V4FlightInfo {
    var flightNumber: String
    var status: String            // scheduled | active | landed | cancelled | incident | diverted
    var delayMinutes: Int         // 0 = on time
    var estimatedArrival: Date?
    var airline: String
    var origin: String
    var destination: String

    var isDelayed: Bool    { delayMinutes > 0 }
    var isCancelled: Bool  { status == "cancelled" }
    var isLanded: Bool     { status == "landed" }

    var statusLabel: String {
        switch status {
        case "scheduled":  return "Scheduled"
        case "active":     return "In Flight"
        case "landed":     return "Landed"
        case "cancelled":  return "Cancelled"
        case "incident":   return "Incident"
        case "diverted":   return "Diverted"
        default:           return status.capitalized
        }
    }

    var delayLabel: String {
        guard delayMinutes > 0 else { return "" }
        let h = delayMinutes / 60
        let m = delayMinutes % 60
        if h > 0 { return "+\(h)h \(m)m" }
        return "+\(m)m"
    }
}

// MARK: - Flight Manager

enum V4FlightManager {

    // Keys are injected from Config/Secrets.xcconfig → Info.plist at build time.
    // To rotate: update AVIATION_STACK_KEY in Config/Secrets.xcconfig (never commit that file).
    // To upgrade to HTTPS: set AVIATION_STACK_SCHEME = https in Secrets.xcconfig and
    // remove the NSAppTransportSecurity block from Info.plist.
    private static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AviationStackKey") as? String ?? ""
    }
    private static var scheme: String {
        Bundle.main.object(forInfoDictionaryKey: "AviationStackScheme") as? String ?? "https"
    }

    // MARK: - Check Flight

    /// Fetches the current status for a flight IATA code (e.g. "BA456").
    static func checkFlight(_ rawNumber: String) async throws -> V4FlightInfo {
        guard !apiKey.isEmpty else { throw FlightError.apiKeyNotSet }

        let iata = rawNumber
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        var components = URLComponents()
        components.scheme = scheme
        components.host   = "api.aviationstack.com"
        components.path   = "/v1/flights"
        components.queryItems = [
            URLQueryItem(name: "access_key", value: apiKey),
            URLQueryItem(name: "flight_iata", value: iata),
            URLQueryItem(name: "limit",       value: "1")
        ]

        guard let url = components.url else {
            throw FlightError.invalidFlightNumber
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw FlightError.networkError
        }

        guard http.statusCode == 200 else {
            throw FlightError.httpError(http.statusCode)
        }

        guard let json = try? JSONDecoder().decode(AviationStackResponse.self, from: data) else {
            throw FlightError.parseError
        }

        if let errInfo = json.error {
            throw FlightError.apiError(errInfo.info ?? "Unknown API error")
        }

        guard let flight = json.data?.first else {
            throw FlightError.flightNotFound
        }

        let delayMinutes = flight.arrival?.delay ?? 0
        let estimatedArrival: Date? = flight.arrival?.estimated
            .flatMap { parseISO8601($0) }

        return V4FlightInfo(
            flightNumber:    flight.flight?.iata ?? iata,
            status:          flight.flightStatus ?? "unknown",
            delayMinutes:    delayMinutes,
            estimatedArrival: estimatedArrival,
            airline:         flight.airline?.name ?? "",
            origin:          flight.departure?.iata ?? "",
            destination:     flight.arrival?.iata ?? ""
        )
    }

    // MARK: - Polling Gate

    /// Returns true if this booking's flight should be polled now.
    /// Rules: has a flight number, not yet landed, checkIn within +-24-48 hrs,
    /// and at least 30 minutes since last check.
    static func shouldPoll(_ booking: STBooking) -> Bool {
        guard let _ = booking.flightNumber else { return false }
        guard booking.flightStatus != "landed" else { return false }
        guard booking.flightStatus != "cancelled" else { return false }

        let hoursUntil = booking.checkIn.timeIntervalSinceNow / 3600
        guard hoursUntil > -24 && hoursUntil < 48 else { return false }

        if let last = booking.flightLastChecked {
            return Date().timeIntervalSince(last) > 1800   // 30 min throttle
        }
        return true
    }

    // MARK: - Update Booking

    /// Fetches flight status and writes results back to the SwiftData booking.
    /// Returns the FlightInfo if the request succeeded, nil otherwise.
    @discardableResult
    static func updateBooking(_ booking: STBooking, context: ModelContext) async -> V4FlightInfo? {
        guard let number = booking.flightNumber, !number.isEmpty else { return nil }

        do {
            let info = try await checkFlight(number)
            booking.flightStatus      = info.status
            booking.flightDelayMinutes = info.delayMinutes
            booking.estimatedArrival  = info.estimatedArrival
            booking.flightLastChecked = Date()
            try? context.save()
            return info
        } catch {
            booking.flightLastChecked = Date()   // still throttle on error
            try? context.save()
            return nil
        }
    }

    // MARK: - Date Parsing

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: string) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: - Errors

    enum FlightError: LocalizedError {
        case invalidFlightNumber
        case networkError
        case httpError(Int)
        case parseError
        case flightNotFound
        case apiError(String)
        case apiKeyNotSet

        var errorDescription: String? {
            switch self {
            case .invalidFlightNumber:
                return "Invalid flight number. Use IATA format, e.g. BA456."
            case .networkError:
                return "Unable to reach flight data service. Check your internet connection."
            case .httpError(let code):
                return "Flight service returned an error (HTTP \(code))."
            case .parseError:
                return "Unexpected response from flight service."
            case .flightNotFound:
                return "Flight not found. Check the flight number and try again."
            case .apiError(let msg):
                return "Flight API error: \(msg)"
            case .apiKeyNotSet:
                return "AviationStack API key is not configured."
            }
        }
    }
}

// MARK: - AviationStack Response Models

private struct AviationStackResponse: Decodable {
    let data: [AviationFlight]?
    let error: AviationError?
}

private struct AviationError: Decodable {
    let info: String?
}

private struct AviationFlight: Decodable {
    let flightStatus: String?
    let airline: AviationAirline?
    let departure: AviationAirport?
    let arrival: AviationAirport?
    let flight: AviationFlightCode?

    enum CodingKeys: String, CodingKey {
        case flightStatus = "flight_status"
        case airline, departure, arrival, flight
    }
}

private struct AviationAirline: Decodable {
    let name: String?
}

private struct AviationAirport: Decodable {
    let iata: String?
    let airport: String?
    let estimated: String?
    let delay: Int?
}

private struct AviationFlightCode: Decodable {
    let iata: String?
}
