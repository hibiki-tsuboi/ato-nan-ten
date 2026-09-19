import Foundation
import SwiftData
import Testing
@testable import AtoNanTen

@MainActor
struct BackupServiceTests {
    @Test
    func exportAndImportPreserveEveryRecordAndPreferenceAcrossDevices() throws {
        let source = try makeContainer()
        let destination = try makeContainer()
        let sourceDefaults = makeDefaults()
        let destinationDefaults = makeDefaults()
        defer {
            clear(sourceDefaults)
            clear(destinationDefaults)
        }
        seed(source.mainContext, defaults: sourceDefaults)
        let original = try BackupService.snapshot(in: source.mainContext, defaults: sourceDefaults)
        let data = try BackupService.encode(original)
        #expect(!String(decoding: data, as: UTF8.self).contains("parentPasscodeHash"))
        #expect(!String(decoding: data, as: UTF8.self).contains("isResettingData"))
        let decoded = try BackupService.decode(data)
        #expect(decoded == original)

        destinationDefaults.set(42.0, forKey: "postponedAchievement-\(UUID().uuidString)")
        seed(destination.mainContext, defaults: destinationDefaults)
        destinationDefaults.set("destination-passcode", forKey: "parentPasscodeHash")
        try BackupService.restore(decoded, in: destination.mainContext, defaults: destinationDefaults)
        let restored = try BackupService.snapshot(
            in: destination.mainContext, defaults: destinationDefaults, date: original.exportedAt
        )
        expectSameRecords(restored, original)
        #expect(destinationDefaults.string(forKey: "parentPasscodeHash") == "destination-passcode")
        #expect(destinationDefaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("postponedAchievement-")
        }.count == 1)

        // Re-import is replacement, so it never doubles points or history records.
        try BackupService.restore(decoded, in: destination.mainContext, defaults: destinationDefaults)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<ChildProfile>()) == 2)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<PointHistory>()) == 3)
    }

    @Test
    func invalidArchivesDoNotModifyExistingDataOrSettings() throws {
        let container = try makeContainer()
        let defaults = makeDefaults()
        defer { clear(defaults) }
        seed(container.mainContext, defaults: defaults)
        let original = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        var invalidCopies: [BackupArchive] = []
        var invalid = original
        invalid.version = 999
        invalidCopies.append(invalid)
        invalid = original
        invalid.children.append(invalid.children[0])
        invalidCopies.append(invalid)
        invalid = original
        invalid.goals[0].childID = UUID()
        invalidCopies.append(invalid)
        invalid = original
        invalid.requests[0].statusRawValue = "unknown"
        invalidCopies.append(invalid)
        invalid = original
        invalid.histories[0].typeRawValue = "unknown"
        invalidCopies.append(invalid)
        invalid = original
        invalid.goals[0].currentPoints = Int.max
        invalidCopies.append(invalid)
        invalid = original
        invalid.tasks[0].weekdayMask = -1
        invalidCopies.append(invalid)
        invalid = original
        invalid.settings.dailyReminderHour = 99
        invalidCopies.append(invalid)
        invalid = original
        invalid.goals[0].timerEndsAt = Date(timeIntervalSince1970: 1e100)
        invalidCopies.append(invalid)

        for var archive in invalidCopies {
            archive.settings.soundEnabled.toggle()
            #expect(throws: BackupError.self) {
                try BackupService.restore(archive, in: container.mainContext, defaults: defaults)
            }
            let after = try BackupService.snapshot(
                in: container.mainContext, defaults: defaults, date: original.exportedAt
            )
            expectSameRecords(after, original)
        }
    }

    @Test
    func malformedTruncatedUnrelatedAndFutureFilesAreRejected() throws {
        for text in ["", "{", "{}", "[]", "{\"format\":\"other-app\",\"version\":1}"] {
            #expect(throws: BackupError.self) { try BackupService.decode(Data(text.utf8)) }
        }
        let future = Data("{\"format\":\"jp.hibiki.gohobiplus.backup\",\"version\":999}".utf8)
        do {
            _ = try BackupService.decode(future)
            Issue.record("Future formats must be rejected")
        } catch BackupError.unsupportedVersion {
            // Version is checked before decoding fields whose schema might have changed.
        }
        #expect(throws: BackupError.self) {
            try BackupService.decode(Data(repeating: 0, count: BackupFileReader.maximumSize + 1))
        }
    }

    @Test
    func fileReaderLoadsAnExportedBackup() throws {
        let container = try makeContainer()
        let defaults = makeDefaults()
        defer { clear(defaults) }
        seed(container.mainContext, defaults: defaults)
        let original = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackupService.encode(original).write(to: url)
        let read = try BackupService.decode(BackupFileReader.read(from: url))
        #expect(read == original)
    }

    @Test
    func restorePersistsAfterOpeningANewDatabaseContext() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("backup.store"))
        let container = try makeContainer(configuration: configuration)
        let defaults = makeDefaults()
        defer { clear(defaults) }
        seed(container.mainContext, defaults: defaults)
        let original = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        var imported = original
        imported.children[0].name = "引き継いだ名前"
        imported.goals[0].currentPoints = 17
        try BackupService.restore(imported, in: container.mainContext, defaults: defaults)
        let reopened = ModelContext(container)
        expectSameRecords(
            try BackupService.snapshot(in: reopened, defaults: defaults, date: imported.exportedAt), imported
        )
    }

    @Test
    func readOnlyStoreFailurePreservesOriginalRecordsAndPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("backup.store")
        let writable = try makeContainer(configuration: ModelConfiguration(url: url))
        let defaults = makeDefaults()
        defer { clear(defaults) }
        seed(writable.mainContext, defaults: defaults)
        let original = try BackupService.snapshot(in: writable.mainContext, defaults: defaults)
        let readOnly = try makeContainer(configuration: ModelConfiguration(url: url, allowsSave: false))
        var imported = original
        imported.children[0].name = "保存できない変更"
        imported.settings.soundEnabled.toggle()
        #expect(throws: (any Error).self) {
            try BackupService.restore(imported, in: readOnly.mainContext, defaults: defaults)
        }
        let children = try readOnly.mainContext.fetch(FetchDescriptor<ChildProfile>())
        #expect(children.map(ChildProfileRecord.init).sorted { $0.id.uuidString < $1.id.uuidString }
            == original.children.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(defaults.bool(forKey: AppSettings.Key.soundEnabled) == original.settings.soundEnabled)
        #expect(!readOnly.mainContext.hasChanges)
    }

    @Test
    func oldBackupKeepsHistoryWhileDailyResetStillRunsAfterRestoration() throws {
        let container = try makeContainer()
        let defaults = makeDefaults()
        defer { clear(defaults) }
        seed(container.mainContext, defaults: defaults)
        let original = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        try BackupService.restore(original, in: container.mainContext, defaults: defaults)
        let goals = try container.mainContext.fetch(FetchDescriptor<RewardGoal>())
        let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        let requests = try container.mainContext.fetch(FetchDescriptor<CompletionRequest>())
        try DailyChallengeService.prepareForToday(
            goals: goals, tasks: tasks, requests: requests, in: container.mainContext,
            date: Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(86_400)
        )
        #expect(goals.allSatisfy { $0.currentPoints == 0 })
        #expect(requests.allSatisfy { $0.status != .pending })
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyAchievement>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PointHistory>()) == 3)
    }

    @Test
    func emptyAndLegacyBackupsCanBeRestored() throws {
        let container = try makeContainer()
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let empty = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        seed(container.mainContext, defaults: defaults)
        try BackupService.restore(empty, in: container.mainContext, defaults: defaults)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ChildProfile>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RewardGoal>()) == 0)
        container.mainContext.insert(RewardGoal(title: "昔のごほうび", emoji: "🎁", targetPoints: 5, configuredDate: nil))
        container.mainContext.insert(TaskItem(title: "昔の行動", emoji: "📚", points: 1, dailyLimit: nil))
        let legacy = try BackupService.snapshot(in: container.mainContext, defaults: defaults)
        try BackupService.restore(BackupService.decode(BackupService.encode(legacy)), in: container.mainContext, defaults: defaults)
        #expect(try container.mainContext.fetch(FetchDescriptor<RewardGoal>()).first?.configuredDate == nil)
    }

    private func seed(_ context: ModelContext, defaults: UserDefaults) {
        let date = Date(timeIntervalSince1970: 1_800_000_000.125)
        let first = ChildProfile(name: "はる", avatarEmoji: "🦁", sortOrder: 2, createdAt: date)
        let second = ChildProfile(name: "あき", avatarEmoji: "🐱", sortOrder: 5, createdAt: date)
        context.insert(first)
        context.insert(second)
        let goal = RewardGoal(
            childID: first.id, title: "ゲーム30ぷん", emoji: "🎮", targetPoints: 10,
            currentPoints: 12, createdAt: date, configuredDate: date,
            durationMinutes: 30, timerEndsAt: date.addingTimeInterval(600)
        )
        context.insert(goal)
        context.insert(RewardGoal(childID: second.id, title: "おやつ", emoji: "🍦", targetPoints: 3,
                                  createdAt: date, configuredDate: date))
        let task = TaskItem(childID: first.id, title: "宿題", emoji: "📖", points: 3, dailyLimit: 2,
                            isEnabled: false, sortOrder: 7, scheduledDate: date, weekdayMask: 0b0101010)
        context.insert(task)
        context.insert(TaskItem(childID: second.id, title: "お手伝い", emoji: "🧹", points: 1, dailyLimit: nil))
        for status in [CompletionStatus.pending, .approved, .rejected] {
            context.insert(CompletionRequest(childID: first.id, taskID: task.id, taskTitle: task.title,
                                             taskEmoji: task.emoji, points: 3, requestedAt: date, status: status))
        }
        for type in [PointHistoryType.task, .manualAdjustment, .rewardReset] {
            context.insert(PointHistory(childID: first.id, title: "記録", points: type == .task ? 3 : -2,
                                        createdAt: date, type: type))
        }
        context.insert(RewardRedemption(childID: first.id, rewardTitle: "前のごほうび", rewardEmoji: "🍭",
                                        earnedPoints: 8, redeemedAt: date))
        // Deleted profiles/goals can still have historical achievement records.
        context.insert(DailyAchievement(childID: UUID(), goalID: UUID(), rewardTitle: "達成", rewardEmoji: "🎉",
                                        earnedPoints: 9, targetPoints: 8, achievedOn: date, achievedAt: date))
        defaults.set(false, forKey: AppSettings.Key.requiresApproval)
        defaults.set(false, forKey: AppSettings.Key.soundEnabled)
        defaults.set(true, forKey: AppSettings.Key.pendingNotification)
        defaults.set(true, forKey: AppSettings.Key.dailyReminder)
        defaults.set(21, forKey: AppSettings.Key.dailyReminderHour)
        defaults.set("dark", forKey: AppSettings.Key.colorScheme)
        defaults.set(second.id.uuidString, forKey: "selectedChildID")
        defaults.set(true, forKey: "hasSeenParentModeHint")
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: "postponedAchievement-\(goal.id.uuidString)")
        defaults.set("do-not-export", forKey: "parentPasscodeHash")
        defaults.set(true, forKey: "isResettingData")
    }

    private func expectSameRecords(_ actual: BackupArchive, _ expected: BackupArchive) {
        #expect(actual.settings == expected.settings)
        #expect(actual.children.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.children.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.goals.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.goals.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.tasks.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.tasks.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.requests.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.requests.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.histories.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.histories.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.redemptions.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.redemptions.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(actual.achievements.sorted { $0.id.uuidString < $1.id.uuidString }
            == expected.achievements.sorted { $0.id.uuidString < $1.id.uuidString })
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "BackupServiceTests.\(UUID().uuidString)")!
    }

    private func clear(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    private func makeContainer(configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        try ModelContainer(
            for: ChildProfile.self, RewardGoal.self, TaskItem.self, CompletionRequest.self,
            PointHistory.self, RewardRedemption.self, DailyAchievement.self,
            configurations: configuration ?? ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
