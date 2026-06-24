import Foundation

/// Generic async URLSession client with typed endpoints and centralized
/// error handling. Stubbed for Milestone 1 — the Polygon provider (M3)
/// and PortfolioService (M4) will use it.
actor APIClient {
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case http(status: Int, body: String?)
        case decoding(DecodingError)
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:                return "Invalid URL."
            case .invalidResponse:           return "Invalid response from server."
            case .http(let status, _):       return "Server error (HTTP \(status))."
            case .decoding:                  return "Could not parse the response."
            case .network(let err):          return err.localizedDescription
            }
        }
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try endpoint.urlRequest()
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw APIError.http(status: http.statusCode, body: body)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch let e as DecodingError {
                throw APIError.decoding(e)
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error)
        }
    }
}

/// Describes a single HTTP request. Concrete providers build Endpoint values.
struct Endpoint {
    enum Method: String { case GET, POST, DELETE, PUT }
    let baseURL: URL
    let path: String
    var method: Method = .GET
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data? = nil

    func urlRequest() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw APIClient.APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }
}