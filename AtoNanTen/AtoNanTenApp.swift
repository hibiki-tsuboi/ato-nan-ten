//
//  AtoNanTenApp.swift
//  AtoNanTen
//
//  Created by Hibiki Tsuboi on 2026/08/23.
//

import SwiftData
import SwiftUI

@main
struct AtoNanTenApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // 起動引数 -demoScene があるときだけスクリーンショット用の画面に差し替わる
            DemoScreenshotRoot()
            #else
            ContentView()
            #endif
        }
        .modelContainer(for: [
            ChildProfile.self,
            RewardGoal.self,
            TaskItem.self,
            CompletionRequest.self,
            PointHistory.self,
            RewardRedemption.self,
            DailyAchievement.self
        ])
    }
}
