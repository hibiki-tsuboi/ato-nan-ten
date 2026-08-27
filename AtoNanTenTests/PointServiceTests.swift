import AudioToolbox
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
    func lateNightStaysOnTheSameChallengeDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let lateNight = day.addingTimeInterval(15.5 * 3600)
        let afterMidnight = day.addingTimeInterval(17 * 3600)
        let goal = RewardGoal(title: "ゲーム", emoji: "🎮", targetPoints: 5, currentPoints: 3)
        goal.markConfigured(on: day, calendar: calendar)
        let request = CompletionRequest(
            taskID: UUID(),
            taskTitle: "くもん",
            taskEmoji: "✏️",
            points: 2,
            requestedAt: lateNight
        )
        context.insert(goal)
        context.insert(request)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [],
            requests: [request],
            in: context,
            date: afterMidnight,
            calendar: calendar
        )

        #expect(goal.currentPoints == 3)
        #expect(goal.isConfigured(on: afterMidnight, calendar: calendar))
        #expect(request.status == .pending)
    }

    @Test
    func challengeDayRollsOverAtFourInTheMorning() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let lateNight = day.addingTimeInterval(15.5 * 3600)
        let earlyMorning = day.addingTimeInterval(20.5 * 3600)
        let goal = RewardGoal(title: "ゲーム", emoji: "🎮", targetPoints: 5, currentPoints: 3)
        goal.markConfigured(on: day, calendar: calendar)
        let request = CompletionRequest(
            taskID: UUID(),
            taskTitle: "くもん",
            taskEmoji: "✏️",
            points: 2,
            requestedAt: lateNight
        )
        context.insert(goal)
        context.insert(request)

        try DailyChallengeService.prepareForToday(
            goals: [goal],
            tasks: [],
            requests: [request],
            in: context,
            date: earlyMorning,
            calendar: calendar
        )

        #expect(goal.currentPoints == 0)
        #expect(goal.isConfigured(on: earlyMorning, calendar: calendar))
        #expect(request.status == .rejected)
    }

    @Test
    func approvedTaskStaysDoneAfterMidnight() {
        let calendar = utcCalendar()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let lateNight = day.addingTimeInterval(15.5 * 3600)
        let afterMidnight = day.addingTimeInterval(17 * 3600)
        let task = TaskItem(title: "宿題", emoji: "📚", points: 1, dailyLimit: 1)
        let request = CompletionRequest(
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points,
            requestedAt: lateNight,
            status: .approved
        )

        #expect(
            PointService.availability(
                for: task,
                requests: [request],
                on: afterMidnight,
                calendar: calendar
            ) == .limitReached
        )
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
        hiddenTask.setEnabled(false, on: yesterday, calendar: calendar)
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

    @Test
    func taskAppearsOnlyOnSelectedWeekdays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let friday = Date(timeIntervalSince1970: 1_800_000_000)
        let saturday = calendar.date(byAdding: .day, value: 1, to: friday)!
        let task = TaskItem(
            title: "ピアノ",
            emoji: "🎹",
            points: 2,
            weekdayMask: 1 << 5
        )
        context.insert(task)

        try DailyChallengeService.prepareForToday(
            goals: [], tasks: [task], requests: [], in: context, date: friday, calendar: calendar
        )
        #expect(task.isScheduled(on: friday, calendar: calendar))

        try DailyChallengeService.prepareForToday(
            goals: [], tasks: [task], requests: [], in: context, date: saturday, calendar: calendar
        )
        #expect(!task.isScheduled(on: saturday, calendar: calendar))
        #expect(task.isEnabled)
    }

    @Test
    func streakCountsConsecutiveAchievedDays() {
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today)!
        }

        #expect(StreakCalculator.currentStreak(
            achievedDays: [day(0), day(-1), day(-2)], on: today, calendar: calendar
        ) == 3)

        #expect(StreakCalculator.currentStreak(
            achievedDays: [day(-1), day(-2)], on: today, calendar: calendar
        ) == 2)

        #expect(StreakCalculator.currentStreak(
            achievedDays: [day(0), day(-2)], on: today, calendar: calendar
        ) == 1)

        #expect(StreakCalculator.currentStreak(achievedDays: [], on: today, calendar: calendar) == 0)
    }

    @Test
    func achievementIsRecordedOncePerDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = RewardGoal(title: "ゲーム", emoji: "🎮", targetPoints: 2, currentPoints: 2)
        context.insert(goal)

        #expect(PointService.recordAchievementIfNeeded(goal: goal, in: context, date: today, calendar: calendar))
        try context.save()
        #expect(!PointService.recordAchievementIfNeeded(goal: goal, in: context, date: today, calendar: calendar))

        let achievements = try context.fetch(FetchDescriptor<DailyAchievement>())
        #expect(achievements.count == 1)
        #expect(achievements.first?.earnedPoints == 2)
    }

    @Test
    func completingWithoutApprovalAddsPointsImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let childID = UUID()
        let goal = RewardGoal(childID: childID, title: "アイス", emoji: "🍦", targetPoints: 5)
        let task = TaskItem(childID: childID, title: "読書", emoji: "📖", points: 2)
        context.insert(goal)
        context.insert(task)

        try PointService.completeWithoutApproval(task: task, goal: goal, in: context)

        #expect(goal.currentPoints == 2)
        let requests = try context.fetch(FetchDescriptor<CompletionRequest>())
        #expect(requests.count == 1)
        #expect(requests.first?.status == .approved)
        let histories = try context.fetch(FetchDescriptor<PointHistory>())
        #expect(histories.count == 1)
    }

    @Test
    func soundFilesAreBundledAndLoadable() throws {
        for sound in AppSound.allCases {
            let url = try #require(
                Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                "\(sound.rawValue).wav がアプリのバンドルに入っていません"
            )
            var soundID: SystemSoundID = 0
            #expect(AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError)
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }

    @Test
    func rewardDurationIsReadFromTheTitle() {
        #expect(RewardDuration.minutes(in: "ゲーム 30ぷん") == 30)
        #expect(RewardDuration.minutes(in: "Switch 30分") == 30)
        #expect(RewardDuration.minutes(in: "YouTube 15 分") == 15)
        #expect(RewardDuration.minutes(in: "アイス") == nil)
        #expect(RewardDuration.minutes(in: "999分") == nil)
        #expect(RewardDuration.text(for: 30) == "30分")
        #expect(RewardDuration.text(for: 60) == "1時間")
    }

    @Test
    func expiredRewardTimerIsClearedOnPrepare() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let finished = RewardGoal(title: "ゲーム", emoji: "🎮", targetPoints: 5, durationMinutes: 30)
        finished.markConfigured(on: now, calendar: calendar)
        finished.timerEndsAt = now.addingTimeInterval(-60)
        let running = RewardGoal(title: "アイス", emoji: "🍦", targetPoints: 5, durationMinutes: 30)
        running.markConfigured(on: now, calendar: calendar)
        running.timerEndsAt = now.addingTimeInterval(600)
        context.insert(finished)
        context.insert(running)

        try DailyChallengeService.prepareForToday(
            goals: [finished, running],
            tasks: [],
            requests: [],
            in: context,
            date: now,
            calendar: calendar
        )

        #expect(finished.timerEndsAt == nil)
        #expect(running.isTimerRunning(at: now))
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
            DailyAchievement.self,
            configurations: configuration
        )
    }
}
