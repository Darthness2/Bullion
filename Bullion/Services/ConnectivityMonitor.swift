import Foundation
import Network
import SwiftUI

/// Monitors network reachability via `NWPathMonitor` and publishes the
/// current status as an `@Observable`. An offline banner can subscribe to
/// `isOnline` and surface "You're offline — showing last-known data."
@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private(set) var isOnline: Bool = true
    private(set) var isWifiOrCellular: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.bullion.connectivity")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let goodInterface = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular)
            Task { @MainActor [weak self] in
                self?.isOnline = online
                self?.isWifiOrCellular = online && goodInterface
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}