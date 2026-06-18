import SwiftUI

// MARK: - 设置页面
struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏 + 关闭按钮
            HStack {
                Text("设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(state.currentTheme.textColorSwift)

                Spacer()

                Button(action: { state.showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }
                .buttonStyle(.plain)
                .help("关闭设置")
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(state.currentTheme.cardColorSwift)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.15)),
                alignment: .bottom
            )

            TabView {
                generalSettings
                    .tabItem { Label("通用", systemImage: "gearshape") }

                aboutSettings
                    .tabItem { Label("关于", systemImage: "info.circle") }
            }
        }
        .frame(width: 460, height: 420)
        .background(state.currentTheme.backgroundColorSwift)
        .foregroundColor(state.currentTheme.textColorSwift)
        .preferredColorScheme(state.currentTheme.isDark ? .dark : nil)
    }

    // MARK: - General
    private var generalSettings: some View {
        Form {
            Section("编辑器") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { true },
                        set: { _ in }
                    )) {
                        Text("自动保存")
                    }
                    Text("内容将在编辑后自动保存")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { true },
                        set: { _ in }
                    )) {
                        Text("启用拼写检查")
                    }
                }
            }

            Section("数据") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { state.iCloudEnabled },
                        set: { state.iCloudEnabled = $0; state.saveData() }
                    )) {
                        Text("iCloud 同步")
                    }
                    .disabled(!state.iCloudAvailable)
                    Text(state.iCloudAvailable
                         ? "iCloud Drive 可用，数据将自动在多设备间同步"
                         : "iCloud Drive 不可用，请登录 iCloud 账号")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                    Text("检测: \(FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs") ? "可用" : "不可用")")
                        .font(.caption2)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.5))
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }

                Button("清空最近删除", role: .destructive) {
                    state.emptyTrash()
                }
                .disabled(state.trashCount == 0)

                HStack {
                    Text("自动清理天数")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { state.trashRetentionDays },
                        set: { state.trashRetentionDays = $0; state.saveData(); state.cleanupTrash() }
                    )) {
                        Text("7 天").tag(7)
                        Text("15 天").tag(15)
                        Text("30 天").tag(30)
                        Text("60 天").tag(60)
                        Text("90 天").tag(90)
                        Text("不自动删除").tag(0)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                Text("超过设定天数的已删除笔记将被彻底清除")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }

            Section("快捷键") {
                shortcutRow("新建笔记", "⌘N")
                shortcutRow("搜索", "⌘F")
                shortcutRow("删除笔记", "⌘⌫")
                shortcutRow("主题编辑器", "⌘T")
                shortcutRow("设置", "⌘,")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - About
    private var aboutSettings: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(state.currentTheme.accentColorSwift)

            Text("Noto")
                .font(.system(size: 24, weight: .bold))

            Text("版本 1.1.2")
                .font(.callout)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)

            Text("极简笔记 · 个性主题 · 流畅体验")
                .font(.callout)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)

            VStack(spacing: 4) {
                Text("原生构建 · 适配 Apple Silicon")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.6))

                Text("SwiftUI · macOS 15+")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.6))
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(state.currentTheme.secondaryTextColorSwift.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
