import Foundation
import SwiftData

/// SwiftData model for a persisted watchlist item.
@Model
final class WatchlistItem {
    var symbol: String
    var name: String
    var typeRaw: String
    var exchange: String?
    var underlying: String?
    var order: Int
    var addedAt: Date

    init(symbol: String, name: String, type: InstrumentType,
         exchange: String?, underlying: String?, order: Int) {
        self.symbol = symbol
        self.name = name
        self.typeRaw = type.rawValue
        self.exchange = exchange
        self.underlying = underlying
        self.order = order
        self.addedAt = Date()
    }

    var type: InstrumentType {
        get { InstrumentType(rawValue: typeRaw) ?? .stock }
        set { typeRaw = newValue.rawValue }
    }

    var instrument: Instrument {
        Instrument(symbol: symbol, name: name, type: type, exchange: exchange, underlying: underlying)
    }
}