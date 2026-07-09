//
//  ContentView.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import AppIntents
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var rideIndexStatus = "Ready to index sample ride schedules."
    @State private var noteIndexStatus = "Ready to index lab notes."
    @State private var labNotes: [LabNote] = []

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

                Section("Lab Notes") {
                    if labNotes.isEmpty {
                        Text("No lab notes yet.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(labNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.headline)

                            Text(note.content)
                                .foregroundStyle(.secondary)

                            LabeledContent("Folder", value: note.folderID)
                            LabeledContent("Pinned", value: note.isPinned ? "Yes" : "No")
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Spotlight Index") {
                    Button("Index Schedules") {
                        indexSchedules()
                    }

                    Text(rideIndexStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Index Notes") {
                        indexNotes()
                    }

                    Text(noteIndexStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Siri Exact Phrases") {
                    PhraseRow("List all ride schedules in Intent Lab")
                    PhraseRow("Show all ride schedules in Intent Lab")
                    PhraseRow("Find Go to Work in Intent Lab")
                    PhraseRow("Show Go to Work ride schedule in Intent Lab")
                    PhraseRow("What is the payment method for Go to Work in Intent Lab")
                    PhraseRow("Show Airport Pickup payment method in Intent Lab")
                    PhraseRow("Find Airport Pickup payment method in Intent Lab")
                    PhraseRow("Get Airport Pickup payment method in Intent Lab")
                    PhraseRow("Search ride schedules in Intent Lab")
                }

                Section("Notes AppSchema Phrases") {
                    PhraseRow("Create a note in Intent Lab")
                    PhraseRow("Create an Intent Lab note")
                    PhraseRow("Find Trip Plan note in Intent Lab")
                    PhraseRow("Show Trip Plan note in Intent Lab")
                    PhraseRow("Update Trip Plan note in Intent Lab")
                    PhraseRow("Add text to Trip Plan note in Intent Lab")
                    PhraseRow("Append text to Trip Plan note in Intent Lab")
                }

                Section("Exploratory Phrases") {
                    PhraseRow("Do I have a ride to the office in Intent Lab?")
                    PhraseRow("What is my payment method for Go to Work in Intent Lab?")
                    PhraseRow("Show my airport pickup ride in Intent Lab")
                    PhraseRow("What does my Trip Plan note say in Intent Lab?")
                    PhraseRow("Create a note about airport pickup in Intent Lab")
                }
            }
            .navigationTitle("Intent Lab")
            .task {
                await reloadNotes()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                Task {
                    await reloadNotes()
                }
            }
        }
    }

    @MainActor
    private func reloadNotes() async {
        labNotes = await LabNoteStore.shared.allNotes()
    }

    private func indexSchedules() {
        rideIndexStatus = "Indexing ride schedules..."

        // UI 上提供手動重建索引，方便在修改 IndexedEntity 欄位後重新測 Spotlight。
        Task {
            do {
                let count = try await RideScheduleIndexer.indexAll()
                rideIndexStatus = "Indexed \(count) ride schedules."
            } catch {
                rideIndexStatus = "Indexing failed: \(error.localizedDescription)"
            }
        }
    }

    private func indexNotes() {
        noteIndexStatus = "Indexing lab notes..."

        // 建立或更新 note 後可手動重建索引，用來測 Spotlight / semantic index 是否讀到最新資料。
        Task {
            do {
                let count = try await LabNoteIndexer.indexAll()
                noteIndexStatus = "Indexed \(count) lab notes."
                await reloadNotes()
            } catch {
                noteIndexStatus = "Indexing failed: \(error.localizedDescription)"
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
