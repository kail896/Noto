import SwiftUI

// MARK: - 主内容视图 (三栏布局)
struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var app = state

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 150, ideal: state.sidebarWidth, max: 350)
        } content: {
            NoteListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: state.noteListWidth, max: 500)
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
                Button(action: { withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) { state.createNote() } }) {
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
        .onChange(of: state.currentTheme.isDark) { _, newVal in
            NSApp.appearance = newVal
                ? NSAppearance(named: .darkAqua)
                : NSAppearance(named: .aqua)
        }
        .onAppear {
            // 监听系统外观变化，更新跟随系统主题
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil, queue: .main
            ) { [weak state] _ in
                if state?.selectedThemeId == "system-auto" {
                    state?.appearanceVersion += 1
                }
            }
        }
    }

    /// 主题的 isDark 决定颜色方案（不再使用单独的 darkModePreference）
    private var colorSchemePreference: ColorScheme? {
        state.currentTheme.isDark ? .dark : .light
    }

}
