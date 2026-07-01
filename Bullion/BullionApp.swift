import SwiftUI
import SwiftData

@main
struct BullionApp: App {
    @State private var env = AppEnvironment()
    @State private var appNav = AppNav()
    @State private var connectivity = ConnectivityMonitor.shared
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                RootView()
                    .environment(\.appEnv, env)
                    .environment(env.aiSettings)
                    .environment(appNav)
                    .environment(connectivity)
                    .preferredColorScheme(preferredScheme)
                    .onOpenURL { url in
                        // Defense-in-depth: ASWebAuthenticationSession consumes
                        // the Plaid callback internally, but if the user
                        // taps a bullion:// link from outside the app (email,
                        // notes), we still handle it gracefully.
                        handleDeepLink(url)
                    }
            } else {
                OnboardingView()
                    .environment(\.appEnv, env)
                    .environment(env.aiSettings)
                    .environment(appNav)
                    .environment(connectivity)
                    .preferredColorScheme(preferredScheme)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            }
        }
        .modelContainer(for: [WatchlistItem.self, PriceAlert.self])
    }

    /// Best-effort deep-link handler for the `bullion://plaid-callback`
    /// scheme. The primary flow uses ASWebAuthenticationSession which
    /// consumes the callback directly; this handles the external-tap path.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == Secrets.plaidCallbackScheme else { return }
        // The Plaid callback is consumed by the ASWebAuthenticationSession
        // wrapper; no further action needed here.
    }

    private var preferredScheme: ColorScheme? {
        let raw = UserDefaults.standard.string(forKey: "appearance") ?? "System"
        switch raw {
        case "Light": return .light
        case "Dark":  return .dark
        default:      return nil
        }
    }
}