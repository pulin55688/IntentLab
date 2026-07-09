//
//  IntentLabAppShortcuts.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import AppIntents

// AppShortcut 是 Siri / Shortcuts / Spotlight 能發現這些 AppIntent 的入口。
struct IntentLabAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListRideSchedulesIntent(),
            phrases: [
                "List all ride schedules in \(.applicationName)",
                "Show all ride schedules in \(.applicationName)"
            ],
            shortTitle: "Ride Schedules",
            systemImageName: "car"
        )

        AppShortcut(
            intent: FindRideScheduleIntent(),
            phrases: [
                "Find \(\.$schedule) in \(.applicationName)",
                "Show \(\.$schedule) ride schedule in \(.applicationName)"
            ],
            shortTitle: "Find Ride",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: GetRideSchedulePaymentMethodIntent(),
            phrases: [
                "What is the payment method for \(\.$schedule) in \(.applicationName)",
                "Show \(\.$schedule) payment method in \(.applicationName)",
                "Find \(\.$schedule) payment method in \(.applicationName)",
                "Get \(\.$schedule) payment method in \(.applicationName)"
            ],
            shortTitle: "Ride Payment",
            systemImageName: "creditcard"
        )

        AppShortcut(
            intent: SearchRideSchedulesIntent(),
            phrases: [
                "Search ride schedules in \(.applicationName)"
            ],
            shortTitle: "Search Rides",
            systemImageName: "text.magnifyingglass"
        )

        // Note intent 的實作放在 NoteAppIntents.swift，但 shortcut 仍集中註冊在這裡。
        // App Intents metadata processor 要求 target 內只能有一個 AppShortcutsProvider，
        // 且 AppShortcut 必須直接在 provider 裡初始化，拆成另一個 provider 或 helper array 會無法產生 metadata。
        AppShortcut(
            intent: CreateLabNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "Create an \(.applicationName) note"
            ],
            shortTitle: "Create Note",
            systemImageName: "note.text.badge.plus"
        )

        AppShortcut(
            intent: UpdateLabNoteIntent(),
            phrases: [
                "Update \(\.$target) note in \(.applicationName)",
                "Edit \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Update Note",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: AppendToLabNoteIntent(),
            phrases: [
                "Add text to \(\.$target) note in \(.applicationName)",
                "Append text to \(\.$target) note in \(.applicationName)"
            ],
            shortTitle: "Append Note",
            systemImageName: "text.badge.plus"
        )

        AppShortcut(
            intent: FindLabNoteIntent(),
            phrases: [
                "Find \(\.$note) note in \(.applicationName)",
                "Show \(\.$note) note in \(.applicationName)"
            ],
            shortTitle: "Find Note",
            systemImageName: "note.text"
        )
    }
}
