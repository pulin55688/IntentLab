//
//  IntentLabApp.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import AppIntents
import Foundation
import CoreSpotlight

// 測試用的純資料模型；刻意不使用資料庫或 API，避免資料來源影響 App Intents 測試結果。
struct RideSchedule: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let pickupAddress: String
    let dropoffAddress: String
    let paymentMethod: String
    let aliases: [String]

    // 給 EntityStringQuery 和 Spotlight index 共用的搜尋文字。
    // aliases 用來模擬使用者不一定會講出完整行程名稱的情境，例如只說 office 或 airport。
    nonisolated var searchableText: String {
        ([name, pickupAddress, dropoffAddress, paymentMethod] + aliases)
            .joined(separator: " ")
    }
}

// 固定的假資料來源。這個實驗重點是 Siri / Shortcuts / Spotlight 行為，不是資料載入流程。
enum RideScheduleStore {
    nonisolated static let allSchedules: [RideSchedule] = [
        RideSchedule(
            id: "go-to-work",
            name: "Go to Work",
            pickupAddress: "Home",
            dropoffAddress: "Office",
            paymentMethod: "Corporate Card",
            aliases: ["work", "commute", "morning ride", "office", "ride to the office"]
        ),
        RideSchedule(
            id: "go-home",
            name: "Go Home",
            pickupAddress: "Office",
            dropoffAddress: "Home",
            paymentMethod: "Personal Card",
            aliases: ["home", "evening ride", "ride home", "after work"]
        ),
        RideSchedule(
            id: "airport-pickup",
            name: "Airport Pickup",
            pickupAddress: "Airport",
            dropoffAddress: "Hotel",
            paymentMethod: "Apple Pay",
            aliases: ["airport", "pickup", "hotel", "travel ride"]
        )
    ]

    // AppEntity 解析 id 時會走這類查詢，例如 Shortcuts 儲存了一個 entity 後重新執行。
    nonisolated static func schedule(id: String) -> RideSchedule? {
        allSchedules.first { $0.id == id }
    }

    // 文字查詢的核心邏輯；同時支援完整名稱、地址、付款方式和 aliases。
    nonisolated static func schedules(matching query: String) -> [RideSchedule] {
        let normalizedQuery = query.normalizedForSearch
        guard !normalizedQuery.isEmpty else {
            return allSchedules
        }

        return allSchedules.filter { schedule in
            schedule.searchableText.normalizedForSearch.contains(normalizedQuery)
                || normalizedQuery.contains(schedule.name.normalizedForSearch)
        }
    }
}

// 把 custom IndexedEntity 寫進 Spotlight / semantic index。
// Siri 和 Spotlight 是否能找到資料，會依賴這裡是否成功 index。
enum RideScheduleIndexer {
    @discardableResult
    static func indexAll() async throws -> Int {
        let entities = RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
        try await CSSearchableIndex.default().indexAppEntities(entities)
        return entities.count
    }

    @discardableResult
    static func index(ids: [RideSchedule.ID]) async throws -> Int {
        let entities = RideScheduleStore.allSchedules
            .filter { ids.contains($0.id) }
            .map(RideScheduleEntity.init(schedule:))

        try await CSSearchableIndex.default().indexAppEntities(entities)
        return entities.count
    }
}

extension String {
    // 讓測試字串比對穩定一點：忽略大小寫、重音符號和前後空白。
    nonisolated var normalizedForSearch: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
