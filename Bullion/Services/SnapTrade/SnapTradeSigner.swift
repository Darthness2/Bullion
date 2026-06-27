import Foundation
import CryptoKit

/// Signs SnapTrade API requests.
///
/// Per SnapTrade's spec (https://docs.snaptrade.com), each request carries a
/// `Signature` header that is the base64 HMAC-SHA256 of a canonical JSON object
/// keyed by the partner consumer key:
///
///     { "content": <body or null>, "path": "/api/v1/...", "query": "k=v&..." }
///
/// The JSON is serialized compact with **sorted keys** (matching the reference
/// Python `json.dumps(..., separators=(",", ":"), sort_keys=True)`), and the
/// `query` string must be byte-identical to the request's actual query string.
enum SnapTradeSigner {

    /// Returns the base64 `Signature` header value, or nil if serialization fails.
    /// - Parameters:
    ///   - consumerKey: partner consumer key (used as the raw HMAC key).
    ///   - content: the request body as a JSON object, or nil for no body.
    ///   - path: request path including the `/api/v1` prefix.
    ///   - query: the exact query string sent on the request (no leading `?`).
    static func signature(consumerKey: String,
                          content: [String: Any]?,
                          path: String,
                          query: String) -> String? {
        let sigObject: [String: Any] = [
            "content": content ?? NSNull(),
            "path": path,
            "query": query
        ]
        guard JSONSerialization.isValidJSONObject(sigObject),
              let data = try? JSONSerialization.data(withJSONObject: sigObject,
                                                     options: [.sortedKeys]) else {
            return nil
        }
        let key = SymmetricKey(data: Data(consumerKey.utf8))
        let code = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(code).base64EncodedString()
    }
}
