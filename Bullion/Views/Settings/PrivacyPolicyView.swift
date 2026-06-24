import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        LegalPage(title: "Privacy Policy", sections: [
            LegalSection(
                heading: "Overview",
                text: "Bullion is a read-only investing companion. We are committed to minimizing data collection and keeping your information under your control."
            ),
            LegalSection(
                heading: "Market data",
                text: "Market quotes, charts, and key statistics are fetched on demand from public market-data providers (such as Yahoo Finance). Your search queries and the symbols you view are not transmitted to Bullion servers; they go directly to the market-data provider."
            ),
            LegalSection(
                heading: "Brokerage linking (SnapTrade)",
                text: "When you link a brokerage account, Bullion connects you to SnapTrade, which handles the secure OAuth flow in the system browser. Your brokerage credentials are entered directly with SnapTrade and your broker — Bullion never sees or stores them. SnapTrade returns a user secret to our backend proxy, which is kept server-side and used only to fetch read-only holdings, balances, and transactions for display in the app."
            ),
            LegalSection(
                heading: "AI research",
                text: "If you choose to enable AI research, the API key you enter is stored in your device's iOS Keychain and is sent only to the AI provider you select (Anthropic, OpenAI, or a local Ollama instance). Bullion does not relay it through any other server. The data sent for analysis consists of public market context about the instrument you are viewing."
            ),
            LegalSection(
                heading: "Watchlist & preferences",
                text: "Your watchlist, appearance, and refresh preferences are stored locally on your device via SwiftData and UserDefaults. They are not uploaded to Bullion servers."
            ),
            LegalSection(
                heading: "Data retention",
                text: "We do not maintain user accounts or profiles on Bullion servers. The only server-side state is the SnapTrade user secret held by our backend proxy for the purpose of fetching your linked account data, which you can revoke at any time by disconnecting in the app."
            ),
            LegalSection(
                heading: "Contact",
                text: "For privacy questions or requests, contact the developer through the App Store listing."
            ),
        ])
    }
}