//
//  IntentLabApp.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import AppIntents
import CoreSpotlight
import Foundation

// AppEntity 是 App 內資料提供給系統看的表示法。
// IndexedEntity 則再多一層能力：這筆資料可以被 Spotlight / semantic index 收錄。
struct RideScheduleEntity: IndexedEntity {
    let schedule: RideSchedule

    init(schedule: RideSchedule) {
        self.schedule = schedule
    }

    // id 必須穩定，系統會用它在之後重新找回同一筆 entity。
    var id: String {
        schedule.id
    }

    // title 是 Spotlight 結果與語意索引最重要的文字欄位。
    @ComputedProperty(indexingKey: \.title)
    var name: String {
        schedule.name
    }

    // 這些欄位提供給 Shortcuts / AppIntentsTesting 讀取，也可作為系統理解 entity 的輔助資訊。
    @ComputedProperty
    var pickupAddress: String {
        schedule.pickupAddress
    }

    @ComputedProperty
    var dropoffAddress: String {
        schedule.dropoffAddress
    }

    @ComputedProperty
    var paymentMethod: String {
        schedule.paymentMethod
    }

    // textContent 是給 Spotlight / semantic index 搜尋用的整合文字。
    // 這裡放入 aliases，讓 office、airport 這類非完整名稱也有機會搜尋到對應行程。
    @ComputedProperty(indexingKey: \.textContent)
    var searchableContent: String {
        schedule.searchableText
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Ride Schedule"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(pickupAddress) to \(dropoffAddress) · \(paymentMethod)"
        )
    }

    // Shortcuts 或 Siri 需要把文字 / id 解析回 RideScheduleEntity 時，會使用這個 query。
    static var defaultQuery = RideScheduleEntityQuery()
}

// 這個 query 是系統「找回 AppEntity」的入口。
// 它同時支援文字查詢、列出建議、列出全部資料，以及 Spotlight 要求重新索引。
struct RideScheduleEntityQuery: EntityStringQuery, EnumerableEntityQuery, IndexedEntityQuery {
    // 透過 id 找回 entity；常見於 Shortcuts 已經儲存過某個 entity 參數後再次執行。
    func entities(for identifiers: [RideScheduleEntity.ID]) async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules
            .filter { identifiers.contains($0.id) }
            .map(RideScheduleEntity.init(schedule:))
    }

    // 透過使用者輸入的文字找 entity；例如 AppIntentsTesting 傳入 "Go to Work" 或 "office"。
    func entities(matching string: String) async throws -> [RideScheduleEntity] {
        RideScheduleStore.schedules(matching: string)
            .map(RideScheduleEntity.init(schedule:))
    }

    // Shortcuts 參數選單會用這裡提供可選項目。
    func suggestedEntities() async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
    }

    // EnumerableEntityQuery 需要列出全部 entity，方便系統做完整列舉或測試。
    func allEntities() async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
    }

    // IndexedEntityQuery 讓系統可以要求 App 重新索引指定幾筆資料。
    func reindexEntities(
        for identifiers: [RideScheduleEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await RideScheduleIndexer.index(ids: identifiers)
    }

    // IndexedEntityQuery 讓系統可以要求 App 重新索引所有資料。
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await RideScheduleIndexer.indexAll()
    }
}

// 不帶參數的 action，用來驗證明確 phrase 是否能啟動 App Intent 並回傳全部資料。
struct ListRideSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "List Ride Schedules"
    static let description = IntentDescription("Lists every ride schedule in Intent Lab.")

    func perform() async throws -> some ReturnsValue<[RideScheduleEntity]> & ProvidesDialog {
        let entities = RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
        return .result(value: entities, dialog: "Intent Lab has \(entities.count) ride schedules.")
    }
}

// 帶 AppEntity 參數的 action，用來測試 Siri / Shortcuts 是否能把文字解析成指定行程。
struct FindRideScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Ride Schedule"
    static let description = IntentDescription("Finds one ride schedule by name.")

    @Parameter(title: "Ride Schedule", query: RideScheduleEntityQuery())
    var schedule: RideScheduleEntity

    // parameterSummary 會影響 Shortcuts 裡這個 action 的顯示句型。
    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$schedule)")
    }

    func perform() async throws -> some ReturnsValue<RideScheduleEntity> & ProvidesDialog {
        return .result(
            value: schedule,
            dialog: "\(schedule.name) goes from \(schedule.pickupAddress) to \(schedule.dropoffAddress) and uses \(schedule.paymentMethod)."
        )
    }
}

// 更窄的屬性查詢 action，用來測試 Siri 能不能先解析行程 entity，再回覆該行程的付款方式。
struct GetRideSchedulePaymentMethodIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Ride Schedule Payment Method"
    static let description = IntentDescription("Gets the payment method for a ride schedule.")

    @Parameter(title: "Ride Schedule", query: RideScheduleEntityQuery())
    var schedule: RideScheduleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$schedule) payment method")
    }

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        return .result(
            value: schedule.paymentMethod,
            dialog: "\(schedule.name) uses \(schedule.paymentMethod)."
        )
    }
}

// 帶純文字參數的 action，用來測試直接用文字搜尋 App 內資料。
struct SearchRideSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Ride Schedules"
    static let description = IntentDescription("Searches ride schedules by name, place, payment method, or alias.")

    @Parameter(title: "Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search ride schedules for \(\.$query)")
    }

    func perform() async throws -> some ReturnsValue<[RideScheduleEntity]> & ProvidesDialog {
        let entities = RideScheduleStore.schedules(matching: query)
            .map(RideScheduleEntity.init(schedule:))

        let dialog = entities.isEmpty
            ? "No ride schedules matched \(query)."
            : "Found \(entities.count) ride schedules for \(query)."

        return .result(value: entities, dialog: IntentDialog(stringLiteral: dialog))
    }
}

// 測試專用 intent：手動觸發 Spotlight / semantic index 更新。
// isDiscoverable = false 讓它不出現在一般使用者可見的 Shortcuts action 清單。
struct IndexRideSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Index Ride Schedules"
    static let description = IntentDescription("Indexes the sample ride schedules for Spotlight and semantic search.")
    static let isDiscoverable = false

    func perform() async throws -> some ReturnsValue<Int> & ProvidesDialog {
        let count = try await RideScheduleIndexer.indexAll()
        return .result(value: count, dialog: "Indexed \(count) ride schedules.")
    }
}
