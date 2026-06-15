import SwiftUI

// MARK: - 笔记列表
struct NoteListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 笔记列表
            if state.filteredNotes.isEmpty {
                emptyStateView
            } else {
                noteList
            }
        }
        .background(state.currentTheme.noteListBgColorSwift)
        .background {
            BackgroundTextureView(
                texture: state.currentTheme.backgroundTexture,
                intensity: state.themeIntensity * 0.6
            )
        }
        .sheet(isPresented: Binding(
            get: { state.showNoteMoveSheet },
            set: { state.showNoteMoveSheet = $0 }
        )) {
            moveSheetView
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text(sectionTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(state.currentTheme.textColorSwift)

            Spacer()

            // 排序选择
            if !state.isBatchMode {
                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            state.sortOption = option
                            state.saveData()
                        } label: {
                            HStack {
                                Text(option.label)
                                if state.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: state.sortOption.icon)
                            .font(.caption)
                        Text(state.sortOption.label)
                            .font(.caption)
                    }
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.trailing, 4)
                .help("排序方式")
            }

            if state.isBatchMode {
                Button(state.batchSelectedIds.count == state.filteredNotes.count ? "取消全选" : "全选") {
                    state.batchSelectAll()
                }
                .font(.caption)
                .foregroundColor(state.currentTheme.accentColorSwift)
                .buttonStyle(.plain)

                Button("完成") {
                    state.exitBatchMode()
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(state.currentTheme.accentColorSwift)
                .buttonStyle(.plain)
                .padding(.leading, 8)
            } else {
                Button("选择") {
                    state.isBatchMode = true
                }
                .font(.caption)
                .foregroundColor(state.currentTheme.accentColorSwift)
                .buttonStyle(.plain)

                Text("\(state.filteredNotes.count) 篇")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(state.currentTheme.noteListBgColorSwift.opacity(0.8))
    }

    private var sectionTitle: String {
        if let smart = state.selectedSmartFolder {
            return smart.rawValue
        } else if let folderId = state.selectedFolderId,
                  let folder = state.folders.first(where: { $0.id == folderId }) {
            return folder.name
        }
        return "笔记"
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.5))

            Text("暂无笔记")
                .font(.title3)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)

            Text("点击 ⌘N 或工具栏按钮新建")
                .font(.caption)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.7))

            Button(action: { withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) { state.createNote() } }) {
                Label("新建笔记", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.currentTheme.accentColorSwift)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Note List
    private var noteList: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(state.filteredNotes) { note in
                        noteCard(note)
                            .id(note.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(note.id == state.selectedNoteId && !state.isBatchMode
                                        ? state.currentTheme.accentColorSwift.opacity(0.12)
                                        : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if state.isBatchMode {
                                    state.toggleBatchSelection(note.id)
                                } else {
                                    selectNote(note)
                                }
                            }
                            .overlay(RightClickHostView { [state] in
                Self.rightClickMenuItems(for: note, state: state)
            })
                            
                    }
                    .onDelete { indexSet in
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9)) {
                            if let idx = indexSet.first, idx < state.filteredNotes.count {
                                let note = state.filteredNotes[idx]
                                if state.selectedSmartFolder == .trash {
                                    state.permanentlyDeleteNote(note)
                                } else {
                                    state.deleteNote(note)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(.easeInOut(duration: 0.15), value: state.selectedNoteId)
                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: state.filteredNotes.count)
                .background(NSTableViewSelectionFix())
            }

            // 批量操作栏
            if state.isBatchMode {
                batchActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .id("list-\(state.selectedSmartFolder?.rawValue ?? "")-\(state.selectedFolderId?.uuidString ?? "")")
        .transition(.opacity)
    }

    // MARK: - Batch Action Bar
    private var batchActionBar: some View {
        HStack(spacing: 16) {
            if state.selectedSmartFolder == .trash {
                Button {
                    batchRestore()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("恢复").lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    batchPermanentDelete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("永久删除").lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .disabled(state.batchSelectedIds.isEmpty)
            } else {
                Button {
                    state.batchDelete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除").lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    state.showNoteMoveSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("移动").lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    state.batchTogglePin()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pin")
                        Text("置顶").lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .disabled(state.batchSelectedIds.isEmpty)
            }

            Spacer()

            Text("已选 \(state.batchSelectedIds.count) 项")
                .font(.caption)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)

            if !state.batchSelectedIds.isEmpty {
                Button("清除") { state.batchSelectedIds.removeAll() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(state.currentTheme.cardColorSwift)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Note Card
    private func noteCard(_ note: Note) -> some View {
        HStack(spacing: 10) {
            // 批量模式复选框
            if state.isBatchMode {
                Button {
                    state.toggleBatchSelection(note.id)
                } label: {
                    Image(systemName: state.batchSelectedIds.contains(note.id)
                        ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(state.batchSelectedIds.contains(note.id)
                            ? state.currentTheme.accentColorSwift
                            : state.currentTheme.secondaryTextColorSwift.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(state.currentTheme.accentColorSwift)
                    }

                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(state.currentTheme.textColorSwift)
                        .lineLimit(1)

                    Spacer()

                    Text(note.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }

                Text(note.previewText)
                    .font(.system(size: 12))
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(state.currentTheme.cardColorSwift)
                .shadow(color: .black.opacity(state.currentTheme.isDark ? 0.15 : 0.04),
                        radius: 4, y: 1)
        )
    }

    // MARK: - Move Sheet
    private var moveSheetView: some View {
        VStack(spacing: 16) {
            Text("移动到文件夹")
                .font(.headline)

            List(state.folders) { folder in
                Button(action: {
                    if state.isBatchMode {
                        state.batchMove(to: folder.id)
                    } else if let noteId = state.movingNoteId {
                        state.moveNote(noteId, to: folder.id)
                        state.movingNoteId = nil
                    }
                    state.showNoteMoveSheet = false
                }) {
                    HStack {
                        Image(systemName: folder.icon)
                            .foregroundColor(state.currentTheme.accentColorSwift)
                        Text(folder.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 200)

            Button("取消") { state.showNoteMoveSheet = false }
                .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 280, height: 300)
    }

    // MARK: - Context Menu
    static func rightClickMenuItems(for note: Note, state: AppState) -> [RightClickMenuItem2] {
        if state.selectedSmartFolder == .trash {
            return [
                RightClickMenuItem2("恢复", systemImage: "arrow.uturn.backward") { state.restoreNote(note) },
                RightClickMenuItem2("永久删除", systemImage: "trash", destructive: true) { state.permanentlyDeleteNote(note) },
                RightClickMenuItem2.separator(),
                RightClickMenuItem2("清空最近删除", systemImage: "trash.slash", destructive: true) { state.emptyTrash() },
            ]
        }
        return [
            RightClickMenuItem2("新建笔记", systemImage: "square.and.pencil") { withAnimation { state.createNote() } },
            RightClickMenuItem2.separator(),
            RightClickMenuItem2(note.isPinned ? "取消置顶" : "置顶", systemImage: "pin") { state.togglePin(note) },
            RightClickMenuItem2("复制笔记", systemImage: "doc.on.doc") { state.duplicateNote(note) },
            RightClickMenuItem2("移动到...", systemImage: "folder") {
                state.movingNoteId = note.id
                state.showNoteMoveSheet = true
            },
            RightClickMenuItem2.separator(),
            RightClickMenuItem2("删除", systemImage: "trash", destructive: true) { state.deleteNote(note) },
        ]
    }
    // MARK: - Batch Actions (Trash)
    private func batchRestore() {
        for id in state.batchSelectedIds {
            if let note = state.notes.first(where: { $0.id == id }) {
                state.restoreNote(note)
            }
        }
        state.exitBatchMode()
    }

    private func batchPermanentDelete() {
        for id in state.batchSelectedIds {
            if let note = state.notes.first(where: { $0.id == id }) {
                state.permanentlyDeleteNote(note)
            }
        }
        state.exitBatchMode()
    }

    // MARK: - Selection
    private func deselectNote() {
        state.selectedNoteId = nil
        state.editingNote = nil
    }

    private func selectNote(_ note: Note) {
        state.selectedNoteId = note.id
        state.editingNote = note
    }
}

// MARK: - 右键菜单组件（无蓝色高亮）
struct RightClickMenuItem2 {
    let title: String
    let systemImage: String?
    let action: () -> Void
    let isDestructive: Bool
    let isSeparator: Bool

    init(_ title: String, systemImage: String? = nil, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.isDestructive = destructive
        self.isSeparator = false
    }

    static func separator() -> RightClickMenuItem2 {
        RightClickMenuItem2(title: "", systemImage: nil, destructive: false, action: {}, isSeparator: true)
    }

    private init(title: String, systemImage: String?, destructive: Bool, action: @escaping () -> Void, isSeparator: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.isDestructive = destructive
        self.isSeparator = isSeparator
    }
}

/// 叠加层视图：截获右键事件并弹出 NSMenu（绕过 SwiftUI 的蓝色高亮）
struct RightClickHostView: NSViewRepresentable {
    let builder: () -> [RightClickMenuItem2]

    func makeNSView(context: Context) -> NSView {
        let v = _RightClickView()
        v.builder = builder
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? _RightClickView)?.builder = builder
    }
}

class _RightClickView: NSView {
    var builder: (() -> [RightClickMenuItem2])?

    override func rightMouseDown(with event: NSEvent) {
        guard let items = builder?() else { return }
        let menu = NSMenu(title: "")
        for item in items {
            if item.isSeparator {
                menu.addItem(NSMenuItem.separator())
                continue
            }
            let mi = NSMenuItem(title: item.title, action: #selector(doAction(_:)), keyEquivalent: "")
            mi.representedObject = item
            mi.target = self
            if item.isDestructive {
                mi.attributedTitle = NSAttributedString(string: item.title, attributes: [.foregroundColor: NSColor.red])
            }
            if let icon = item.systemImage, let img = NSImage(systemSymbolName: icon, accessibilityDescription: item.title) {
                mi.image = img
            }
            menu.addItem(mi)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func doAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? RightClickMenuItem2 else { return }
        item.action()
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    /// 只拦截右键事件，左键穿透到下层视图
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        if event.type == .rightMouseDown || event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            return self
        }
        return nil  // 左键穿透
    }
}

// MARK: - 持续禁用 NSTableView 选中高亮（定时强制定制，防止 SwiftUI 重置）
struct NSTableViewSelectionFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DisabledSelectionView()
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 自定义 NSView：高频禁用所有 NSTableView 的选中高亮和聚焦环
@MainActor class DisabledSelectionView: NSView {
    private var timer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let w = self?.window else { return }
            self?.disableAll(in: w.contentView)
        }
        if let w = window { disableAll(in: w.contentView) }
    }

    func disableAll(in view: NSView?) {
        guard let view else { return }
        view.focusRingType = .none
        if let tv = view as? NSTableView {
            tv.selectionHighlightStyle = .none
            tv.focusRingType = .none
            tv.gridColor = .clear
            tv.backgroundColor = .clear
        }
        if let sv = view as? NSScrollView {
            sv.focusRingType = .none
            sv.drawsBackground = false
        }
        for sub in view.subviews { disableAll(in: sub) }
    }

    nonisolated deinit {
        Task { @MainActor in
            // timer invalidated on main actor
        }
    }
}


