import SwiftUI

/// Small backend-reachability indicator. Pings GET /health on appear and
/// re-checks on tap. Green dot + "Backend online" / red dot + actionable hint.
struct BackendHealthView: View {
    @Environment(\.appEnv) private var env
    @State private var status: Status = .checking

    private enum Status { case checking, online, offline }

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
        .task { await check() }
    }

    private var color: Color {
        switch status {
        case .checking: return Theme.Colors.textSecondary
        case .online:   return Theme.Colors.positive
        case .offline:  return Theme.Colors.negative
        }
    }

    private var label: String {
        switch status {
        case .checking: return "Checking backend…"
        case .online:   return "Backend online"
        case .offline:  return "Backend unreachable — tap to retry"
        }
    }

    @MainActor
    private func check() async {
        status = .checking
        let ok: Bool = await withCheckedContinuation { cont in
            Task {
                let result = await (env.portfolioService as? BackendPortfolioService)?.checkBackendHealth() ?? false
                cont.resume(returning: result)
            }
        }
        withAnimation(Theme.Animation.interactive) {
            status = ok ? .online : .offline
        }
    }
}