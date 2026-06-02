import SwiftUI

// MARK: - 主内容视图 (三栏布局)
struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var app = state

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: state.sidebarWidth, max: 300)
        } content: {
            NoteListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 400)
        } detail: {
            NoteEditorView()
        }
        .background(state.currentTheme.backgroundColorSwift)
        .background {
            BackgroundTextureView(
                texture: state.currentTheme.backgroundTexture,
                intensity: state.themeIntensity
            )
        }
        .preferredColorScheme(colorSchemePreference)
        .sheet(isPresented: $app.showThemeEditor) {
            ThemeEditorView()
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $app.showLockScreen) {
            if let folderId = state.pendingLockFolderId {
                let mode: LockScreenView.LockMode = {
                    if state.isDeleteFolderMode { return .deleteFolder }
                    if state.isRemovePasswordMode { return .removePassword }
                    if state.isChangePasswordMode { return .changePassword }
                    if state.isSettingPassword { return .setPassword }
                    return .unlock
                }()
                return LockScreenView(folderId: folderId, mode: mode)
            }
            return LockScreenView(folderId: "", mode: .unlock)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { state.createNote() }) {
                    Label("新建笔记", systemImage: "square.and.pencil")
                }
                .help("新建笔记 (Cmd+N)")
                .keyboardShortcut("n")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { app.showThemeEditor = true }) {
                    Label("主题", systemImage: "paintpalette")
                }
                .help("自定义主题")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { app.showSettings = true }) {
                    Label("设置", systemImage: "gearshape")
                }
                .help("设置")
            }
        }
        .onAppear {
            applyAppearance()
        }
        .onChange(of: state.darkModePreference) { _, _ in
            applyAppearance()
        }
        .onChange(of: state.currentTheme.isDark) { _, _ in
            applyAppearance()
        }
    }

    /// 根据暗色模式偏好计算 ColorScheme
    private var colorSchemePreference: ColorScheme? {
        switch state.darkModePreference {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func applyAppearance() {
        let isDark: Bool = {
            switch state.darkModePreference {
            case .dark: return true
            case .light: return false
            case .system: return state.currentTheme.isDark
            }
        }()
        NSApp.appearance = isDark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
    }

}
