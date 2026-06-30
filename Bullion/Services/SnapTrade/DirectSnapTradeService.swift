import Foundation
import AuthenticationServices

/// Backend-less `PortfolioService`: the app talks to the SnapTrade REST API
/// directly, signing each request on-device with the partner consumer key
/// (stored in the Keychain via `SnapTradeKeyStore`). No proxy server required.
///
/// Tradeoff: the consumer key ships inside the app. Fine for a personal,
/// single-user build; SnapTrade discourages it for multi-user distribution.
final class DirectSnapTradeService: PortfolioService, @unchecked Sendable {

    private let baseHost = "https://api.snaptrade.com"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let isoFormatter = ISO8601DateFormatter()
    private let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    // MARK: - PortfolioService

    var isLinked: Bool {
        get async {
            guard SnapTradeKeyStore.isRegistered else { return false }
            do { return try await !rawAccounts().isEmpty }
            catch {
                if error.isSnapTradeAuthFailure {
                    SnapTradeKeyStore.clearRegistration()
                }
                return false
            }
        }
    }

    func accounts() async throws -> [BrokerageAccount] {
        guard SnapTradeKeyStore.isRegistered else { return [] }
        do {
            return try await rawAccounts().map { a in
                BrokerageAccount(
                    id: a.id,
                    name: a.name ?? a.institutionName ?? "Account",
                    brokerage: a.institutionName ?? "Brokerage",
                    totalValue: a.balance?.total?.amount ?? 0,
                    currency: a.balance?.total?.currency ?? "USD",
                    lastSynced: parseDate(a.syncStatus?.holdings?.lastSuccessfulSync) ?? Date(),
                    connectionStatus: mapConnectionStatus(a)
                )
            }
        } catch {
            if error.isSnapTradeAuthFailure {
                SnapTradeKeyStore.clearRegistration()
                return []
            }
            throw error
        }
    }

    func holdings(accountId: String) async throws -> [Holding] {
        let response: STPositionsResponse = try await send(
            "GET", "/accounts/\(percentEncodedPathComponent(accountId))/positions/all", authedUser: true
        )
        return response.results.map { p in
            let units = p.units?.value ?? 0
            let price = p.price?.value ?? 0
            let ticker = p.instrument.symbol ?? p.instrument.rawSymbol ?? p.instrument.rootSymbol ?? "—"
            return Holding(
                symbol: ticker,
                name: p.instrument.description ?? ticker,
                quantity: units,
                avgCost: p.costBasis?.value,
                marketValue: units * price,
                dayChange: nil,
                dayChangePercent: nil,
                allocation: nil
            )
        }
    }

    /// Recent account activity: brokerage *transactions* (dividends, interest,
    /// transfers, corporate actions) merged with *orders* (buys/sells).
    ///
    /// Previously this only hit `/orders`, so dividends, splits, and transfers
    /// never appeared — and `amount` was computed as qty*price, so a dividend
    /// (which has no qty/price but a real cash amount) would render as \$0.
    /// Now we hit `/transactions` for the cash-amount-bearing activity and
    /// merge with `/orders` for trade detail, deduping by id. The transactions
    /// endpoint's `cash.amount` is the authoritative cash flow for dividends
    /// and interest; for orders we fall back to qty*price only when cash is
    /// absent.
    func transactions(accountId: String) async throws -> [Transaction] {
        let path = "/accounts/\(percentEncodedPathComponent(accountId))"
        async let txnsResp: STTransactionsResponse? = try? await send(
            "GET", "\(path)/transactions", authedUser: true,
            extraQuery: [("days", "90")]
        )
        async let ordersResp: [STOrder] = try await send(
            "GET", "\(path)/orders", authedUser: true,
            extraQuery: [("state", "all"), ("days", "90")]
        )

        let txns = (try? await txnsResp)?.results ?? []
        let orders = try await ordersResp

        var merged: [String: Transaction] = [:]
        for t in txns {
            let sym = t.universalSymbol ?? t.symbol?.symbol
            let ticker = sym?.symbol ?? sym?.rawSymbol ?? t.currency ?? ""
            let amount = t.cash?.amount ?? t.fee?.amount
            let qty = t.units?.value
            let price = t.price?.value
            // If the transactions endpoint gives no amount (some brokers),
            // derive from qty*price so we don't show a misleading \$0.
            let resolvedAmount = amount ?? ((qty ?? 0) * (price ?? 0))
            let id = t.id ?? UUID().uuidString
            merged[id] = Transaction(
                id: id,
                symbol: ticker,
                type: t.type ?? "transaction",
                quantity: qty,
                price: price,
                amount: resolvedAmount,
                date: parseDate(t.date),
                description: t.description ?? "\(t.type ?? "Transaction") \(ticker)".trimmingCharacters(in: .whitespaces)
            )
        }
        for o in orders {
            let sym = o.universalSymbol ?? o.symbol?.symbol
            let ticker = sym?.symbol ?? sym?.rawSymbol ?? ""
            let qty = o.totalQuantity?.value ?? o.filledQuantity?.value
            let price = o.executionPrice?.value
            let id = o.brokerageOrderId ?? UUID().uuidString
            // Don't overwrite a real transaction (e.g. a dividend) with an
            // order that happens to share an id; orders are supplementary.
            if merged[id] == nil {
                merged[id] = Transaction(
                    id: id,
                    symbol: ticker,
                    type: o.action ?? "order",
                    quantity: qty,
                    price: price,
                    amount: (qty ?? 0) * (price ?? 0),
                    date: parseDate(o.timeExecuted ?? o.timePlaced),
                    description: "\(o.action ?? "Order") \(qty.map { String($0) } ?? "") \(ticker)"
                        .trimmingCharacters(in: .whitespaces)
                )
            }
        }
        // Newest first.
        return merged.values.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    func connectionPortalURL() async throws -> URL {
        try await registerIfNeeded()
        do {
            return try await loginPortalURL()
        } catch {
            // A saved user secret can become invalid after dashboard resets or
            // manual test cleanup. Re-register once and retry the short-lived
            // portal URL before surfacing the error.
            guard error.isSnapTradeAuthFailure else { throw error }
            SnapTradeKeyStore.clearRegistration()
            try await registerIfNeeded()
            return try await loginPortalURL()
        }
    }

    func openConnectionPortal(url: URL) async throws {
        let session = await STWebAuthSession(url: url, scheme: Secrets.snaptradeCallbackScheme)
        try await session.start()
    }

    func disconnect(accountId: String) async throws {
        guard let authId = try await authorizationId(for: accountId) else { return }
        try await sendVoid("DELETE", "/authorizations/\(authId)", authedUser: true)
    }

    func refresh(accountId: String) async throws {
        guard let authId = try await authorizationId(for: accountId) else { return }
        // Manual refresh is a premium SnapTrade feature; tolerate a 402/404.
        do {
            try await sendVoid("POST", "/authorizations/\(authId)/refresh", authedUser: true)
        } catch PortfolioError.httpError(let code, _) where code == 402 || code == 404 {
            return
        }
    }

    // MARK: - Registration

    /// Registers a SnapTrade user if we don't already hold a user secret.
    ///
    /// On HTTP 409 the SnapTrade server already knows our `userId` (e.g. the
    /// app was reinstalled, or the local keychain secret was wiped while the
    /// server-side user record and its brokerage authorizations still exist).
    /// Previously this path cleared the local `userId` and registered a
    /// *different* user, orphaning the original user and every authorization
    /// attached to it. We now keep the existing `userId` and surface a clear
    /// "re-link your brokerage" error so the user re-authorizes via the portal
    /// (which re-issues a userSecret for the same userId) instead of silently
    /// accumulating orphaned SnapTrade users on every reinstall.
    private func registerIfNeeded() async throws {
        guard SnapTradeKeyStore.hasPartnerCredentials else {
            throw PortfolioError.notConfigured("Add your SnapTrade client ID and consumer key in Settings → Brokerage to connect.")
        }
        if SnapTradeKeyStore.isRegistered { return }
        do {
            try await registerNewUser()
        } catch PortfolioError.httpError(let code, _) where code == 409 {
            // userId already exists server-side. Preserve it; the user re-links
            // via the Connection Portal, which re-issues a userSecret for this
            // same userId rather than creating a brand-new orphaned user.
            if SnapTradeKeyStore.userId == nil {
                SnapTradeKeyStore.clearRegistration()
            }
            throw PortfolioError.notConfigured("This SnapTrade user already exists on the server. Tap Connect Account to re-link your brokerage — your existing connections are preserved.")
        }
    }

    private func registerNewUser() async throws {
        let userId = SnapTradeKeyStore.userId ?? "bullion-\(UUID().uuidString.prefix(8))"
        SnapTradeKeyStore.userId = userId
        let resp: STRegisterResponse = try await send(
            "POST", "/snapTrade/registerUser", authedUser: false,
            body: ["userId": userId]
        )
        guard let secret = resp.userSecret else {
            throw PortfolioError.notConfigured("SnapTrade did not return a user secret. Check your credentials and try again.")
        }
        SnapTradeKeyStore.userId = resp.userId ?? userId
        SnapTradeKeyStore.userSecret = secret
    }

    private func loginPortalURL() async throws -> URL {
        let redirect = "\(Secrets.snaptradeCallbackScheme)://snaptrade-callback"
        let resp: STLoginResponse = try await send(
            "POST", "/snapTrade/login", authedUser: true,
            body: [
                "customRedirect": redirect,
                "connectionType": "read",
                "showCloseButton": true,
                "connectionPortalVersion": "v4"
            ]
        )
        guard resp.encryptedMessageData == nil else {
            throw PortfolioError.httpError(
                0,
                "SnapTrade response encryption is enabled for this client. Disable encrypted responses for this personal direct integration, or add a backend that can decrypt them."
            )
        }
        guard let urlString = resp.redirectURI, let url = URL(string: urlString) else {
            throw PortfolioError.invalidPortalURL
        }
        return url
    }

    /// Validates partner credentials without needing a registered user
    /// (GET /snapTrade/listUsers requires partner signature only). Used by the
    /// Settings "Test connection" button.
    func validatePartnerCredentials() async throws {
        let _: [String] = try await send("GET", "/snapTrade/listUsers", authedUser: false)
    }

    // MARK: - Helpers

    private func rawAccounts() async throws -> [STAccount] {
        try await send("GET", "/accounts", authedUser: true)
    }

    private func authorizationId(for accountId: String) async throws -> String? {
        try await rawAccounts().first { $0.id == accountId }?.brokerageAuthorization
    }

    private func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return fractionalISOFormatter.date(from: s) ?? isoFormatter.date(from: s)
    }

    private func mapConnectionStatus(_ account: STAccount) -> ConnectionStatus {
        account.status == "unavailable" ? .needsReconnect : .active
    }

    private func percentEncodedPathComponent(_ s: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// RFC3986-unreserved percent-encoding, applied identically to the signed
    /// query string and the request URL so the signature verifies.
    private func percentEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// Builds the query string shared by signing and the URL. Ordering mirrors
    /// the official SDK: partner params first, then user params, then endpoint
    /// params. The signature only works if this string is byte-identical to
    /// the request URL's query.
    private func canonicalQuery(authedUser: Bool, extra: [(String, String)]) throws -> String {
        guard let clientId = SnapTradeKeyStore.clientId, !clientId.isEmpty else {
            throw PortfolioError.notConfigured("SnapTrade client ID not set. Add it in Settings → Brokerage.")
        }
        var items: [(String, String)] = [("clientId", clientId),
                                          ("timestamp", String(Int(Date().timeIntervalSince1970)))]
        if authedUser {
            guard let uid = SnapTradeKeyStore.userId, !uid.isEmpty,
                  let usec = SnapTradeKeyStore.userSecret, !usec.isEmpty else {
                throw PortfolioError.notConfigured("SnapTrade user not registered yet. Tap Connect Account to register.")
            }
            items.append(("userId", uid))
            items.append(("userSecret", usec))
        }
        items.append(contentsOf: extra)
        return items.map { "\($0.0)=\(percentEncode($0.1))" }.joined(separator: "&")
    }

    private func makeRequest(_ method: String, _ path: String,
                             authedUser: Bool,
                             extraQuery: [(String, String)],
                             body: [String: Any]?) throws -> URLRequest {
        guard let consumerKey = SnapTradeKeyStore.consumerKey, !consumerKey.isEmpty else {
            throw PortfolioError.notConfigured("SnapTrade consumer key not set. Add it in Settings → Brokerage.")
        }
        let query = try canonicalQuery(authedUser: authedUser, extra: extraQuery)
        guard let signature = SnapTradeSigner.signature(consumerKey: consumerKey,
                                                        content: body, path: path, query: query) else {
            throw PortfolioError.notConfigured("Could not sign the SnapTrade request. Re-check your consumer key.")
        }
        guard let url = URL(string: "\(baseHost)\(path)?\(query)") else {
            throw PortfolioError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(signature, forHTTPHeaderField: "Signature")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        return req
    }

    private func execute(_ req: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
                 .notConnectedToInternet, .timedOut, .cannotLoadFromNetwork:
                throw PortfolioError.networkUnreachable
            case .cancelled:
                throw PortfolioError.authenticationCancelled
            default:
                throw PortfolioError.httpError(0, urlError.localizedDescription)
            }
        }
        guard let http = response as? HTTPURLResponse else { throw PortfolioError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw PortfolioError.httpError(http.statusCode, snapTradeErrorMessage(from: data))
        }
        return data
    }

    private func snapTradeErrorMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["detail", "message", "error", "errorMessage"] {
                if let value = object[key] as? String, !value.isEmpty { return value }
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func send<T: Decodable>(_ method: String, _ path: String,
                                    authedUser: Bool,
                                    extraQuery: [(String, String)] = [],
                                    body: [String: Any]? = nil) async throws -> T {
        let req = try makeRequest(method, path, authedUser: authedUser, extraQuery: extraQuery, body: body)
        let data = try await execute(req)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PortfolioError.decodingError(error)
        }
    }

    /// For endpoints whose body we don't need (DELETE, refresh).
    private func sendVoid(_ method: String, _ path: String,
                          authedUser: Bool,
                          extraQuery: [(String, String)] = [],
                          body: [String: Any]? = nil) async throws {
        let req = try makeRequest(method, path, authedUser: authedUser, extraQuery: extraQuery, body: body)
        _ = try await execute(req)
    }
}

// MARK: - SnapTrade response models
// SnapTrade uses snake_case; the decoder converts to these camelCase names.

private struct STRegisterResponse: Decodable {
    let userId: String?
    let userSecret: String?
}

private struct STLoginResponse: Decodable {
    let redirectURI: String?
    let encryptedMessageData: [String: String]?
}

private struct STAccount: Decodable {
    let id: String
    let name: String?
    let institutionName: String?
    let brokerageAuthorization: String?
    let balance: STBalanceHolder?
    let syncStatus: STSyncStatus?
    let status: String?

    struct STBalanceHolder: Decodable { let total: STAmount? }
}

/// Cash amount returned by SnapTrade for balances, transactions, and fees.
/// Top-level so both `STAccount` and `STTransaction` can use it.
private struct STAmount: Decodable { let amount: Double?; let currency: String? }

private struct STSyncStatus: Decodable {
    let holdings: STStatus?
    let transactions: STStatus?

    struct STStatus: Decodable {
        let initialSyncCompleted: Bool?
        let lastSuccessfulSync: String?
    }
}

private struct STSymbol: Decodable {
    let symbol: String?
    let rawSymbol: String?
    let description: String?
}

private struct STSymbolHolder: Decodable {
    let symbol: STSymbol?
}

private struct STPositionsResponse: Decodable {
    let results: [STPosition]
}

private struct STPosition: Decodable {
    let instrument: STInstrument
    let units: STDecimal?
    let price: STDecimal?
    let costBasis: STDecimal?
}

private struct STInstrument: Decodable {
    let kind: String?
    let symbol: String?
    let rawSymbol: String?
    let rootSymbol: String?
    let description: String?
}

private struct STOrder: Decodable {
    let brokerageOrderId: String?
    let action: String?
    let totalQuantity: STDecimal?
    let filledQuantity: STDecimal?
    let executionPrice: STDecimal?
    let timeExecuted: String?
    let timePlaced: String?
    let symbol: STSymbolHolder?
    let universalSymbol: STSymbol?
}

/// Brokerage *transactions*: dividends, interest, transfers, corporate
/// actions, fees, etc. These carry a real cash amount (unlike orders, whose
/// amount we previously derived from qty*price — which made dividends show
/// as \$0). The `/accounts/{id}/transactions` endpoint returns these.
private struct STTransactionsResponse: Decodable {
    let results: [STTransaction]
}

private struct STTransaction: Decodable {
    let id: String?
    let type: String?          // Dividend, Interest, Transfer, Buy, Sell, ...
    let date: String?
    let currency: String?
    let description: String?
    let symbol: STSymbolHolder?
    let universalSymbol: STSymbol?
    let units: STDecimal?
    let price: STDecimal?
    let cash: STAmount?         // the authoritative cash flow (dividends!)
    let fee: STAmount?
}

private struct STDecimal: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
            return
        }
        if let string = try? container.decode(String.self) {
            let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let double = Double(cleaned) {
                value = double
                return
            }
        }
        value = 0
    }
}

private extension Error {
    var isSnapTradeAuthFailure: Bool {
        guard let error = self as? PortfolioError,
              case PortfolioError.httpError(let code, _) = error else { return false }
        return code == 401 || code == 403
    }
}

// MARK: - ASWebAuthenticationSession wrapper

/// Opens the SnapTrade Connection Portal in `ASWebAuthenticationSession`.
/// A strong reference is held for the session's lifetime so the sheet can't be
/// deallocated mid-flight.
private final class STWebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
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
