import Foundation

public enum CanvasDate {
    private static let plain = ISO8601DateFormatter()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return plain.date(from: s) ?? fractional.date(from: s)
    }
}
