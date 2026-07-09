//
//  NoteAppIntents.swift
//  IntentLab
//
//  Created by Pulin on 2026/7/9.
//

import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum LabNoteIntentError: LocalizedError {
    case noteNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noteNotFound(let title):
            "Could not find \(title)."
        }
    }
}

// 使用 Apple 內建 Notes AppSchema 的 entity，作為 custom RideScheduleEntity 的對照組。
// LabNote 是 App 內部資料；LabNoteEntity 是把這筆資料包成系統可理解的 Notes schema 版本。
@AppEntity(schema: .notes.note)
struct LabNoteEntity: IndexedEntity {
    let note: LabNote

    init(note: LabNote) {
        self.note = note
    }

    var id: String {
        note.id
    }

    // Notes schema 的 note 名稱欄位。型別要符合 schema 要求，因此這裡使用 AttributedString。
    @ComputedProperty
    var name: AttributedString {
        AttributedString(note.title)
    }

    // 把 note content 對應到 textContent indexing key，讓 Spotlight / semantic index 有主要文字可索引。
    @ComputedProperty(indexingKey: \.textContent)
    var content: AttributedString? {
        AttributedString(note.content)
    }

    // 下面這些 property 是 Notes schema 會理解的欄位，用來描述這筆 note 的狀態與歸屬。
    @ComputedProperty
    var isPinned: Bool {
        note.isPinned
    }

    @ComputedProperty
    var attachments: [IntentFile] {
        []
    }

    @ComputedProperty
    var creationDate: Date? {
        note.creationDate
    }

    @ComputedProperty
    var modificationDate: Date? {
        note.modificationDate
    }

    // 實驗資料只有一個固定 folder，因此直接回傳 snapshot 包出的 folder entity。
    @ComputedProperty
    var folder: LabNoteFolderEntity? {
        LabNoteFolderEntity(folder: LabNoteStore.defaultFolderSnapshot)
    }

    // displayRepresentation 是 Shortcuts / Spotlight 顯示 entity 時看到的標題與副標題。
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(note.title)", subtitle: "\(note.content)")
    }

    // defaultQuery 讓系統知道要透過哪個 query 把 id / 使用者輸入文字解析回 LabNoteEntity。
    static var defaultQuery = LabNoteEntityQuery()
}

// Notes schema 要求 Note 隸屬 folder，因此實驗也補一個最小 folder entity。
// 這個 entity 主要是讓 Create / Update Note 的 folder 參數可以符合 schema。
@AppEntity(schema: .notes.folder)
struct LabNoteFolderEntity: AppEntity {
    let folder: LabNoteFolder

    init(folder: LabNoteFolder) {
        self.folder = folder
    }

    var id: String {
        folder.id
    }

    @ComputedProperty
    var name: String {
        folder.name
    }

    // Notes folder 會隸屬於 account；實驗中只有一個固定 account。
    @ComputedProperty
    var account: LabNoteAccountEntity? {
        LabNoteAccountEntity(account: LabNoteStore.defaultAccountSnapshot)
    }

    // 實驗資料不做巢狀資料夾，所以 parentFolder 固定為 nil。
    @ComputedProperty
    var parentFolder: LabNoteFolderEntity? {
        nil
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(folder.name)")
    }

    static var defaultQuery = LabNoteFolderEntityQuery()
}

// Notes schema 的 account entity。這裡只提供最小 name / id，讓 folder 的 account 關係成立。
@AppEntity(schema: .notes.account)
struct LabNoteAccountEntity: AppEntity {
    let account: LabNoteAccount

    init(account: LabNoteAccount) {
        self.account = account
    }

    var id: String {
        account.id
    }

    @ComputedProperty
    var name: String {
        account.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(account.name)")
    }

    static var defaultQuery = LabNoteAccountEntityQuery()
}

// Account query：系統需要用它把 account id 或使用者輸入文字解析回 LabNoteAccountEntity。
struct LabNoteAccountEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    // 用 id 找回 entity；系統保存 entity 後，之後常會走這個入口還原資料。
    func entities(for identifiers: [LabNoteAccountEntity.ID]) async throws -> [LabNoteAccountEntity] {
        let accounts = await LabNoteStore.shared.allAccounts()
        return accounts
            .filter { identifiers.contains($0.id) }
            .map(LabNoteAccountEntity.init(account:))
    }

    // 用文字搜尋 entity；使用者在 Shortcuts 選參數或 Siri 嘗試解析文字時會用到。
    func entities(matching string: String) async throws -> [LabNoteAccountEntity] {
        let normalizedQuery = string.normalizedForSearch
        let accounts = await LabNoteStore.shared.allAccounts()
        guard !normalizedQuery.isEmpty else {
            return accounts.map(LabNoteAccountEntity.init(account:))
        }

        return accounts
            .filter { $0.name.normalizedForSearch.contains(normalizedQuery) }
            .map(LabNoteAccountEntity.init(account:))
    }

    // suggestedEntities 會影響 Shortcuts 參數選擇時先看到哪些候選值。
    func suggestedEntities() async throws -> [LabNoteAccountEntity] {
        let accounts = await LabNoteStore.shared.allAccounts()
        return accounts.map(LabNoteAccountEntity.init(account:))
    }

    // EnumerableEntityQuery 讓系統可以列出所有 account。
    func allEntities() async throws -> [LabNoteAccountEntity] {
        let accounts = await LabNoteStore.shared.allAccounts()
        return accounts.map(LabNoteAccountEntity.init(account:))
    }
}

// Folder query：Create / Update Note 的 folder 參數會透過這裡解析候選資料。
struct LabNoteFolderEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    func entities(for identifiers: [LabNoteFolderEntity.ID]) async throws -> [LabNoteFolderEntity] {
        let folders = await LabNoteStore.shared.allFolders()
        return folders
            .filter { identifiers.contains($0.id) }
            .map(LabNoteFolderEntity.init(folder:))
    }

    func entities(matching string: String) async throws -> [LabNoteFolderEntity] {
        let folders = await LabNoteStore.shared.folders(matching: string)
        return folders.map(LabNoteFolderEntity.init(folder:))
    }

    func suggestedEntities() async throws -> [LabNoteFolderEntity] {
        let folders = await LabNoteStore.shared.allFolders()
        return folders.map(LabNoteFolderEntity.init(folder:))
    }

    func allEntities() async throws -> [LabNoteFolderEntity] {
        let folders = await LabNoteStore.shared.allFolders()
        return folders.map(LabNoteFolderEntity.init(folder:))
    }
}

// Notes entity 的查詢入口，讓 Siri / Shortcuts 可以把文字或 id 找回 LabNoteEntity。
struct LabNoteEntityQuery: EntityStringQuery, EnumerableEntityQuery, IndexedEntityQuery {
    // 用 id 找回 Note entity；例如 Shortcuts 已經保存某筆 note 參數時會需要這個方法。
    func entities(for identifiers: [LabNoteEntity.ID]) async throws -> [LabNoteEntity] {
        let notes = await LabNoteStore.shared.allNotes()
        return notes
            .filter { identifiers.contains($0.id) }
            .map(LabNoteEntity.init(note:))
    }

    // 用文字搜尋 Note entity；例如輸入 "Trip Plan" 或 "airport" 時會走這個入口。
    func entities(matching string: String) async throws -> [LabNoteEntity] {
        let notes = await LabNoteStore.shared.notes(matching: string)
        return notes.map(LabNoteEntity.init(note:))
    }

    // Shortcuts 參數選單中會先列出這些 note 供使用者選擇。
    func suggestedEntities() async throws -> [LabNoteEntity] {
        let notes = await LabNoteStore.shared.allNotes()
        return notes.map(LabNoteEntity.init(note:))
    }

    // 讓系統可以取得完整 note 清單，也方便 AppIntentsTesting 驗證。
    func allEntities() async throws -> [LabNoteEntity] {
        let notes = await LabNoteStore.shared.allNotes()
        return notes.map(LabNoteEntity.init(note:))
    }

    // IndexedEntityQuery 的重建單筆索引入口；系統要求重建指定 id 時會呼叫。
    func reindexEntities(
        for identifiers: [LabNoteEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await LabNoteIndexer.index(ids: identifiers)
    }

    // IndexedEntityQuery 的重建全部索引入口；系統或測試可用它重新送出所有 note entity。
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await LabNoteIndexer.indexAll()
    }
}

enum LabNoteIndexer {
    @discardableResult
    static func indexAll() async throws -> Int {
        let entities = await LabNoteStore.shared.allNotes()
            .map(LabNoteEntity.init(note:))
        try await CSSearchableIndex.default().indexAppEntities(entities)
        return entities.count
    }

    @discardableResult
    static func index(ids: [LabNoteEntity.ID]) async throws -> Int {
        let entities = await LabNoteStore.shared.allNotes()
            .filter { ids.contains($0.id) }
            .map(LabNoteEntity.init(note:))
        try await CSSearchableIndex.default().indexAppEntities(entities)
        return entities.count
    }
}

// AppSchema 版本的建立 Note action，用來測試 Siri 是否更能理解「建立筆記」這種系統已知語意。
@AppIntent(schema: .notes.createNote)
struct CreateLabNoteIntent {
    static let title: LocalizedStringResource = "Create Lab Note"
    static let description = IntentDescription("Creates a note in Intent Lab.")

    // 使用 schema 版 createNote 時，參數名稱與型別要能對應到 Apple 定義的 Notes schema。
    @Parameter(title: "Title")
    var name: AttributedString

    @Parameter(title: "Content")
    var content: AttributedString?

    @Parameter(title: "Folder", query: LabNoteFolderEntityQuery())
    var folder: LabNoteFolderEntity?

    @Parameter(title: "Attachments", default: [], supportedContentTypes: [.item])
    var attachments: [IntentFile]

    @Parameter(title: "Pinned", default: false)
    var isPinned: Bool

    // parameterSummary 影響 Shortcuts action 顯示方式，也讓使用者知道主要必填參數是 name。
    static var parameterSummary: some ParameterSummary {
        Summary("Create note \(\.$name)")
    }

    func perform() async throws -> some ReturnsValue<LabNoteEntity> & ProvidesDialog {
        // App 內部資料使用 String，因此在 perform 裡把 schema 要求的 AttributedString 轉回 String。
        let note = await LabNoteStore.shared.createNote(
            title: String(name.characters),
            content: content.map { String($0.characters) } ?? "",
            isPinned: isPinned,
            folderID: folder?.id ?? LabNoteStore.defaultFolderSnapshot.id
        )
        let entity = LabNoteEntity(note: note)
        // 建立後立即更新 Spotlight / semantic index，方便後續用搜尋或 entity 解析測試這筆 note。
        try await LabNoteIndexer.index(ids: [entity.id])

        return .result(value: entity, dialog: "Created \(note.title).")
    }
}

// AppSchema 版本的更新 Note action，用來測試系統能否把「更新某筆筆記」對應到已知 schema。
@AppIntent(schema: .notes.updateNote)
struct UpdateLabNoteIntent {
    static let title: LocalizedStringResource = "Update Lab Note"
    static let description = IntentDescription("Updates a note in Intent Lab.")

    // schema 的 update action 需要先知道要更新哪一筆 note；target 會透過 LabNoteEntityQuery 解析。
    @Parameter(title: "Note", query: LabNoteEntityQuery())
    var target: LabNoteEntity

    // 其餘欄位是可選更新值；沒有提供時就保留原本 target.note 的內容。
    @Parameter(title: "Name")
    var name: AttributedString?

    @Parameter(title: "Content")
    var content: AttributedString?

    @Parameter(title: "Folder", query: LabNoteFolderEntityQuery())
    var folder: LabNoteFolderEntity?

    @Parameter(title: "Attachments", supportedContentTypes: [.item])
    var attachments: [IntentFile]?

    @Parameter(title: "Pinned")
    var isPinned: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$target)")
    }

    func perform() async throws -> some ReturnsValue<LabNoteEntity> & ProvidesDialog {
        // 只更新使用者有提供的欄位，沒有提供的欄位沿用原本資料。
        guard let updatedNote = await LabNoteStore.shared.updateNote(
            id: target.id,
            title: name.map { String($0.characters) } ?? target.note.title,
            content: content.map { String($0.characters) } ?? target.note.content,
            isPinned: isPinned ?? target.note.isPinned,
            folderID: folder?.id ?? target.note.folderID
        ) else {
            throw LabNoteIntentError.noteNotFound(target.note.title)
        }

        let entity = LabNoteEntity(note: updatedNote)
        // 更新後重新索引，避免 Spotlight / semantic index 還保留舊內容。
        try await LabNoteIndexer.index(ids: [entity.id])

        return .result(value: entity, dialog: "Updated \(updatedNote.title).")
    }
}

// 追加 Note 內容 action。
// 這裡不套 .notes.updateNote schema，因為 schema 不允許把 content 做成「追加文字」必填參數。
// 和 UpdateLabNoteIntent 不同，這個 intent 明確要求一段文字，降低 Siri 第二輪補參數時猜錯欄位的機率。
struct AppendToLabNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to Lab Note"
    static let description = IntentDescription("Adds text to an existing note in Intent Lab.")

    // 要追加內容的目標 note。
    @Parameter(title: "Note", query: LabNoteEntityQuery())
    var target: LabNoteEntity

    // 使用者要加入 note 的文字。phrase 先解析 target，Siri 再追問這個唯一缺少的必要參數。
    @Parameter(title: "Text")
    var content: AttributedString

    @Parameter(title: "Name")
    var name: AttributedString?

    @Parameter(title: "Folder", query: LabNoteFolderEntityQuery())
    var folder: LabNoteFolderEntity?

    @Parameter(title: "Attachments", supportedContentTypes: [.item])
    var attachments: [IntentFile]?

    @Parameter(title: "Pinned")
    var isPinned: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$content) to \(\.$target)")
    }

    func perform() async throws -> some ReturnsValue<LabNoteEntity> & ProvidesDialog {
        let newText = String(content.characters)
        let appendedContent = target.note.content.isEmpty
            ? newText
            : "\(target.note.content)\n\(newText)"

        guard let updatedNote = await LabNoteStore.shared.updateNote(
            id: target.id,
            title: name.map { String($0.characters) } ?? target.note.title,
            content: appendedContent,
            isPinned: isPinned ?? target.note.isPinned,
            folderID: folder?.id ?? target.note.folderID
        ) else {
            throw LabNoteIntentError.noteNotFound(target.note.title)
        }

        let entity = LabNoteEntity(note: updatedNote)
        try await LabNoteIndexer.index(ids: [entity.id])

        return .result(value: entity, dialog: "Added text to \(updatedNote.title).")
    }
}

// 一般查詢 action，用來驗證 schema note entity 是否能被明確 phrase 解析。
// 這個 intent 沒有套 AppSchema，重點是測試「AppShortcut phrase + AppEntity 參數解析」。
struct FindLabNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Lab Note"
    static let description = IntentDescription("Finds a note in Intent Lab.")

    // 使用者說出或選擇某筆 note 時，系統會透過 LabNoteEntityQuery 找回 LabNoteEntity。
    @Parameter(title: "Note", query: LabNoteEntityQuery())
    var note: LabNoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$note)")
    }

    func perform() async throws -> some ReturnsValue<LabNoteEntity> & ProvidesDialog {
        return .result(value: note, dialog: "\(note.note.title): \(note.note.content)")
    }
}
