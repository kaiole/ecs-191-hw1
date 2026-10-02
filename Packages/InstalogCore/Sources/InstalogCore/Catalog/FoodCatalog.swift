import Foundation

/// One search hit, with enough identity to tell similar foods apart before choosing.
public struct CatalogFoodSummary: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let category: String?
    public let preparation: String?
    public let sourceLabel: String
    /// Energy per 100 g when reported.
    public let energyPer100Grams: Double?
}

public enum CatalogError: Error, Equatable, Sendable, LocalizedError {
    case unavailable(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "Food database unavailable: \(reason)"
        case .queryFailed(let reason): "Food search failed: \(reason)"
        }
    }
}

/// Searches and retrieves locally usable food definitions.
public protocol FoodCatalog: Sendable {
    var sourceDescription: String { get }
    func search(_ query: String, limit: Int) async throws -> [CatalogFoodSummary]
    /// A fresh definition for the record. Callers assign the personal copy's identity.
    func food(id: String) async throws -> FoodDefinition?
}
