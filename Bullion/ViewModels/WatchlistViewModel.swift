import Foundation
import SwiftUI
import SwiftData

/// Watchlist view model using SwiftData for persistence.
/// Migrates any existing UserDefaults watchlist on first load.
@Observable
final class WatchlistViewModel {
    private(set) var items: [Instrument] = []
    var quotes: [String: Quote] = [:]
    var loadState: LoadState<[Quote]> = .idle

    private let provider: any MarketDataProvider
    private let modelContext: ModelContext?
    private let storageKey = "bullion.watchlist.symbols"
    private let migrationKey = "bullion.watchlist.migratedToSwiftData"
    private var hasMigrated = false

    init(provider: any MarketDataProvider, modelContext: ModelContext? = nil) {
        self.provider = provider
        self.modelContext = modelContext
        loadFromDisk()
    }

    func contains(_ instrument: Instrument) -> Bool {
        items.contains(where: { $0.symbol == instrument.symbol })
    }

    func add(_ instrument: Instrument) {
        guard !contains(instrument) else { return }
        items.append(instrument)
        if let ctx = modelContext {
            let item = WatchlistItem(
                symbol: instrument.symbol, name: instrument.name,
                type: instrument.type, exchange: instrument.exchange,
                underlying: instrument.underlying, order: items.count - 1
            )
            ctx.insert(item)
            save(ctx)
        }
    }

    func remove(_ instrument: Instrument) {
        items.removeAll { $0.symbol == instrument.symbol }
        quotes.removeValue(forKey: instrument.symbol)
        if let ctx = modelContext {
            let target = instrument.symbol
            if let entity = try? ctx.fetch(FetchDescriptor<WatchlistItem>(
                predicate: #Predicate { $0.symbol == target }
            )).first {
                ctx.delete(entity)
                save(ctx)
            }
        }
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        let removed = items.remove(at: index)
        quotes.removeValue(forKey: removed.symbol)
        if let ctx = modelContext {
            let target = removed.symbol
            if let entity = try? ctx.fetch(FetchDescriptor<WatchlistItem>(
                predicate: #Predicate { $0.symbol == target }
            )).first {
                ctx.delete(entity)
                save(ctx)
            }
        }
    }

    /// Remove multiple rows at once. SwiftUI delivers an `IndexSet` from
    /// `.onDelete` whose indices are relative to the *current* array; removing
    /// them one at a time in ascending order shifts every higher index down
    /// and makes subsequent `remove(at:)` calls hit the wrong row (or no-op via
    /// the bounds guard). `remove(atOffsets:)` removes them in one atomic
    /// mutation so all indices resolve against the original array.
    func remove(atOffsets offsets: IndexSet) {
        let removedSymbols = offsets.compactMap { items.indices.contains($0) ? items[$0].symbol : nil }
        items.remove(atOffsets: offsets)
        for symbol in removedSymbols { quotes.removeValue(forKey: symbol) }
        guard let ctx = modelContext, !removedSymbols.isEmpty else { return }
        let targets = removedSymbols
        if let entities = try? ctx.fetch(FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { targets.contains($0.symbol) }
        )) {
            for entity in entities { ctx.delete(entity) }
            // Re-persist the order of the remaining items in one pass.
            for (i, instrument) in items.enumerated() {
                let target = instrument.symbol
                if let entity = try? ctx.fetch(FetchDescriptor<WatchlistItem>(
                    predicate: #Predicate { $0.symbol == target }
                )).first {
                    entity.order = i
                }
            }
            save(ctx)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        // Re-persist order.
        if let ctx = modelContext {
            for (i, instrument) in items.enumerated() {
                let target = instrument.symbol
                if let entity = try? ctx.fetch(FetchDescriptor<WatchlistItem>(
                    predicate: #Predicate { $0.symbol == target }
                )).first {
                    entity.order = i
                }
            }
            save(ctx)
        }
    }

    @MainActor
    func refreshQuotes() async {
        guard !items.isEmpty else {
            loadState = .empty
            quotes = [:]
            return
        }
        loadState = .loading
        do {
            let symbols = items.map(\.symbol)
            let qs = try await provider.quotes(symbols)
            for q in qs { quotes[q.symbol] = q }
            loadState = .loaded(qs)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        // Migrate from UserDefaults if SwiftData is available.
        if let ctx = modelContext {
            do {
                let entities = try ctx.fetch(FetchDescriptor<WatchlistItem>(
                    sortBy: [SortDescriptor(\.order)]
                ))
                if !entities.isEmpty {
                    items = entities.map(\.instrument)
                    hasMigrated = true
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    return
                }
                // No SwiftData items — try migrating from UserDefaults.
                if !hasMigrated, !UserDefaults.standard.bool(forKey: migrationKey),
                   let data = UserDefaults.standard.data(forKey: storageKey),
                   let decoded = try? JSONDecoder().decode([Instrument].self, from: data) {
                    hasMigrated = true
                    items = decoded
                    for (i, inst) in decoded.enumerated() {
                        ctx.insert(WatchlistItem(
                            symbol: inst.symbol, name: inst.name,
                            type: inst.type, exchange: inst.exchange,
                            underlying: inst.underlying, order: i
                        ))
                    }
                    // Only destroy the UserDefaults backup once the SwiftData
                    // save is confirmed — otherwise a failed save (schema
                    // mismatch, disk pressure) would lose the watchlist
                    // entirely on the next launch.
                    if save(ctx) {
                        UserDefaults.standard.removeObject(forKey: storageKey)
                        UserDefaults.standard.set(true, forKey: migrationKey)
                    }
                }
            } catch {
                // Fall back to UserDefaults-only.
                loadFromUserDefaults()
            }
        } else {
            loadFromUserDefaults()
        }
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Instrument].self, from: data) else { return }
        items = decoded
    }

    @discardableResult
    private func save(_ ctx: ModelContext) -> Bool {
        do {
            try ctx.save()
            return true
        } catch {
            // Non-fatal: in-memory state is still correct, but the caller now
            // knows the persistence failed (return false) so it can avoid
            // destroying any fallback backup.
            print("WatchlistViewModel: failed to save: \(error)")
            return false
        }
    }
}