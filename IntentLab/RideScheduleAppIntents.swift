import AppIntents
import CoreSpotlight
import Foundation

struct RideScheduleEntity: IndexedEntity {
    let schedule: RideSchedule

    init(schedule: RideSchedule) {
        self.schedule = schedule
    }

    var id: String {
        schedule.id
    }

    @ComputedProperty(indexingKey: \.title)
    var name: String {
        schedule.name
    }

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

    static var defaultQuery = RideScheduleEntityQuery()
}

struct RideScheduleEntityQuery: EntityStringQuery, EnumerableEntityQuery, IndexedEntityQuery {
    func entities(for identifiers: [RideScheduleEntity.ID]) async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules
            .filter { identifiers.contains($0.id) }
            .map(RideScheduleEntity.init(schedule:))
    }

    func entities(matching string: String) async throws -> [RideScheduleEntity] {
        RideScheduleStore.schedules(matching: string)
            .map(RideScheduleEntity.init(schedule:))
    }

    func suggestedEntities() async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
    }

    func allEntities() async throws -> [RideScheduleEntity] {
        RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
    }

    func reindexEntities(
        for identifiers: [RideScheduleEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await RideScheduleIndexer.index(ids: identifiers)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await RideScheduleIndexer.indexAll()
    }
}

struct ListRideSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "List Ride Schedules"
    static let description = IntentDescription("Lists every ride schedule in Intent Lab.")

    func perform() async throws -> some ReturnsValue<[RideScheduleEntity]> & ProvidesDialog {
        let entities = RideScheduleStore.allSchedules.map(RideScheduleEntity.init(schedule:))
        return .result(value: entities, dialog: "Intent Lab has \(entities.count) ride schedules.")
    }
}

struct FindRideScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Ride Schedule"
    static let description = IntentDescription("Finds one ride schedule by name.")

    @Parameter(title: "Ride Schedule", query: RideScheduleEntityQuery())
    var schedule: RideScheduleEntity

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

struct IndexRideSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Index Ride Schedules"
    static let description = IntentDescription("Indexes the sample ride schedules for Spotlight and semantic search.")
    static let isDiscoverable = false

    func perform() async throws -> some ReturnsValue<Int> & ProvidesDialog {
        let count = try await RideScheduleIndexer.indexAll()
        return .result(value: count, dialog: "Indexed \(count) ride schedules.")
    }
}

struct IntentLabAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListRideSchedulesIntent(),
            phrases: [
                "Show my ride schedules in \(.applicationName)",
                "Show \(.applicationName) ride schedules"
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
            intent: SearchRideSchedulesIntent(),
            phrases: [
                "Search ride schedules in \(.applicationName)"
            ],
            shortTitle: "Search Rides",
            systemImageName: "text.magnifyingglass"
        )
    }
}
