import SwiftUI
import SwiftData

/// Lists all price alerts (active + triggered), lets the user delete or
/// re-arm them, and shows whether notification permission is granted.
struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appEnv) private var env
    @Query(sort: \PriceAlert.createdAt, order: .reverse) private var alerts: [PriceAlert]
    @State private var authorized: Bool = false

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: authorized ? "bell.fill" : "bell.slash.fill")
                        .foregroundColor(authorized ? Theme.Colors.positive : Theme.Colors.negative)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorized ? "Notifications enabled" : "Notifications disabled")
                            .font(Typography.subheadline)
                        Text(authorized
                             ? "Alerts fire when the app is open and the price crosses your threshold."
                             : "Enable notifications so price alerts can reach you.")
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    if !authorized {
                        Spacer()
                        Button("Enable") {
                            Task {
                                await AlertService.shared.requestPermission()
                                authorized = await AlertService.shared.authorized
                            }
                        }
                        .font(Typography.caption)
                    }
                }
            } header: { Text("Permission") }

            if alerts.isEmpty {
                Section {
                    Text("No alerts yet. Open an instrument and tap the bell to create one.")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            } else {
                Section("Active") {
                    ForEach(alerts.filter { !$0.triggered }) { alert in
                        alertRow(alert)
                    }
                    .onDelete { offsets in
                        delete(alerts.filter { !$0.triggered }, at: offsets)
                    }
                }
                let triggered = alerts.filter { $0.triggered }
                if !triggered.isEmpty {
                    Section("Triggered") {
                        ForEach(triggered) { alert in
                            alertRow(alert)
                        }
                        .onDelete { offsets in
                            delete(triggered, at: offsets)
                        }
                    }
                }
            }
        }
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { authorized = await AlertService.shared.authorized }
    }

    @ViewBuilder
    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(alert.symbol) \(alert.direction.displayName) \(NumberFormatting.price(alert.threshold))")
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(alert.name)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            if alert.triggered {
                Label("Triggered", systemImage: "checkmark.circle.fill")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.positive)
            }
        }
        .swipeActions {
            if alert.triggered {
                Button("Re-arm") {
                    alert.triggered = false
                    try? modelContext.save()
                }
                .tint(Theme.Colors.accent)
            }
            Button(role: .destructive) {
                modelContext.delete(alert)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(_ subset: [PriceAlert], at offsets: IndexSet) {
        for index in offsets {
            guard subset.indices.contains(index) else { continue }
            modelContext.delete(subset[index])
        }
        try? modelContext.save()
    }
}