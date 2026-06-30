import Foundation
import SwiftData

/// A user-defined price alert. Persisted via SwiftData. The AlertService
/// checks all alerts on app foreground (and after a quote refresh) and fires
/// a local notification when the condition is met, then marks the alert
/// triggered so it doesn't re-fire on every tick.
@Model
final class PriceAlert {
    var symbol: String
    var name: String
    /// "above" or "below" — the direction of the threshold crossing.
    var directionRaw: String
    var threshold: Double
    /// ISO8601 string of when the alert was created.
    var createdAt: Date
    /// Whether the alert has already fired. Triggered alerts are kept for
    /// history until the user deletes them.
    var triggered: Bool
    /// Optional note the user attached (e.g. "earnings reaction").
    var note: String?

    init(symbol: String, name: String, direction: AlertDirection,
         threshold: Double, note: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.directionRaw = direction.rawValue
        self.threshold = threshold
        self.createdAt = Date()
        self.triggered = false
        self.note = note
    }

    var direction: AlertDirection {
        get { AlertDirection(rawValue: directionRaw) ?? .above }
        set { directionRaw = newValue.rawValue }
    }

    /// Whether `price` satisfies the alert condition.
    func satisfies(_ price: Double) -> Bool {
        switch direction {
        case .above: return price >= threshold
        case .below: return price <= threshold
        }
    }
}

enum AlertDirection: String, Codable, CaseIterable, Sendable {
    case above
    case below

    var displayName: String {
        switch self {
        case .above: return "rises above"
        case .below: return "falls below"
        }
    }
}