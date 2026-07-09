import AppIntents
import SwiftUI

@main
struct IntentLabApp: App {
    init() {
        IntentLabAppShortcuts.updateAppShortcutParameters()

        Task {
            do {
                let count = try await RideScheduleIndexer.indexAll()
                print("[IntentLab] Indexed \(count) ride schedules on launch.")
            } catch {
                print("[IntentLab] Failed to index ride schedules on launch: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var indexStatus = "Ready to index sample ride schedules."

    var body: some View {
        NavigationStack {
            List {
                Section("Ride Schedules") {
                    ForEach(RideScheduleStore.allSchedules) { schedule in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(schedule.name)
                                .font(.headline)

                            LabeledContent("Pickup", value: schedule.pickupAddress)
                            LabeledContent("Dropoff", value: schedule.dropoffAddress)
                            LabeledContent("Payment", value: schedule.paymentMethod)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Spotlight Index") {
                    Button("Index Schedules") {
                        indexSchedules()
                    }

                    Text(indexStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Siri Exact Phrases") {
                    PhraseRow("Show my ride schedules in Intent Lab")
                    PhraseRow("Show Intent Lab ride schedules")
                    PhraseRow("Find Go to Work in Intent Lab")
                    PhraseRow("Show Go to Work ride schedule in Intent Lab")
                    PhraseRow("Search ride schedules in Intent Lab")
                }

                Section("Exploratory Phrases") {
                    PhraseRow("Do I have a ride to the office in Intent Lab?")
                    PhraseRow("What is my payment method for Go to Work in Intent Lab?")
                    PhraseRow("Show my airport pickup ride in Intent Lab")
                }
            }
            .navigationTitle("Intent Lab")
        }
    }

    private func indexSchedules() {
        indexStatus = "Indexing ride schedules..."

        Task {
            do {
                let count = try await RideScheduleIndexer.indexAll()
                indexStatus = "Indexed \(count) ride schedules."
            } catch {
                indexStatus = "Indexing failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct PhraseRow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .textSelection(.enabled)
    }
}

#Preview {
    ContentView()
}
