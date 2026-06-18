import SwiftUI

// MARK: - 侧边栏
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @State private var showNewFolder: Bool = false
    @State private var newFolderName: String = ""
    @State private var newFolderIcon: String = "folder"
    @State private var showDeleteConfirm: Folder?

    var body: some View {
        List {
            // 智能分类
            Section {
                ForEach(SmartFolder.allCases) { smart in
                    smartRow(smart: smart)
                }
            } header: {
                Label("智能分类", systemImage: "sparkle.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }

            // 用户文件夹
            Section {
                ForEach(state.folders) { folder in
                    folderRowView(folder: folder)
                }
                .onMove { from, to in
                    state.folders.move(fromOffsets: from, toOffset: to)
                }
            } header: {
                HStack {
                    Label("文件夹", systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                    Spacer()
                    Button(action: { showNewFolder = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(state.currentTheme.accentColorSwift)
                    }
                    .buttonStyle(.plain)
                    .help("新建文件夹")
                }
            }

            // 标签
            if !state.allTags.isEmpty {
                Section {
                    ForEach(state.allTags, id: \.self) { tag in
                        HStack(spacing: 10) {
                            Image(systemName: "tag")
                                .font(.system(size: 11))
                                .foregroundColor(state.currentTheme.accentColorSwift)
                                .frame(width: 18)

                            Text(tag)
                                .font(.system(size: 13, weight: .medium))

                            Spacer()

                            let count = state.notes.filter { $0.tags.contains(tag) && !$0.isDeleted }.count
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(state.currentTheme.secondaryTextColorSwift.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 3)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(selectedBG(isSelected: state.selectedTag == tag))
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if state.selectedTag == tag {
                                    state.selectedTag = nil
                                } else {
                                    state.selectedTag = tag
                                    state.selectedSmartFolder = .all
                                    state.selectedFolderId = nil
                                    state.selectedNoteId = nil
                                    state.editingNote = nil
                                }
                            }
                        })
                    }
                } header: {
                    Label("标签", systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.15), value: state.selectedSmartFolder)
        .animation(.easeInOut(duration: 0.15), value: state.selectedFolderId)
        .animation(.easeInOut(duration: 0.15), value: state.selectedTag)
        .background(state.currentTheme.sidebarBgColorSwift)
        .foregroundColor(state.currentTheme.textColorSwift)
        .searchable(text: searchBinding, placement: .sidebar, prompt: "搜索笔记...")
        .sheet(isPresented: $showNewFolder) {
            newFolderSheet
        }
        .alert("删除文件夹", isPresented: .init(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("取消", role: .cancel) { showDeleteConfirm = nil; state.isDeleteFolderMode = false; state.isChangePasswordMode = false }
            Button("删除", role: .destructive) {
                if let folder = showDeleteConfirm {
                    if folder.isLocked {
                        // 锁定文件夹需要验证密码后才能删除
                        state.pendingLockFolderId = folder.id.uuidString
                        state.passwordErrorMessage = nil
                        state.showLockScreen = true
                        state.isSettingPassword = false
                        state.isDeleteFolderMode = true
                        state.isRemovePasswordMode = false
                        showDeleteConfirm = nil
                    } else {
                        state.deleteFolder(folder)
                        showDeleteConfirm = nil
                    }
                }
            }
        } message: {
            if let folder = showDeleteConfirm {
                Text("删除「\(folder.name)」及其中所有笔记？\n笔记将被移至「最近删除」。")
            }
        }
    }

    // MARK: - New Folder Sheet
    private let folderIcons = [
        "folder", "tray.full", "tray", "archivebox", "doc.text",
        "note.text", "bookmark", "star", "heart", "flag",
        "person", "person.2", "briefcase", "building", "house",
        "graduationcap", "book", "books.vertical", "magazine", "newspaper",
        "pencil", "pen", "highlighter", "scissors", "paperclip",
        "calendar", "clock", "alarm", "bell", "tag",
        "cart", "bag", "gift", "creditcard", "dollarsign",
        "phone", "envelope", "message", "bubble.left", "quote.bubble",
        "camera", "photo", "music.note", "mic", "speaker",
        "sparkles", "lightbulb", "wand.and.stars", "magnifyingglass", "globe",
        "gearshape", "wrench", "hammer", "paintpalette", "scissors",
        "leaf", "flame", "drop", "bolt", "moon",
    ]

    private var newFolderSheet: some View {
        VStack(spacing: 16) {
            Text("新建文件夹")
                .font(.system(size: 16, weight: .semibold))

            TextField("文件夹名称", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            // 当前选中的图标
            HStack {
                Image(systemName: newFolderIcon)
                    .font(.title3)
                    .foregroundColor(state.currentTheme.accentColorSwift)
                    .frame(width: 28)
                Text("选择图标")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }

            // 图标网格
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                    ForEach(folderIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .foregroundColor(icon == newFolderIcon
                                ? Color.primary : state.currentTheme.secondaryTextColorSwift)
                            .background(icon == newFolderIcon
                                ? state.currentTheme.accentColorSwift.opacity(0.12)
                                : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(icon == newFolderIcon
                                        ? state.currentTheme.accentColorSwift.opacity(0.3)
                                        : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture { newFolderIcon = icon }
                            .help(icon)
                    }
                }
                .padding(4)
            }
            .frame(height: 180)

            HStack(spacing: 16) {
                Button("取消") {
                    newFolderName = ""
                    newFolderIcon = "folder"
                    showNewFolder = false
                }
                .keyboardShortcut(.escape)

                Button("创建") {
                    let name = newFolderName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        state.createFolder(name: name, icon: newFolderIcon)
                        newFolderName = ""
                        newFolderIcon = "folder"
                        showNewFolder = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(state.currentTheme.accentColorSwift)
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 400)
        .background(state.currentTheme.backgroundColorSwift)
        .foregroundColor(state.currentTheme.textColorSwift)
    }

    // MARK: - Binding helpers
    private var searchBinding: Binding<String> {
        Binding(
            get: { state.searchText },
            set: { state.searchText = $0; state.isSearching = !$0.isEmpty }
        )
    }

    // MARK: - Selection
    private func selectSmart(_ smart: SmartFolder) {
        state.selectedSmartFolder = smart
        state.selectedFolderId = nil
        state.selectedNoteId = nil
        state.editingNote = nil
        state.selectedTag = nil
    }

    private func smartRow(smart: SmartFolder) -> some View {
        smartFolderRow(smart)
            .listRowInsets(EdgeInsets())
            .listRowBackground(selectedBG(isSelected: state.selectedSmartFolder == smart))
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { selectSmart(smart) })
            .contextMenu {
                Button("新建笔记", systemImage: "square.and.pencil") {
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                        state.createNote()
                    }
                }
                if smart == .trash {
                    Divider()
                    Button("清空最近删除", systemImage: "trash.slash", role: .destructive) {
                        state.emptyTrash()
                    }
                }
            }
    }

    private func folderRowView(folder: Folder) -> some View {
        folderRow(folder)
            .listRowInsets(EdgeInsets())
            .listRowBackground(selectedBG(isSelected: state.selectedFolderId == folder.id))
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { selectFolder(folder) })
            .contextMenu {
                Button("新建笔记", systemImage: "square.and.pencil") {
                    state.selectedFolderId = folder.id
                    state.selectedSmartFolder = nil
                    state.selectedNoteId = nil
                    state.editingNote = nil
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                        state.createNote(in: folder.id)
                    }
                }
                Divider()
                Button("重命名") { renameFolder(folder) }
                if folder.isLocked && state.isFolderUnlocked(folder.id.uuidString) {
                    Button("锁定", systemImage: "lock") { state.lockFolder(folder.id.uuidString) }
                }
                if folder.isLocked {
                    Button("修改密码", systemImage: "key") {
                        state.pendingLockFolderId = folder.id.uuidString
                        state.passwordErrorMessage = nil
                        state.showLockScreen = true
                        state.isSettingPassword = false
                        state.isDeleteFolderMode = false
                        state.isRemovePasswordMode = false
                        state.isChangePasswordMode = true
                    }
                    Button("移除密码", systemImage: "lock.open", role: .destructive) {
                        state.pendingLockFolderId = folder.id.uuidString
                        state.passwordErrorMessage = nil
                        state.showLockScreen = true
                        state.isSettingPassword = false
                        state.isDeleteFolderMode = false
                        state.isRemovePasswordMode = true
                    }
                } else {
                    Button("设置密码", systemImage: "lock") {
                        state.pendingLockFolderId = folder.id.uuidString
                        state.passwordErrorMessage = nil
                        state.showLockScreen = true
                        state.isSettingPassword = true
                        state.isChangePasswordMode = false
                    }
                }
                Divider()
                Button("删除文件夹", systemImage: "trash", role: .destructive) {
                    showDeleteConfirm = folder
                }
            }
    }

    private func selectFolder(_ folder: Folder) {
        if folder.isLocked && !state.isFolderUnlocked(folder.id.uuidString) {
            // 先选中文件夹，再弹出密码输入
            state.selectedFolderId = folder.id
            state.selectedSmartFolder = nil
            state.selectedNoteId = nil
            state.editingNote = nil
            state.selectedTag = nil
            state.pendingLockFolderId = folder.id.uuidString
            state.passwordErrorMessage = nil
            state.showLockScreen = true
            state.isSettingPassword = false
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            state.selectedFolderId = folder.id
            state.selectedSmartFolder = nil
            state.selectedNoteId = nil
            state.editingNote = nil
            state.selectedTag = nil
        }
    }

    // MARK: - Smart Folder Row
    private func smartFolderRow(_ smart: SmartFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: smart.icon)
                .font(.system(size: 12))
                .foregroundColor(state.currentTheme.accentColorSwift)
                .frame(width: 18)

            Text(smart.rawValue)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Text(countText(for: smart))
                .font(.caption2)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(state.currentTheme.secondaryTextColorSwift.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 3)
    }

    // MARK: - Folder Row
    private func folderRow(_ folder: Folder) -> some View {
        HStack(spacing: 10) {
            Group {
                if folder.isLocked && !state.isFolderUnlocked(folder.id.uuidString) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(state.currentTheme.accentColorSwift)
                } else if folder.isLocked && state.isFolderUnlocked(folder.id.uuidString) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 13))
                        .foregroundColor(state.currentTheme.accentColorSwift.opacity(0.6))
                } else {
                    Image(systemName: folder.icon)
                        .font(.system(size: 12))
                        .foregroundColor(state.currentTheme.accentColorSwift)
                }
            }
            .frame(width: 20)

            Text(folder.name)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            let rawCount = state.notes.filter { $0.folderId == folder.id && !$0.isDeleted }.count
            let count = (folder.isLocked && !state.isFolderUnlocked(folder.id.uuidString)) ? 0 : rawCount
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(state.currentTheme.secondaryTextColorSwift.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 3)
        .opacity(folder.isLocked && !state.isFolderUnlocked(folder.id.uuidString) ? 0.6 : 1)
    }

    // MARK: - Visual Helpers
    private func selectedBG(isSelected: Bool) -> some View {
        if isSelected {
            state.currentTheme.accentColorSwift.opacity(0.1)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Color.clear.clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Helpers
    private func countText(for smart: SmartFolder) -> String {
        switch smart {
        case .all: return "\(state.allNotesCount)"
        case .today: return "\(state.todayCount)"
        case .recent: return "\(state.recentCount)"
        case .pinned: return "\(state.pinnedCount)"
        case .trash: return "\(state.trashCount)"
        }
    }

    private func renameFolder(_ folder: Folder) {
        newFolderName = folder.name
        showNewFolder = true
    }
}
