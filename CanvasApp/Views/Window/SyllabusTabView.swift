import SwiftUI
import CanvasUI

/// No view model: the syllabus rides along on the existing course sync
/// (`upsertCourses` writes `syllabusBody`), so a direct store read is the whole job.
struct SyllabusTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @State private var syllabusBody: String?
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            if let body = syllabusBody, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RichTextView(html: body)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
            } else if didLoad {
                ContentUnavailableView {
                    Label("No Syllabus", systemImage: "doc.text")
                } description: {
                    Text("Syllabus not yet loaded — open the Grades tab to sync this course.")
                }
                .padding(.top, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvasBG)
        .task(id: courseId) {
            syllabusBody = (try? session.repository.course(id: courseId))?.syllabusBody
            didLoad = true
        }
    }
}
