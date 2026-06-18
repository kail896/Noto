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

                Divider()

                Button("导出笔记...") {
                    exportNote()
                }
                .keyboardShortcut("e")
                .disabled(appState.editingNote == nil)

                Button("打印...") {
                    let printInfo = NSPrintInfo.shared
                    if let window = NSApp.keyWindow {
                        NSPrintOperation(view: window.contentView!, printInfo: printInfo).run()
                    }
                }
                .keyboardShortcut("p")
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

                Divider()

                Button("查找") {
                    // 聚焦搜索栏
                    DispatchQueue.main.async {
                        appState.isSearching = true
                    }
                }
                .keyboardShortcut("f")
            }

            // 格式菜单
            CommandMenu("格式") {
                Button("粗体") {
                    NotificationCenter.default.post(name: .init("toggleBold"), object: nil)
                }
                .keyboardShortcut("b")

                Button("斜体") {
                    NotificationCenter.default.post(name: .init("toggleItalic"), object: nil)
                }
                .keyboardShortcut("i")

                Button("下划线") {
                    NotificationCenter.default.post(name: .init("toggleUnderline"), object: nil)
                }
                .keyboardShortcut("u")
            }

            // 视图菜单
            CommandMenu("视图") {
                Button("切换侧边栏") {
                    toggleSidebar()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("主题编辑器") {
                    appState.showThemeEditor = true
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("全屏") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])

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

    private func exportNote() {
        guard let note = appState.editingNote else { return }
        NoteListView.exportNote(note: note, state: appState)
    }
}
