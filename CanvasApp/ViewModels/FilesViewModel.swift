import SwiftUI
import CanvasCore
import CanvasData
import QuickLook

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var folders: [CachedFolder] = []
    @Published var files: [CachedFile] = []
    @Published var currentFolderId: Int?
    @Published var selectedFileId: Int?
    @Published var previewURL: URL?
    @Published var isLoading = false
    @Published var downloadingFileId: Int?
    @Published var error: String?

    func load(session: AppSession, courseId: Int) async {
        isLoading = true
        fetchLocal(session: session, courseId: courseId)
        do {
            try await session.syncEngine.refresh(.files(courseId: courseId))
            fetchLocal(session: session, courseId: courseId)
            error = nil
        } catch {
            self.error = String(describing: error)
        }
        isLoading = false
    }

    private func fetchLocal(session: AppSession, courseId: Int) {
        do {
            self.folders = try session.repository.folders(courseId: courseId)
            self.files = try session.repository.files(courseId: courseId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    var visibleFolders: [CachedFolder] {
        folders.filter { $0.parentFolderId == currentFolderId }
    }

    var visibleFiles: [CachedFile] {
        if let currentFolderId {
            return files.filter { $0.folderId == currentFolderId }
        } else {
            // Root folder or files without specific folder
            let rootFolderIds = Set(folders.filter { $0.parentFolderId == nil }.map(\.id))
            return files.filter { $0.folderId == nil || rootFolderIds.contains($0.folderId!) }
        }
    }

    func downloadFile(_ file: CachedFile, session: AppSession) async {
        guard downloadingFileId == nil else { return }
        downloadingFileId = file.id

        do {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let targetURL = downloadsDir.appendingPathComponent(file.displayName)

            if let urlString = file.url, let client = session.apiClient {
                try await client.downloadFile(url: urlString, to: targetURL)
                try session.repository.updateLocalPath(fileId: file.id, localPath: targetURL.path)
                fetchLocal(session: session, courseId: file.courseId)
            }
        } catch {
            self.error = "Download failed: \(error.localizedDescription)"
        }
        downloadingFileId = nil
    }

    func previewFile(_ file: CachedFile, session: AppSession) {
        if let path = file.localPath {
            let url = URL(fileURLWithPath: path)
            previewURL = url
        } else {
            Task {
                await downloadFile(file, session: session)
                if let updated = files.first(where: { $0.id == file.id }), let path = updated.localPath {
                    previewURL = URL(fileURLWithPath: path)
                }
            }
        }
    }
}
