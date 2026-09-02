import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI
import QuickLook

struct FilesTabView: View {
    let courseId: Int
    @StateObject private var vm = FilesViewModel()
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if vm.isLoading && vm.files.isEmpty && vm.folders.isEmpty {
                SkeletonList()
            } else if vm.visibleFolders.isEmpty && vm.visibleFiles.isEmpty {
                ContentUnavailableView("No Files Available", systemImage: "folder", description: Text("This folder or course is empty."))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if vm.currentFolderId != nil {
                        breadcrumbBar
                        Divider()
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(vm.visibleFolders, id: \.id) { folder in
                                FolderRow(folder: folder) {
                                    vm.currentFolderId = folder.id
                                }
                            }

                            ForEach(vm.visibleFiles, id: \.id) { file in
                                FileRow(
                                    file: file,
                                    isSelected: vm.selectedFileId == file.id,
                                    onSelect: { vm.selectedFileId = file.id },
                                    onDownload: {
                                        Task { await vm.downloadFile(file, session: session) }
                                    },
                                    onPreview: {
                                        vm.previewFile(file, session: session)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .quickLookPreview($vm.previewURL)
        .task(id: courseId) {
            await vm.load(session: session, courseId: courseId)
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 8) {
            Button {
                vm.currentFolderId = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "house")
                    Text("Root")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(Color.inkTertiary)

            if let currentFolder = vm.folders.first(where: { $0.id == vm.currentFolderId }) {
                Text(currentFolder.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.inkPrimary.opacity(0.03))
    }
}
