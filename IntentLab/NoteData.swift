//
//  NoteData.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import Foundation

// AppSchema 對照實驗用的 Note 資料模型。
// 這裡仍然只是 App 自己的資料格式，還不是 Siri / Shortcuts 看得懂的 AppEntity。
// 這組資料刻意使用 Apple 已支援的 Notes schema，拿來和 RideSchedule custom entity 比較 Siri 理解能力。
struct LabNote: Identifiable, Hashable, Codable, Sendable {
    // id 是 AppEntity 被系統記住、之後再找回同一筆資料時使用的穩定識別值。
    let id: String
    var title: String
    var content: String
    var isPinned: Bool
    // Notes schema 裡 note 會隸屬於 folder，因此內部資料也保留 folderID 做對應。
    var folderID: String
    let creationDate: Date
    var modificationDate: Date

    // 提供 App 內部文字搜尋使用；真正送進系統索引的欄位會在 LabNoteEntity 裡指定。
    nonisolated var searchableText: String {
        "\(title) \(content)"
    }
}

// Notes schema 的 note 需要 folder 資訊，所以這裡建立最小可用的資料模型。
struct LabNoteFolder: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var accountID: String
    var parentFolderID: String?
}

// Notes schema 的 folder 需要 account 資訊，所以這裡也補上最小 account 模型。
struct LabNoteAccount: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
}

// 用 actor 保存實驗資料，讓 App UI 和 App Intents 都走同一個資料入口。
// 這裡用 UserDefaults 做最小持久化，讓 Siri / Shortcuts 建立的 note 在 App 重啟後仍可觀察。
actor LabNoteStore {
    static let shared = LabNoteStore()
    private static let storageKey = "intent-lab.notes"

    // Entity 的 computed property 不能 await actor，因此提供不可變 snapshot 給 folder / account entity 使用。
    nonisolated static let defaultAccountSnapshot = LabNoteAccount(id: "intent-lab", name: "Intent Lab")
    nonisolated static let defaultFolderSnapshot = LabNoteFolder(
        id: "lab-notes",
        name: "Lab Notes",
        accountID: "intent-lab",
        parentFolderID: nil
    )

    private let accounts: [LabNoteAccount] = [
        LabNoteStore.defaultAccountSnapshot
    ]

    private let folders: [LabNoteFolder] = [
        LabNoteStore.defaultFolderSnapshot
    ]

    private static let defaultNotes: [LabNote] = [
        LabNote(
            id: "trip-plan",
            title: "Trip Plan",
            content: "Book an airport ride and confirm the hotel address.",
            isPinned: false,
            folderID: "lab-notes",
            creationDate: Date(timeIntervalSince1970: 1_788_000_000),
            modificationDate: Date(timeIntervalSince1970: 1_788_000_000)
        ),
        LabNote(
            id: "meeting-notes",
            title: "Meeting Notes",
            content: "Review the AppSchema experiment results.",
            isPinned: true,
            folderID: "lab-notes",
            creationDate: Date(timeIntervalSince1970: 1_788_086_400),
            modificationDate: Date(timeIntervalSince1970: 1_788_086_400)
        )
    ]

    private var notes: [LabNote]

    init() {
        notes = Self.loadPersistedNotes() ?? Self.defaultNotes
    }

    // Folder / account query 會透過這些方法把 id 或文字解析回 App 內部資料。
    func allFolders() -> [LabNoteFolder] {
        folders
    }

    func allAccounts() -> [LabNoteAccount] {
        accounts
    }

    func folder(id: LabNoteFolder.ID) -> LabNoteFolder? {
        folders.first { $0.id == id }
    }

    func folders(matching query: String) -> [LabNoteFolder] {
        let normalizedQuery = query.normalizedForSearch
        guard !normalizedQuery.isEmpty else {
            return folders
        }

        return folders.filter { folder in
            folder.name.normalizedForSearch.contains(normalizedQuery)
        }
    }

    // Note query 會透過這些方法把 id 或文字解析回 App 內部資料。
    func allNotes() -> [LabNote] {
        refreshFromStorage()
        return notes
    }

    func note(id: LabNote.ID) -> LabNote? {
        refreshFromStorage()
        return notes.first { $0.id == id }
    }

    func notes(matching query: String) -> [LabNote] {
        refreshFromStorage()
        let normalizedQuery = query.normalizedForSearch
        guard !normalizedQuery.isEmpty else {
            return notes
        }

        return notes.filter { note in
            note.searchableText.normalizedForSearch.contains(normalizedQuery)
                || normalizedQuery.contains(note.title.normalizedForSearch)
        }
    }

    func createNote(title: String, content: String, isPinned: Bool, folderID: LabNoteFolder.ID) -> LabNote {
        refreshFromStorage()

        let now = Date()
        // 實驗用資料用 title 產生穩定 id；正式 App 通常會使用後端 id 或資料庫主鍵。
        let note = LabNote(
            id: title.normalizedForSearch.replacingOccurrences(of: " ", with: "-"),
            title: title,
            content: content,
            isPinned: isPinned,
            folderID: folderID,
            creationDate: now,
            modificationDate: now
        )

        // 同名 note 會被覆蓋，避免重複建立相同 id 的假資料。
        notes.removeAll { $0.id == note.id }
        notes.append(note)
        persistNotes()
        return note
    }

    func updateNote(
        id: LabNote.ID,
        title: String,
        content: String,
        isPinned: Bool,
        folderID: LabNoteFolder.ID
    ) -> LabNote? {
        refreshFromStorage()

        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        notes[index].title = title
        notes[index].content = content
        notes[index].isPinned = isPinned
        notes[index].folderID = folderID
        notes[index].modificationDate = Date()
        persistNotes()
        return notes[index]
    }

    private func refreshFromStorage() {
        if let persistedNotes = Self.loadPersistedNotes() {
            notes = persistedNotes
        }
    }

    private func persistNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("[IntentLab] Failed to persist lab notes: \(error)")
        }
    }

    private static func loadPersistedNotes() -> [LabNote]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode([LabNote].self, from: data)
        } catch {
            print("[IntentLab] Failed to load persisted lab notes: \(error)")
            return nil
        }
    }
}
