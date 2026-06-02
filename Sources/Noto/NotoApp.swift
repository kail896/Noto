import SwiftUI
import AppKit

// MARK: - Noto App Entry Point
@main
struct NotoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    configureWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.saveDataSync()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            // 文件菜单
            CommandGroup(replacing: .newItem) {
                Button("新建笔记") {
                    appState.createNote()
                }
                .keyboardShortcut("n")

                Button("新建文件夹") {
                    appState.createFolder(name: "新文件夹")
                }
                .keyboardShortcut("N")

                Divider()

                Button("删除笔记") {
                    if let note = appState.editingNote {
                        appState.deleteNote(note)
                    }
                }
                .keyboardShortcut(.delete)
                .disabled(appState.editingNote == nil)
            }

            // 编辑菜单
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z")

                Button("重做") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("Z")
            }

            // 视图菜单
            CommandMenu("视图") {
                Button("切换侧边栏") {
                    toggleSidebar()
                }
                .keyboardShortcut("b")

                Button("主题编辑器") {
                    appState.showThemeEditor = true
                }
                .keyboardShortcut("t")

                Divider()

                Button("设置") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",")
            }

            // 帮助菜单
            CommandGroup(replacing: .help) {
                Button("关于 Noto") {
                    appState.showSettings = true
                }
            }
        }
        .defaultSize(width: 1100, height: 700)
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.title = "Noto"
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.styleMask.insert(.fullSizeContentView)
                window.toolbarStyle = .unifiedCompact
                window.minSize = NSSize(width: 800, height: 500)
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
