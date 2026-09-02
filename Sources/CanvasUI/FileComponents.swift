import SwiftUI
import CanvasData

public struct FolderRow: View {
    public let folder: CachedFolder
    public let action: () -> Void

    public init(folder: CachedFolder, action: @escaping () -> Void) {
        self.folder = folder
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentHypothetical)

                Text(folder.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .hairlineRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct FileRow: View {
    public let file: CachedFile
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onDownload: () -> Void
    public let onPreview: () -> Void

    public init(
        file: CachedFile,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onDownload: @escaping () -> Void,
        onPreview: @escaping () -> Void
    ) {
        self.file = file
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDownload = onDownload
        self.onPreview = onPreview
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForContentType(file.contentType))
                .font(.system(size: 16))
                .foregroundStyle(colorForContentType(file.contentType))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedSize(file.size))
                        .font(.mono(11))
                        .foregroundStyle(Color.inkTertiary)

                    if let date = file.updatedAt {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.inkTertiary)
                        Text(date, style: .date)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
            }

            Spacer()

            if file.localPath != nil {
                Button(action: onPreview) {
                    Label("Preview", systemImage: "eye")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Quick Look Preview (Space)")

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            } else {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentHypothetical)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .hairlineRow(selected: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func iconForContentType(_ type: String?) -> String {
        guard let type = type?.lowercased() else { return "doc" }
        if type.contains("pdf") { return "doc.richtext.fill" }
        if type.contains("image") { return "photo.fill" }
        if type.contains("zip") || type.contains("archive") { return "doc.zipper" }
        if type.contains("video") || type.contains("audio") { return "play.rectangle.fill" }
        if type.contains("text") || type.contains("code") || type.contains("json") { return "doc.text.fill" }
        return "doc.fill"
    }

    private func colorForContentType(_ type: String?) -> Color {
        guard let type = type?.lowercased() else { return .secondary }
        if type.contains("pdf") { return .red }
        if type.contains("image") { return .purple }
        if type.contains("video") { return .orange }
        return Color.accentHypothetical
    }
}
