import Foundation

enum InstrumentType: String, Codable, CaseIterable, Sendable {
    case stock
    case etf
    case future
    case index
}

struct Instrument: Identifiable, Codable, Hashable, Sendable {
    let id: String          // symbol, used as stable identity
    let symbol: String
    let name: String
    let type: InstrumentType
    let exchange: String?
    var underlying: String? = nil   // futures-only: underlying asset symbol

    init(id: String? = nil, symbol: String, name: String,
         type: InstrumentType, exchange: String?, underlying: String? = nil) {
        // Identity is the symbol by default so the same instrument keeps a
        // stable id across refreshes (a random UUID would make SwiftUI `ForEach`
        // re-create rows and reset scroll/selection on every reload).
        self.id = id ?? symbol
        self.symbol = symbol
        self.name = name
        self.type = type
        self.exchange = exchange
        self.underlying = underlying
    }
}