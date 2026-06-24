import Foundation

@Observable
final class AIResearchViewModel {
    enum State: Sendable {
        case idle
        case loading
        case loaded(AIAnalysis)
        case error(String)
    }

    var state: State = .idle
    var isAnalyzing: Bool {
        if case .loading = state { return true }
        return false
    }

    private let aiService: AIService
    private let provider: any MarketDataProvider

    init(aiService: AIService, provider: any MarketDataProvider) {
        self.aiService = aiService
        self.provider = provider
    }

    @MainActor
    func analyze(instrument: Instrument) async {
        state = .loading
        do {
            let analysis = try await aiService.analyze(
                instrument: instrument, provider: provider
            )
            state = .loaded(analysis)
        } catch let e as AIError {
            state = .error(e.errorDescription ?? "AI analysis failed.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}