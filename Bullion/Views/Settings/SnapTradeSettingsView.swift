import SwiftUI

/// Settings screen for the backend-less SnapTrade integration. The user pastes
/// their SnapTrade `clientId` and `consumerKey` (from the SnapTrade dashboard);
/// they're stored in the Keychain via `SnapTradeKeyStore` and used to sign
/// requests on-device. Mirrors `AISettingsView`.
struct SnapTradeSettingsView: View {
    @Environment(\.appEnv) private var env

    @State private var clientId: String = SnapTradeKeyStore.clientId ?? ""
    @State private var consumerKey: String = SnapTradeKeyStore.consumerKey ?? ""
    @State private var showConsumerKey = false
    @State private var testResult: TestResult?
    @State private var testing = false
    @State private var confirmingClear = false
    @State private var clientIdSaveTask: Task<Void, Never>?
    @State private var consumerKeySaveTask: Task<Void, Never>?

    enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    private var isConfigured: Bool {
        !clientId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !consumerKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            credentialsSection
            testSection
            statusSection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("Brokerage")
        .navigationBarTitleDisplayMode(.inline)
        // Persist any pending debounced write when leaving the screen.
        .onDisappear {
            clientIdSaveTask?.cancel()
            consumerKeySaveTask?.cancel()
            SnapTradeKeyStore.clientId = clientId.trimmingCharacters(in: .whitespaces)
            SnapTradeKeyStore.consumerKey = consumerKey.trimmingCharacters(in: .whitespaces)
        }
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        Section {
            TextField("Client ID", text: $clientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: clientId) { _, v in
                    testResult = nil
                    scheduleClientIdSave(v.trimmingCharacters(in: .whitespaces))
                }
            HStack {
                if showConsumerKey {
                    TextField("Consumer Key", text: $consumerKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Consumer Key", text: $consumerKey)
                }
                Button {
                    showConsumerKey.toggle()
                } label: {
                    Image(systemName: showConsumerKey ? "eye.slash" : "eye")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .onChange(of: consumerKey) { _, v in
                testResult = nil
                scheduleConsumerKeySave(v.trimmingCharacters(in: .whitespaces))
            }
        } header: {
            Text("SnapTrade Credentials")
        } footer: {
            Text("Get these from dashboard.snaptrade.com. Stored in the iOS Keychain and used only to call SnapTrade directly — no proxy server.")
        }
    }

    /// Debounce Keychain writes so we don't hit the keychain (ms-scale, can
    /// prompt for device passcode, burns battery) on every keystroke of a
    /// 32+ character key. Writes ~0.5s after the last edit, or immediately on
    /// `onDisappear` (above) if the user leaves mid-typing.
    private func scheduleClientIdSave(_ value: String) {
        clientIdSaveTask?.cancel()
        clientIdSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            SnapTradeKeyStore.clientId = value
        }
    }

    private func scheduleConsumerKeySave(_ value: String) {
        consumerKeySaveTask?.cancel()
        consumerKeySaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            SnapTradeKeyStore.consumerKey = value
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
                    Text(testing ? "Testing…" : "Test Connection")
                }
            }
            .disabled(!isConfigured || testing)

            if let testResult {
                switch testResult {
                case .success(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.positive)
                        .font(Typography.callout)
                        .transition(.blurReplace)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.negative)
                        .font(Typography.callout)
                        .transition(.blurReplace)
                }
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Validates your client ID and consumer key against SnapTrade without registering or connecting an account.")
        }
        .animation(Theme.Animation.interactive, value: testResult)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Partner credentials")
                Spacer()
                Text(SnapTradeKeyStore.hasPartnerCredentials ? "Configured" : "Not set")
                    .foregroundColor(SnapTradeKeyStore.hasPartnerCredentials
                                     ? Theme.Colors.positive : Theme.Colors.textSecondary)
            }
            HStack {
                Text("Registered user")
                Spacer()
                Text(SnapTradeKeyStore.isRegistered ? "Yes" : "No")
                    .foregroundColor(SnapTradeKeyStore.isRegistered
                                     ? Theme.Colors.positive : Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Privacy / clear

    private var privacySection: some View {
        Section {
            Text("Your consumer key and user secret are stored in the iOS Keychain. Going backend-less means the consumer key lives on this device — appropriate for personal use, not multi-user distribution.")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            if confirmingClear {
                HStack {
                    Text("Are you sure?")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.negative)
                    Spacer()
                    Button("Clear", role: .destructive) {
                        SnapTradeKeyStore.clearAll()
                        clientId = ""
                        consumerKey = ""
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
                Button("Clear SnapTrade keys", role: .destructive) {
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

    @MainActor
    private func runTest() async {
        testing = true
        defer { testing = false }
        guard let service = env.portfolioService as? DirectSnapTradeService else {
            testResult = .failure("Direct SnapTrade service unavailable.")
            return
        }
        do {
            try await service.validatePartnerCredentials()
            testResult = .success("Credentials valid.")
        } catch let PortfolioError.httpError(code, _) {
            testResult = .failure(code == 401
                ? "Rejected (401) — check your client ID and consumer key."
                : "SnapTrade error (HTTP \(code)).")
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }
}
