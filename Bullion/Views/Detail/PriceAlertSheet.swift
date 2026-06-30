import SwiftUI
import SwiftData

/// Sheet for creating a price alert on an instrument. Lets the user pick a
/// direction (above/below) and a threshold, then persists a `PriceAlert`
/// and requests notification permission on first use.
struct PriceAlertSheet: View {
    let instrument: Instrument
    let currentPrice: Double?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var direction: AlertDirection = .above
    @State private var thresholdText: String = ""
    @State private var permissionRequested = false

    private var threshold: Double? {
        Double(thresholdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isValid: Bool { threshold != nil && threshold! > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Symbol", value: instrument.symbol)
                    if let p = currentPrice {
                        LabeledContent("Current price", value: NumberFormatting.price(p))
                    }
                } header: { Text("Instrument") }

                Section {
                    Picker("Alert me when", selection: $direction) {
                        ForEach(AlertDirection.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Threshold price", text: $thresholdText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Condition")
                } footer: {
                    if let p = currentPrice {
                        Text("Currently \(NumberFormatting.price(p)). You'll get a notification the next time the app is open and the price crosses your threshold.")
                    } else {
                        Text("You'll get a notification the next time the app is open and the price crosses your threshold.")
                    }
                }
            }
            .navigationTitle("Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(!isValid)
                    .bold()
                }
            }
            .onAppear {
                if thresholdText.isEmpty, let p = currentPrice {
                    // Seed the threshold with the current price rounded up/down
                    // so the user has a sensible starting point.
                    thresholdText = String(format: "%.2f", p)
                }
            }
        }
    }

    @MainActor
    private func create() async {
        guard let threshold else { return }
        if !permissionRequested {
            await AlertService.shared.requestPermission()
            permissionRequested = true
        }
        let alert = PriceAlert(
            symbol: instrument.symbol, name: instrument.name,
            direction: direction, threshold: threshold
        )
        modelContext.insert(alert)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}