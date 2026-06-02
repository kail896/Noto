import Foundation
import SwiftUI

// MARK: - 纹理类型
enum TextureType: String, Codable, CaseIterable, Identifiable {
    case none = "无纹理"
    case dots = "圆点"
    case lines = "横线"
    case grid = "网格"
    case paper = "纸纹"
    case linen = "亚麻"
    case noise = "噪点"
    case waves = "波浪"
    case carbon = "碳纤维"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .none: return "square.dashed"
        case .dots: return "circle.fill"
        case .lines: return "line.3.horizontal"
        case .grid: return "grid"
        case .paper: return "doc.text"
        case .linen: return "square.grid.3x3"
        case .noise: return "sparkles"
        case .waves: return "waveform"
        case .carbon: return "hexagon.fill"
        }
    }
}

// MARK: - 字体配置
struct FontConfiguration: Codable, Hashable {
    var family: String = "SF Pro"
    var size: Double = 16
    var weight: FontWeightOption = .medium
    var lineSpacing: Double = 1.5
    var enableLigatures: Bool = true

    static let `default` = FontConfiguration()
}

enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case ultraLight = "极细"
    case thin = "细体"
    case light = "轻体"
    case regular = "常规"
    case medium = "中等"
    case semibold = "半粗"
    case bold = "粗体"
    case heavy = "特粗"
    case black = "黑体"

    var id: String { rawValue }

    var toSwiftWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

// MARK: - 主题模型
struct NoteTheme: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var backgroundColor: String
    var backgroundTexture: TextureType
    var textColor: String
    var secondaryTextColor: String
    var accentColor: String
    var fontConfiguration: FontConfiguration
    var isDark: Bool
    var noteListBgColor: String
    var sidebarBgColor: String
    var cardColor: String
    var cornerRadius: Double = 12
    var blurIntensity: Double = 0.0

    var backgroundColorSwift: Color { Color(hex: backgroundColor) }
    var textColorSwift: Color { Color(hex: textColor) }
    var secondaryTextColorSwift: Color { Color(hex: secondaryTextColor) }
    var accentColorSwift: Color { Color(hex: accentColor) }
    var noteListBgColorSwift: Color { Color(hex: noteListBgColor) }
    var sidebarBgColorSwift: Color { Color(hex: sidebarBgColor) }
    var cardColorSwift: Color { Color(hex: cardColor) }

    static let lightDefault = NoteTheme(
        id: "light-default",
        name: "清新白",
        backgroundColor: "#F5F5F7",
        backgroundTexture: .none,
        textColor: "#1D1D1F",
        secondaryTextColor: "#86868B",
        accentColor: "#007AFF",
        fontConfiguration: .default,
        isDark: false,
        noteListBgColor: "#FFFFFF",
        sidebarBgColor: "#F2F2F7",
        cardColor: "#FFFFFF"
    )

    static let darkDefault = NoteTheme(
        id: "dark-default",
        name: "深邃黑",
        backgroundColor: "#1C1C1E",
        backgroundTexture: .dots,
        textColor: "#F5F5F7",
        secondaryTextColor: "#98989D",
        accentColor: "#0A84FF",
        fontConfiguration: .default,
        isDark: true,
        noteListBgColor: "#2C2C2E",
        sidebarBgColor: "#1C1C1E",
        cardColor: "#2C2C2E"
    )

    static let sepia = NoteTheme(
        id: "sepia",
        name: "复古黄",
        backgroundColor: "#FBF3E8",
        backgroundTexture: .paper,
        textColor: "#3E2E1D",
        secondaryTextColor: "#8B7D6B",
        accentColor: "#C04B1E",
        fontConfiguration: {
            var f = FontConfiguration.default
            f.family = "Georgia"
            return f
        }(),
        isDark: false,
        noteListBgColor: "#FDF8F0",
        sidebarBgColor: "#F5EDE0",
        cardColor: "#FDF8F0"
    )

    static let midnight = NoteTheme(
        id: "midnight",
        name: "午夜蓝",
        backgroundColor: "#1A1B2E",
        backgroundTexture: .noise,
        textColor: "#E8E9F3",
        secondaryTextColor: "#8B8DA6",
        accentColor: "#7B8BFF",
        fontConfiguration: .default,
        isDark: true,
        noteListBgColor: "#222339",
        sidebarBgColor: "#1A1B2E",
        cardColor: "#222339"
    )

    static let forest = NoteTheme(
        id: "forest",
        name: "森林绿",
        backgroundColor: "#E8F0E0",
        backgroundTexture: .linen,
        textColor: "#2C3E2D",
        secondaryTextColor: "#6B8F71",
        accentColor: "#4A7C59",
        fontConfiguration: {
            var f = FontConfiguration.default
            f.family = "STSongti"
            return f
        }(),
        isDark: false,
        noteListBgColor: "#F0F6EC",
        sidebarBgColor: "#E2EDD8",
        cardColor: "#F0F6EC"
    )

    static let ocean = NoteTheme(
        id: "ocean",
        name: "海洋蓝",
        backgroundColor: "#0A1628",
        backgroundTexture: .waves,
        textColor: "#D4E4F7",
        secondaryTextColor: "#7A9CC6",
        accentColor: "#5BA3E6",
        fontConfiguration: .default,
        isDark: true,
        noteListBgColor: "#0F1F35",
        sidebarBgColor: "#0A1628",
        cardColor: "#0F1F35"
    )

    static let defaultThemes: [NoteTheme] = [
        .lightDefault, .darkDefault, .sepia, .midnight, .forest, .ocean
    ]
}
