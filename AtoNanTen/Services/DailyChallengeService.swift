import Foundation
import SwiftData

@MainActor
enum DailyChallengeService {
    static func prepareForToday(
        goals: [RewardGoal],
        tasks: [TaskItem],
        requests: [CompletionRequest],
        in context: ModelContext,
        date: Date = .now,
        calendar: Calendar = .current
    ) throws {
        var hasChanges = false

        for goal in goals {
            guard !goal.isConfigured(on: date, calendar: calendar) else { continue }

            if goal.configuredDate != nil, goal.currentPoints != 0 {
                goal.currentPoints = 0
            }
            goal.markConfigured(on: date, calendar: calendar)
            hasChanges = true
        }

        for task in tasks {
            if task.refreshSchedule(on: date, calendar: calendar) {
                hasChanges = true
            }
        }

        for request in requests where request.status == .pending {
            guard !AppDay.isSameDay(request.requestedAt, date, calendar: calendar) else { continue }
            request.status = .rejected
            hasChanges = true
        }

        if hasChanges {
            try context.save()
        }
    }
}
