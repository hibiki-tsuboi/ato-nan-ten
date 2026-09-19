import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            "ごほうびプラスのバックアップとして読み込めません。元のiPhoneでエクスポートし直してください。"
        case .unsupportedVersion:
            "このバックアップの形式には対応していません。アプリを最新版に更新してください。"
        case .fileTooLarge:
            "ファイルが大きすぎます。50 MB以下のバックアップを選んでください。"
        }
    }
}

@MainActor
enum BackupService {
    static func snapshot(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        date: Date = .now
    ) throws -> BackupArchive {
        try context.save()
        let goals = try context.fetch(FetchDescriptor<RewardGoal>()).map(RewardGoalRecord.init)
        let archive = BackupArchive(
            exportedAt: date,
            settings: BackupSettings(defaults: defaults, goalIDs: Set(goals.map(\.id))),
            children: try context.fetch(FetchDescriptor<ChildProfile>()).map(ChildProfileRecord.init),
            goals: goals,
            tasks: try context.fetch(FetchDescriptor<TaskItem>()).map(TaskItemRecord.init),
            requests: try context.fetch(FetchDescriptor<CompletionRequest>()).map(CompletionRequestRecord.init),
            histories: try context.fetch(FetchDescriptor<PointHistory>()).map(PointHistoryRecord.init),
            redemptions: try context.fetch(FetchDescriptor<RewardRedemption>()).map(RewardRedemptionRecord.init),
            achievements: try context.fetch(FetchDescriptor<DailyAchievement>()).map(DailyAchievementRecord.init)
        )
        try validate(archive)
        return archive
    }

    static func encode(_ archive: BackupArchive) throws -> Data {
        try validate(archive)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= BackupFileReader.maximumSize else { throw BackupError.fileTooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        guard data.count <= BackupFileReader.maximumSize else { throw BackupError.fileTooLarge }
        do {
            // Check the envelope first so a future schema produces an actionable error.
            let header = try JSONDecoder().decode(Header.self, from: data)
            guard header.format == BackupArchive.formatIdentifier else { throw BackupError.invalidFile }
            guard header.version == BackupArchive.currentVersion else { throw BackupError.unsupportedVersion }
            let archive = try JSONDecoder().decode(BackupArchive.self, from: data)
            try validate(archive)
            return archive
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidFile
        }
    }

    static func restore(
        _ archive: BackupArchive,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        try validate(archive)
        // Commit existing edits before opening the replacement transaction.
        try context.save()
        // A failed SwiftData save can leave cached replacement models even after rollback.
        // Use a disposable context so the displayed data stays intact on failure.
        let replacement = ModelContext(context.container)
        replacement.autosaveEnabled = false

        do {
            // Delete individual objects: bulk deletion bypasses rollback on some stores.
            try deleteAll(CompletionRequest.self, in: replacement)
            try deleteAll(PointHistory.self, in: replacement)
            try deleteAll(RewardRedemption.self, in: replacement)
            try deleteAll(DailyAchievement.self, in: replacement)
            try deleteAll(TaskItem.self, in: replacement)
            try deleteAll(RewardGoal.self, in: replacement)
            try deleteAll(ChildProfile.self, in: replacement)

            archive.children.forEach { replacement.insert($0.makeModel()) }
            archive.goals.forEach { replacement.insert($0.makeModel()) }
            archive.tasks.forEach { replacement.insert($0.makeModel()) }
            archive.requests.forEach { replacement.insert($0.makeModel()) }
            archive.histories.forEach { replacement.insert($0.makeModel()) }
            archive.redemptions.forEach { replacement.insert($0.makeModel()) }
            archive.achievements.forEach { replacement.insert($0.makeModel()) }
            try replacement.save()
        } catch {
            replacement.rollback()
            throw error
        }

        // Settings must not change unless the entire database replacement succeeded.
        archive.settings.apply(to: defaults)
    }

    static func validate(_ archive: BackupArchive) throws {
        guard archive.format == BackupArchive.formatIdentifier else { throw BackupError.invalidFile }
        guard archive.version == BackupArchive.currentVersion else { throw BackupError.unsupportedVersion }
        try requireUniqueIDs(archive.children)
        try requireUniqueIDs(archive.goals)
        try requireUniqueIDs(archive.tasks)
        try requireUniqueIDs(archive.requests)
        try requireUniqueIDs(archive.histories)
        try requireUniqueIDs(archive.redemptions)
        try requireUniqueIDs(archive.achievements)
        let dates: [Date?] = [archive.exportedAt]
            + archive.children.map(\.createdAt)
            + archive.goals.flatMap { [$0.createdAt, $0.configuredDate, $0.timerEndsAt] }
            + archive.tasks.map(\.scheduledDate)
            + archive.requests.map(\.requestedAt)
            + archive.histories.map(\.createdAt)
            + archive.redemptions.map(\.redeemedAt)
            + archive.achievements.flatMap { [$0.achievedOn, $0.achievedAt] }
        guard dates.compactMap({ $0 }).allSatisfy(isValidDate) else { throw BackupError.invalidFile }

        let childIDs = Set(archive.children.map(\.id))
        let goalIDs = Set(archive.goals.map(\.id))
        if childIDs.isEmpty {
            // Older single-child data is migrated by ContentView after restoration.
            guard archive.goals.count <= 1,
                  archive.goals.allSatisfy({ $0.childID == nil }),
                  archive.tasks.allSatisfy({ $0.childID == nil }),
                  !archive.goals.isEmpty || archive.tasks.isEmpty else { throw BackupError.invalidFile }
        } else {
            let goalChildIDs = archive.goals.compactMap(\.childID)
            guard goalChildIDs.count == archive.goals.count,
                  goalChildIDs.count == childIDs.count,
                  Set(goalChildIDs) == childIDs,
                  archive.tasks.allSatisfy({ $0.childID.map(childIDs.contains) ?? false }) else {
                throw BackupError.invalidFile
            }
        }

        let points = 0...1_000_000_000
        guard archive.goals.allSatisfy({
            (1...99).contains($0.targetPoints) && points.contains($0.currentPoints)
                && ($0.durationMinutes.map { (1...1_000_000).contains($0) } ?? true)
        }), archive.tasks.allSatisfy({
            (1...99).contains($0.points) && (0...TaskItem.everyWeekday).contains($0.weekdayMask)
                && ($0.dailyLimit.map { (1...1_000_000).contains($0) } ?? true)
        }), archive.requests.allSatisfy({
            (1...99).contains($0.points) && CompletionStatus(rawValue: $0.statusRawValue) != nil
        }), archive.histories.allSatisfy({
            (-1_000_000_000...1_000_000_000).contains($0.points)
                && PointHistoryType(rawValue: $0.typeRawValue) != nil
        }), archive.redemptions.allSatisfy({ points.contains($0.earnedPoints) }),
        archive.achievements.allSatisfy({ points.contains($0.earnedPoints) && (1...99).contains($0.targetPoints) }),
        (6...22).contains(archive.settings.dailyReminderHour),
        AppColorSchemeOption(rawValue: archive.settings.colorScheme) != nil,
        archive.settings.postponedAchievements.allSatisfy({ id, day in
            UUID(uuidString: id).map(goalIDs.contains) == true
                && isValidDate(Date(timeIntervalSinceReferenceDate: day))
        }) else { throw BackupError.invalidFile }

        // Historical entries may reference deleted tasks, rewards or children; keep those records.
    }

    private static func requireUniqueIDs<T: Identifiable>(_ records: [T]) throws {
        guard Set(records.map(\.id)).count == records.count else { throw BackupError.invalidFile }
    }

    private static func isValidDate(_ date: Date) -> Bool {
        // Years 1...9999 keep calendar and timer calculations in their supported range.
        (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }

    private struct Header: Decodable {
        let format: String
        let version: Int
    }
}
