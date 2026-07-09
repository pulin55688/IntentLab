//
//  IntentLabApp.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import Foundation
import SwiftUI
import AppIntents

@main
struct IntentLabApp: App {
    init() {
        // 讓 Shortcuts 更新 entity 參數的建議值，例如 Find Ride Schedule 內可選的行程。
        IntentLabAppShortcuts.updateAppShortcutParameters()

        // App 啟動時先 index 一次，讓 Spotlight / semantic index 盡快有測試資料。
        Task {
            do {
                let rideCount = try await RideScheduleIndexer.indexAll()
                let noteCount = try await LabNoteIndexer.indexAll()
                print("[IntentLab] Indexed \(rideCount) ride schedules and \(noteCount) lab notes on launch.")
            } catch {
                print("[IntentLab] Failed to index launch data: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
