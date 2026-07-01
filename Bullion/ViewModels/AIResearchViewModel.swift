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
    /// Accumulated streaming text shown live as the model generates tokens.
    /// Cleared on each new analysis. When the stream finishes, this is
    /// parsed into a structured AIAnalysis and `state` moves to `.loaded`.
    var streamingText: String = ""
    var isAnalyzing: Bool {
        if case .loading = state { return true }
        return false
    }

    private let aiService: AIService
    private let provider: any MarketDataProvider
    private var analyzeTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    private(set) var lastContext: MarketContext?
    private(set) var lastAnalysis: AIAnalysis?

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
        streamingText = ""
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (stream, context) = try await self.aiService.analyzeStreamWithContext(
                    instrument: instrument, provider: self.provider
                )
                self.lastContext = context
                var accumulated = ""
                for try await delta in stream {
                    if Task.isCancelled { break }
                    accumulated += delta
                    self.streamingText = accumulated
                }
                guard !Task.isCancelled else { return }
                let analysis = try AIPromptBuilder.parseAnalysis(accumulated)
                self.lastAnalysis = analysis
                self.streamingText = ""
                self.state = .loaded(analysis)
            } catch is CancellationError {
                // Cancellation is expected when the user taps Cancel or leaves.
            } catch let e as AIError {
                guard !Task.isCancelled else { return }
                self.streamingText = ""
                self.state = .error(e.errorDescription ?? "AI analysis failed.")
            } catch {
                guard !Task.isCancelled else { return }
                self.streamingText = ""
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
        // Build conversation history from existing chat for multi-turn context.
        let history = chat.map { msg -> (role: ChatRole, text: String) in
            (role: msg.role == .user ? .user : .assistant, text: msg.text)
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let answer = try await self.aiService.followUp(
                    question: q, instrument: instrument, provider: self.provider,
                    priorAnalysis: self.lastAnalysis,
                    cachedContext: self.lastContext,
                    history: history
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