import SwiftUI

struct HelpView: View {
    var body: some View {
        LegalPage(title: "Help & FAQ", sections: [
            LegalSection(
                heading: "What is Bullion?",
                text: "Bullion is a minimalist investing companion for tracking stocks, ETFs, and futures. You can browse markets, build a watchlist, link your brokerage to view holdings, and get AI-generated research summaries."
            ),
            LegalSection(
                heading: "How do I add an instrument to my watchlist?",
                text: "Open any instrument (tap it in Markets or Search) and tap the star icon in the top-right corner. Tap again to remove. Your watchlist has its own tab at the bottom."
            ),
            LegalSection(
                heading: "How do I connect my brokerage?",
                text: "Go to the Portfolio tab and tap Connect Account. You'll be taken to Plaid's secure link flow to choose your broker (Fidelity, Schwab, Robinhood, and more) and authenticate. Bullion never sees your credentials — only Plaid and your broker do."
            ),
            LegalSection(
                heading: "Why do I need to set a backend URL?",
                text: "Bullion uses a thin backend server only for Plaid's token exchange (swapping a public token for an access token). Plaid's client ID and secret stay on that server — they never touch your device. Once connected, all data calls go directly from your device to Plaid. Set the backend URL in Settings → Brokerage."
            ),
            LegalSection(
                heading: "Why is some data delayed?",
                text: "Free market-data feeds (such as Yahoo Finance) typically provide 15-minute delayed quotes for US equities and may not include real-time futures data. Real-time data requires a paid provider configured by the developer."
            ),
            LegalSection(
                heading: "How does AI research work?",
                text: "If you enable AI research in Settings → Advanced, Bullion sends public market context about the instrument you're viewing to your chosen AI provider (Anthropic, OpenAI, or a local Ollama instance). Your API key stays in the iOS Keychain and goes only to that provider. The analysis is informational, not advice."
            ),
            LegalSection(
                heading: "Is my data private?",
                text: "Yes — see the Privacy Policy. Bullion stores your watchlist and preferences locally, never uploads them, and your brokerage credentials are handled exclusively by Plaid."
            ),
            LegalSection(
                heading: "Need more help?",
                text: "Report issues or request features through the App Store listing for Bullion."
            ),
        ])
    }
}