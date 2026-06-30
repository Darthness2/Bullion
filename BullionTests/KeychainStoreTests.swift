import Testing
import Foundation
@testable import Bullion

@Suite("KeychainStore")
struct KeychainStoreTests {

    // Use unique, test-scoped keys so we never collide with real stored secrets.
    private let testKey = "bullion.test.\(UUID().uuidString)"
    private let testKey2 = "bullion.test.2.\(UUID().uuidString)"

    @Test("Round-trip set then get")
    func roundTrip() {
        defer { KeychainStore.remove(testKey) }
        let ok = KeychainStore.set("secret-value-123", for: testKey)
        #expect(ok)
        #expect(KeychainStore.get(testKey) == "secret-value-123")
    }

    @Test("get returns nil for a key that was never set")
    func missingKey() {
        KeychainStore.remove(testKey2)
        #expect(KeychainStore.get(testKey2) == nil)
    }

    @Test("set overwrites an existing value")
    func overwrites() {
        defer { KeychainStore.remove(testKey) }
        _ = KeychainStore.set("first", for: testKey)
        _ = KeychainStore.set("second", for: testKey)
        #expect(KeychainStore.get(testKey) == "second")
    }

    @Test("remove deletes the value")
    func removeDeletes() {
        _ = KeychainStore.set("temp", for: testKey)
        KeychainStore.remove(testKey)
        #expect(KeychainStore.get(testKey) == nil)
    }

    @Test("removing a key that was never set is a no-op")
    func removeMissing() {
        KeychainStore.remove(testKey2)
        // Should not throw / not crash.
        #expect(KeychainStore.get(testKey2) == nil)
    }

    @Test("set returns true for a typical UTF-8 string")
    func setSucceedsForUnicode() {
        defer { KeychainStore.remove(testKey) }
        let ok = KeychainStore.set("héllo-key-🔑", for: testKey)
        #expect(ok)
        #expect(KeychainStore.get(testKey) == "héllo-key-🔑")
    }
}