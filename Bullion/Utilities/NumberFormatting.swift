import Foundation

/// Centralized number formatting helpers.
enum NumberFormatting {
    /// Non-finite guard shared by every helper: NaN / ±Infinity from a bad
    /// upstream payload should render as an em dash, never "nan"/"inf".
    private static let nonFinitePlaceholder = "—"

    /// Currency with optional fixed decimal digits.
    ///
    /// A fresh `NumberFormatter` is created per call: `NumberFormatter` is not
    /// thread-safe and mutating a shared instance for `digits` would leak that
    /// setting into later default-digit calls.
    static func currency(_ value: Double, digits: Int? = nil) -> String {
        guard value.isFinite else { return nonFinitePlaceholder }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = digits ?? 2
        f.minimumFractionDigits = digits ?? 2
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Plain decimal with optional fixed digits.
    static func decimal(_ value: Double, digits: Int? = nil) -> String {
        guard value.isFinite else { return nonFinitePlaceholder }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits ?? 2
        f.minimumFractionDigits = digits ?? 0
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Price: 2 decimals by default.
    static func price(_ value: Double, digits: Int = 2) -> String {
        currency(value, digits: digits)
    }

    /// Compact notation for large numbers: 1.2K, 3.4M, 5.6B, 7.8T.
    static func compact(_ value: Double) -> String {
        guard value.isFinite else { return nonFinitePlaceholder }
        let absVal = abs(value)
        let suffix: String
        let divisor: Double
        if absVal >= 1_000_000_000_000 {
            suffix = "T"; divisor = 1_000_000_000_000
        } else if absVal >= 1_000_000_000 {
            suffix = "B"; divisor = 1_000_000_000
        } else if absVal >= 1_000_000 {
            suffix = "M"; divisor = 1_000_000
        } else if absVal >= 1_000 {
            suffix = "K"; divisor = 1_000
        } else {
            suffix = ""; divisor = 1
        }
        let scaled = value / divisor
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        let num = f.string(from: NSNumber(value: scaled)) ?? String(scaled)
        return num + suffix
    }

    /// Percentage from a 0–100 value, e.g. 1.23%.
    static func percent(_ value: Double, digits: Int = 2) -> String {
        guard value.isFinite else { return nonFinitePlaceholder }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        let num = f.string(from: NSNumber(value: value)) ?? String(value)
        return num + "%"
    }

    /// Signed percentage with + / − prefix.
    static func signedPercent(_ value: Double, digits: Int = 2) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + percent(value, digits: digits)
    }
}