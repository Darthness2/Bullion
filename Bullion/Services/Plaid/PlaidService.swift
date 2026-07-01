import Foundation
import AuthenticationServices

/// Plaid-based `PortfolioService`. The app uses a thin backend server for:
/// 1. Token exchange (public_token → access_token) — keeps Plaid secret server-side
/// 2. Data call proxy (holdings, transactions, balances) — the device talks to the
///    backend which forwards to Plaid. This means the server can return mock data
///    in demo mode (before Plaid credentials are configured).
///
/// Flow:
/// 1. Device → backend: POST /api/link_token → gets `link_token`
/// 2. Device opens Plaid Link via ASWebAuthenticationSession
/// 3. User authenticates at their broker (Fidelity, Schwab, etc.)
/// 4. Plaid returns `public_token` via the callback
/// 5. Device → backend: POST /api/exchange_token → gets `access_token`
/// 6. Device stores `access_token` in Keychain
/// 7. Device → backend: POST /api/plaid/<endpoint> (holdings/transactions/balances)
final class PlaidService: PortfolioService, @unchecked Sendable {

    private let session: URLSession
    private let decoder: JSONDecoder
    private let isoFormatter = ISO8601DateFormatter()

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Backend helpers

    private var backendBaseURL: String {
        PlaidKeyStore.backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func backendURL(_ path: String) throws -> URL {
        guard let base = URL(string: backendBaseURL) else {
            throw PortfolioError.notConfigured("Plaid backend URL is invalid. Set it in Settings → Brokerage.")
        }
        return base.appendingPathComponent(path)
    }

    private func postBackend(_ path: String, body: [String: Any]) async throws -> Data {
        let url = try backendURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw PortfolioError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PortfolioError.httpError(http.statusCode, body)
        }
        return data
    }

    // MARK: - PortfolioService

    var isLinked: Bool {
        get async {
            guard PlaidKeyStore.isLinked else { return false }
            do {
                let data = try await postBackend("/api/plaid/accounts/balance/get",
                                                  body: ["access_token": PlaidKeyStore.accessToken ?? ""])
                let balances = try decoder.decode(PlaidBalancesResponse.self, from: data)
                return !balances.accounts.isEmpty
            } catch {
                if isPlaidAuthFailure(error) {
                    PlaidKeyStore.clearLink()
                }
                return false
            }
        }
    }

    func accounts() async throws -> [BrokerageAccount] {
        guard PlaidKeyStore.isLinked else { return [] }
        do {
            let data = try await postBackend("/api/plaid/accounts/balance/get",
                                             body: ["access_token": PlaidKeyStore.accessToken ?? ""])
            let balances = try decoder.decode(PlaidBalancesResponse.self, from: data)
            return balances.accounts.map { acc in
                BrokerageAccount(
                    id: acc.accountId,
                    name: acc.name ?? acc.officialName ?? "Account",
                    brokerage: balances.item?.institutionName ?? "Brokerage",
                    totalValue: (acc.balances?.current ?? 0) + (acc.balances?.investment ?? 0),
                    currency: acc.balances?.isoCurrencyCode ?? "USD",
                    lastSynced: Date(),
                    connectionStatus: .active
                )
            }
        } catch {
            if isPlaidAuthFailure(error) {
                PlaidKeyStore.clearLink()
                return []
            }
            throw error
        }
    }

    func holdings(accountId: String) async throws -> [Holding] {
        let data = try await postBackend("/api/plaid/investments/holdings/get",
                                        body: ["access_token": PlaidKeyStore.accessToken ?? ""])
        let resp = try decoder.decode(PlaidHoldingsResponse.self, from: data)
        return resp.holdings
            .filter { $0.accountId == accountId }
            .map { h in
                let qty = h.quantity ?? 0
                let price = h.institutionPrice ?? h.latestPrice ?? 0
                return Holding(
                    symbol: h.tickerSymbol ?? "—",
                    name: h.name ?? h.tickerSymbol ?? "—",
                    quantity: qty,
                    avgCost: h.costBasis,
                    marketValue: qty * price,
                    dayChange: nil,
                    dayChangePercent: nil,
                    allocation: nil
                )
            }
    }

    func transactions(accountId: String) async throws -> [Transaction] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let body: [String: Any] = [
            "access_token": PlaidKeyStore.accessToken ?? "",
            "start_date": isoDateString(start),
            "end_date": isoDateString(now)
        ]
        let data = try await postBackend("/api/plaid/investments/transactions/get", body: body)
        let resp = try decoder.decode(PlaidTransactionsResponse.self, from: data)
        return resp.transactions
            .filter { $0.accountId == accountId }
            .map { t in
                Transaction(
                    id: t.transactionId,
                    symbol: t.tickerSymbol ?? "",
                    type: t.type ?? "transaction",
                    quantity: t.quantity,
                    price: t.price,
                    amount: t.amount,
                    date: t.date.flatMap { parseDate($0) },
                    description: t.name ?? t.type ?? "Transaction"
                )
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    func connectionPortalURL() async throws -> URL {
        let redirectURI = "\(Secrets.plaidCallbackScheme)://plaid-callback"
        let data = try await postBackend("/api/link_token", body: ["redirect_uri": redirectURI])

        struct LinkTokenResponse: Decodable {
            let linkToken: String?
            enum CodingKeys: String, CodingKey {
                case linkToken = "link_token"
            }
        }
        let resp = try decoder.decode(LinkTokenResponse.self, from: data)
        guard let linkToken = resp.linkToken else {
            throw PortfolioError.notConfigured("Plaid did not return a link token.")
        }

        // Build the Plaid Link URL — the device opens this in ASWebAuthenticationSession
        let url = URL(string: "https://cdn.plaid.com/link/v2/stable/link.html?token=\(linkToken)&redirectUri=\(redirectURI)")!
        return url
    }

    func openConnectionPortal(url: URL) async throws {
        let session = await PlaidWebAuthSession(url: url, scheme: Secrets.plaidCallbackScheme)
        try await session.start()
    }

    func disconnect(accountId: String) async throws {
        _ = try? await postBackend("/api/plaid/item/remove",
                                   body: ["access_token": PlaidKeyStore.accessToken ?? ""])
        PlaidKeyStore.clearLink()
    }

    func refresh(accountId: String) async throws {
        // Plaid syncs automatically; no manual refresh needed
    }

    /// Exchange the public_token (from Plaid Link) for an access_token via
    /// the backend server. Stores the access_token in the Keychain.
    func exchangePublicToken(_ publicToken: String) async throws {
        let data = try await postBackend("/api/exchange_token", body: ["public_token": publicToken])

        struct ExchangeResponse: Decodable {
            let accessToken: String?
            let itemId: String?
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case itemId = "item_id"
            }
        }
        let resp = try decoder.decode(ExchangeResponse.self, from: data)
        guard let token = resp.accessToken, !token.isEmpty else {
            throw PortfolioError.notConfigured("Plaid did not return an access token.")
        }
        PlaidKeyStore.accessToken = token
        PlaidKeyStore.itemId = resp.itemId
    }

    // MARK: - Private helpers

    private func parseDate(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        return isoFormatter.date(from: s)
            ?? ISO8601DateFormatter().date(from: s)
    }

    private func isoDateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: d)
    }

    private func isPlaidAuthFailure(_ error: Error) -> Bool {
        guard let e = error as? PortfolioError,
              case PortfolioError.httpError(let code, _) = e else { return false }
        return code == 401 || code == 403
    }
}

// MARK: - Plaid response models

private struct PlaidBalancesResponse: Decodable {
    struct Account: Decodable {
        let accountId: String
        let name: String?
        let officialName: String?
        let balances: Balances?
        enum CodingKeys: String, CodingKey {
            case accountId = "account_id"
            case name
            case officialName = "official_name"
            case balances
        }
        struct Balances: Decodable {
            let current: Double?
            let available: Double?
            let investment: Double?
            let isoCurrencyCode: String?
            enum CodingKeys: String, CodingKey {
                case current
                case available
                case investment
                case isoCurrencyCode = "iso_currency_code"
            }
        }
    }
    struct Item: Decodable {
        let itemId: String?
        let institutionName: String?
        enum CodingKeys: String, CodingKey {
            case itemId = "item_id"
            case institutionName = "institution_name"
        }
    }
    let accounts: [Account]
    let item: Item?
}

private struct PlaidHoldingsResponse: Decodable {
    struct Holding: Decodable {
        let accountId: String?
        let securityId: String?
        let quantity: Double?
        let costBasis: Double?
        let institutionPrice: Double?
        let latestPrice: Double?
        let tickerSymbol: String?
        let name: String?
        enum CodingKeys: String, CodingKey {
            case accountId = "account_id"
            case securityId = "security_id"
            case quantity
            case costBasis = "cost_basis"
            case institutionPrice = "institution_price"
            case latestPrice = "latest_price"
            case tickerSymbol = "ticker_symbol"
            case name
        }
    }
    let holdings: [Holding]
}

private struct PlaidTransactionsResponse: Decodable {
    struct InvestmentTransaction: Decodable {
        let transactionId: String
        let accountId: String
        let amount: Double?
        let quantity: Double?
        let price: Double?
        let type: String?
        let name: String?
        let date: String?
        let tickerSymbol: String?
        enum CodingKeys: String, CodingKey {
            case transactionId = "investment_transaction_id"
            case accountId = "account_id"
            case amount
            case quantity
            case price
            case type
            case name
            case date
            case tickerSymbol = "ticker_symbol"
        }
    }
    let transactions: [InvestmentTransaction]
}

// MARK: - ASWebAuthenticationSession wrapper

private final class PlaidWebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let url: URL
    private let scheme: String
    private var authSession: ASWebAuthenticationSession?

    init(url: URL, scheme: String) {
        self.url = url
        self.scheme = scheme
    }

    @MainActor
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] _, error in
                self?.authSession = nil
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: PortfolioError.authenticationCancelled)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}