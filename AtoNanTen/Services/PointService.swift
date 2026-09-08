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
        let relevantRequests = todaysRequests(for: task, requests: requests, on: date, calendar: calendar)

        if relevantRequests.contains(where: { $0.status == .pending }) {
            return .pending
        }
        if let dailyLimit = task.dailyLimit, relevantRequests.count >= dailyLimit {
            return .limitReached
        }
        return .available
    }

    /// その日にあと何回できるか。上限なしの行動は nil を返す。
    /// 確認待ちの申請も消費済みとして数える。
    static func remainingCount(
        for task: TaskItem,
        requests: [CompletionRequest],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let dailyLimit = task.dailyLimit else { return nil }
        let used = todaysRequests(for: task, requests: requests, on: date, calendar: calendar).count
        return max(dailyLimit - used, 0)
    }

    /// その日に有効な申請（却下ぶんは数えない）。
    private static func todaysRequests(
        for task: TaskItem,
        requests: [CompletionRequest],
        on date: Date,
        calendar: Calendar
    ) -> [CompletionRequest] {
        requests.filter {
            $0.taskID == task.id &&
                AppDay.isSameDay($0.requestedAt, date, calendar: calendar) &&
                $0.status != .rejected
        }
    }

    @discardableResult
    static func requestCompletion(for task: TaskItem, in context: ModelContext) throws -> CompletionRequest {
        let request = CompletionRequest(
            childID: task.childID,
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points
        )
        context.insert(request)
        try context.save()
        return request
    }

    /// 承認なしモード用。申請を作らずにその場で加点する。
    static func completeWithoutApproval(
        task: TaskItem,
        goal: RewardGoal,
        in context: ModelContext,
        date: Date = .now
    ) throws {
        context.insert(CompletionRequest(
            childID: task.childID,
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points,
            requestedAt: date,
            status: .approved
        ))
        goal.currentPoints += task.points
        context.insert(PointHistory(
            childID: task.childID,
            title: task.title,
            points: task.points,
            type: .task
        ))
        recordAchievementIfNeeded(goal: goal, in: context, date: date)
        try context.save()
    }

    /// その日はじめて目標に届いたときだけ達成を記録する。
    @discardableResult
    static func recordAchievementIfNeeded(
        goal: RewardGoal,
        in context: ModelContext,
        date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard goal.isAchieved else { return false }

        let day = AppDay.start(of: date, calendar: calendar)
        let achievements = (try? context.fetch(FetchDescriptor<DailyAchievement>())) ?? []
        guard !achievements.contains(where: { $0.goalID == goal.id && $0.achievedOn == day }) else {
            return false
        }

        context.insert(DailyAchievement(
            childID: goal.childID,
            goalID: goal.id,
            rewardTitle: goal.title,
            rewardEmoji: goal.emoji,
            earnedPoints: goal.currentPoints,
            targetPoints: goal.targetPoints,
            achievedOn: day,
            achievedAt: date
        ))
        return true
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
        recordAchievementIfNeeded(goal: goal, in: context)
        NotificationService.cancelPendingApproval(requestID: request.id)
        try context.save()
    }

    static func reject(_ request: CompletionRequest, in context: ModelContext) throws {
        guard request.status == .pending else { return }
        request.status = .rejected
        NotificationService.cancelPendingApproval(requestID: request.id)
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
        recordAchievementIfNeeded(goal: goal, in: context)
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
