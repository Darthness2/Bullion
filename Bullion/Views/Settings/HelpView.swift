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
                text: "Go to the Portfolio tab and tap Connect Account. You'll be taken to SnapTrade's secure portal in the system browser to choose your broker and authenticate. Bullion never sees your credentials — only SnapTrade and your broker do."
            ),
            LegalSection(
                heading: "Why does it say to add SnapTrade keys?",
                text: "Bullion connects to SnapTrade directly from your device — there's no server. Add your SnapTrade clientId and consumerKey in Settings → Advanced → Brokerage (SnapTrade). They're stored in the iOS Keychain and used only to sign requests to SnapTrade."
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
                text: "Yes — see the Privacy Policy. Bullion stores your watchlist and preferences locally, never uploads them, and your brokerage credentials are handled exclusively by SnapTrade."
            ),
            LegalSection(
                heading: "Need more help?",
                text: "Report issues or request features through the App Store listing for Bullion."
            ),
        ])
    }
}