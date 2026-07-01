import Testing
import Foundation
import CryptoKit
@testable import Bullion

@Suite("SnapTradeSigner")
struct SnapTradeSignerTests {

    @Test("Signature is deterministic for the same input")
    func deterministic() {
        let s1 = SnapTradeSigner.signature(
            consumerKey: "test-key", content: ["userId": "abc"],
            path: "/api/v1/snapTrade/registerUser", query: "clientId=def"
        )
        let s2 = SnapTradeSigner.signature(
            consumerKey: "test-key", content: ["userId": "abc"],
            path: "/api/v1/snapTrade/registerUser", query: "clientId=def"
        )
        #expect(s1 != nil)
        #expect(s1 == s2)
    }

    @Test("Signature changes when any input changes")
    func changesWithInput() {
        let base = SnapTradeSigner.signature(
            consumerKey: "k", content: nil, path: "/api/v1/p", query: "a=1"
        )
        let diffKey = SnapTradeSigner.signature(
            consumerKey: "K", content: nil, path: "/api/v1/p", query: "a=1"
        )
        let diffPath = SnapTradeSigner.signature(
            consumerKey: "k", content: nil, path: "/api/v1/P", query: "a=1"
        )
        let diffQuery = SnapTradeSigner.signature(
            consumerKey: "k", content: nil, path: "/api/v1/p", query: "a=2"
        )
        let diffBody = SnapTradeSigner.signature(
            consumerKey: "k", content: ["x": 1], path: "/api/v1/p", query: "a=1"
        )
        #expect(base != diffKey)
        #expect(base != diffPath)
        #expect(base != diffQuery)
        #expect(base != diffBody)
    }

    @Test("Signature is base64-encoded HMAC-SHA256 of the sorted compact JSON")
    func matchesReferenceHMAC() throws {
        // Reproduce the exact canonical string the signer builds, then
        // compute the expected HMAC-SHA256 independently and compare.
        // The path includes the /api/v1 prefix per SnapTrade's signing spec.
        let consumerKey = "consumer-secret"
        let path = "/api/v1/accounts"
        let query = "clientId=cid&userId=uid"
        // JSONSerialization with .sortedKeys produces: {"content":null,"path":"/accounts","query":"..."}
        let sigObject: [String: Any] = [
            "content": NSNull(),
            "path": path,
            "query": query
        ]
        let canonical = try JSONSerialization.data(
            withJSONObject: sigObject, options: [.sortedKeys]
        )
        // The signer applies encodeURI to the consumer key before HMAC.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.insert(charactersIn: "#")
        let encodedKey = consumerKey.addingPercentEncoding(withAllowedCharacters: allowed) ?? consumerKey
        let key = SymmetricKey(data: Data(encodedKey.utf8))
        let expected = Data(HMAC<SHA256>.authenticationCode(for: canonical, using: key))
            .base64EncodedString()
        let actual = SnapTradeSigner.signature(
            consumerKey: consumerKey, content: nil, path: path, query: query
        )
        #expect(actual == expected)
    }

    @Test("Signature handles a body with nested content")
    func withBody() {
        let s = SnapTradeSigner.signature(
            consumerKey: "k",
            content: ["userId": "u1", "connectionType": "read"],
            path: "/api/v1/snapTrade/login", query: "clientId=c"
        )
        #expect(s != nil)
        #expect(!s!.isEmpty)
    }

    @Test("Consumer key with special chars is encodeURI'd before HMAC")
    func encodeURIKey() {
        // A consumer key containing a character that addingPercentEncoding
        // changes (space -> %20) must produce a different signature than one
        // computed with the raw key — confirming the encodeURI step runs.
        let rawSig = SnapTradeSigner.signature(
            consumerKey: "key with space", content: nil, path: "/api/v1/p", query: ""
        )
        // Manually compute with the raw (un-encoded) key for comparison.
        let sigObject: [String: Any] = ["content": NSNull(), "path": "/api/v1/p", "query": ""]
        let data = try! JSONSerialization.data(withJSONObject: sigObject, options: [.sortedKeys])
        let rawKey = SymmetricKey(data: Data("key with space".utf8))
        let rawExpected = Data(HMAC<SHA256>.authenticationCode(for: data, using: rawKey))
            .base64EncodedString()
        #expect(rawSig != rawExpected)
    }
}