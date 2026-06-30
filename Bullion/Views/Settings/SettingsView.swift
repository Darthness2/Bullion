import SwiftUI

struct SettingsView: View {
    @Environment(\.appEnv) private var env
    @State private var vm: SettingsViewModel?
    @Namespace private var pickerNamespace

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Settings")
        }
    }

    @ViewBuilder private var content: some View {
        if let vm {
            Form {
                appearanceSection(vm: vm)
                dataSection(vm: vm)
                aboutSection(vm: vm)
                advancedSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
        } else {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                GlowLoadingView()
            }
            .onAppear {
                vm = SettingsViewModel(provider: env.marketProvider)
            }
        }
    }

    private func appearanceSection(vm: SettingsViewModel) -> some View {
        Section("Appearance") {
            SegmentedPill(
                options: SettingsViewModel.Appearance.allCases,
                selection: Binding(
                    get: { vm.appearance },
                    set: { vm.appearance = $0 }
                ),
                namespace: pickerNamespace
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
    }

    private func dataSection(vm: SettingsViewModel) -> some View {
        Section("Data Source") {
            HStack {
                Text("Provider")
                Spacer()
                Text(vm.providerName)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            HStack {
                Text("Futures data")
                Spacer()
                if vm.futuresAreRealTime {
                    Label("Real-time", systemImage: "bolt.fill")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.positive)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                } else {
                    Label("Delayed", systemImage: "clock")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func aboutSection(vm: SettingsViewModel) -> some View {
        Section("About") {
            HStack(spacing: Theme.Metrics.spacing) {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bullion")
                        .font(Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Version \(vm.appVersion)")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .listRowBackground(Color.clear)
            Text("Bullion is for informational purposes only and is not investment advice. Data may be delayed.")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            NavigationLink {
                TermsView()
            } label: {
                Label("Terms of Use", systemImage: "doc.text")
            }
            NavigationLink {
                HelpView()
            } label: {
                Label("Help & FAQ", systemImage: "questionmark.circle")
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            NavigationLink {
                AlertsView()
            } label: {
                Label("Price Alerts", systemImage: "bell.badge")
            }
            NavigationLink {
                SnapTradeSettingsView()
            } label: {
                Label("Brokerage (SnapTrade)", systemImage: "building.columns")
            }
            NavigationLink {
                AISettingsView()
            } label: {
                Label("AI Research Provider", systemImage: "brain.head.profile")
            }
        }
    }
}