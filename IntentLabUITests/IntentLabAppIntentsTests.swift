//
//  IntentLabApp.swift
//  IntentLabUITests
//
//  Created by Pulin on 2026/7/9.
//

import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class IntentLabAppIntentsTests: XCTestCase {
    // AppIntentsTesting 透過 bundle id 連到已安裝 app 的 App Intents metadata。
    private let definitions = IntentDefinitions(bundleIdentifier: "com.pulin55688.intetnlab")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        // 先啟動 App，確保 App Intents metadata、Shortcuts 參數和 Spotlight index 有機會被註冊。
        XCUIApplication().launch()
    }

    func testEntityStringQueryFindsExactRideScheduleName() async throws {
        // 驗證完整名稱能透過 EntityStringQuery 解析成 RideScheduleEntity。
        let results = try await rideScheduleEntity.entities(matching: "Go to Work")
        let names = try names(from: results)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(names.first, "Go to Work")
    }

    func testEntityStringQueryFindsAlias() async throws {
        // 驗證 aliases 也能解析到 entity，模擬使用者只說目的地或語意關鍵字。
        let results = try await rideScheduleEntity.entities(matching: "office")
        let names = try names(from: results)

        XCTAssertTrue(names.contains("Go to Work"))
    }

    func testSuggestedEntitiesReturnsAllRideSchedules() async throws {
        let results = try await rideScheduleEntity.suggestedEntities()
        let names = try names(from: results)

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(names.contains("Go to Work"))
        XCTAssertTrue(names.contains("Go Home"))
        XCTAssertTrue(names.contains("Airport Pickup"))
    }

    func testEntityIdentifiersResolveRideSchedule() async throws {
        let results = try await rideScheduleEntity.entities(identifiers: ["go-to-work"])
        let names = try names(from: results)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(names.first, "Go to Work")
    }

    func testListRideSchedulesIntentReturnsAllRideSchedules() async throws {
        let result = try await definitions.intents["ListRideSchedulesIntent"]
            .makeIntent()
            .run()

        let schedules: [AnyAppEntity] = try result.value
        XCTAssertEqual(schedules.count, 3)
    }

    func testFindRideScheduleIntentResolvesStringParameter() async throws {
        // AppIntentsTesting 會把 "Go to Work" 透過 query 解析成 RideScheduleEntity 參數。
        let result = try await definitions.intents["FindRideScheduleIntent"]
            .makeIntent(schedule: "Go to Work")
            .run()

        let schedule: AnyAppEntity = try result.value
        let name: String = try schedule.name

        XCTAssertEqual(name, "Go to Work")
    }

    func testGetRideSchedulePaymentMethodIntentReturnsPaymentMethod() async throws {
        // 驗證屬性查詢 intent：先解析 RideScheduleEntity，再回傳該行程的付款方式。
        let result = try await definitions.intents["GetRideSchedulePaymentMethodIntent"]
            .makeIntent(schedule: "Go to Work")
            .run()

        let paymentMethod: String = try result.value

        XCTAssertEqual(paymentMethod, "Corporate Card")
    }

    func testSearchRideSchedulesIntentReturnsMatchingRideSchedule() async throws {
        let result = try await definitions.intents["SearchRideSchedulesIntent"]
            .makeIntent(query: "airport")
            .run()

        let schedules: [AnyAppEntity] = try result.value
        let names = try names(from: schedules)

        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(names.first, "Airport Pickup")
    }

    func testLabNoteEntityStringQueryFindsNote() async throws {
        let results = try await labNoteEntity.entities(matching: "Trip Plan")
        let names = try attributedNames(from: results)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(names.first, "Trip Plan")
    }

    func testFindLabNoteIntentResolvesStringParameter() async throws {
        let result = try await definitions.intents["FindLabNoteIntent"]
            .makeIntent(note: "Trip Plan")
            .run()

        let note: AnyAppEntity = try result.value
        let name = try attributedName(from: note)

        XCTAssertEqual(name, "Trip Plan")
    }

    func testCreateLabNoteIntentCreatesNote() async throws {
        let result = try await definitions.intents["CreateLabNoteIntent"]
            .makeIntent(
                name: "Weekend Plan",
                content: "Pack bags and book airport pickup",
                isPinned: false
            )
            .run()

        let note: AnyAppEntity = try result.value
        let name = try attributedName(from: note)

        XCTAssertEqual(name, "Weekend Plan")
    }

    func testIndexRideSchedulesIntentRuns() async throws {
        let result = try await definitions.intents["IndexRideSchedulesIntent"]
            .makeIntent()
            .run()

        let count: Int = try result.value
        XCTAssertEqual(count, 3)
    }

    func testSpotlightFindsIndexedRideScheduleName() async throws {
        // 先執行 index intent，再驗證 Spotlight 能用 entity title 找到資料。
        try await indexRideSchedules()

        let results = try await rideScheduleEntity.spotlightQuery("Go to Work")
        let names = try names(from: results)

        XCTAssertTrue(names.contains("Go to Work"))
    }

    func testSpotlightFindsIndexedAlias() async throws {
        // 驗證 textContent 內的 alias 是否能進入 Spotlight / semantic index 搜尋。
        try await indexRideSchedules()

        let results = try await rideScheduleEntity.spotlightQuery("office")
        let names = try names(from: results)

        XCTAssertTrue(names.contains("Go to Work"))
    }

    func testSpotlightFindsIndexedAirportRide() async throws {
        try await indexRideSchedules()

        let results = try await rideScheduleEntity.spotlightQuery("airport")
        let names = try names(from: results)

        XCTAssertTrue(names.contains("Airport Pickup"))
    }

    private var rideScheduleEntity: AppEntityDefinition {
        definitions.entities["RideScheduleEntity"]
    }

    private var labNoteEntity: AppEntityDefinition {
        definitions.entities["LabNoteEntity"]
    }

    private func indexRideSchedules() async throws {
        // 統一走 App Intent 執行索引，讓測試路徑接近系統實際呼叫方式。
        _ = try await definitions.intents["IndexRideSchedulesIntent"]
            .makeIntent()
            .run()
    }

    private func names(from entities: [AnyAppEntity]) throws -> [String] {
        try entities.map { entity in
            let name: String = try entity.name
            return name
        }
    }

    private func attributedNames(from entities: [AnyAppEntity]) throws -> [String] {
        try entities.map(attributedName(from:))
    }

    private func attributedName(from entity: AnyAppEntity) throws -> String {
        let name: AttributedString = try entity.name
        return String(name.characters)
    }
}
