import Foundation

@Observable
final class SettingsViewModel {
    enum Appearance: String, CaseIterable, Identifiable, SegmentedPillOption {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
        var pillTitle: String { rawValue }
    }

    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case off = 0
        case tenSec = 10
        case fifteenSec = 15
        case thirtySec = 30
        case oneMin = 60
        var id: Int { rawValue }
        var displayName: String {
            rawValue == 0 ? "Off" : "\(rawValue)s"
        }
    }

    var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "System") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appearance") }
    }

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: UserDefaults.standard.integer(forKey: "refreshInterval")) ?? .fifteenSec }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "refreshInterval") }
    }

    let providerName: String
    let futuresAreRealTime: Bool

    init(provider: any MarketDataProvider) {
        providerName = provider.displayName
        futuresAreRealTime = provider.futuresAreRealTime
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}