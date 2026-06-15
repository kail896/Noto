import SwiftUI
import Combine
import AppKit
import CryptoKit

// MARK: - 排序选项
enum SortOption: String, Codable, CaseIterable, Identifiable {
    case updatedAt = "updatedAt"
    case createdAt = "createdAt"
    case title = "title"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .updatedAt: return "编辑时间"
        case .createdAt: return "创建时间"
        case .title: return "标题"
        }
    }
    var icon: String {
        switch self {
        case .updatedAt: return "clock"
        case .createdAt: return "calendar.badge.plus"
        case .title: return "textformat.abc"
        }
    }
}

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
    var sidebarWidth: CGFloat = 200
    var noteListWidth: CGFloat = 260
    var sortOption: SortOption = .updatedAt
    var trashRetentionDays: Int = 30  // 最近删除保留天数
    var showThemeEditor: Bool = false
    var showSettings: Bool = false
    var showNoteMoveSheet: Bool = false
    var movingNoteId: UUID?

    // 主题
    var customThemes: [NoteTheme] = []
    var selectedThemeId: String = "light-default"
    var themeIntensity: Double = 0.8

    // 暗色模式
    var darkModePreference: DarkModePreference = .system

    // 密码管理
    var folderPasswords: [String: String] = [:]      // UUID字符串 -> SHA256(salt+password) hex
    var folderSalts: [String: String] = [:]           // UUID字符串 -> 随机盐值 hex
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

        // 最终排序：置顶 > 选中的排序方式 > 在 notes 数组中的原始位置
        let notePositions: [UUID: Int] = {
            var pos: [UUID: Int] = [:]
            for (i, n) in notes.enumerated() { pos[n.id] = i }
            return pos
        }()

        func sortNotes(_ a: Note, _ b: Note) -> Bool {
            if a.isPinned != b.isPinned { return a.isPinned }
            // 根据排序选项比较
            switch sortOption {
            case .updatedAt:
                if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            case .createdAt:
                if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            case .title:
                let cmp = a.title.localizedCompare(b.title)
                if cmp != .orderedSame { return cmp == .orderedAscending }
            }
            // 用 notes 数组中的索引作为最终排序依据（确保不跳动）
            return (notePositions[a.id] ?? 0) < (notePositions[b.id] ?? 0)
        }

        if searchText.isEmpty {
            return result.sorted(by: sortNotes)
        } else {
            return result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.plainText.localizedCaseInsensitiveContains(searchText)
            }
            .sorted(by: sortNotes)
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
        // 先确定存储位置，再加载数据（避免触发 iCloud 迁移）
        let isICloudOn = UserDefaults.standard.bool(forKey: "iCloudEnabled")
        let dir: URL
        if isICloudOn, let iCloudURL = Self.iCloudDriveURL {
            dir = iCloudURL
        } else {
            dir = Self.appSupportDir
        }
        loadData(from: dir)

        // 如果本地无数据但 iCloud 有，自动切换
        if notes.isEmpty, folders.isEmpty,
           let iCloudURL = Self.iCloudDriveURL,
           FileManager.default.fileExists(atPath: iCloudURL.appendingPathComponent("notes.json").path) {
            // 直接设 UserDefaults 但不触发迁移（不调用 setter 的 side effect）
            UserDefaults.standard.set(true, forKey: "iCloudEnabled")
            loadData(from: iCloudURL)  // 从 iCloud 重新加载
        }

        if folders.isEmpty {
            folders = Folder.defaultFolders
        } else {
            // 迁移：重命名旧版"全部笔记"文件夹（与智能分类重名）
            for i in folders.indices where folders[i].name == "全部笔记" {
                folders[i].name = "默认"
                folders[i].icon = "tray"
            }
        }

        // 清理过期回收站笔记
        cleanupTrash()
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

    /// 清理超过保留天数的回收站笔记（0 = 不自动删除）
    func cleanupTrash() {
        guard trashRetentionDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(trashRetentionDays) * 86400)
        let toRemove = notes.filter { $0.isDeleted && ($0.deletedAt ?? $0.updatedAt) < cutoff }
        if !toRemove.isEmpty {
            notes.removeAll { note in toRemove.contains(where: { $0.id == note.id }) }
            saveData()
        }
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
    /// 为文件夹设置密码（SHA256 + 随机盐值）
    func setFolderPassword(_ folderId: String, password: String, hint: String) {
        let salt = UUID().uuidString
        let hash = SHA256.hash(data: Data((salt + password).utf8)).compactMap { String(format: "%02x", $0) }.joined()
        folderSalts[folderId] = salt
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
        folderSalts.removeValue(forKey: folderId)
        folderPasswordHints.removeValue(forKey: folderId)
        folderFailedAttempts.removeValue(forKey: folderId)
        unlockedFolders.remove(folderId)
        if let idx = folders.firstIndex(where: { $0.id.uuidString == folderId }) {
            folders[idx].isLocked = false
            folders[idx].passwordHint = ""
        }
        saveData()
    }

    /// 验证密码（带盐值）
    private func hashPassword(_ password: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + password).utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 仅验证密码（不关闭弹窗，用于修改密码时的第一步验证）
    func checkFolderPassword(_ folderId: String, password: String) -> Bool {
        guard let storedHash = folderPasswords[folderId] else { return false }
        let salt = folderSalts[folderId] ?? ""
        let hash = hashPassword(password, salt: salt)

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

    /// 尝试验证密码（带盐值）
    func verifyFolderPassword(_ folderId: String, password: String) -> Bool {
        guard let storedHash = folderPasswords[folderId] else { return false }
        let salt = folderSalts[folderId] ?? ""
        let hash = hashPassword(password, salt: salt)

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

    /// 原子化迁移到 iCloud（先复制到临时目录，再批量移动）
    private func migrateToICloud() {
        guard let iCloudURL = Self.iCloudDriveURL else { iCloudEnabled = false; return }
        let fm = FileManager.default
        let fileNames = ["notes.json", "folders.json", "themes.json", "prefs.json", "lock.json"]
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("noto-migrate-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpDir) }

        // Step 1: 复制到临时目录
        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        for name in fileNames {
            let src = Self.appSupportDir.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: tmpDir.appendingPathComponent(name))
            }
        }

        // Step 2: 移动到目标（目标存在则先删除）
        try? fm.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
        for name in fileNames {
            let tmpFile = tmpDir.appendingPathComponent(name)
            let dest = iCloudURL.appendingPathComponent(name)
            if fm.fileExists(atPath: tmpFile.path) {
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try? fm.moveItem(at: tmpFile, to: dest)
            }
        }

        // Step 3: 删除本地源文件
        for name in fileNames {
            let src = Self.appSupportDir.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) { try? fm.removeItem(at: src) }
        }
        saveData()
    }

    /// 从 iCloud 迁回本地（原子化）
    private func migrateFromICloud() {
        guard let iCloudURL = Self.iCloudDriveURL else { return }
        let fm = FileManager.default
        let fileNames = ["notes.json", "folders.json", "themes.json", "prefs.json", "lock.json"]
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("noto-migrate-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpDir) }

        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        for name in fileNames {
            let src = iCloudURL.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: tmpDir.appendingPathComponent(name))
            }
        }

        try? fm.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)
        for name in fileNames {
            let tmpFile = tmpDir.appendingPathComponent(name)
            let dest = Self.appSupportDir.appendingPathComponent(name)
            if fm.fileExists(atPath: tmpFile.path) {
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try? fm.moveItem(at: tmpFile, to: dest)
            }
        }

        for name in fileNames {
            let src = iCloudURL.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) { try? fm.removeItem(at: src) }
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
                "noteListWidth": AnyCodable(noteListWidth),
                "sortOption": AnyCodable(sortOption.rawValue),
                "trashRetentionDays": AnyCodable(Double(trashRetentionDays)),
                "darkModePreference": AnyCodable(darkModePreference.rawValue),
            ]
            let prefsData = try encoder.encode(prefs)
            try prefsData.write(to: dir.appendingPathComponent("prefs.json"), options: .atomic)

            let lockData = FolderLockData(
                folderPasswords: folderPasswords,
                folderSalts: folderSalts,
                folderPasswordHints: folderPasswordHints,
                folderFailedAttempts: folderFailedAttempts
            )
            let lockDataEncoded = try encoder.encode(lockData)
            try lockDataEncoded.write(to: dir.appendingPathComponent("lock.json"), options: .atomic)
        } catch {
            print("Save error: \(error)")
        }
    }

    private func loadData(from dir: URL) {
        let decoder = JSONDecoder()
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
                if case .double(let nw) = prefs["noteListWidth"] { noteListWidth = nw }
                if case .string(let so) = prefs["sortOption"], let opt = SortOption(rawValue: so) { sortOption = opt }
                if case .double(let td) = prefs["trashRetentionDays"] { trashRetentionDays = Int(td) }
                if case .string(let dm) = prefs["darkModePreference"] { darkModePreference = DarkModePreference(rawValue: dm) ?? .system }
            }
        }
        if let lockData = try? Data(contentsOf: dir.appendingPathComponent("lock.json")) {
            if let decoded = try? decoder.decode(FolderLockData.self, from: lockData) {
                folderPasswords = decoded.folderPasswords
                folderSalts = decoded.folderSalts
                folderPasswordHints = decoded.folderPasswordHints
                folderFailedAttempts = decoded.folderFailedAttempts
            }
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
    var folderSalts: [String: String] = [:]
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
