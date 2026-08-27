import Foundation
import SwiftData

enum CompletionAvailability: Equatable {
    case available
    case pending
    case limitReached
}

@MainActor
enum PointService {
    static func availability(
        for task: TaskItem,
        requests: [CompletionRequest],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> CompletionAvailability {
        let relevantRequests = requests.filter {
            $0.taskID == task.id &&
                AppDay.isSameDay($0.requestedAt, date, calendar: calendar) &&
                $0.status != .rejected
        }

        if relevantRequests.contains(where: { $0.status == .pending }) {
            return .pending
        }
        if let dailyLimit = task.dailyLimit, relevantRequests.count >= dailyLimit {
            return .limitReached
        }
        return .available
    }

    static func requestCompletion(for task: TaskItem, in context: ModelContext) throws {
        context.insert(CompletionRequest(
            childID: task.childID,
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points
        ))
        try context.save()
    }

    static func approve(
        _ request: CompletionRequest,
        goal: RewardGoal,
        in context: ModelContext
    ) throws {
        guard request.status == .pending else { return }
        request.status = .approved
        goal.currentPoints += request.points
        context.insert(PointHistory(
            childID: request.childID,
            title: request.taskTitle,
            points: request.points,
            type: .task
        ))
        try context.save()
    }

    static func reject(_ request: CompletionRequest, in context: ModelContext) throws {
        guard request.status == .pending else { return }
        request.status = .rejected
        try context.save()
    }

    @discardableResult
    static func adjust(
        goal: RewardGoal,
        by requestedAdjustment: Int,
        note: String,
        in context: ModelContext
    ) throws -> Int {
        let newPoints = max(goal.currentPoints + requestedAdjustment, 0)
        let actualAdjustment = newPoints - goal.currentPoints
        guard actualAdjustment != 0 else { return 0 }

        goal.currentPoints = newPoints
        context.insert(PointHistory(
            childID: goal.childID,
            title: note.isEmpty ? "親によるポイント修正" : note,
            points: actualAdjustment,
            type: .manualAdjustment
        ))
        try context.save()
        return actualAdjustment
    }

    static func redeem(goal: RewardGoal, in context: ModelContext) throws {
        let earnedPoints = goal.currentPoints
        context.insert(RewardRedemption(
            childID: goal.childID,
            rewardTitle: goal.title,
            rewardEmoji: goal.emoji,
            earnedPoints: earnedPoints
        ))
        context.insert(PointHistory(
            childID: goal.childID,
            title: "ごほうびを受け取りました",
            points: -earnedPoints,
            type: .rewardReset
        ))
        goal.currentPoints = 0
        try context.save()
    }
}
