import Foundation

/// Common load-state envelope so every async view can render
/// loading / error / empty / loaded without a blank screen.
enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}