import SwiftUI

// MARK: - 笔记列表
struct NoteListView: View {
    @Environment(AppState.self) private var state
    @State private var showMoveSheet: Bool = false
    @State private var moveTarget: Note?

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
        .sheet(isPresented: $showMoveSheet) {
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

            Button(action: { state.createNote() }) {
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
                            .contextMenu { noteContextMenu(note: note) }
                    }
                    .onDelete { indexSet in
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(NSTableViewSelectionFix())
            }

            // 批量操作栏
            if state.isBatchMode {
                batchActionBar
            }
        }
    }

    // MARK: - Batch Action Bar
    private var batchActionBar: some View {
        HStack(spacing: 16) {
            if state.selectedSmartFolder == .trash {
                Button {
                    batchRestore()
                } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    batchPermanentDelete()
                } label: {
                    Label("永久删除", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .disabled(state.batchSelectedIds.isEmpty)
            } else {
                Button {
                    state.batchDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    showMoveSheet = true
                } label: {
                    Label("移动", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .disabled(state.batchSelectedIds.isEmpty)

                Button {
                    state.batchTogglePin()
                } label: {
                    Label("置顶", systemImage: "pin")
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

    // MARK: - Context Menu
    private func noteContextMenu(note: Note) -> some View {
        Group {
            if state.selectedSmartFolder == .trash {
                Button("恢复", systemImage: "arrow.uturn.backward") {
                    state.restoreNote(note)
                }
                Button("永久删除", systemImage: "trash", role: .destructive) {
                    state.permanentlyDeleteNote(note)
                }
            } else {
                Button(note.isPinned ? "取消置顶" : "置顶") {
                    state.togglePin(note)
                }
                Button("复制笔记") { state.duplicateNote(note) }
                Button("移动到...") {
                    moveTarget = note
                    showMoveSheet = true
                }
                Divider()
                Button("删除", role: .destructive) {
                    if state.selectedSmartFolder == .trash {
                        state.permanentlyDeleteNote(note)
                    } else {
                        state.deleteNote(note)
                    }
                }
            }
        }
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
                    } else if let note = moveTarget {
                        state.moveNote(note.id, to: folder.id)
                    }
                    showMoveSheet = false
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

            Button("取消") { showMoveSheet = false }
                .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 280, height: 300)
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

// MARK: - 移除私有 TableView 蓝色选中轮廓（适配 SwiftUI List 内部视图）
struct NSTableViewSelectionFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.retryFix(from: view, tries: 20)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor class Coordinator: NSObject {
        func retryFix(from view: NSView, tries: Int) {
            guard tries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                guard let window = view.window else {
                    self.retryFix(from: view, tries: tries - 1)
                    return
                }
                if self.fixAllTables(in: window.contentView) { return }
                self.retryFix(from: view, tries: tries - 1)
            }
        }

        /// 递归查找并修复所有 NSTableView（包括 NSOutlineView 等子类）
        func fixAllTables(in view: NSView?) -> Bool {
            guard let view else { return false }
            var found = false
            if let tv = view as? NSTableView {
                tv.selectionHighlightStyle = .none
                tv.focusRingType = .none
                tv.allowsEmptySelection = true
                tv.allowsColumnSelection = false
                tv.allowsMultipleSelection = false
                tv.allowsColumnReordering = false
                found = true
            }
            // 同时禁用所有 NSScrollView 的聚焦环
            if let sv = view as? NSScrollView {
                sv.focusRingType = .none
            }
            // 禁用所有 NSView 的聚焦环
            view.focusRingType = .none
            for sub in view.subviews {
                if fixAllTables(in: sub) { found = true }
            }
            return found
        }
    }
}

