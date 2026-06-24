import SwiftUI
import SwiftData

@main
struct BullionApp: App {
    @State private var env = AppEnvironment()
    @State private var appNav = AppNav()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                RootView()
                    .environment(\.appEnv, env)
                    .environment(env.aiSettings)
                    .environment(appNav)
                    .preferredColorScheme(preferredScheme)
            } else {
                OnboardingView()
                    .environment(\.appEnv, env)
                    .environment(env.aiSettings)
                    .environment(appNav)
                    .preferredColorScheme(preferredScheme)
            }
        }
        .modelContainer(for: WatchlistItem.self)
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