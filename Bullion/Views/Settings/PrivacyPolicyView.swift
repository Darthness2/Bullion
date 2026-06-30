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
                text: "When you link a brokerage account, Bullion connects you to SnapTrade, which handles the secure OAuth flow in the system browser. Your brokerage credentials are entered directly with SnapTrade and your broker — Bullion never sees or stores them. Bullion talks to SnapTrade directly from your device (no Bullion server); the SnapTrade user secret is stored in your device's iOS Keychain and used only to fetch read-only holdings, balances, and transactions for display in the app."
            ),
            LegalSection(
                heading: "AI research",
                text: "If you choose to enable AI research, the API key you enter is stored in your device's iOS Keychain and is sent only to the AI provider you select (Anthropic, OpenAI, or a local Ollama instance). Bullion does not relay it through any other server. The data sent for analysis consists of public market context about the instrument you are viewing, including computed technical indicators and recent news headlines. Anthropic and OpenAI may retain this data per their own retention policies; Ollama processes it on a model running on your device or a host you control."
            ),
            LegalSection(
                heading: "Watchlist & preferences",
                text: "Your watchlist, appearance, and refresh preferences are stored locally on your device via SwiftData and UserDefaults. They are not uploaded to Bullion servers."
            ),
            LegalSection(
                heading: "Data retention",
                text: "We do not maintain user accounts or profiles on Bullion servers — Bullion has no backend. Your SnapTrade credentials and user secret are stored only in your device's iOS Keychain, and you can revoke access at any time by disconnecting in the app or clearing the keys in Settings. AI API keys are likewise stored only in the Keychain and deleted when you clear them."
            ),
            LegalSection(
                heading: "Children's privacy",
                text: "Bullion is not directed at children under 13 (or the equivalent minimum age in the relevant jurisdiction), and we do not knowingly collect personal information from them. The app is a financial reference tool intended for a general audience."
            ),
            LegalSection(
                heading: "Your choices",
                text: "You can disconnect your brokerage at any time from Settings or the account detail screen, which removes the SnapTrade user secret from the Keychain. You can clear all AI keys from Settings → AI Research. Deleting the app removes all locally stored data (watchlist, preferences, Keychain items for this app)."
            ),
            LegalSection(
                heading: "Contact",
                text: "For privacy questions or data requests, contact the developer at support@bullion.app or through the App Store listing."
            ),
        ])
    }
}