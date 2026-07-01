import SwiftUI

/// AI research analysis card — shown on the Instrument Detail page.
struct AIResearchView: View {
    let instrument: Instrument
    @Environment(\.appEnv) private var env
    @Environment(AISettingsStore.self) private var aiSettings
    @State private var vm: AIResearchViewModel?
    @State private var followUpDraft: String = ""
    @State private var streamCursorVisible = true

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                HStack {
                    SectionHeader(title: "AI Research")
                    Spacer()
                    if aiSettings.isConfigured {
                        if vm?.isAnalyzing == true {
                            Button {
                                vm?.cancel()
                            } label: {
                                Image(systemName: "stop.circle.fill")
                                    .foregroundColor(Theme.Colors.negative)
                            }
                            .accessibilityLabel("Cancel analysis")
                        } else {
                            Button {
                                Haptics.light()
                                Task { await vm?.analyze(instrument: instrument) }
                            } label: {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .symbolEffect(.bounce, value: vm?.isAnalyzing == true)
                            }
                            .disabled(vm?.isAnalyzing == true)
                            .accessibilityLabel("Run AI analysis")
                            .sensoryFeedback(.impact(weight: .light), trigger: vm?.isAnalyzing)
                        }
                    }
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .symbolEffect(.bounce, value: aiSettings.isConfigured)
                    }
                    .buttonStyle(.plain)
                }

                if !aiSettings.isConfigured {
                    unconfiguredState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Group {
                        switch vm?.state ?? .idle {
                        case .idle:
                            idleState
                                .transition(.opacity)
                        case .loading:
                            // While streaming, show the accumulating text with a
                            // typing cursor instead of the bare thinking dots.
                            if vm?.streamingText.isEmpty ?? true {
                                loadingState
                                    .transition(.opacity)
                            } else {
                                streamingState
                                    .transition(.opacity)
                            }
                        case .loaded(let analysis):
                            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                                analysisContent(analysis)
                                followUpSection
                            }
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        case .error(let msg):
                            ErrorView(message: msg, retry: {
                                Task { await vm?.analyze(instrument: instrument) }
                            })
                            .transition(.opacity)
                        }
                    }
                    .animation(Theme.Animation.gentle, value: vm?.isAnalyzing)
                }
            }
        }
        .onAppear {
            if vm == nil {
                vm = AIResearchViewModel(
                    aiService: AIService(settings: aiSettings),
                    provider: env.marketProvider
                )
            }
        }
        .onDisappear { vm?.cancel() }
        .onChange(of: instrument.symbol) { _, _ in
            // Reset state when the instrument changes so we never show the
            // previous ticker's analysis for a new one.
            vm?.reset()
            vm?.streamingText = ""
        }
    }

    private var unconfiguredState: some View {
        VStack(spacing: Theme.Metrics.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                .symbolEffect(.pulse, options: .repeating)
            Text("Connect an AI provider to get research analysis of \(instrument.symbol).")
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                AISettingsView()
            } label: {
                Text("Set up AI provider")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.Gradients.inkGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
                    .shadow(color: Theme.Colors.textPrimary.opacity(0.18), radius: 10, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .pressScale()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Metrics.spacing)
    }

    private var idleState: some View {
        VStack(spacing: Theme.Metrics.spacingS) {
            Text("Get an AI-powered analysis of \(instrument.symbol) based on technicals, news, and market movements.")
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Analyze \(instrument.symbol)", style: .primary, icon: "sparkles") {
                Task { await vm?.analyze(instrument: instrument) }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.Metrics.spacingS)
    }

    // MARK: - Follow-up chat (multi-turn)

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
            Divider().overlay(Theme.Colors.separator)
            SectionHeader(title: "Ask a follow-up")
            ForEach(vm?.chat ?? []) { msg in
                chatBubble(msg)
            }
            if vm?.isAskingFollowUp == true {
                HStack(spacing: 6) {
                    ThinkingDots().frame(width: 36, height: 12)
                    Text("Thinking…")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            if let err = vm?.followUpError {
                Text(err)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.negative)
            }
            HStack(spacing: Theme.Metrics.spacingS) {
                TextField("Ask about \(instrument.symbol)…", text: $followUpDraft, axis: .vertical)
                    .font(Typography.body)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                            .stroke(Theme.Colors.separator, lineWidth: Theme.Metrics.hairline)
                    )
                Button {
                    let q = followUpDraft
                    followUpDraft = ""
                    Task { await vm?.askFollowUp(q, instrument: instrument) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(followUpDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                         || vm?.isAskingFollowUp == true
                                         ? Theme.Colors.textSecondary : Theme.Colors.accent)
                }
                .disabled(followUpDraft.trimmingCharacters(in: .whitespaces).isEmpty
                          || vm?.isAskingFollowUp == true)
                .accessibilityLabel("Send follow-up")
            }
        }
    }

    @ViewBuilder
    private func bubbleBackground(for role: AIResearchViewModel.ChatMessage.Role) -> some View {
        if role == .user {
            Theme.Gradients.accentGradient
        } else {
            Theme.Colors.surface
        }
    }

    private func chatBubble(_ msg: AIResearchViewModel.ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 0) }
            Text(msg.text)
                .font(Typography.callout)
                .foregroundColor(msg.role == .user ? Theme.Colors.textOnPrimary : Theme.Colors.textPrimary)
                .padding(10)
                .background(bubbleBackground(for: msg.role))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                        .stroke(Theme.Colors.separator.opacity(msg.role == .user ? 0 : 1), lineWidth: Theme.Metrics.hairline)
                )
            if msg.role == .assistant { Spacer(minLength: 0) }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            ThinkingDots()
                .frame(width: 48, height: 16)
            Text("Analyzing \(instrument.symbol)…")
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            Text("Gathering technicals, news, and market data")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Metrics.spacing)
    }

    /// Live streaming text with a blinking cursor — shown while the LLM
    /// generates tokens. Replaces the full-wait spinner once the first
    /// token arrives, giving the user immediate visual feedback.
    private var streamingState: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack(spacing: 6) {
                ThinkingDots().frame(width: 24, height: 8)
                Text("Generating…")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            (Text(vm?.streamingText ?? "")
                .font(Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
             + Text("▍")
                .font(Typography.body)
                .foregroundColor(Theme.Colors.accent))
            .opacity(streamCursorVisible ? 1 : 0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Metrics.spacing)
        .onAppear {
            streamCursorVisible = true
        }
    }

    private func analysisContent(_ analysis: AIAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            recommendationHeader(analysis)
                .transition(.scale.combined(with: .opacity))
            Text(analysis.summary)
                .font(Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .appearAnimation(.fade, index: 1)

            if !analysis.bullishFactors.isEmpty {
                factorList(title: "Bullish", icon: "arrowtriangle.up.fill",
                           color: Theme.Colors.positive, factors: analysis.bullishFactors)
                    .staggeredAppear(index: 2)
            }
            if !analysis.bearishFactors.isEmpty {
                factorList(title: "Bearish", icon: "arrowtriangle.down.fill",
                           color: Theme.Colors.negative, factors: analysis.bearishFactors)
                    .staggeredAppear(index: 3)
            }

            VStack(alignment: .leading, spacing: 4) {
                StatCell(label: "Technical Outlook", value: analysis.technicalOutlook)
                StatCell(label: "News Sentiment", value: analysis.newsSentiment)
                StatCell(label: "Risk Level", value: analysis.riskLevel.rawValue)
                StatCell(label: "Time Horizon", value: analysis.timeHorizon.rawValue)
            }
            .staggeredAppear(index: 4)

            Text("Generated \(analysis.generatedAt.relativeText)")
                .font(Typography.caption2)
                .foregroundColor(Theme.Colors.textSecondary)
            Text("For informational purposes only — not investment advice.")
                .font(Typography.caption2)
                .foregroundColor(Theme.Colors.textSecondary)

            // Copy + Regenerate affordances.
            HStack(spacing: Theme.Metrics.spacing) {
                Button {
                    Haptics.light()
                    UIPasteboard.general.string = """
                    \(instrument.symbol) — \(analysis.recommendation.rawValue) (\(analysis.confidence.rawValue))
                    \(analysis.summary)

                    Bullish: \(analysis.bullishFactors.joined(separator: ", "))
                    Bearish: \(analysis.bearishFactors.joined(separator: ", "))
                    Technical: \(analysis.technicalOutlook)
                    Risk: \(analysis.riskLevel.rawValue) · Horizon: \(analysis.timeHorizon.rawValue)
                    Generated: \(analysis.generatedAt)
                    """
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.light()
                    Task { await vm?.analyze(instrument: instrument) }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(vm?.isAnalyzing == true)
            }
        }
    }

    private func recommendationHeader(_ analysis: AIAnalysis) -> some View {
        HStack(spacing: Theme.Metrics.spacing) {
            // Color-coded pill background for the recommendation — emerald
            // tint for buy, red tint for sell, slate for hold. Much more
            // scannable than bare colored text.
            HStack(spacing: 6) {
                Image(systemName: recommendationIcon(analysis.recommendation))
                    .font(.system(size: 13, weight: .bold))
                Text(analysis.recommendation.rawValue)
                    .font(Typography.title2)
            }
            .foregroundColor(recommendationColor(analysis.recommendation))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(recommendationColor(analysis.recommendation).opacity(0.14))
            )
            .overlay(
                Capsule().stroke(recommendationColor(analysis.recommendation).opacity(0.3),
                                 lineWidth: Theme.Metrics.hairline)
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Confidence: \(analysis.confidence.rawValue)")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func recommendationIcon(_ rec: AIAnalysis.Recommendation) -> String {
        switch rec {
        case .strongBuy: return "arrow.up.circle.fill"
        case .buy:       return "arrow.up"
        case .hold:      return "equal.circle.fill"
        case .sell:      return "arrow.down"
        case .strongSell: return "arrow.down.circle.fill"
        }
    }

    private func factorList(title: String, icon: String, color: Color, factors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color)
                Text(title)
                    .font(Typography.subheadline)
                    .foregroundColor(color)
            }
            ForEach(factors, id: \.self) { factor in
                Text("• \(factor)")
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func recommendationColor(_ rec: AIAnalysis.Recommendation) -> Color {
        switch rec {
        case .strongBuy, .buy: return Theme.Colors.positive
        case .hold:            return Theme.Colors.textSecondary
        case .sell, .strongSell: return Theme.Colors.negative
        }
    }
}

/// Three monochrome dots that fade in sequence — a quiet "thinking" indicator
/// that replaces the bare `ProgressView` and fits the minimal palette.
private struct ThinkingDots: View {
    private enum Phase: Double, CaseIterable {
        case one = 0.0, two = 0.33, three = 0.66
    }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 6, height: 6)
                        .opacity(opacity(for: i, phase: phase.rawValue))
                        .scaleEffect(scale(for: i, phase: phase.rawValue))
                        .animation(Theme.Animation.interactive, value: phase.rawValue)
                }
            }
        } animation: { _ in
            Theme.Animation.interactive
        }
    }

    private func opacity(for index: Int, phase: Double) -> Double {
        let p = (phase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
        return 0.25 + 0.75 * max(0, 1 - abs(p - 0.5) * 2)
    }

    private func scale(for index: Int, phase: Double) -> CGFloat {
        CGFloat(0.7 + 0.3 * opacity(for: index, phase: phase))
    }
}