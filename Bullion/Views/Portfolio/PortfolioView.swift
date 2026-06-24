import SwiftUI

/// Portfolio tab root — a thin router between the connect-onboarding screen
/// (unlinked) and the holdings dashboard (linked). Owns the single shared
/// PortfolioViewModel so state isn't duplicated across sub-screens.
struct PortfolioView: View {
    @Environment(\.appEnv) private var env
    @State private var vm: PortfolioViewModel?

    var body: some View {
        Group {
            if let vm {
                if vm.isLinked {
                    PortfolioDashboardView(vm: vm)
                } else {
                    ConnectBrokerageView(vm: vm)
                }
            } else {
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    GlowLoadingView()
                }
                .onAppear {
                    vm = PortfolioViewModel(service: env.portfolioService)
                    Task { await vm?.load() }
                }
            }
        }
    }
}