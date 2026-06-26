import SwiftUI

struct AISettingsView: View {
    @Environment(AISettingsStore.self) private var store
    @State private var showAnthropicKey = false
    @State private var showOpenAIKey = false
    @State private var testResult: TestResult?
    @State private var confirmingClear = false
    @State private var isTesting = false

    enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            providerSection
            modelSection
            credentialsSection
            testSection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("AI Research")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Provider

    private var providerSection: some View {
        Section {
            Picker("Provider", selection: Binding(
                get: { store.providerType },
                set: { newValue in
                    store.providerType = newValue
                    store.selectedModel = newValue.defaultModels.first ?? ""
                }
            )) {
                ForEach(AIProviderType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text("Provider")
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section {
            Picker("Model", selection: Binding(
                get: { store.selectedModel },
                set: { store.selectedModel = $0 }
            )) {
                ForEach(store.providerType.defaultModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            if store.providerType == .ollama {
                TextField("Ollama endpoint", text: Binding(
                    get: { store.ollamaEndpoint },
                    set: { store.ollamaEndpoint = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        } header: {
            Text("Model")
        } footer: {
            switch store.providerType {
            case .anthropic: Text("Get an API key at console.anthropic.com")
            case .openai:    Text("Get an API key at platform.openai.com")
            case .ollama:    Text("Install Ollama at ollama.com, then run `ollama pull llama3.1`")
            }
        }
    }

    // MARK: - Credentials

    @ViewBuilder private var credentialsSection: some View {
        switch store.providerType {
        case .anthropic:
            Section {
                HStack {
                    if showAnthropicKey {
                        TextField("Anthropic API Key", text: Binding(
                            get: { store.anthropicAPIKey },
                            set: { store.anthropicAPIKey = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    } else {
                        SecureField("Anthropic API Key", text: Binding(
                            get: { store.anthropicAPIKey },
                            set: { store.anthropicAPIKey = $0 }
                        ))
                    }
                    Button {
                        showAnthropicKey.toggle()
                    } label: {
                        Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } header: {
                Text("Credentials")
            } footer: {
                Text("Stored in iOS Keychain. Never leaves your device except to call Anthropic directly.")
            }
        case .openai:
            Section {
                HStack {
                    if showOpenAIKey {
                        TextField("OpenAI API Key", text: Binding(
                            get: { store.openAIAPIKey },
                            set: { store.openAIAPIKey = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    } else {
                        SecureField("OpenAI API Key", text: Binding(
                            get: { store.openAIAPIKey },
                            set: { store.openAIAPIKey = $0 }
                        ))
                    }
                    Button {
                        showOpenAIKey.toggle()
                    } label: {
                        Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } header: {
                Text("Credentials")
            } footer: {
                Text("Stored in iOS Keychain. Never leaves your device except to call OpenAI directly.")
            }
        case .ollama:
            EmptyView()
        }
    }

    // MARK: - Test

    private var testSection: some View {
        Section {
            Button {
                Task { await runTest() }
            } label: {
                HStack {
                    Image(systemName: "stethoscope")
                        .symbolEffect(.bounce, value: testResult != nil)
                    Text("Test Connection")
                    if isTesting {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.accent)
                    }
                }
            }
            .disabled(!store.isConfigured || isTesting)

            if let testResult {
                switch testResult {
                case .success(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.positive)
                        .font(Typography.callout)
                        .symbolEffect(.bounce, value: msg)
                        .transition(.blurReplace)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.negative)
                        .font(Typography.callout)
                        .symbolEffect(.bounce, value: msg)
                        .transition(.blurReplace)
                }
            }
        } header: {
            Text("Diagnostics")
        }
        .animation(Theme.Animation.interactive, value: testResult)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            Text("API keys are stored in the iOS Keychain and used only to call the selected AI provider directly. Bullion does not transmit them to any other server.")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            if confirmingClear {
                HStack {
                    Text("Are you sure?")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.negative)
                    Spacer()
                    Button("Clear", role: .destructive) {
                        store.clearKeys()
                        testResult = nil
                        withAnimation(Theme.Animation.snappy) { confirmingClear = false }
                    }
                    .font(Typography.caption)
                    Button("Cancel", role: .cancel) {
                        withAnimation(Theme.Animation.snappy) { confirmingClear = false }
                    }
                    .font(Typography.caption)
                }
                .transition(.blurReplace)
            } else {
                Button("Clear all AI keys", role: .destructive) {
                    withAnimation(Theme.Animation.snappy) { confirmingClear = true }
                }
                .transition(.blurReplace)
            }
        } header: {
            Text("Privacy")
        }
        .animation(Theme.Animation.snappy, value: confirmingClear)
    }

    // MARK: - Test logic

    private func runTest() async {
        guard !isTesting else { return }
        isTesting = true
        defer { isTesting = false }
        do {
            let provider = store.makeProvider()
            let context = MarketContext(
                symbol: "TEST", name: "Test", type: "Stock",
                currentPrice: 100, dayChange: 1, dayChangePercent: 1,
                previousClose: 99, week52Low: 80, week52High: 120,
                volume: 1000000, avgVolume: 900000, marketCap: nil,
                peRatio: nil, eps: nil, dividendYield: nil, beta: nil,
                sector: nil, industry: nil,
                rsi14: 55, sma20: 98, sma50: 96, ema12: 99, ema26: 97,
                macd: 0.5, macdSignal: 0.3, macdHistogram: 0.2,
                bollingerUpper: 105, bollingerMiddle: 100, bollingerLower: 95,
                volumeTrend: "flat", pricePosition: "aboveMiddle",
                recentHeadlines: [], newsSources: [], recentCloses: [98, 99, 100]
            )
            _ = try await provider.analyze(context: context, model: store.selectedModel, apiKey: store.currentAPIKey())
            testResult = .success("Connection successful.")
        } catch let e as AIError {
            testResult = .failure(e.errorDescription ?? "Test failed.")
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }
}