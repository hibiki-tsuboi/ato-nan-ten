//
//  ContentView.swift
//  AtoNanTen
//
//  Created by Hibiki Tsuboi on 2026/08/23.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @Query(sort: \RewardGoal.createdAt) private var goals: [RewardGoal]

    var body: some View {
        Group {
            if children.isEmpty && goals.isEmpty {
                SetupFlowView()
            } else if children.isEmpty {
                ProgressView("データを準備しています…")
                    .task { migrateLegacyData() }
            } else {
                FamilyHomeView()
            }
        }
        .preferredColorScheme(.light)
    }

    private func migrateLegacyData() {
        guard children.isEmpty, !goals.isEmpty else { return }

        let child = ChildProfile(name: "こども", avatarEmoji: "🧒")
        modelContext.insert(child)
        goals.filter { $0.childID == nil }.forEach { $0.childID = child.id }

        if let tasks = try? modelContext.fetch(FetchDescriptor<TaskItem>()) {
            tasks.filter { $0.childID == nil }.forEach { $0.childID = child.id }
        }
        if let requests = try? modelContext.fetch(FetchDescriptor<CompletionRequest>()) {
            requests.filter { $0.childID == nil }.forEach { $0.childID = child.id }
        }
        if let histories = try? modelContext.fetch(FetchDescriptor<PointHistory>()) {
            histories.filter { $0.childID == nil }.forEach { $0.childID = child.id }
        }
        if let redemptions = try? modelContext.fetch(FetchDescriptor<RewardRedemption>()) {
            redemptions.filter { $0.childID == nil }.forEach { $0.childID = child.id }
        }
        try? modelContext.save()
    }
}

private struct FamilyHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @Query(sort: \RewardGoal.createdAt) private var goals: [RewardGoal]
    @Query private var tasks: [TaskItem]
    @Query private var requests: [CompletionRequest]
    @AppStorage("selectedChildID") private var selectedChildID = ""
    @State private var currentDate = Date.now

    private var selectedChild: ChildProfile? {
        children.first { $0.id.uuidString == selectedChildID } ?? children.first
    }

    var body: some View {
        Group {
            if let child = selectedChild,
               let goal = goals.first(where: { $0.childID == child.id }) {
                ChildHomeView(
                    child: child,
                    goal: goal,
                    siblings: children,
                    date: currentDate,
                    onSelectChild: { selectedChildID = $0.id.uuidString }
                )
                .id(childViewID(for: child))
                .task {
                    prepareForToday()
                    if selectedChildID != child.id.uuidString {
                        selectedChildID = child.id.uuidString
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        prepareForToday()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    prepareForToday()
                }
            } else {
                ContentUnavailableView(
                    "チャレンジがありません",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("親モードから子どもの設定を確認してください。")
                )
            }
        }
    }

    private func childViewID(for child: ChildProfile) -> String {
        let day = AppDay.start(of: currentDate).timeIntervalSinceReferenceDate
        return "\(child.id.uuidString)-\(day)"
    }

    private func prepareForToday() {
        let now = Date.now
        try? DailyChallengeService.prepareForToday(
            goals: goals,
            tasks: tasks,
            requests: requests,
            in: modelContext,
            date: now
        )
        currentDate = now
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            ChildProfile.self,
            RewardGoal.self,
            TaskItem.self,
            CompletionRequest.self,
            PointHistory.self,
            RewardRedemption.self
        ], inMemory: true)
}
