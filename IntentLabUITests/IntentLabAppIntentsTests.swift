import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class IntentLabAppIntentsTests: XCTestCase {
    private let definitions = IntentDefinitions(bundleIdentifier: "devplaceholder.P9T2K2KN.IntentLab")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    func testEntityStringQueryFindsExactRideScheduleName() async throws {
        let results = try await rideScheduleEntity.entities(matching: "Go to Work")
        let names = try names(from: results)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(names.first, "Go to Work")
    }

    func testEntityStringQueryFindsAlias() async throws {
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
        let result = try await definitions.intents["FindRideScheduleIntent"]
            .makeIntent(schedule: "Go to Work")
            .run()

        let schedule: AnyAppEntity = try result.value
        let name: String = try schedule.name

        XCTAssertEqual(name, "Go to Work")
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

    func testIndexRideSchedulesIntentRuns() async throws {
        let result = try await definitions.intents["IndexRideSchedulesIntent"]
            .makeIntent()
            .run()

        let count: Int = try result.value
        XCTAssertEqual(count, 3)
    }

    func testSpotlightFindsIndexedRideScheduleName() async throws {
        try await indexRideSchedules()

        let results = try await rideScheduleEntity.spotlightQuery("Go to Work")
        let names = try names(from: results)

        XCTAssertTrue(names.contains("Go to Work"))
    }

    func testSpotlightFindsIndexedAlias() async throws {
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

    private func indexRideSchedules() async throws {
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
}
