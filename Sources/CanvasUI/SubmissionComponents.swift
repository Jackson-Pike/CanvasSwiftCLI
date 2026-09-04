import SwiftUI
import CanvasCore

public struct SubmissionEditor: View {
    public struct PickedFile: Identifiable, Sendable {
        public let id: UUID
        public let filename: String
        public let sizeBytes: Int
        public var isAllowed: Bool
        public init(id: UUID = UUID(), filename: String, sizeBytes: Int, isAllowed: Bool) {
            self.id = id; self.filename = filename; self.sizeBytes = sizeBytes; self.isAllowed = isAllowed
        }
    }

    let types: [SubmissionType]
    @Binding var selection: SubmissionType
    @Binding var text: String
    @Binding var url: String
    let files: [PickedFile]
    let allowedExtensions: [String]?
    let onAddFiles: () -> Void
    let onRemoveFile: (UUID) -> Void

    public init(types: [SubmissionType], selection: Binding<SubmissionType>,
                text: Binding<String>, url: Binding<String>, files: [PickedFile],
                allowedExtensions: [String]?, onAddFiles: @escaping () -> Void,
                onRemoveFile: @escaping (UUID) -> Void) {
        self.types = types; self._selection = selection; self._text = text; self._url = url
        self.files = files; self.allowedExtensions = allowedExtensions
        self.onAddFiles = onAddFiles; self.onRemoveFile = onRemoveFile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if types.count > 1 {
                Picker("Submission type", selection: $selection) {
                    ForEach(types, id: \.self) { Text(label(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            switch selection {
            case .onlineText:
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .font(.system(size: 13))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline))
            case .onlineURL:
                TextField("https://…", text: $url)
                    .textFieldStyle(.roundedBorder)
            case .onlineUpload:
                fileList
            }
            if selection == .onlineUpload, let exts = allowedExtensions, !exts.isEmpty {
                Text("Allowed: \(exts.joined(separator: ", "))")
                    .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(files) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                    Text(file.filename).font(.system(size: 12.5))
                        .foregroundStyle(file.isAllowed ? Color.inkPrimary : Color.lostMissing)
                    if !file.isAllowed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lostMissing).font(.system(size: 11))
                    }
                    Spacer()
                    Button { onRemoveFile(file.id) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain).foregroundStyle(Color.inkTertiary)
                }
            }
            Button(action: onAddFiles) { Label("Add files…", systemImage: "doc.badge.plus") }
                .buttonStyle(.plain).foregroundStyle(Color.accentHypothetical)
        }
    }

    private func label(for t: SubmissionType) -> String {
        switch t { case .onlineUpload: "File"; case .onlineText: "Text"; case .onlineURL: "URL" }
    }
}

public struct SubmissionStatusView: View {
    public enum Phase: Equatable {
        case idle
        case uploading(current: Int, total: Int)
        case submitting
        case verifying
        case success(attempt: Int, submittedAt: String?)
        case failed(String)
    }
    let phase: Phase
    public init(phase: Phase) { self.phase = phase }

    public var body: some View {
        switch phase {
        case .idle: EmptyView()
        case .uploading(let c, let t): progress("Uploading file \(c) of \(t)…")
        case .submitting: progress("Submitting…")
        case .verifying: progress("Verifying…")
        case .success(let attempt, _):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Submitted — attempt \(attempt)").font(.system(size: 12.5, weight: .medium))
            }
        case .failed(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.lostMissing)
                Text(msg).font(.system(size: 12.5)).foregroundStyle(Color.lostMissing)
            }
        }
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).font(.system(size: 12.5)) }
    }
}
