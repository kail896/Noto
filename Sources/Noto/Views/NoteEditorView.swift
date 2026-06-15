import SwiftUI
import AppKit

// MARK: - 笔记编辑器
struct NoteEditorView: View {
    @Environment(AppState.self) private var state
    @FocusState private var isTitleFocused: Bool
    @State private var editorContent: NSAttributedString = .init()
    @State private var isEditing: Bool = false
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var savingNoteId: UUID?
    @State private var isLoadingContent: Bool = false
    @State private var formatState = FormatState()
    @State private var slideOffset: CGFloat = 0

    var body: some View {
        Group {
            if let note = state.editingNote {
                editorContent(note: note)
                    .offset(x: slideOffset)
                    .opacity(slideOffset == 0 ? 1 : Double(max(0, 1 - slideOffset / 200)))
            } else {
                emptyEditor
            }
        }
        .background(state.currentTheme.backgroundColorSwift)
        .background {
            BackgroundTextureView(
                texture: state.currentTheme.backgroundTexture,
                intensity: state.themeIntensity
            )
        }
        .onChange(of: state.selectedNoteId) { _, newId in
            // 触发抽屉滑入动画：先将内容推到左侧
            slideOffset = -200
            // 保存当前内容
            saveCurrentContent()
            // 后台加载新笔记内容
            if let id = newId, let note = state.notes.first(where: { $0.id == id }) {
                isLoadingContent = true
                loadContentAsync(note)
                // 延迟一帧后滑动归位（此时内容已加载）
                DispatchQueue.main.async {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.82)) {
                        slideOffset = 0
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            saveCurrentContent()
            saveWorkItem?.cancel()
            state.saveData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            saveCurrentContent()
            state.saveDataSync()
        }
    }

    // MARK: - Empty State
    private var emptyEditor: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.3))

            VStack(spacing: 8) {
                Text("选择一个笔记")
                    .font(.title2)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)

                Text("从左侧选择一个笔记或新建笔记")
                    .font(.callout)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.6))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editor Content
    private func editorContent(note: Note) -> some View {
        VStack(spacing: 0) {
            formattingToolbar

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        titleField(note: note)

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                            Text("上次编辑 \(note.formattedDate)")
                                .font(.caption2)
                                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                            if note.isPinned {
                                Text("·")
                                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundColor(state.currentTheme.accentColorSwift)
                                Text("已置顶")
                                    .font(.caption2)
                                    .foregroundColor(state.currentTheme.accentColorSwift)
                            }
                        }

                        Divider()
                            .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.3))

                        RichTextView(
                            attributedText: $editorContent,
                            theme: state.currentTheme,
                            onChange: {
                                isEditing = true
                                autoSave(note: note)
                            },
                            onSelectionChange: { fmt in
                                formatState = fmt
                            }
                        )
                        .frame(minHeight: max(300, geo.size.height - 150))
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            isTitleFocused = note.title.isEmpty
        }
    }

    // MARK: - Title
    private func titleField(note: Note) -> some View {
        TextField("无标题", text: Binding(
            get: { note.title },
            set: { newTitle in
                if let idx = state.notes.firstIndex(where: { $0.id == note.id }) {
                    state.notes[idx].title = newTitle
                    state.notes[idx].updatedAt = Date()
                    state.editingNote?.title = newTitle
                    debounceSave()
                }
            }
        ))
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(state.currentTheme.textColorSwift)
        .textFieldStyle(.plain)
        .focused($isTitleFocused)
        .tint(state.currentTheme.accentColorSwift)
    }

    // MARK: - Formatting Toolbar
    private var formattingToolbar: some View {
        VStack(spacing: 0) {
            // ── 第一行：文字样式 + 对齐 + 字号 + 列表 ──
            HStack(spacing: 1) {
                // 文字样式
                formatButton("bold", help: "粗体", isActive: formatState.isBold) { toggleBold() }
                formatButton("italic", help: "斜体", isActive: formatState.isItalic) { toggleItalic() }
                formatButton("underline", help: "下划线", isActive: formatState.isUnderline) { toggleUnderline() }
                formatButton("strikethrough", help: "删除线", isActive: formatState.isStrikethrough) { toggleStrikethrough() }

                Divider().frame(height: 18).padding(.horizontal, 3)

                // 对齐
                toolButton("text.alignleft", help: "左对齐") { setAlignment(.left) }
                toolButton("text.aligncenter", help: "居中") { setAlignment(.center) }
                toolButton("text.alignright", help: "右对齐") { setAlignment(.right) }

                Divider().frame(height: 18).padding(.horizontal, 3)

                // 字号
                toolButton("textformat.size.larger", help: "增大字号") { toggleFontSize(increase: true) }
                toolButton("textformat.size.smaller", help: "减小字号") { toggleFontSize(increase: false) }

                Divider().frame(height: 18).padding(.horizontal, 3)

                // 列表
                toolButton("list.bullet", help: "无序列表") { toggleBulletList() }
                toolButton("list.number", help: "有序列表") { toggleNumberedList() }
                toolButton("checkmark.square", help: "待办事项") { insertTodo() }

                Divider().frame(height: 18).padding(.horizontal, 3)

                // 缩进
                toolButton("increase.indent", help: "增加缩进") { adjustIndent(increase: true) }
                toolButton("decrease.indent", help: "减少缩进") { adjustIndent(increase: false) }

                Divider().frame(height: 18).padding(.horizontal, 3)

                // 行距 / 对齐方式
                toolButton("line.3.horizontal.decrease", help: "行距") { toggleLineSpacing() }
                toolButton("text.alignjustified", help: "两端对齐") { setAlignment(.justified) }

                Spacer(minLength: 4)

                // 字数统计
                Text("\(editorContent.length)")
                    .font(.caption2)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.5))
                    .padding(.trailing, 6)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)

            // ── 第二行：颜色 + 高亮 + 引用 + 链接 + 代码 + 图片 + 分割线 + 清除格式 ──
            HStack(spacing: 1) {
                toolButton("text.quote", help: "引用块") { toggleQuoteBlock() }
                colorButton
                toolButton("highlighter", help: "背景高亮") { toggleHighlight() }

                Divider().frame(height: 18).padding(.horizontal, 3)

                linkButton
                toolButton("chevron.left.forwardslash.chevron.right", help: "代码块") { toggleCodeBlock() }
                toolButton("photo.on.rectangle", help: "插入图片") { insertImage() }
                toolButton("minus", help: "分割线") { insertDivider() }

                Divider().frame(height: 18).padding(.horizontal, 3)

                toolButton("eraser", help: "清除格式") { clearFormatting() }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .background(state.currentTheme.cardColorSwift.opacity(0.6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(state.currentTheme.secondaryTextColorSwift.opacity(0.2)),
            alignment: .bottom
        )
        .sheet(isPresented: $showLinkSheet) {
            linkInputView
        }
        .popover(isPresented: $showColorPicker) {
            colorPickerView
        }
    }

    // MARK: - Toolbar Buttons
    /// 普通工具栏按钮
    private func toolButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        ToolbarButton(icon: icon, help: help, isActive: false, accentColor: state.currentTheme.accentColorSwift, action: action)
    }

    /// 格式切换按钮（带激活态高亮）
    private func formatButton(_ icon: String, help: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        ToolbarButton(icon: icon, help: help, isActive: isActive, accentColor: state.currentTheme.accentColorSwift, action: action)
    }

    // MARK: - Formatting Toggle Helpers
    private func toggleBold() {
        guard let tv = findFirstResponderTextView() else { return }
        guard let font = tv.font else { return }
        let desc = font.fontDescriptor
        let sym = desc.symbolicTraits
        let addBold = !sym.contains(.bold)
        let newSym = addBold ? sym.union(.bold) : sym.subtracting(.bold)
        let newDesc = desc.withSymbolicTraits(newSym)
        if let newFont = NSFont(descriptor: newDesc, size: font.pointSize) {
            tv.font = newFont
        }
    }

    private func toggleItalic() {
        guard let tv = findFirstResponderTextView() else { return }
        guard let font = tv.font else { return }
        let desc = font.fontDescriptor
        let sym = desc.symbolicTraits
        let addItalic = !sym.contains(.italic) && !font.fontName.lowercased().contains("italic")
        let newSym = addItalic ? sym.union(.italic) : sym.subtracting(.italic)
        let newDesc = desc.withSymbolicTraits(newSym)
        if let newFont = NSFont(descriptor: newDesc, size: font.pointSize) {
            tv.font = newFont
        }
    }

    private func toggleUnderline() {
        guard let tv = findFirstResponderTextView() else { return }
        let selectedRange = tv.selectedRange()
        guard selectedRange.length > 0 else { return }
        let storage = tv.textStorage!
        storage.beginEditing()
        let existing = storage.attribute(.underlineStyle, at: selectedRange.location, effectiveRange: nil) as? Int
        if existing != nil, existing! > 0 {
            storage.removeAttribute(.underlineStyle, range: selectedRange)
        } else {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        storage.endEditing()
    }

    private func toggleStrikethrough() {
        guard let tv = findFirstResponderTextView() else { return }
        let selectedRange = tv.selectedRange()
        guard selectedRange.length > 0 else { return }
        let storage = tv.textStorage!
        storage.beginEditing()
        let existing = storage.attribute(.strikethroughStyle, at: selectedRange.location, effectiveRange: nil) as? Int
        if existing != nil, existing! > 0 {
            storage.removeAttribute(.strikethroughStyle, range: selectedRange)
        } else {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        storage.endEditing()
    }

    // MARK: - Color Picker
    @State private var showColorPicker = false
    private let presetColors: [(String, NSColor)] = [
        ("红色", .systemRed), ("橙色", .systemOrange), ("黄色", .systemYellow),
        ("绿色", .systemGreen), ("蓝色", .systemBlue), ("紫色", .systemPurple),
        ("黑色", .black), ("灰色", .gray), ("白色", .white),
    ]

    private var colorButton: some View {
        Button(action: { showColorPicker.toggle() }) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundColor(state.currentTheme.accentColorSwift)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("字体颜色")
    }

    private var colorPickerView: some View {
        VStack(spacing: 8) {
            Text("选择字体颜色").font(.caption).foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                ForEach(presetColors, id: \.0) { name, color in
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .onTapGesture { applyFontColor(color) }
                        .help(name)
                }
            }
            .padding(8)
        }
        .frame(width: 180)
        .padding(8)
    }

    // MARK: - Link Input
    @State private var showLinkSheet = false
    @State private var linkURL = ""
    @State private var linkText = ""

    private var linkButton: some View {
        Button(action: {
            if let tv = findFirstResponderTextView(), tv.selectedRange().length > 0 {
                linkText = (tv.string as NSString).substring(with: tv.selectedRange())
            } else {
                linkText = ""
            }
            linkURL = "https://"
            showLinkSheet = true
        }) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("插入链接")
    }

    private var linkInputView: some View {
        VStack(spacing: 12) {
            Text("插入链接").font(.headline)
            TextField("链接文字", text: $linkText)
                .textFieldStyle(.roundedBorder)
            TextField("URL", text: $linkURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showLinkSheet = false; linkURL = ""; linkText = "" }
                    .keyboardShortcut(.escape)
                Button("插入") {
                    insertLink(url: linkURL, text: linkText)
                    showLinkSheet = false
                    linkURL = ""
                    linkText = ""
                }
                .keyboardShortcut(.return)
                .disabled(linkURL.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Toolbar Helpers

    private func setAlignment(_ alignment: NSTextAlignment) {
        findFirstResponderTextView()?.alignment = alignment
    }

    private func toggleLineSpacing() {
        guard let tv = findFirstResponderTextView() else { return }
        guard let text = tv.textStorage else { return }
        let range = tv.selectedRange()

        // Read current spacing from paragraph style
        var current: CGFloat = -1
        text.enumerateAttribute(.paragraphStyle, in: range) { (style, _, _) in
            if current < 0 {
                current = (style as? NSParagraphStyle)?.lineSpacing ?? 0
            }
        }
        if current < 0 { current = 0 }

        // Cycle: none -> 1.5x -> 2x -> none
        let newSpacing: CGFloat
        if current < 1 { newSpacing = 8 }
        else if current < 10 { newSpacing = 16 }
        else { newSpacing = 0 }

        text.beginEditing()
        text.enumerateAttribute(.paragraphStyle, in: range) { (style, rng, _) in
            let para = (style as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            para.lineSpacing = newSpacing
            text.addAttribute(.paragraphStyle, value: para, range: rng)
        }
        text.endEditing()
    }

    private func adjustIndent(increase: Bool) {
        guard let tv = findFirstResponderTextView() else { return }
        guard !tv.string.isEmpty else { return }
        let factor: CGFloat = increase ? 24.0 : -24.0

        // 获取当前段落范围
        let text = tv.string as NSString
        let sel = tv.selectedRange()
        let loc = min(sel.location, text.length - 1)
        let paraRange = text.paragraphRange(for: NSRange(location: loc, length: 0))
        guard paraRange.length > 0 else { return }

        // 直接修改 textStorage 并让 layoutManager 重排
        if let storage = tv.textStorage,
           let lm = tv.layoutManager {
            let existing = storage.attribute(.paragraphStyle, at: paraRange.location, effectiveRange: nil) as? NSParagraphStyle
            let para = NSMutableParagraphStyle()
            // 复制现有样式
            if let e = existing {
                para.setParagraphStyle(e)
            }
            // 调整缩进
            para.headIndent = max(0, para.headIndent + factor)
            para.firstLineHeadIndent = max(0, para.firstLineHeadIndent + factor)
            // 保留默认行距
            if para.lineSpacing < 0.1 {
                para.lineSpacing = tv.defaultParagraphStyle?.lineSpacing ?? 0
            }

            // 编辑 textStorage
            storage.beginEditing()
            storage.addAttribute(.paragraphStyle, value: para, range: paraRange)
            storage.endEditing()

            // 强制布局管理器刷新
            lm.invalidateLayout(forCharacterRange: paraRange, actualCharacterRange: nil)
            lm.invalidateDisplay(forCharacterRange: paraRange)
        }

        // 设置 typing attributes 以便新文字继承
        var typing = tv.typingAttributes
        typing[.paragraphStyle] = tv.textStorage?.attribute(.paragraphStyle, at: loc, effectiveRange: nil) as? NSParagraphStyle ?? tv.defaultParagraphStyle
        tv.typingAttributes = typing
    }

    private func insertTodo() {
        guard let tv = findFirstResponderTextView() else { return }
        tv.insertText("\u{2610} ", replacementRange: tv.selectedRange())
        autoSave(note: state.editingNote ?? Note.empty())
    }

    private func insertDivider() {
        guard let tv = findFirstResponderTextView() else { return }
        tv.insertText("\n\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\n", replacementRange: tv.selectedRange())
        autoSave(note: state.editingNote ?? Note.empty())
    }

    private func applyFontColor(_ color: NSColor) {
        guard let tv = findFirstResponderTextView() else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }
        tv.textStorage?.addAttribute(.foregroundColor, value: color, range: range)
    }

    private func toggleHighlight() {
        guard let tv = findFirstResponderTextView() else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }

        let storage = tv.textStorage!
        // Check if already highlighted
        var isHighlighted = false
        storage.enumerateAttribute(.backgroundColor, in: range) { (value, _, stop) in
            if value != nil { isHighlighted = true; stop.pointee = true }
        }

        storage.beginEditing()
        if isHighlighted {
            storage.removeAttribute(.backgroundColor, range: range)
        } else {
            let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
            storage.addAttribute(.backgroundColor, value: highlightColor, range: range)
        }
        storage.endEditing()
    }

    private func toggleQuoteBlock() {
        guard let tv = findFirstResponderTextView() else { return }
        let range = tv.selectedRange()
        tv.textStorage?.beginEditing()

        let para = NSMutableParagraphStyle()
        para.headIndent = 20
        para.firstLineHeadIndent = 20
        para.tailIndent = -10

        tv.textStorage?.enumerateAttribute(.paragraphStyle, in: range) { (style, rng, _) in
            let existing = style as? NSParagraphStyle
            if existing?.headIndent ?? 0 > 10 {
                // Remove quote
                let clean = NSMutableParagraphStyle()
                clean.headIndent = 0
                clean.firstLineHeadIndent = 0
                clean.tailIndent = 0
                tv.textStorage?.addAttribute(.paragraphStyle, value: clean, range: rng)
                tv.textStorage?.removeAttribute(.foregroundColor, range: rng)
            } else {
                // Apply quote
                tv.textStorage?.addAttribute(.paragraphStyle, value: para, range: rng)
                tv.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGray, range: rng)
                tv.textStorage?.addAttribute(.obliqueness, value: 0.1, range: rng)
            }
        }
        tv.textStorage?.endEditing()
    }

    private func insertLink(url: String, text: String) {
        guard let tv = findFirstResponderTextView() else { return }
        guard let nsurl = URL(string: url) else { return }

        let linkAttr: [NSAttributedString.Key: Any] = [
            .link: nsurl,
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let range = tv.selectedRange()
        if range.length > 0 {
            tv.textStorage?.addAttributes(linkAttr, range: range)
        } else if !text.isEmpty {
            let attrStr = NSAttributedString(string: text, attributes: linkAttr)
            tv.textStorage?.append(attrStr)
        }
        autoSave(note: state.editingNote ?? Note.empty())
    }

    private func toggleCodeBlock() {
        guard let tv = findFirstResponderTextView() else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }

        let storage = tv.textStorage!
        let monoFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Check if already code
        var isCode = false
        storage.enumerateAttribute(.font, in: range) { (value, _, stop) in
            if let font = value as? NSFont, font.fontName.contains("Menlo") || font.fontName.contains("Mono") {
                isCode = true; stop.pointee = true
            }
        }

        storage.beginEditing()
        if isCode {
            // Revert
            storage.removeAttribute(.font, range: range)
            storage.removeAttribute(.backgroundColor, range: range)
        } else {
            let bgColor = NSColor(white: 0.95, alpha: 1.0)
            storage.addAttribute(.font, value: monoFont, range: range)
            storage.addAttribute(.backgroundColor, value: bgColor, range: range)
        }
        storage.endEditing()
    }

    private func insertImage() {
        // 在弹窗前保存 NSTextView 引用（弹窗期间它会失去第一响应者状态）
        guard let tv = findFirstResponderTextView() else { return }
        let textStorage = tv.textStorage

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let image = NSImage(contentsOf: url) else { return }

            let maxSize: CGFloat = 400
            var imageSize = image.size
            if imageSize.width > maxSize || imageSize.height > maxSize {
                let ratio = min(maxSize / imageSize.width, maxSize / imageSize.height)
                imageSize = NSSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
            }
            image.size = imageSize

            let attachment = NSTextAttachment()
            attachment.image = image
            let attrStr = NSAttributedString(attachment: attachment)

            DispatchQueue.main.async {
                textStorage?.append(attrStr)
                self.autoSave(note: self.state.editingNote ?? Note.empty())
            }
        }
    }

    private func clearFormatting() {
        guard let tv = findFirstResponderTextView() else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }

        // Keep the plain text, remove all attributes
        let plainText = (tv.string as NSString).substring(with: range)
        let plainAttr = NSAttributedString(string: plainText, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.textColor
        ])
        tv.textStorage?.replaceCharacters(in: range, with: plainAttr)
    }

    private func toggleFontSize(increase: Bool) {
        guard let textView = findFirstResponderTextView() else { return }
        let currentSize = textView.font.map { Double($0.pointSize) } ?? state.currentTheme.fontConfiguration.size
        let newSize = increase ? min(currentSize + 2, 48) : max(currentSize - 2, 10)
        textView.font = NSFont.systemFont(ofSize: newSize)
        autoSave(note: state.editingNote ?? Note.empty())
    }

    private func toggleBulletList() {
        guard let textView = findFirstResponderTextView() else { return }
        let selectedRange = textView.selectedRange()
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: selectedRange)
        let line = text.substring(with: lineRange)
        if line.hasPrefix("\u{2022} ") {
            let newText = line.replacingOccurrences(of: "\u{2022} ", with: "")
            textView.replaceCharacters(in: lineRange, with: newText)
        } else {
            textView.replaceCharacters(in: lineRange, with: "\u{2022} \(line)")
        }
    }

    private func toggleNumberedList() {
        guard let textView = findFirstResponderTextView() else { return }
        let selectedRange = textView.selectedRange()
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: selectedRange)
        let line = text.substring(with: lineRange)
        let pattern = "^(\\d+)\\.\\s"
        if let _ = line.range(of: pattern, options: .regularExpression) {
            let newText = line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            textView.replaceCharacters(in: lineRange, with: newText)
        } else {
            textView.replaceCharacters(in: lineRange, with: "1. \(line)")
        }
    }

    private func findFirstResponderTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    // MARK: - Load / Save
    /// 加载笔记内容
    private func loadContentAsync(_ note: Note) {
        if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && note.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editorContent = NSAttributedString(string: "")
            isLoadingContent = false
            return
        }

        if let data = note.content.data(using: .utf8),
           data.count > 0,
           let parsed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
           ) {
            editorContent = parsed
        } else {
            editorContent = NSAttributedString(string: note.plainText)
        }
        isLoadingContent = false
    }

    private func autoSave(note: Note) {
        saveCurrentContent()
    }

    /// 异步保存 — 省去背景线程转换的复杂性，直接在主线程完成
    private func saveCurrentContent() {
        guard isEditing, let currentNote = state.editingNote else { return }
        savingNoteId = currentNote.id

        let htmlData = try? editorContent.data(
            from: .init(location: 0, length: editorContent.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
        let htmlString = htmlData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        var updatedNote = currentNote
        updatedNote.content = htmlString
        updatedNote.plainText = editorContent.string
        updatedNote.updatedAt = Date()

        if let idx = state.notes.firstIndex(where: { $0.id == currentNote.id }) {
            state.notes[idx] = updatedNote
            state.editingNote = updatedNote
        }

        isEditing = false
        debounceSave()
    }

    private func debounceSave() {
        let noteId = savingNoteId
        saveWorkItem?.cancel()
        let task = DispatchWorkItem { [weak state] in
            // 如果当前选中的笔记和保存时的笔记不是同一篇，说明已切换，丢弃本次保存
            guard let state, state.editingNote?.id == noteId else { return }
            state.saveData()
        }
        saveWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }
}

// MARK: - 工具栏按钮（带悬停 + 激活反馈）
struct ToolbarButton: View {
    let icon: String
    let help: String
    let isActive: Bool
    let accentColor: Color
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundColor(isActive ? accentColor : (isHovered ? .primary : .secondary))
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? accentColor.opacity(0.3) : (isPressed ? accentColor.opacity(0.5) : Color.clear), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
        .help(help)
    }
}

// MARK: - 格式状态
struct FormatState: Equatable {
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isStrikethrough = false
}

// MARK: - Rich Text View (NSViewRepresentable)
struct RichTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    let theme: NoteTheme
    let onChange: () -> Void
    var onSelectionChange: (FormatState) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = NSFont(name: theme.fontConfiguration.family, size: theme.fontConfiguration.size)
            ?? NSFont.systemFont(ofSize: theme.fontConfiguration.size)
        textView.textColor = NSColor(theme.textColorSwift)
        textView.linkTextAttributes = [
            .foregroundColor: NSColor(theme.accentColorSwift),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            textView.textStorage?.setAttributedString(attributedText)
            context.coordinator.isUpdating = false
        }

        textView.font = NSFont(name: theme.fontConfiguration.family, size: theme.fontConfiguration.size)
            ?? NSFont.systemFont(ofSize: theme.fontConfiguration.size)
        textView.textColor = NSColor(theme.textColorSwift)
        textView.linkTextAttributes = [
            .foregroundColor: NSColor(theme.accentColorSwift),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = (theme.fontConfiguration.lineSpacing - 1) * theme.fontConfiguration.size
            return style
        }()
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        var isUpdating: Bool = false
        var changeTimer: Timer?

        init(_ parent: RichTextView) {
            self.parent = parent
        }

        /// 更新格式状态（粗体/斜体/下划线/删除线）
        func updateFormatState(from textView: NSTextView) {
            guard let storage = textView.textStorage, storage.length > 0 else { return }
            let range = textView.selectedRange()
            let location = min(range.location, storage.length - 1)
            let attrs = storage.attributes(at: location, effectiveRange: nil)
            let font = attrs[.font] as? NSFont
            let fontName = font?.fontName.lowercased() ?? ""
            let state = FormatState(
                isBold: fontName.contains("bold") || (font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false),
                isItalic: fontName.contains("italic") || fontName.contains("oblique") || (font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false),
                isUnderline: (attrs[.underlineStyle] as? Int) ?? 0 > 0,
                isStrikethrough: (attrs[.strikethroughStyle] as? Int) ?? 0 > 0
            )
            parent.onSelectionChange(state)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            updateFormatState(from: tv)
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }

            // 更新 attributedText 但不触发立即保存 — 通过 debounce timer 做批量保存
            parent.attributedText = textView.attributedString()

            changeTimer?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                self?.parent.onChange()
            }
            changeTimer = timer
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}
