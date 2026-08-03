import Foundation

public struct RubricRating: Codable {
    public let id: String
    public let description: String
    public let points: Double

    public init(id: String, description: String, points: Double) {
        self.id = id
        self.description = description
        self.points = points
    }
}

public struct RubricCriterion: Codable {
    public let id: String
    public let description: String
    public let points: Double
    public let ratings: [RubricRating]?

    public init(id: String, description: String, points: Double, ratings: [RubricRating]?) {
        self.id = id
        self.description = description
        self.points = points
        self.ratings = ratings
    }
}

public struct RubricAssessmentEntry: Codable {
    public let points: Double?
    public let comments: String?
    public let ratingId: String?

    public init(points: Double?, comments: String?, ratingId: String?) {
        self.points = points
        self.comments = comments
        self.ratingId = ratingId
    }
}

public struct RubricLine {
    public let criterionDescription: String
    public let possiblePoints: Double
    public let earnedPoints: Double?
    public let ratingLabel: String?
    public let comment: String?

    public init(criterionDescription: String, possiblePoints: Double, earnedPoints: Double?, ratingLabel: String?, comment: String?) {
        self.criterionDescription = criterionDescription
        self.possiblePoints = possiblePoints
        self.earnedPoints = earnedPoints
        self.ratingLabel = ratingLabel
        self.comment = comment
    }
}

public func formatRubricAssessment(criteria: [RubricCriterion], assessment: [String: RubricAssessmentEntry]) -> [RubricLine] {
    criteria.map { c in
        let entry = assessment[c.id]
        let ratingLabel = entry?.ratingId.flatMap { rid in c.ratings?.first { $0.id == rid }?.description }
        return RubricLine(criterionDescription: c.description, possiblePoints: c.points,
                          earnedPoints: entry?.points, ratingLabel: ratingLabel, comment: entry?.comments)
    }
}
