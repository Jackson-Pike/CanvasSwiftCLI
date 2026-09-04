import Foundation

public enum SubmissionType: String, Sendable, CaseIterable {
    case onlineUpload = "online_upload"
    case onlineText   = "online_text_entry"
    case onlineURL    = "online_url"

    /// The app-supported subset of an assignment's raw `submission_types`, in display order.
    public static func supported(from raw: [String]?) -> [SubmissionType] {
        guard let raw else { return [] }
        let set = Set(raw)
        return [.onlineUpload, .onlineText, .onlineURL].filter { set.contains($0.rawValue) }
    }
}

public enum SubmissionValidator {
    /// `allowed` nil/empty ⇒ any file accepted. Otherwise the file's extension (sans dot,
    /// case-insensitive) must appear in the list. A file with no extension is rejected when a
    /// non-empty allow-list is present.
    public static func isExtensionAllowed(_ filename: String, allowed: [String]?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return allowed.map { $0.lowercased() }.contains(ext)
    }
}
