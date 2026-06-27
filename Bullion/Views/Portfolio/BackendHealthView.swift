import SwiftUI

/// SnapTrade readiness indicator for the backend-less integration. Shows
/// whether partner credentials (clientId + consumerKey) are configured, and
/// optionally validates them against SnapTrade on tap. Green = ready,
/// amber = keys missing, red = keys rejected.
struct BackendHealthView: View {
    @Environment(\.appEnv) private var env
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
        case .unknown:  return "SnapTrade keys"
        case .checking: return "Checking SnapTrade keys…"
        case .ready:    return "SnapTrade keys configured"
        case .missing:  return "Add SnapTrade keys in Settings → Brokerage"
        case .invalid:  return "SnapTrade keys rejected — tap to recheck"
        }
    }

    private func refreshLocal() {
        status = SnapTradeKeyStore.hasPartnerCredentials ? .ready : .missing
    }

    @MainActor
    private func check() async {
        guard SnapTradeKeyStore.hasPartnerCredentials else { status = .missing; return }
        status = .checking
        do {
            try await (env.portfolioService as? DirectSnapTradeService)?.validatePartnerCredentials()
            withAnimation(Theme.Animation.interactive) { status = .ready }
        } catch {
            withAnimation(Theme.Animation.interactive) { status = .invalid }
        }
    }
}
