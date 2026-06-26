import Foundation
import AuthenticationServices

/// Real PortfolioService that calls our backend proxy for SnapTrade data.
/// The app never touches SnapTrade credentials — all secret operations
/// happen server-side. The app only calls our backend's REST API.
final class BackendPortfolioService: PortfolioService, @unchecked Sendable {

    private static let iso8601 = ISO8601DateFormatter()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL? = URL(string: Secrets.backendBaseURL)) {
        // Fall back to localhost rather than crashing if Secrets.backendBaseURL
        // is misconfigured (it's a gitignored, hand-edited file).
        self.baseURL = baseURL ?? URL(string: "http://localhost:8787")!
        self.session = URLSession.shared
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
    }

    var isLinked: Bool {
        get async {
            do {
                let resp: AccountsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts") }
                return !resp.accounts.isEmpty
            } catch {
                return false
            }
        }
    }

    func accounts() async throws -> [BrokerageAccount] {
        let result = try await accountsWithSyncState()
        return result.accounts
    }

    /// Fetch accounts plus partial-failure info. Enriches each account's
    /// `totalValue`/`currency`/`lastSynced` from its holdings endpoint (the
    /// `/accounts` endpoint doesn't include totals).
    func accountsWithSyncState() async throws -> AccountsSyncResult {
        let resp: AccountsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts") }
        var accounts: [BrokerageAccount] = []
        for a in resp.accounts {
            // Fetch holdings to get the real totalValue/currency/lastSynced.
            let total: Double
            let currency: String
            let synced: Date
            if let h: HoldingsResponse = try? await mapNetwork({ try await self.get("/snaptrade/accounts/\(a.id)/holdings") }) {
                total = h.totalValue ?? h.holdings.map(\.marketValue).reduce(0, +)
                currency = h.currency ?? "USD"
                synced = h.lastSynced.flatMap { Self.iso8601.date(from: $0) } ?? Date()
            } else {
                total = 0
                currency = "USD"
                synced = Date()
            }
            accounts.append(BrokerageAccount(
                id: a.id,
                name: a.name ?? "Account",
                brokerage: a.brokerage ?? "Unknown",
                totalValue: total,
                currency: currency,
                lastSynced: synced,
                connectionStatus: mapSyncStatus(a.syncStatus)
            ))
        }
        return AccountsSyncResult(
            accounts: accounts,
            partial: resp.partial ?? false,
            failedConnectionIds: resp.failedConnections ?? []
        )
    }

    private func mapSyncStatus(_ raw: String?) -> ConnectionStatus {
        switch raw?.lowercased() {
        case "expired", "disconnected", "disabled": return .needsReconnect
        case "active", "connected":                return .active
        default:                                   return .active
        }
    }

    func holdings(accountId: String) async throws -> [Holding] {
        let resp: HoldingsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts/\(accountId)/holdings") }
        return resp.holdings.map { h in
            Holding(
                symbol: h.symbol,
                name: h.name,
                quantity: h.quantity,
                avgCost: h.avgCost,
                marketValue: h.marketValue,
                dayChange: h.dayChange,
                dayChangePercent: h.dayChangePercent,
                allocation: nil
            )
        }
    }

    func transactions(accountId: String) async throws -> [Transaction] {
        let resp: TransactionsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts/\(accountId)/transactions") }
        return resp.transactions.map { t in
            Transaction(
                id: t.id ?? UUID().uuidString,
                symbol: t.symbol ?? "",
                type: t.type ?? "transaction",
                quantity: t.quantity,
                price: t.price,
                amount: t.amount,
                date: t.date.flatMap { Self.iso8601.date(from: $0) },
                description: t.description ?? ""
            )
        }
    }

    func connectionPortalURL() async throws -> URL {
        // First ensure the user is registered.
        struct EmptyResponse: Codable {}
        _ = try await mapNetwork { try await self.post("/snaptrade/register-user", body: [:]) as EmptyResponse }
        // Then get the portal URL.
        struct PortalResponse: Codable { let url: String }
        let resp: PortalResponse = try await mapNetwork { try await self.post("/snaptrade/connection-portal-url", body: [:]) }
        guard let url = URL(string: resp.url) else {
            throw PortfolioError.invalidPortalURL
        }
        return url
    }

    func disconnect(accountId: String) async throws {
        let accsResp: AccountsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts") }
        if let acc = accsResp.accounts.first(where: { $0.id == accountId }),
           let connId = acc.connectionId {
            struct EmptyResponse: Codable {}
            _ = try await mapNetwork { try await self.delete("/snaptrade/connections/\(connId)") as EmptyResponse }
        }
    }

    func refresh(accountId: String) async throws {
        let accsResp: AccountsResponse = try await mapNetwork { try await self.get("/snaptrade/accounts") }
        if let acc = accsResp.accounts.first(where: { $0.id == accountId }),
           let connId = acc.connectionId {
            struct EmptyResponse: Codable {}
            _ = try await mapNetwork { try await self.post("/snaptrade/refresh/\(connId)", body: [:]) as EmptyResponse }
        }
    }

    /// Lightweight GET /health — returns true if the backend is reachable.
    /// Used by the connect screen to surface a status indicator before the
    /// user taps Connect.
    func checkBackendHealth() async -> Bool {
        struct HealthResponse: Decodable { let status: String }
        do {
            let url = baseURL.appendingPathComponent("/health")
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 4
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            let resp = try decoder.decode(HealthResponse.self, from: data)
            return resp.status == "ok"
        } catch {
            return false
        }
    }

    // MARK: - ASWebAuthenticationSession

    /// Opens the SnapTrade Connection Portal in ASWebAuthenticationSession
    /// (not WKWebView — required for OAuth/passkeys to work correctly).
    /// Returns when the redirect URI is received.
    func openConnectionPortal(url: URL) async throws {
        let scheme = Secrets.snaptradeCallbackScheme
        let session = WebAuthSession(url: url, scheme: scheme)
        try await session.start()
    }

    // MARK: - Private HTTP helpers

    /// Adds the shared backend bearer token when one is configured.
    private func authorized(_ req: inout URLRequest) {
        if !Secrets.backendAPIToken.isEmpty {
            req.setValue("Bearer \(Secrets.backendAPIToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        authorized(&req)
        return try await execute(req)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorized(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(req)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        authorized(&req)
        return try await execute(req)
    }

    private func execute<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw PortfolioError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw PortfolioError.httpError(http.statusCode, body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PortfolioError.decodingError(error)
        }
    }
}

extension BackendPortfolioService {
    /// Wrap a throwing call so transport-level failures (backend not running,
    /// wrong URL, no internet) surface as `PortfolioError.networkUnreachable`
    /// instead of a raw `URLError` with an opaque localized description.
    func mapNetwork<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost,
                 .networkConnectionLost, .notConnectedToInternet,
                 .timedOut, .cannotLoadFromNetwork:
                throw PortfolioError.networkUnreachable
            case .cancelled:
                throw PortfolioError.authenticationCancelled
            default:
                throw PortfolioError.httpError(0, urlError.localizedDescription)
            }
        }
    }
}

// MARK: - Sync result

struct AccountsSyncResult: Sendable {
    let accounts: [BrokerageAccount]
    let partial: Bool
    let failedConnectionIds: [String]
}

// MARK: - Response types

private struct AccountsResponse: Codable {
    struct Account: Codable {
        let id: String
        let name: String?
        let brokerage: String?
        let connectionId: String?
        let syncStatus: String?
    }
    let accounts: [Account]
    /// Backend reports partial failures when some connections couldn't list.
    let partial: Bool?
    let failedConnections: [String]?
}

private struct HoldingsResponse: Codable {
    struct Holding: Codable {
        let symbol: String
        let name: String
        let quantity: Double
        let avgCost: Double?
        let marketValue: Double
        let dayChange: Double?
        let dayChangePercent: Double?
    }
    let accountId: String?
    let totalValue: Double?
    let currency: String?
    let holdings: [Holding]
    let lastSynced: String?
}

private struct TransactionsResponse: Codable {
    struct Transaction: Codable {
        let id: String?
        let symbol: String?
        let type: String?
        let quantity: Double?
        let price: Double?
        let amount: Double?
        let date: String?
        let description: String?
    }
    let transactions: [Transaction]
}

// MARK: - Errors

enum PortfolioError: LocalizedError {
    case invalidPortalURL
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case authenticationCancelled
    case networkUnreachable

    var errorDescription: String? {
        switch self {
        case .invalidPortalURL:
            return "Invalid Connection Portal URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code, _):
            return "Server error (HTTP \(code))."
        case .decodingError:
            return "Could not parse server response."
        case .authenticationCancelled:
            return "Authentication was cancelled."
        case .networkUnreachable:
            return "Couldn't reach the connection service. Check your internet and try again."
        }
    }
}

// MARK: - WebAuthSession wrapper

private final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let url: URL
    private let scheme: String
    /// Strong reference held for the whole presentation. Without this the
    /// `ASWebAuthenticationSession` is only retained by the start closure and
    /// can be deallocated mid-flight, tearing the auth sheet down.
    private var authSession: ASWebAuthenticationSession?

    init(url: URL, scheme: String) {
        self.url = url
        self.scheme = scheme
    }

    @MainActor
    func start() async throws {
        return try await withCheckedThrowingContinuation { continuation in
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
        // `presentationAnchor(for:)` is called on the main thread; resolve the
        // key window directly. (Wrapping in DispatchQueue.main.sync here would
        // deadlock since we're already on the main queue.)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}