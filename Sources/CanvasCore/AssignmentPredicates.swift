import Foundation

public func isAssignmentMissing(dueAt: Date?, submissionWorkflowState: String?, missingFlag: Bool?, now: Date) -> Bool {
    if missingFlag == true { return true }
    guard let due = dueAt, due < now else { return false }
    return submissionWorkflowState == nil || submissionWorkflowState == "unsubmitted"
}

public enum AssignmentFilter: String, CaseIterable { case upcoming, missing, graded, all }

public func assignmentMatchesFilter(_ filter: AssignmentFilter, dueAt: Date?, workflowState: String?,
                                    score: Double?, missingFlag: Bool?, now: Date) -> Bool {
    switch filter {
    case .all: return true
    case .missing: return isAssignmentMissing(dueAt: dueAt, submissionWorkflowState: workflowState, missingFlag: missingFlag, now: now)
    case .graded: return workflowState == "graded" && score != nil
    case .upcoming: return (dueAt.map { $0 >= now }) ?? false
    }
}
