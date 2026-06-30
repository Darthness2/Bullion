import Foundation

@Observable
final class AIResearchViewModel {
    enum State: Sendable {
        case idle
        case loading
        case loaded(AIAnalysis)
        case error(String)
    }

    /// A single follow-up Q&A turn. Lets the user ask "why?" after the
    /// initial analysis without re-running the full research pipeline.
    struct ChatMessage: Identifiable, Sendable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, assistant }
    }

    var state: State = .idle
    /// Follow-up conversation after the initial analysis.
    var chat: [ChatMessage] = []
    var followUpAnswer: String?
    var isAskingFollowUp = false
    var followUpError: String?
    var isAnalyzing: Bool {
        if case .loading = state { return true }
        return false
    }

    private let aiService: AIService
    private let provider: any MarketDataProvider
    private var analyzeTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    private var lastContext: MarketContext?
    private var lastAnalysis: AIAnalysis?

    init(aiService: AIService, provider: any MarketDataProvider) {
        self.aiService = aiService
        self.provider = provider
    }

    @MainActor
    func analyze(instrument: Instrument) async {
        // Cancel any in-flight analysis or follow-up before starting.
        analyzeTask?.cancel()
        followUpTask?.cancel()
        state = .loading
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let analysis = try await self.aiService.analyze(
                    instrument: instrument, provider: self.provider
                )
                guard !Task.isCancelled else { return }
                self.lastAnalysis = analysis
                self.state = .loaded(analysis)
            } catch is CancellationError {
                // Cancellation is expected when the user taps Cancel or leaves.
            } catch let e as AIError {
                guard !Task.isCancelled else { return }
                self.state = .error(e.errorDescription ?? "AI analysis failed.")
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .error(error.localizedDescription)
            }
        }
        analyzeTask = task
        await task.value
    }

    /// Cancel any in-flight analysis or follow-up. Called on view disappear.
    func cancel() {
        analyzeTask?.cancel()
        followUpTask?.cancel()
    }

    /// Ask a free-form follow-up question about the most recent analysis.
    /// Reuses the cached market context so it's cheap and fast. No-op if no
    /// analysis has been run yet.
    @MainActor
    func askFollowUp(_ question: String, instrument: Instrument) async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chat.append(ChatMessage(role: .user, text: question))
        isAskingFollowUp = true
        followUpError = nil
        followUpTask?.cancel()
        let q = question
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let answer = try await self.aiService.followUp(
                    question: q, instrument: instrument, provider: self.provider,
                    priorAnalysis: self.lastAnalysis
                )
                guard !Task.isCancelled else { return }
                self.chat.append(ChatMessage(role: .assistant, text: answer))
                self.followUpAnswer = answer
            } catch is CancellationError {
                // Expected on cancel / disappear.
            } catch let e as AIError {
                guard !Task.isCancelled else { return }
                self.followUpError = e.errorDescription ?? "Follow-up failed."
            } catch {
                guard !Task.isCancelled else { return }
                self.followUpError = error.localizedDescription
            }
        }
        followUpTask = task
        await task.value
        isAskingFollowUp = false
    }

    func reset() {
        state = .idle
        chat = []
        followUpAnswer = nil
        followUpError = nil
    }
}