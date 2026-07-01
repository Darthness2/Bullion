import SwiftUI

/// Settings screen for the Plaid integration. The user configures the
/// backend server URL (where the thin token-exchange endpoint lives).
/// Plaid client_id and secret stay on the server — they never touch the
/// device.
struct PlaidSettingsView: View {
    @State private var backendURL: String = PlaidKeyStore.backendURL
    @State private var testResult: TestResult?
    @State private var testing = false
    @State private var confirmingClear = false
    @State private var urlEdited = false

    enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    private var isConfigured: Bool {
        !backendURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            configurationSection
            statusSection
            testSection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("Brokerage")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if urlEdited {
                PlaidKeyStore.backendURL = backendURL.trimmingCharacters(in: .whitespaces)
            }
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        Section {
            TextField("Backend server URL", text: $backendURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onChange(of: backendURL) { _, _ in
                    urlEdited = true
                    testResult = nil
                }
        } header: {
            Text("Plaid Backend")
        } footer: {
            Text("The URL of the thin server that handles Plaid's token exchange. Plaid's client ID and secret are stored on that server — they never touch your device. For local development, use http://127.0.0.1:8787.")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Backend URL")
                Spacer()
                Text(backendURL.isEmpty ? "Not set" : "Configured")
                    .foregroundColor(backendURL.isEmpty
                                     ? Theme.Colors.textSecondary : Theme.Colors.positive)
            }
            HStack {
                Text("Brokerage linked")
                Spacer()
                Text(PlaidKeyStore.isLinked ? "Yes" : "No")
                    .foregroundColor(PlaidKeyStore.isLinked
                                     ? Theme.Colors.positive : Theme.Colors.textSecondary)
            }
            if let name = PlaidKeyStore.institutionName {
                HStack {
                    Text("Institution")
                    Spacer()
                    Text(name)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
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
            Text("Pings the backend server's health endpoint to verify it's running.")
        }
        .animation(Theme.Animation.interactive, value: testResult)
    }

    // MARK: - Privacy / clear

    private var privacySection: some View {
        Section {
            Text("Plaid handles the secure connection to your broker. Your brokerage credentials are entered directly with Plaid and your broker — Bullion never sees them. The Plaid access token is stored in your device's iOS Keychain and used to fetch read-only holdings, balances, and transactions.")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            if confirmingClear {
                HStack {
                    Text("Are you sure?")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.negative)
                    Spacer()
                    Button("Clear", role: .destructive) {
                        PlaidKeyStore.clearLink()
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
                Button("Disconnect brokerage", role: .destructive) {
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
        guard let url = URL(string: backendURL.trimmingCharacters(in: .whitespaces)) else {
            testResult = .failure("Invalid URL.")
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url.appendingPathComponent("health"))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                testResult = .failure("Backend not responding.")
                return
            }
            struct HealthResponse: Decodable { let status: String? }
            let health = try? JSONDecoder().decode(HealthResponse.self, from: data)
            testResult = .success("Backend running (\(health?.status ?? "ok")).")
        } catch {
            testResult = .failure("Can't reach backend: \(error.localizedDescription)")
        }
    }
}