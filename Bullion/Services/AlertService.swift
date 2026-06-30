import Foundation
import UserNotifications
import SwiftData

/// Schedules and checks price alerts. On app foreground (and after a manual
/// quote refresh), `checkAlerts(provider:)` fetches current quotes for every
/// active alert's symbol and fires a local notification for any whose
/// threshold condition is met, marking them triggered so they don't re-fire.
///
/// This is the #1 retention driver for a markets app — the reason users keep
/// it installed. Backend-less by design: no server push tokens, just local
/// notifications checked while the app is in the foreground.
final class AlertService: @unchecked Sendable {
    static let shared = AlertService()

    private let notificationCenter = UNUserNotificationCenter.current()

    /// Request permission to display notifications. Call once on first
    /// alert creation. Returns whether permission was granted.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Whether the user has granted notification permission.
    var authorized: Bool {
        get async {
            await notificationCenter.notificationSettings().authorizationStatus == .authorized
        }
    }

    /// Check every active (non-triggered) alert against current quotes and
    /// fire a local notification for any whose condition is met. Called on
    /// app foreground and after a manual refresh.
    @MainActor
    func checkAlerts(provider: any MarketDataProvider, modelContext: ModelContext) async {
        let alerts: [PriceAlert]
        do {
            alerts = try modelContext.fetch(FetchDescriptor<PriceAlert>(
                predicate: #Predicate { !$0.triggered }
            ))
        } catch {
            return
        }
        guard !alerts.isEmpty else { return }
        let symbols = Array(Set(alerts.map(\.symbol)))
        let quotes: [Quote] = (try? await provider.quotes(symbols)) ?? []
        let quoteBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        for alert in alerts {
            guard let q = quoteBySymbol[alert.symbol], alert.satisfies(q.last) else { continue }
            alert.triggered = true
            await fireNotification(for: alert, price: q.last)
        }
        try? modelContext.save()
    }

    /// Fire a local notification for a triggered alert.
    private func fireNotification(for alert: PriceAlert, price: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.symbol) \(alert.direction.displayName) \(NumberFormatting.price(alert.threshold))"
        content.body = "\(alert.name) is now \(NumberFormatting.price(price))."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "price-alert-\(alert.symbol)-\(alert.createdAt.timeIntervalSince1970)",
            content: content,
            trigger: nil   // fire immediately
        )
        try? await notificationCenter.add(request)
    }
}