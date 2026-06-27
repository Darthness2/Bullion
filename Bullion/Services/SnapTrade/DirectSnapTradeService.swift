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
    private let apiPrefix = "/api/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

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
            do { return try await !rawAccounts().isEmpty } catch { return false }
        }
    }

    func accounts() async throws -> [BrokerageAccount] {
        try await rawAccounts().map { a in
            BrokerageAccount(
                id: a.id,
                name: a.name ?? a.institutionName ?? "Account",
                brokerage: a.institutionName ?? "Brokerage",
                totalValue: a.balance?.total?.amount ?? 0,
                currency: a.balance?.total?.currency ?? "USD",
                lastSynced: Date(),
                connectionStatus: .active
            )
        }
    }

    func holdings(accountId: String) async throws -> [Holding] {
        let positions: [STPosition] = try await send(
            "GET", "/accounts/\(accountId)/positions", authedUser: true
        )
        return positions.map { p in
            let units = p.units ?? 0
            let price = p.price ?? 0
            let sym = p.symbol?.symbol
            let ticker = sym?.symbol ?? sym?.rawSymbol ?? "—"
            return Holding(
                symbol: ticker,
                name: sym?.description ?? ticker,
                quantity: units,
                avgCost: p.averagePurchasePrice,
                marketValue: units * price,
                dayChange: nil,
                dayChangePercent: nil,
                allocation: nil
            )
        }
    }

    func transactions(accountId: String) async throws -> [Transaction] {
        let orders: [STOrder] = try await send(
            "GET", "/accounts/\(accountId)/orders", authedUser: true
        )
        return orders.map { o in
            let sym = o.symbol?.symbol ?? o.universalSymbol
            let ticker = sym?.symbol ?? sym?.rawSymbol ?? ""
            let qty = o.totalQuantity ?? o.filledQuantity
            let price = o.executionPrice
            return Transaction(
                id: o.brokerageOrderId ?? UUID().uuidString,
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

    func connectionPortalURL() async throws -> URL {
        try await registerIfNeeded()
        // POST /snapTrade/login — userId/userSecret are query params; the portal
        // URL comes back in the body. customRedirect routes back to our scheme.
        let redirect = "\(Secrets.snaptradeCallbackScheme)://snaptrade-callback"
        let resp: STLoginResponse = try await send(
            "POST", "/snapTrade/login", authedUser: true,
            extraQuery: [("customRedirect", redirect)]
        )
        guard let urlString = resp.redirectURI, let url = URL(string: urlString) else {
            throw PortfolioError.invalidPortalURL
        }
        return url
    }

    func openConnectionPortal(url: URL) async throws {
        let session = STWebAuthSession(url: url, scheme: Secrets.snaptradeCallbackScheme)
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
    private func registerIfNeeded() async throws {
        guard SnapTradeKeyStore.hasPartnerCredentials else {
            throw PortfolioError.httpError(0, "SnapTrade keys not set. Add them in Settings → Brokerage.")
        }
        if SnapTradeKeyStore.isRegistered { return }
        let userId = SnapTradeKeyStore.userId ?? "bullion-\(UUID().uuidString.prefix(8))"
        SnapTradeKeyStore.userId = userId
        let resp: STRegisterResponse = try await send(
            "POST", "/snapTrade/registerUser", authedUser: false,
            body: ["userId": userId]
        )
        guard let secret = resp.userSecret else {
            throw PortfolioError.httpError(0, "SnapTrade did not return a user secret.")
        }
        SnapTradeKeyStore.userId = resp.userId ?? userId
        SnapTradeKeyStore.userSecret = secret
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
        return ISO8601DateFormatter().date(from: s)
    }

    /// RFC3986-unreserved percent-encoding, applied identically to the signed
    /// query string and the request URL so the signature verifies.
    private func percentEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// Builds the canonical (key-sorted) query string shared by signing and the URL.
    private func canonicalQuery(authedUser: Bool, extra: [(String, String)]) throws -> String {
        guard let clientId = SnapTradeKeyStore.clientId, !clientId.isEmpty else {
            throw PortfolioError.httpError(0, "SnapTrade clientId not set.")
        }
        var items: [(String, String)] = [("clientId", clientId),
                                          ("timestamp", String(Int(Date().timeIntervalSince1970)))]
        if authedUser {
            guard let uid = SnapTradeKeyStore.userId, !uid.isEmpty,
                  let usec = SnapTradeKeyStore.userSecret, !usec.isEmpty else {
                throw PortfolioError.httpError(0, "SnapTrade user not registered.")
            }
            items.append(("userId", uid))
            items.append(("userSecret", usec))
        }
        items.append(contentsOf: extra)
        // Sort by key for a deterministic, canonical ordering.
        items.sort { $0.0 < $1.0 }
        return items.map { "\($0.0)=\(percentEncode($0.1))" }.joined(separator: "&")
    }

    private func makeRequest(_ method: String, _ path: String,
                             authedUser: Bool,
                             extraQuery: [(String, String)],
                             body: [String: Any]?) throws -> URLRequest {
        guard let consumerKey = SnapTradeKeyStore.consumerKey, !consumerKey.isEmpty else {
            throw PortfolioError.httpError(0, "SnapTrade consumerKey not set.")
        }
        let fullPath = apiPrefix + path
        let query = try canonicalQuery(authedUser: authedUser, extra: extraQuery)
        guard let signature = SnapTradeSigner.signature(consumerKey: consumerKey,
                                                        content: body, path: fullPath, query: query) else {
            throw PortfolioError.httpError(0, "Failed to sign request.")
        }
        guard let url = URL(string: "\(baseHost)\(fullPath)?\(query)") else {
            throw PortfolioError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(signature, forHTTPHeaderField: "Signature")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
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
            throw PortfolioError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
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
}

private struct STAccount: Decodable {
    let id: String
    let name: String?
    let number: String?
    let institutionName: String?
    let brokerageAuthorization: String?
    let balance: STBalanceHolder?

    struct STBalanceHolder: Decodable { let total: STAmount? }
    struct STAmount: Decodable { let amount: Double?; let currency: String? }
}

private struct STSymbol: Decodable {
    let symbol: String?
    let rawSymbol: String?
    let description: String?
}

private struct STSymbolHolder: Decodable {
    let symbol: STSymbol?
}

private struct STPosition: Decodable {
    let units: Double?
    let price: Double?
    let averagePurchasePrice: Double?
    let symbol: STSymbolHolder?
}

private struct STOrder: Decodable {
    let brokerageOrderId: String?
    let action: String?
    let totalQuantity: Double?
    let filledQuantity: Double?
    let executionPrice: Double?
    let timeExecuted: String?
    let timePlaced: String?
    let symbol: STSymbolHolder?
    let universalSymbol: STSymbol?
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
