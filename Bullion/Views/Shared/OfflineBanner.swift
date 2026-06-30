import SwiftUI

/// Thin offline banner shown when `ConnectivityMonitor` reports no network.
/// Non-blocking: the user can still read cached data; this just makes the
/// staleness honest.
struct OfflineBanner: View {
    @Environment(ConnectivityMonitor.self) private var connectivity

    var body: some View {
        if !connectivity.isOnline {
            HStack(spacing: Theme.Metrics.spacingS) {
                Image(systemName: "wifi.slash")
                    .font(Typography.caption)
                Text("Offline — showing last-known data")
                    .font(Typography.caption)
                Spacer(minLength: 0)
            }
            .foregroundColor(Theme.Colors.textOnPrimary)
            .padding(.horizontal, Theme.Metrics.spacing)
            .padding(.vertical, Theme.Metrics.spacingS)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.negative)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Offline. Showing last-known data.")
        }
    }
}