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

    init(id: String = UUID().uuidString, symbol: String, name: String,
         type: InstrumentType, exchange: String?, underlying: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.type = type
        self.exchange = exchange
        self.underlying = underlying
    }
}