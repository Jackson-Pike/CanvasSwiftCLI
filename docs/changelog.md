# Changelog

## 2026-06-26

### UI
- Replaced transparent/material backgrounds in `CourseDetailView` and `CalculatorView` with solid `Color.systemBackground` to match the course list card style
- Fixed loading and error states in `CourseDetailView` — were rendering on `Color.clear`, now use `Color.systemBackground`

### Dev Experience
- `KeychainHelper` uses `UserDefaults` in `DEBUG` builds instead of Keychain, eliminating the macOS password prompt on every rebuild. Release builds still use Keychain.

### Course Stream (new)
New section in `CourseDetailView` below the Open Calculator button. Sections appear only when they have data.

**Awaiting Grade** (up to 2)
Submissions where the grade is not yet visible: `workflow_state == "submitted"`, `"pending_review"`, or `"graded"` with `score == null` (muted grades).

**Upcoming** (up to 2)
Assignments with a future due date and no active submission, sorted soonest first.

**Recently Graded** (up to 2)
Submissions with `workflow_state == "graded"` and a non-null score, sorted by `graded_at` descending.

**Recent Feedback** (up to 3)
Instructor comments from `submission_comments`, sorted newest first. Student's own comments are excluded by comparing `comment.author_id` to `submission.user_id`.

### Canvas API
- Added `include[]=submission_comments` to the submissions fetch — no extra network request
- Extended `Submission` model: `userId`, `gradedAt`, `submittedAt`, `submissionComments`
- Added `SubmissionComment` model: `authorId`, `authorName`, `comment`, `createdAt`

### Bug Fixes
- Course stream "Recently Graded" no longer shows assignments with a muted/hidden grade (`score == null`)
