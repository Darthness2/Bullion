import SwiftUI

/// Plaid backend readiness indicator. Shows whether the backend server URL
/// is configured and pings the health endpoint to verify it's running.
/// Green = ready, amber = not configured, red = unreachable.
struct BackendHealthView: View {
    @State private var status: Status = .unknown

    private enum Status { case unknown, checking, ready, missing, invalid }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: status == .checking)
            Text(label)
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .contentShape(Rectangle())
        .onTapGesture { Task { await check() } }
        .onAppear { refreshLocal() }
    }

    private var color: Color {
        switch status {
        case .unknown, .checking: return Theme.Colors.textSecondary
        case .ready:              return Theme.Colors.positive
        case .missing:            return Theme.Colors.accent
        case .invalid:            return Theme.Colors.negative
        }
    }

    private var label: String {
        switch status {
        case .unknown:  return "Plaid backend"
        case .checking: return "Checking backend…"
        case .ready:    return "Plaid backend connected"
        case .missing:  return "Set backend URL in Settings → Brokerage"
        case .invalid:  return "Backend unreachable — tap to recheck"
        }
    }

    private func refreshLocal() {
        let url = PlaidKeyStore.backendURL.trimmingCharacters(in: .whitespaces)
        status = url.isEmpty ? .missing : .ready
    }

    @MainActor
    private func check() async {
        let urlString = PlaidKeyStore.backendURL.trimmingCharacters(in: .whitespaces)
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            status = .missing
            return
        }
        status = .checking
        do {
            let (_, response) = try await URLSession.shared.data(from: url.appendingPathComponent("health"))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                withAnimation(Theme.Animation.interactive) { status = .invalid }
                return
            }
            withAnimation(Theme.Animation.interactive) { status = .ready }
        } catch {
            withAnimation(Theme.Animation.interactive) { status = .invalid }
        }
    }
}