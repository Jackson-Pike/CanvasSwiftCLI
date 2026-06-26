import Foundation
import CanvasCore

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var enrollments: [Int: Enrollment] = [:]
    @Published var isLoading = false
    @Published var error: String?

    func fetch(client: APIClient) async {
        isLoading = true
        error = nil
        do {
            let fetched = try await client.courses()
            courses = fetched
            await withTaskGroup(of: (Int, Enrollment?).self) { group in
                for course in fetched {
                    group.addTask {
                        let e = try? await client.enrollments(courseId: course.id).first
                        return (course.id, e)
                    }
                }
                for await (id, enrollment) in group {
                    if let enrollment { self.enrollments[id] = enrollment }
                }
            }
        } catch let e as APIError {
            error = e.description
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func currentScore(for courseId: Int) -> Double? {
        enrollments[courseId]?.grades?.currentScore
    }
}
