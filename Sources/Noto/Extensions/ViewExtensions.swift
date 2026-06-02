import SwiftUI

// MARK: - View Extensions

extension View {
    /// 添加毛玻璃背景效果
    func glassBackground(cornerRadius: CGFloat = 12, opacity: Double = 0.3) -> some View {
        self.background(
            .ultraThinMaterial.opacity(opacity),
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
    }

    /// 暗色模式适配
    func conditionalDarkMode(_ isDark: Bool) -> some View {
        self.preferredColorScheme(isDark ? .dark : nil)
    }
}

// MARK: - NSImage Extensions
extension NSImage {
    /// Create NSImage from system symbol
    static func symbol(_ name: String, size: CGFloat = 16) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}

// MARK: - String Extensions
extension String {
    /// 截取预览文本
    func preview(limit: Int = 100) -> String {
        if count > limit {
            return String(prefix(limit)) + "..."
        }
        return self
    }

    /// 是否为空白或空
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
