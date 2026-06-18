import Foundation
import SwiftUI

// MARK: - Note Model
struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var content: String          // 富文本 HTML 格式
    var plainText: String        // 纯文本预览
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    var folderId: UUID?
    var themeId: String?
    var isDeleted: Bool = false
    var deletedAt: Date?
    var tags: [String] = []

    var previewText: String {
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "空笔记" : trimmed
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        let diff = Date().timeIntervalSince(updatedAt)
        if diff < 3600 * 24 {
            return formatter.localizedString(for: updatedAt, relativeTo: Date())
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_Hans_CN")
        df.dateFormat = "M/d"
        return df.string(from: updatedAt)
    }

    static func empty() -> Note {
        Note(title: "", content: "", plainText: "")
    }
}

// MARK: - Folder Model
struct Folder: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String = "folder"
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isLocked: Bool = false
    var passwordHint: String = ""

    static let defaultFolders: [Folder] = [
        Folder(name: "快速笔记", icon: "note.text", sortOrder: -1),
        Folder(name: "工作", icon: "briefcase", sortOrder: 0),
        Folder(name: "个人", icon: "person", sortOrder: 1),
        Folder(name: "灵感", icon: "sparkles", sortOrder: 2),
    ]
}

// MARK: - Smart Folders (系统智能分类, 非持久化)
enum SmartFolder: String, CaseIterable, Identifiable {
    case all = "全部笔记"
    case today = "今天"
    case recent = "最近"
    case pinned = "已置顶"
    case trash = "最近删除"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "calendar.day.timeline.left"
        case .recent: return "clock"
        case .pinned: return "pin.fill"
        case .trash: return "trash"
        }
    }
}
