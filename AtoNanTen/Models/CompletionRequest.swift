import Foundation
import SwiftData

enum CompletionStatus: String {
    case pending
    case approved
    case rejected
}

@Model
final class CompletionRequest {
    var id: UUID
    var childID: UUID?
    var taskID: UUID
    var taskTitle: String
    var taskEmoji: String
    var points: Int
    var requestedAt: Date
    var statusRawValue: String

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        taskID: UUID,
        taskTitle: String,
        taskEmoji: String,
        points: Int,
        requestedAt: Date = .now,
        status: CompletionStatus = .pending
    ) {
        self.id = id
        self.childID = childID
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.taskEmoji = taskEmoji
        self.points = points
        self.requestedAt = requestedAt
        self.statusRawValue = status.rawValue
    }

    var status: CompletionStatus {
        get { CompletionStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }
}
