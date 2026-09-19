import Foundation

/// Versioned, model-independent snapshot. Dates keep their original precision and IDs stay stable.
struct BackupArchive: Codable, Equatable {
    static let currentVersion = 1
    static let formatIdentifier = "jp.hibiki.gohobiplus.backup"

    var format = formatIdentifier
    var version = currentVersion
    var exportedAt: Date
    var settings: BackupSettings
    var children: [ChildProfileRecord]
    var goals: [RewardGoalRecord]
    var tasks: [TaskItemRecord]
    var requests: [CompletionRequestRecord]
    var histories: [PointHistoryRecord]
    var redemptions: [RewardRedemptionRecord]
    var achievements: [DailyAchievementRecord]
}

struct ChildProfileRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var avatarEmoji: String
    var sortOrder: Int
    var createdAt: Date

    init(_ model: ChildProfile) {
        id = model.id
        name = model.name
        avatarEmoji = model.avatarEmoji
        sortOrder = model.sortOrder
        createdAt = model.createdAt
    }

    func makeModel() -> ChildProfile {
        ChildProfile(
            id: id,
            name: name,
            avatarEmoji: avatarEmoji,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}

struct RewardGoalRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var title: String
    var emoji: String
    var targetPoints: Int
    var currentPoints: Int
    var createdAt: Date
    var configuredDate: Date?
    var durationMinutes: Int?
    var timerEndsAt: Date?

    init(_ model: RewardGoal) {
        id = model.id
        childID = model.childID
        title = model.title
        emoji = model.emoji
        targetPoints = model.targetPoints
        currentPoints = model.currentPoints
        createdAt = model.createdAt
        configuredDate = model.configuredDate
        durationMinutes = model.durationMinutes
        timerEndsAt = model.timerEndsAt
    }

    func makeModel() -> RewardGoal {
        RewardGoal(
            id: id,
            childID: childID,
            title: title,
            emoji: emoji,
            targetPoints: targetPoints,
            currentPoints: currentPoints,
            createdAt: createdAt,
            configuredDate: configuredDate,
            durationMinutes: durationMinutes,
            timerEndsAt: timerEndsAt
        )
    }
}

struct TaskItemRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var title: String
    var emoji: String
    var points: Int
    var dailyLimit: Int?
    var isEnabled: Bool
    var sortOrder: Int
    var scheduledDate: Date?
    var weekdayMask: Int

    init(_ model: TaskItem) {
        id = model.id
        childID = model.childID
        title = model.title
        emoji = model.emoji
        points = model.points
        dailyLimit = model.dailyLimit
        isEnabled = model.isEnabled
        sortOrder = model.sortOrder
        scheduledDate = model.scheduledDate
        weekdayMask = model.weekdayMask
    }

    func makeModel() -> TaskItem {
        TaskItem(
            id: id,
            childID: childID,
            title: title,
            emoji: emoji,
            points: points,
            dailyLimit: dailyLimit,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            scheduledDate: scheduledDate,
            weekdayMask: weekdayMask
        )
    }
}

struct CompletionRequestRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var taskID: UUID
    var taskTitle: String
    var taskEmoji: String
    var points: Int
    var requestedAt: Date
    var statusRawValue: String

    init(_ model: CompletionRequest) {
        id = model.id
        childID = model.childID
        taskID = model.taskID
        taskTitle = model.taskTitle
        taskEmoji = model.taskEmoji
        points = model.points
        requestedAt = model.requestedAt
        statusRawValue = model.statusRawValue
    }

    func makeModel() -> CompletionRequest {
        CompletionRequest(
            id: id,
            childID: childID,
            taskID: taskID,
            taskTitle: taskTitle,
            taskEmoji: taskEmoji,
            points: points,
            requestedAt: requestedAt,
            status: CompletionStatus(rawValue: statusRawValue) ?? .pending
        )
    }
}

struct PointHistoryRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var title: String
    var points: Int
    var createdAt: Date
    var typeRawValue: String

    init(_ model: PointHistory) {
        id = model.id
        childID = model.childID
        title = model.title
        points = model.points
        createdAt = model.createdAt
        typeRawValue = model.typeRawValue
    }

    func makeModel() -> PointHistory {
        PointHistory(
            id: id,
            childID: childID,
            title: title,
            points: points,
            createdAt: createdAt,
            type: PointHistoryType(rawValue: typeRawValue) ?? .task
        )
    }
}

struct RewardRedemptionRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var rewardTitle: String
    var rewardEmoji: String
    var earnedPoints: Int
    var redeemedAt: Date

    init(_ model: RewardRedemption) {
        id = model.id
        childID = model.childID
        rewardTitle = model.rewardTitle
        rewardEmoji = model.rewardEmoji
        earnedPoints = model.earnedPoints
        redeemedAt = model.redeemedAt
    }

    func makeModel() -> RewardRedemption {
        RewardRedemption(
            id: id,
            childID: childID,
            rewardTitle: rewardTitle,
            rewardEmoji: rewardEmoji,
            earnedPoints: earnedPoints,
            redeemedAt: redeemedAt
        )
    }
}

struct DailyAchievementRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var childID: UUID?
    var goalID: UUID?
    var rewardTitle: String
    var rewardEmoji: String
    var earnedPoints: Int
    var targetPoints: Int
    var achievedOn: Date
    var achievedAt: Date

    init(_ model: DailyAchievement) {
        id = model.id
        childID = model.childID
        goalID = model.goalID
        rewardTitle = model.rewardTitle
        rewardEmoji = model.rewardEmoji
        earnedPoints = model.earnedPoints
        targetPoints = model.targetPoints
        achievedOn = model.achievedOn
        achievedAt = model.achievedAt
    }

    func makeModel() -> DailyAchievement {
        DailyAchievement(
            id: id,
            childID: childID,
            goalID: goalID,
            rewardTitle: rewardTitle,
            rewardEmoji: rewardEmoji,
            earnedPoints: earnedPoints,
            targetPoints: targetPoints,
            achievedOn: achievedOn,
            achievedAt: achievedAt
        )
    }
}
