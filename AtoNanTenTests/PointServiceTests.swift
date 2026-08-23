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
