import Foundation
import SwiftData
import Testing
@testable import AtoNanTen

@MainActor
struct PointServiceTests {
    @Test
    func pendingRequestBlocksAnotherRequest() {
        let task = TaskItem(title: "読書", emoji: "📖", points: 1, dailyLimit: 1)
        let request = CompletionRequest(
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points
        )

        #expect(PointService.availability(for: task, requests: [request]) == .pending)
    }

    @Test
    func dailyLimitCountsApprovedRequests() {
        let task = TaskItem(title: "宿題", emoji: "📚", points: 1, dailyLimit: 1)
        let request = CompletionRequest(
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points,
            status: .approved
        )

        #expect(PointService.availability(for: task, requests: [request]) == .limitReached)

        task.dailyLimit = nil
        #expect(PointService.availability(for: task, requests: [request]) == .available)
    }

    @Test
    func approvalAddsPointsAndHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let childID = UUID()
        let goal = RewardGoal(childID: childID, title: "ゲーム", emoji: "🎮", targetPoints: 5)
        let request = CompletionRequest(
            childID: childID,
            taskID: UUID(),
            taskTitle: "くもんの宿題",
            taskEmoji: "✏️",
            points: 2
        )
        context.insert(goal)
        context.insert(request)

        try PointService.approve(request, goal: goal, in: context)

        #expect(goal.currentPoints == 2)
        #expect(request.status == .approved)
        let histories = try context.fetch(FetchDescriptor<PointHistory>())
        #expect(histories.count == 1)
        #expect(histories.first?.points == 2)
        #expect(histories.first?.childID == childID)
    }

    @Test
    func completionRequestKeepsItsChildID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstChildID = UUID()
        let secondChildID = UUID()
        let firstTask = TaskItem(
            childID: firstChildID,
            title: "読書",
            emoji: "📖",
            points: 1
        )
        let secondTask = TaskItem(
            childID: secondChildID,
            title: "読書",
            emoji: "📖",
            points: 1
        )
        context.insert(firstTask)
        context.insert(secondTask)

        try PointService.requestCompletion(for: firstTask, in: context)

        let requests = try context.fetch(FetchDescriptor<CompletionRequest>())
        #expect(requests.count == 1)
        #expect(requests.first?.childID == firstChildID)
        #expect(requests.first?.childID != secondChildID)
    }

    @Test
    func redeemResetsPointsAndKeepsChallengeRecord() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let goal = RewardGoal(
            title: "アイス",
            emoji: "🍦",
            targetPoints: 5,
            currentPoints: 6
        )
        context.insert(goal)

        try PointService.redeem(goal: goal, in: context)

        #expect(goal.currentPoints == 0)
        let redemptions = try context.fetch(FetchDescriptor<RewardRedemption>())
        #expect(redemptions.count == 1)
        #expect(redemptions.first?.earnedPoints == 6)
    }

    @Test
    func taskIsShownOnlyOnItsScheduledDay() {
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let task = TaskItem(
            title: "くもん",
            emoji: "✏️",
            points: 2,
            scheduledDate: today
        )

        #expect(task.isScheduled(on: today, calendar: calendar))
        #expect(!task.isScheduled(on: tomorrow, calendar: calendar))
    }

    @Test
    func newDayResetsPointsAndRejectsOldPendingRequests() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let childID = UUID()
        let goal = RewardGoal(
            childID: childID,
            title: "ゲーム",
            emoji: "🎮",
            targetPoints: 5,
            currentPoints: 3,
            configuredDate: yesterday
        )
        let request = CompletionRequest(
            childID: childID,
            taskID: UUID(),
            taskTitle: "くもん",
            taskEmoji: "✏️",
            points: 2,
            requestedAt: yesterday
        )
        context.insert(goal)
        context.insert(request)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [],
            requests: [request],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(goal.currentPoints == 0)
        #expect(request.status == .rejected)
        let histories = try context.fetch(FetchDescriptor<PointHistory>())
        #expect(histories.isEmpty)
    }

    @Test
    func preparingTheSameDayKeepsPointsAndPendingRequests() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = RewardGoal(
            title: "アイス",
            emoji: "🍦",
            targetPoints: 5,
            currentPoints: 2,
            configuredDate: today
        )
        let request = CompletionRequest(
            taskID: UUID(),
            taskTitle: "読書",
            taskEmoji: "📖",
            points: 1,
            requestedAt: today
        )
        context.insert(goal)
        context.insert(request)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [],
            requests: [request],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(goal.currentPoints == 2)
        #expect(request.status == .pending)
    }

    @Test
    func legacyDataIsAdoptedAsTodaysChallengeWithoutLosingPoints() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = RewardGoal(
            title: "ゲーム",
            emoji: "🎮",
            targetPoints: 5,
            currentPoints: 3,
            configuredDate: nil
        )
        let visibleTask = TaskItem(title: "くもん", emoji: "✏️", points: 2)
        let hiddenTask = TaskItem(title: "読書", emoji: "📖", points: 1, isEnabled: false)
        context.insert(goal)
        context.insert(visibleTask)
        context.insert(hiddenTask)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [visibleTask, hiddenTask],
            requests: [],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(goal.currentPoints == 3)
        #expect(goal.isConfigured(on: today, calendar: calendar))
        #expect(visibleTask.isScheduled(on: today, calendar: calendar))
        #expect(!hiddenTask.isScheduled(on: today, calendar: calendar))
    }

    @Test
    func rewardCarriesOverToTheNextDayWithPointsReset() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let goal = RewardGoal(
            title: "ゲーム",
            emoji: "🎮",
            targetPoints: 5,
            currentPoints: 5,
            configuredDate: yesterday
        )
        context.insert(goal)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [],
            requests: [],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(goal.isConfigured(on: today, calendar: calendar))
        #expect(goal.currentPoints == 0)
        #expect(!goal.isAchieved)
        #expect(goal.title == "ゲーム")
        #expect(goal.emoji == "🎮")
        #expect(goal.targetPoints == 5)
    }

    @Test
    func visibleTasksCarryOverToTheNextDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let visibleTask = TaskItem(
            title: "くもん",
            emoji: "✏️",
            points: 2,
            scheduledDate: yesterday
        )
        let hiddenTask = TaskItem(
            title: "読書",
            emoji: "📖",
            points: 1,
            scheduledDate: yesterday
        )
        hiddenTask.setScheduled(false, on: yesterday, calendar: calendar)
        context.insert(visibleTask)
        context.insert(hiddenTask)

        try DailyChallengeService.prepareForToday(
            goals: [],
            tasks: [visibleTask, hiddenTask],
            requests: [],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(visibleTask.isScheduled(on: today, calendar: calendar))
        #expect(!hiddenTask.isScheduled(on: today, calendar: calendar))
    }

    @Test
    func visibleTasksCarryOverAfterSeveralUnusedDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let lastUsedDay = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 9, to: lastUsedDay)!
        let task = TaskItem(
            title: "おてつだい",
            emoji: "🧹",
            points: 1,
            scheduledDate: lastUsedDay
        )
        context.insert(task)

        try DailyChallengeService.prepareForToday(
            goals: [],
            tasks: [task],
            requests: [],
            in: context,
            date: today,
            calendar: calendar
        )

        #expect(task.isScheduled(on: today, calendar: calendar))
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: RewardGoal.self,
            TaskItem.self,
            CompletionRequest.self,
            PointHistory.self,
            RewardRedemption.self,
            configurations: configuration
        )
    }
}
