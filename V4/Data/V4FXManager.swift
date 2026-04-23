//
//  V4FXManager.swift
//  StayTrackr V3 (V4)
//
//  Fetches live exchange rates from frankfurter.app (ECB data).
//  Free, no API key, HTTPS, updated daily.
//

import Foundation
import SwiftData

enum V4FXManager {

    private static let baseURL = "https://api.frankfurter.app/latest"

    // MARK: - Refresh All Existing Pairs

    /// Fetches live rates for every STFXRate pair already stored in SwiftData
    /// and updates them in-place via V4FXStore.upsert().
    /// Groups by fromCode to minimise API calls (one call per base currency).
    @discardableResult
    static func refreshAll(in context: ModelContext) async throws -> Int {
        let descriptor = FetchDescriptor<STFXRate>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard !existing.isEmpty else { return 0 }

        // Group toCodes by fromCode: ["EUR": ["CZK","USD","GBP"], ...]
        var groups: [String: Set<String>] = [:]
        for r in existing {
            groups[r.fromCode, default: []].insert(r.toCode)
        }

        var updated = 0
        for (base, targets) in groups {
            let targetList = targets.joined(separator: ",")
            guard let rates = try? await fetchRates(from: base, to: targetList) else { continue }
            for (toCode, rate) in rates {
                V4FXStore.upsert(from: base, to: toCode, rate: rate, in: context)
                updated += 1
            }
        }

        try? context.save()
        return updated
    }

    // MARK: - Fetch a Specific Pair

    /// Returns the live rate for a single currency pair, e.g. EUR -> CZK.
    static func fetchRate(from: String, to: String) async throws -> Double {
        guard let rates = try await fetchRates(from: from, to: to),
              let rate = rates[to.uppercased()] else {
            throw FXError.rateNotFound(from, to)
        }
        return rate
    }

    // MARK: - Private API Call

    /// Calls frankfurter.app and returns a [toCode: rate] dictionary.
    private static func fetchRates(from base: String, to targets: String) async throws -> [String: Double]? {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "from", value: base.uppercased()),
            URLQueryItem(name: "to",   value: targets.uppercased())
        ]
        guard let url = components.url else { throw FXError.invalidRequest }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FXError.httpError
        }

        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        return decoded.rates
    }

    // MARK: - Errors

    enum FXError: LocalizedError {
        case invalidRequest
        case httpError
        case rateNotFound(String, String)

        var errorDescription: String? {
            switch self {
            case .invalidRequest:
                return "Invalid currency code."
            case .httpError:
                return "Unable to reach the exchange rate service. Check your connection."
            case .rateNotFound(let from, let to):
                return "No rate available for \(from) -> \(to)."
            }
        }
    }
}

// MARK: - Frankfurter Response Model

private struct FrankfurterResponse: Decodable {
    let base: String
    let date: String
    let rates: [String: Double]
}
