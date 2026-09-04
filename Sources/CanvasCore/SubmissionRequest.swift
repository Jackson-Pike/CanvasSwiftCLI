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

public struct UploadedFile: Codable, Sendable, Equatable {
    public let id: Int
}

public struct UploadTicket: Sendable, Equatable, Decodable {
    public let uploadURL: String
    public let uploadParams: [(String, String)]

    public init(uploadURL: String, uploadParams: [(String, String)]) {
        self.uploadURL = uploadURL
        self.uploadParams = uploadParams
    }

    public static func == (l: UploadTicket, r: UploadTicket) -> Bool {
        l.uploadURL == r.uploadURL
            && Dictionary(uniqueKeysWithValues: l.uploadParams) == Dictionary(uniqueKeysWithValues: r.uploadParams)
    }

    private enum CodingKeys: String, CodingKey { case uploadURL = "upload_url", uploadParams = "upload_params" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uploadURL = try c.decode(String.self, forKey: .uploadURL)
        // upload_params is an object of scalar values; preserve order and coerce scalars to strings.
        let paramsContainer = try c.nestedContainer(keyedBy: DynamicKey.self, forKey: .uploadParams)
        var pairs: [(String, String)] = []
        for key in paramsContainer.allKeys {
            if let s = try? paramsContainer.decode(String.self, forKey: key) { pairs.append((key.stringValue, s)) }
            else if let i = try? paramsContainer.decode(Int.self, forKey: key) { pairs.append((key.stringValue, String(i))) }
            else if let d = try? paramsContainer.decode(Double.self, forKey: key) { pairs.append((key.stringValue, String(d))) }
            else if let b = try? paramsContainer.decode(Bool.self, forKey: key) { pairs.append((key.stringValue, String(b))) }
            // null / unsupported → dropped
        }
        uploadParams = pairs
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String; var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    }
}

public enum MultipartBody {
    public static func contentTypeHeader(boundary: String) -> String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public static func build(params: [(String, String)], fileField: String, filename: String,
                             contentType: String, fileData: Data, boundary: String) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        for (name, value) in params {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
