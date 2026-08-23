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
            ContentView()
        }
        .modelContainer(for: [
            ChildProfile.self,
            RewardGoal.self,
            TaskItem.self,
            CompletionRequest.self,
            PointHistory.self,
            RewardRedemption.self
        ])
    }
}
