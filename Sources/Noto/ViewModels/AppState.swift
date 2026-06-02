import SwiftUI
import Combine
import AppKit
import CryptoKit

// MARK: - 暗色模式偏好
enum DarkModePreference: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

// MARK: - App 全局状态
@Observable
final class AppState {
    // 笔记数据
    var notes: [Note] = []
    var folders: [Folder] = []

    // 当前选择
    var selectedSmartFolder: SmartFolder? = .all
    var selectedFolderId: UUID?
    var selectedNoteId: UUID?
    var editingNote: Note?

    // 界面状态
    var searchText: String = ""
    var isSearching: Bool = false
    var sidebarWidth: CGFloat = 220
    var showThemeEditor: Bool = false
    var showSettings: Bool = false

    // 主题
    var customThemes: [NoteTheme] = []
    var selectedThemeId: String = "light-default"
    var themeIntensity: Double = 0.8

    // 暗色模式
    var darkModePreference: DarkModePreference = .system

    // 密码管理
    var folderPasswords: [String: String] = [:]      // UUID字符串 -> SHA256 hex
    var folderPasswordHints: [String: String] = [:]
    var folderFailedAttempts: [String: Int] = [:]
    var unlockedFolders: Set<String> = []             // 已解锁的文件夹ID集合
    var showLockScreen: Bool = false
    var pendingLockFolderId: String? = nil            // 待解锁的文件夹ID
    var isSettingPassword: Bool = false               // 是否在设置密码模式
    var isDeleteFolderMode: Bool = false              // 是否在删除文件夹验证模式
    var isRemovePasswordMode: Bool = false            // 是否在移除密码验证模式
    var isChangePasswordMode: Bool = false            // 是否在修改密码模式
    var passwordErrorMessage: String? = nil

    // 批量操作
    var isBatchMode: Bool = false
    var batchSelectedIds: Set<UUID> = []

    // 当前选中主题
    var currentTheme: NoteTheme {
        allThemes.first(where: { $0.id == selectedThemeId }) ?? NoteTheme.lightDefault
    }

    var allThemes: [NoteTheme] {
        NoteTheme.defaultThemes + customThemes
    }

    // 筛选后的笔记
    var filteredNotes: [Note] {
        let result: [Note]
        let activeNotes = visibleNotes

        if let smart = selectedSmartFolder {
            switch smart {
            case .all:
                result = activeNotes
            case .today:
                result = activeNotes.filter { Calendar.current.isDateInToday($0.updatedAt) }
            case .recent:
                result = activeNotes.filter { $0.updatedAt > Date().addingTimeInterval(-7 * 86400) }
            case .pinned:
                result = activeNotes.filter { $0.isPinned }
            case .trash:
                return notes.filter { $0.isDeleted }
                    .sorted { ($0.deletedAt ?? $0.updatedAt) > ($1.deletedAt ?? $1.updatedAt) }
            }
        } else if let folderId = selectedFolderId {
            result = activeNotes.filter { $0.folderId == folderId }
        } else {
            result = activeNotes
        }

        if searchText.isEmpty {
            return result.sorted { $0.isPinned && !$1.isPinned ? true : $0.updatedAt > $1.updatedAt }
        } else {
            return result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.plainText.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    // 所有笔记数量（排除锁定文件夹的笔记，与 filteredNotes 一致）
    private var unlockedFolderIds: Set<UUID> {
        Set(folders.filter { !$0.isLocked || unlockedFolders.contains($0.id.uuidString) }.map { $0.id })
    }

    private var visibleNotes: [Note] {
        let ids = unlockedFolderIds
        return notes.filter { !$0.isDeleted && ($0.folderId == nil || ids.contains($0.folderId!)) }
    }

    var allNotesCount: Int { visibleNotes.count }
    var todayCount: Int { visibleNotes.filter { Calendar.current.isDateInToday($0.updatedAt) }.count }
    var recentCount: Int { visibleNotes.filter { $0.updatedAt > Date().addingTimeInterval(-7 * 86400) }.count }
    var pinnedCount: Int { visibleNotes.filter { $0.isPinned }.count }
    var trashCount: Int { notes.filter { $0.isDeleted }.count }

    // MARK: - 初始化
    init() {
        loadData()
        if folders.isEmpty {
            folders = Folder.defaultFolders
        }
    }

    // MARK: - 笔记操作
    func createNote(in folderId: UUID? = nil) {
        // 如果在某个文件夹中新建，归入该文件夹；否则留在"未分类"（folderId = nil）
        let folder = folderId ?? selectedFolderId
        let note = Note(
            title: "新笔记",
            content: "",
            plainText: "",
            folderId: folder,
            themeId: currentTheme.id
        )
        notes.insert(note, at: 0)
        selectedNoteId = note.id
        editingNote = note
        saveData()
    }

    func updateNote(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated.updatedAt = Date()
            notes[idx] = updated
            if editingNote?.id == note.id {
                editingNote = updated
            }
            saveData()
        }
    }

    func deleteNote(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isDeleted = true
            notes[idx].deletedAt = Date()
            if selectedNoteId == note.id {
                selectedNoteId = nil
                editingNote = nil
            }
            saveData()
        }
    }

    func permanentlyDeleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        if selectedNoteId == note.id {
            selectedNoteId = nil
            editingNote = nil
        }
        saveData()
    }

    func restoreNote(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isDeleted = false
            notes[idx].deletedAt = nil
            saveData()
        }
    }

    func togglePin(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isPinned.toggle()
            notes[idx].updatedAt = Date()
            saveData()
        }
    }

    func duplicateNote(_ note: Note) {
        var copy = note
        copy.id = UUID()
        copy.title = note.title + " (副本)"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        notes.insert(copy, at: 0)
        saveData()
    }

    func moveNote(_ noteId: UUID, to folderId: UUID) {
        if let idx = notes.firstIndex(where: { $0.id == noteId }) {
            notes[idx].folderId = folderId
            notes[idx].updatedAt = Date()
            saveData()
        }
    }

    func emptyTrash() {
        notes.removeAll { $0.isDeleted }
        saveData()
    }

    // MARK: - 文件夹操作
    func createFolder(name: String, icon: String = "folder") {
        let folder = Folder(name: name, icon: icon, sortOrder: folders.count)
        folders.append(folder)
        saveData()
    }

    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        // 文件夹内的笔记移至「最近删除」，不彻底删除
        for i in notes.indices where notes[i].folderId == folder.id && !notes[i].isDeleted {
            notes[i].isDeleted = true
            notes[i].deletedAt = Date()
        }
        if selectedFolderId == folder.id {
            selectedFolderId = nil
            selectedSmartFolder = .all
        }
        saveData()
    }

    func renameFolder(_ folder: Folder, name: String) {
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx].name = name
            saveData()
        }
    }

    // MARK: - 密码操作
    /// 为文件夹设置密码
    func setFolderPassword(_ folderId: String, password: String, hint: String) {
        let hash = SHA256.hash(data: Data(password.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        folderPasswords[folderId] = hash
        folderPasswordHints[folderId] = hint
        folderFailedAttempts[folderId] = 0
        if let idx = folders.firstIndex(where: { $0.id.uuidString == folderId }) {
            folders[idx].isLocked = true
            folders[idx].passwordHint = hint
        }
        saveData()
    }

    /// 移除文件夹密码
    func removeFolderPassword(_ folderId: String) {
        folderPasswords.removeValue(forKey: folderId)
        folderPasswordHints.removeValue(forKey: folderId)
        folderFailedAttempts.removeValue(forKey: folderId)
        unlockedFolders.remove(folderId)
        if let idx = folders.firstIndex(where: { $0.id.uuidString == folderId }) {
            folders[idx].isLocked = false
            folders[idx].passwordHint = ""
        }
        saveData()
    }

    /// 仅验证密码（不关闭弹窗，用于修改密码时的第一步验证）
    func checkFolderPassword(_ folderId: String, password: String) -> Bool {
        let hash = SHA256.hash(data: Data(password.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        guard let storedHash = folderPasswords[folderId] else { return false }

        if hash == storedHash {
            folderFailedAttempts[folderId] = 0
            passwordErrorMessage = nil
            return true
        } else {
            let attempts = (folderFailedAttempts[folderId] ?? 0) + 1
            folderFailedAttempts[folderId] = attempts
            if attempts >= 3 {
                passwordErrorMessage = folderPasswordHints[folderId].map { "密码提示：\($0)" } ?? "密码错误已达3次"
            } else {
                passwordErrorMessage = "密码错误，还剩\(3 - attempts)次机会。"
            }
            return false
        }
    }

    /// 尝试验证密码
    func verifyFolderPassword(_ folderId: String, password: String) -> Bool {
        let hash = SHA256.hash(data: Data(password.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        guard let storedHash = folderPasswords[folderId] else { return false }

        if hash == storedHash {
            unlockedFolders.insert(folderId)
            folderFailedAttempts[folderId] = 0
            passwordErrorMessage = nil
            saveData()
            return true
        } else {
            let attempts = (folderFailedAttempts[folderId] ?? 0) + 1
            folderFailedAttempts[folderId] = attempts
            if attempts >= 3 {
                passwordErrorMessage = folderPasswordHints[folderId].map { "密码提示：\($0)" } ?? "密码错误已达3次"
            } else {
                passwordErrorMessage = "密码错误，还剩\(3 - attempts)次机会。"
            }
            return false
        }
    }

    /// 锁定文件夹（退出时自动调用）
    func lockFolder(_ folderId: String) {
        unlockedFolders.remove(folderId)
    }

    /// 检查文件夹是否已解锁
    func isFolderUnlocked(_ folderId: String) -> Bool {
        unlockedFolders.contains(folderId)
    }

    // MARK: - 批量操作
    func toggleBatchSelection(_ noteId: UUID) {
        if batchSelectedIds.contains(noteId) {
            batchSelectedIds.remove(noteId)
        } else {
            batchSelectedIds.insert(noteId)
        }
    }

    func batchSelectAll() {
        let current = filteredNotes
        if batchSelectedIds.count == current.count {
            batchSelectedIds.removeAll()
        } else {
            batchSelectedIds = Set(current.map { $0.id })
        }
    }

    func batchDelete() {
        let ids = batchSelectedIds
        if selectedSmartFolder == .trash {
            notes.removeAll { ids.contains($0.id) }
        } else {
            for i in notes.indices where ids.contains(notes[i].id) {
                notes[i].isDeleted = true
                notes[i].deletedAt = Date()
            }
        }
        batchSelectedIds.removeAll()
        isBatchMode = false
        saveData()
    }

    func batchMove(to folderId: UUID) {
        let ids = batchSelectedIds
        for i in notes.indices where ids.contains(notes[i].id) {
            notes[i].folderId = folderId
            notes[i].updatedAt = Date()
        }
        batchSelectedIds.removeAll()
        isBatchMode = false
        saveData()
    }

    func batchTogglePin() {
        let ids = batchSelectedIds
        for i in notes.indices where ids.contains(notes[i].id) {
            notes[i].isPinned.toggle()
            notes[i].updatedAt = Date()
        }
        batchSelectedIds.removeAll()
        isBatchMode = false
        saveData()
    }

    func exitBatchMode() {
        isBatchMode = false
        batchSelectedIds.removeAll()
    }

    // MARK: - 主题操作
    func saveTheme(_ theme: NoteTheme) {
        if let idx = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[idx] = theme
        } else {
            customThemes.append(theme)
        }
        saveData()
    }

    func deleteCustomTheme(_ theme: NoteTheme) {
        customThemes.removeAll { $0.id == theme.id }
        if selectedThemeId == theme.id {
            selectedThemeId = NoteTheme.lightDefault.id
        }
        saveData()
    }

    func applyTheme(_ themeId: String) {
        selectedThemeId = themeId
        saveData()
    }

    // MARK: - iCloud
    var iCloudEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "iCloudEnabled") }
        set {
            let old = UserDefaults.standard.bool(forKey: "iCloudEnabled")
            UserDefaults.standard.set(newValue, forKey: "iCloudEnabled")
            if old != newValue { onICloudToggle() }
        }
    }

    var iCloudAvailable: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path)
            || FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/CloudStorage").path)
    }

    /// iCloud Drive 路径（直接访问用户 iCloud Drive 文件夹，无需 entitlements）
    private static var iCloudDriveURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // macOS 标准路径: ~/Library/Mobile Documents/com~apple~CloudDocs/
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: cloudDocs.path) {
            let notoDir = cloudDocs.appendingPathComponent("Noto")
            try? FileManager.default.createDirectory(at: notoDir, withIntermediateDirectories: true)
            return notoDir
        }
        // macOS Ventura+ 替代路径
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage")
        if FileManager.default.fileExists(atPath: cloudStorage.path) {
            let notoDir = cloudStorage.appendingPathComponent("Noto")
            try? FileManager.default.createDirectory(at: notoDir, withIntermediateDirectories: true)
            return notoDir
        }
        return nil
    }

    /// 当前存储目录（根据 iCloudEnabled 偏好选择存储位置）
    private static var currentStorageDir: URL {
        let fm = FileManager.default
        let isICloudOn = UserDefaults.standard.bool(forKey: "iCloudEnabled")

        if isICloudOn, let iCloudURL = Self.iCloudDriveURL {
            return iCloudURL
        }

        // 回退到本地
        try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        return appSupportDir
    }

    private func onICloudToggle() {
        if iCloudEnabled {
            migrateToICloud()
        } else {
            migrateFromICloud()
        }
    }

    /// 从本地迁移到 iCloud
    private func migrateToICloud() {
        guard let iCloudURL = Self.iCloudDriveURL else { iCloudEnabled = false; return }
        let fm = FileManager.default
        try? fm.createDirectory(at: iCloudURL, withIntermediateDirectories: true)

        for name in ["notes.json", "folders.json", "themes.json", "prefs.json", "lock.json"] {
            let local = Self.appSupportDir.appendingPathComponent(name)
            let remote = iCloudURL.appendingPathComponent(name)
            if fm.fileExists(atPath: local.path) {
                try? fm.copyItem(at: local, to: remote)
                try? fm.removeItem(at: local)
            }
        }
        saveData()
    }

    /// 从 iCloud 迁回本地
    private func migrateFromICloud() {
        guard let iCloudURL = Self.iCloudDriveURL else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)

        for name in ["notes.json", "folders.json", "themes.json", "prefs.json", "lock.json"] {
            let remote = iCloudURL.appendingPathComponent(name)
            let local = Self.appSupportDir.appendingPathComponent(name)
            if fm.fileExists(atPath: remote.path) {
                try? fm.copyItem(at: remote, to: local)
                try? fm.removeItem(at: remote)
            }
        }
        saveData()
    }

    // MARK: - Persistence
    private var saveWorkItem: DispatchWorkItem?

    func saveData() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.writeToDisk()
        }
        saveWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// 同步写入磁盘 — 用于应用退出等需要立即保存的场景
    func saveDataSync() {
        saveWorkItem?.cancel()
        writeToDisk()
    }

    private func writeToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let dir = Self.currentStorageDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let notesData = try encoder.encode(notes)
            try notesData.write(to: dir.appendingPathComponent("notes.json"), options: .atomic)

            let foldersData = try encoder.encode(folders)
            try foldersData.write(to: dir.appendingPathComponent("folders.json"), options: .atomic)

            let themesData = try encoder.encode(customThemes)
            try themesData.write(to: dir.appendingPathComponent("themes.json"), options: .atomic)

            let prefs: [String: AnyCodable] = [
                "selectedThemeId": AnyCodable(selectedThemeId),
                "sidebarWidth": AnyCodable(sidebarWidth),
                "darkModePreference": AnyCodable(darkModePreference.rawValue),
            ]
            let prefsData = try encoder.encode(prefs)
            try prefsData.write(to: dir.appendingPathComponent("prefs.json"), options: .atomic)

            let lockData = FolderLockData(
                folderPasswords: folderPasswords,
                folderPasswordHints: folderPasswordHints,
                folderFailedAttempts: folderFailedAttempts
            )
            let lockDataEncoded = try encoder.encode(lockData)
            try lockDataEncoded.write(to: dir.appendingPathComponent("lock.json"), options: .atomic)
        } catch {
            print("Save error: \(error)")
        }
    }

    private func loadData() {
        let decoder = JSONDecoder()
        let dir = Self.currentStorageDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: dir.appendingPathComponent("notes.json")) {
            if let decoded = try? decoder.decode([Note].self, from: data) { notes = decoded }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("folders.json")) {
            if let decoded = try? decoder.decode([Folder].self, from: data) { folders = decoded }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("themes.json")) {
            if let decoded = try? decoder.decode([NoteTheme].self, from: data) { customThemes = decoded }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("prefs.json")) {
            if let prefs = try? decoder.decode([String: AnyCodable].self, from: data) {
                if case .string(let tid) = prefs["selectedThemeId"] { selectedThemeId = tid }
                if case .double(let sw) = prefs["sidebarWidth"] { sidebarWidth = sw }
                if case .string(let dm) = prefs["darkModePreference"] { darkModePreference = DarkModePreference(rawValue: dm) ?? .system }
            }
        }
        if let lockData = try? Data(contentsOf: dir.appendingPathComponent("lock.json")) {
            if let decoded = try? decoder.decode(FolderLockData.self, from: lockData) {
                folderPasswords = decoded.folderPasswords
                folderPasswordHints = decoded.folderPasswordHints
                folderFailedAttempts = decoded.folderFailedAttempts
            }
        }

        // 检查 iCloud Drive 是否有现有数据（首次启动时自动检测）
        if notes.isEmpty, folders.isEmpty,
           let iCloudURL = Self.iCloudDriveURL,
           FileManager.default.fileExists(atPath: iCloudURL.appendingPathComponent("notes.json").path) {
            iCloudEnabled = true
        }
    }
    private static let appSupportDir: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Noto", isDirectory: true)
    }()
}

// MARK: - 密码存储模型
struct FolderLockData: Codable {
    var folderPasswords: [String: String] = [:]
    var folderPasswordHints: [String: String] = [:]
    var folderFailedAttempts: [String: Int] = [:]
}

// MARK: - 辅助类型
enum AnyCodable: Codable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case null

    init(_ value: String) { self = .string(value) }
    init(_ value: Double) { self = .double(value) }
    init(_ value: Bool) { self = .bool(value) }
    init(_ value: CGFloat) { self = .double(Double(value)) }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let dbl = try? container.decode(Double.self) {
            self = .double(dbl)
        } else if let bl = try? container.decode(Bool.self) {
            self = .bool(bl)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
