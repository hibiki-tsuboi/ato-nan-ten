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
            if goal.configuredDate == nil {
                goal.markConfigured(on: date, calendar: calendar)
                hasChanges = true
                continue
            }

            guard !goal.isConfigured(on: date, calendar: calendar) else { continue }
            if goal.currentPoints != 0 {
                goal.currentPoints = 0
                hasChanges = true
            }
        }

        for task in tasks where task.scheduledDate == nil && task.isEnabled {
            task.setScheduled(true, on: date, calendar: calendar)
            hasChanges = true
        }

        for request in requests where request.status == .pending {
            guard !calendar.isDate(request.requestedAt, inSameDayAs: date) else { continue }
            request.status = .rejected
            hasChanges = true
        }

        if hasChanges {
            try context.save()
        }
    }
}
