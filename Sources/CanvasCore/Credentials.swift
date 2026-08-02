import Foundation

public struct Credentials: Sendable, Equatable {
    public let host: String   // host only — no scheme, no path
    public let token: String

    public init(host: String, token: String) {
        self.host = host
        self.token = token
    }

    /// Trims whitespace, strips a leading scheme and any trailing path,
    /// lowercases, and validates. Returns nil for anything that isn't a hostname.
    public static func normalizeHost(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        guard !s.isEmpty, !s.contains(" "), s.contains("."),
              s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
        else { return nil }
        return s
    }
}
