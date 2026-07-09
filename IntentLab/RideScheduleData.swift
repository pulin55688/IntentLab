import AppIntents
import Foundation
import CoreSpotlight

struct RideSchedule: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let pickupAddress: String
    let dropoffAddress: String
    let paymentMethod: String
    let aliases: [String]

    nonisolated var searchableText: String {
        ([name, pickupAddress, dropoffAddress, paymentMethod] + aliases)
            .joined(separator: " ")
    }
}

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

    nonisolated static func schedule(id: String) -> RideSchedule? {
        allSchedules.first { $0.id == id }
    }

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
    nonisolated var normalizedForSearch: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
