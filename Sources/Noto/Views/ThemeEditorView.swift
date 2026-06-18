import SwiftUI

// MARK: - 主题编辑器
struct ThemeEditorView: View {
    @Environment(AppState.self) private var state
    @State private var editingTheme: NoteTheme?
    @State private var showDeleteConfirm: String?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                if editingTheme != nil {
                    Button(action: { editingTheme = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(state.currentTheme.accentColorSwift)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("自定义主题")
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                if editingTheme != nil {
                    Button("保存") {
                        if let theme = editingTheme {
                            state.saveTheme(theme)
                            editingTheme = nil
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(state.currentTheme.accentColorSwift)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                } else {
                    Button("完成") {
                        state.showThemeEditor = false
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .padding()
            .background(state.currentTheme.cardColorSwift)

            Divider()

            if let theme = editingTheme {
                themeEditContent(theme: theme)
            } else {
                themeListView
            }
        }
        .frame(width: 520, height: 580)
        .background(state.currentTheme.backgroundColorSwift)
        .foregroundColor(state.currentTheme.textColorSwift)
        .preferredColorScheme(state.currentTheme.isDark ? .dark : nil)
    }

    // MARK: - Theme List
    private var themeListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("预设主题")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(NoteTheme.defaultThemes) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.horizontal)

                if !state.customThemes.isEmpty {
                    Text("自定义主题")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                        ForEach(state.customThemes) { theme in
                            themeCard(theme)
                                .contextMenu {
                                    Button("编辑") { editingTheme = theme }
                                    Button("删除", role: .destructive) {
                                        showDeleteConfirm = theme.id
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                Button(action: createNewTheme) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("创建自定义主题")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(state.currentTheme.accentColorSwift)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(state.currentTheme.accentColorSwift.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .alert("删除主题", isPresented: .init(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("取消", role: .cancel) { showDeleteConfirm = nil }
            Button("删除", role: .destructive) {
                if let id = showDeleteConfirm,
                   let theme = state.customThemes.first(where: { $0.id == id }) {
                    state.deleteCustomTheme(theme)
                    showDeleteConfirm = nil
                }
            }
        } message: {
            Text("确定删除此自定义主题？")
        }
    }

    // MARK: - Theme Card
    private func themeCard(_ theme: NoteTheme) -> some View {
        let isActive = state.selectedThemeId == theme.id
        return VStack(spacing: 8) {
            cardPreview(theme: theme, isActive: isActive)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? state.currentTheme.accentColorSwift : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Group {
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(state.currentTheme.accentColorSwift)
                                .background(Circle().fill(.white).frame(width: 12, height: 12))
                                .position(x: 20, y: 20)
                        }
                    }
                )

            Text(theme.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(state.currentTheme.textColorSwift)
                .lineLimit(1)
        }
        .onTapGesture {
            state.applyTheme(theme.id)
        }
        .onDoubleTap {
            if state.customThemes.contains(where: { $0.id == theme.id }) {
                editingTheme = theme
            }
        }
    }

    // MARK: - Theme Edit Content
    private func themeEditContent(theme: NoteTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("编辑「\(theme.name)」")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal)

                themeForm
            }
            .padding(.vertical)
        }
    }

    // MARK: - Theme Form
    private var themeForm: some View {
        guard let theme = editingTheme else { return AnyView(EmptyView()) }
        // Use a custom binding approach for all properties
        return AnyView(themeFormContent(theme: theme))
    }

    private func themeFormContent(theme: NoteTheme) -> some View {
        // Mirror of editingTheme with computed bindings
        let nameBinding = Binding<String>(
            get: { self.editingTheme?.name ?? theme.name },
            set: { self.editingTheme?.name = $0 }
        )
        let bgBinding = Binding<String>(
            get: { self.editingTheme?.backgroundColor ?? theme.backgroundColor },
            set: { self.editingTheme?.backgroundColor = $0 }
        )
        let textColorBinding = Binding<String>(
            get: { self.editingTheme?.textColor ?? theme.textColor },
            set: { self.editingTheme?.textColor = $0 }
        )
        let accentBinding = Binding<String>(
            get: { self.editingTheme?.accentColor ?? theme.accentColor },
            set: { self.editingTheme?.accentColor = $0 }
        )
        let cardBinding = Binding<String>(
            get: { self.editingTheme?.cardColor ?? theme.cardColor },
            set: { self.editingTheme?.cardColor = $0 }
        )
        let sidebarBinding = Binding<String>(
            get: { self.editingTheme?.sidebarBgColor ?? theme.sidebarBgColor },
            set: { self.editingTheme?.sidebarBgColor = $0 }
        )
        let listBgBinding = Binding<String>(
            get: { self.editingTheme?.noteListBgColor ?? theme.noteListBgColor },
            set: { self.editingTheme?.noteListBgColor = $0 }
        )

        // Font configuration bindings
        let fontFamilyBinding = Binding<String>(
            get: { self.editingTheme?.fontConfiguration.family ?? theme.fontConfiguration.family },
            set: { self.editingTheme?.fontConfiguration.family = $0 }
        )
        let fontSizeBinding = Binding<Double>(
            get: { self.editingTheme?.fontConfiguration.size ?? theme.fontConfiguration.size },
            set: { self.editingTheme?.fontConfiguration.size = $0 }
        )
        let fontWeightBinding = Binding<FontWeightOption>(
            get: { self.editingTheme?.fontConfiguration.weight ?? theme.fontConfiguration.weight },
            set: { self.editingTheme?.fontConfiguration.weight = $0 }
        )
        let lineSpacingBinding = Binding<Double>(
            get: { self.editingTheme?.fontConfiguration.lineSpacing ?? theme.fontConfiguration.lineSpacing },
            set: { self.editingTheme?.fontConfiguration.lineSpacing = $0 }
        )
        let textureBinding = Binding<TextureType>(
            get: { self.editingTheme?.backgroundTexture ?? theme.backgroundTexture },
            set: { self.editingTheme?.backgroundTexture = $0 }
        )
        let cornerRadiusBinding = Binding<Double>(
            get: { self.editingTheme?.cornerRadius ?? theme.cornerRadius },
            set: { self.editingTheme?.cornerRadius = $0 }
        )
        let isDarkBinding = Binding<Bool>(
            get: { self.editingTheme?.isDark ?? theme.isDark },
            set: { self.editingTheme?.isDark = $0 }
        )
        let secondaryTextColorBinding = Binding<String>(
            get: { self.editingTheme?.secondaryTextColor ?? theme.secondaryTextColor },
            set: { self.editingTheme?.secondaryTextColor = $0 }
        )

        return VStack(spacing: 16) {
            labeledField("主题名称") {
                TextField("名称", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
            }

            Group {
                labeledField("背景色") { colorPickerRow(color: bgBinding) }
                labeledField("文字颜色") { colorPickerRow(color: textColorBinding) }
                labeledField("次要文字颜色") { colorPickerRow(color: secondaryTextColorBinding) }
                labeledField("强调色") { colorPickerRow(color: accentBinding) }
                labeledField("卡片颜色") { colorPickerRow(color: cardBinding) }
                labeledField("侧边栏背景") { colorPickerRow(color: sidebarBinding) }
                labeledField("笔记列表背景") { colorPickerRow(color: listBgBinding) }
            }

            labeledField("背景纹理") {
                Picker("", selection: textureBinding) {
                    ForEach(TextureType.allCases) { t in
                        HStack {
                            Image(systemName: t.iconName)
                            Text(t.rawValue)
                        }.tag(t)
                    }
                }
                .pickerStyle(.menu)
            }

            Group {
                labeledField("字体") {
                    Picker("", selection: fontFamilyBinding) {
                        Text("SF Pro").tag("SF Pro")
                        Text("Helvetica Neue").tag("Helvetica Neue")
                        Text("Georgia").tag("Georgia")
                        Text("STSongti").tag("STSongti")
                        Text("PingFang SC").tag("PingFang SC")
                        Text("Monaco").tag("Monaco")
                        Text("Palatino").tag("Palatino")
                        Text("Avenir").tag("Avenir")
                    }
                    .pickerStyle(.menu)
                }

                labeledField("字号") {
                    HStack {
                        Slider(value: fontSizeBinding, in: 10...32, step: 1)
                        Text("\(Int(fontSizeBinding.wrappedValue))pt")
                            .font(.caption)
                            .frame(width: 40)
                    }
                }

                labeledField("字重") {
                    Picker("", selection: fontWeightBinding) {
                        ForEach(FontWeightOption.allCases) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                }

                labeledField("行间距") {
                    HStack {
                        Slider(value: lineSpacingBinding, in: 1.0...3.0, step: 0.1)
                        Text(String(format: "%.1f", lineSpacingBinding.wrappedValue))
                            .font(.caption)
                            .frame(width: 30)
                    }
                }
            }

            labeledField("圆角") {
                HStack {
                    Slider(value: cornerRadiusBinding, in: 4...24, step: 2)
                    Text("\(Int(cornerRadiusBinding.wrappedValue))")
                        .font(.caption)
                        .frame(width: 30)
                }
            }

            Toggle(isOn: isDarkBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("深色模式")
                        .font(.system(size: 13, weight: .medium))
                    Text("开启后将覆盖系统深色模式设置")
                        .font(.caption)
                        .foregroundColor(state.currentTheme.secondaryTextColorSwift)
                }
            }
            .toggleStyle(.switch)
            .tint(state.currentTheme.accentColorSwift)

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("预览")
                    .font(.caption)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)

                let previewTheme = editingTheme ?? theme
                RoundedRectangle(cornerRadius: previewTheme.cornerRadius)
                    .fill(Color(hex: previewTheme.backgroundColor))
                    .overlay {
                        BackgroundTextureView(texture: previewTheme.backgroundTexture, intensity: 1)
                    }
                    .overlay {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标题")
                                .font(.custom(previewTheme.fontConfiguration.family,
                                              size: previewTheme.fontConfiguration.size + 4)
                                    .weight(previewTheme.fontConfiguration.weight.toSwiftWeight))
                                .foregroundColor(Color(hex: previewTheme.textColor))
                            Text("这是一段示例文字，用于预览当前主题的显示效果。")
                                .font(.custom(previewTheme.fontConfiguration.family,
                                              size: previewTheme.fontConfiguration.size))
                                .foregroundColor(Color(hex: previewTheme.secondaryTextColor))
                                .lineSpacing(previewTheme.fontConfiguration.lineSpacing)
                        }
                        .padding(16)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: previewTheme.cornerRadius))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Card Preview Helper
    private func cardPreview(theme: NoteTheme, isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: theme.backgroundColor))
            .overlay {
                if theme.backgroundTexture != .none {
                    BackgroundTextureView(texture: theme.backgroundTexture, intensity: 1)
                }
            }
            .overlay {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: theme.accentColor))
                        .frame(width: 8, height: 8)
                    Text("Aa")
                        .font(.custom(theme.fontConfiguration.family, size: 12))
                        .foregroundColor(Color(hex: theme.textColor))
                }
            }
    }

    // MARK: - Helpers
    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            content()
        }
    }

    private func colorPickerRow(color: Binding<String>) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: color.wrappedValue))
                .frame(width: 32, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )

            TextField("Hex", text: color)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 80)

            ColorPicker("", selection: Binding(
                get: { Color(hex: color.wrappedValue) },
                set: { newColor in color.wrappedValue = newColor.toHex }
            ))
            .labelsHidden()
            .scaleEffect(0.8)

            HStack(spacing: 4) {
                ForEach(colorPresets, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .onTapGesture { color.wrappedValue = hex }
                }
            }
        }
    }

    private var colorPresets: [String] {
        ["#F5F5F7", "#FFFFFF", "#1C1C1E", "#FBF3E8",
         "#1A1B2E", "#E8F0E0", "#0A1628", "#FF9500",
         "#FF3B30", "#34C759", "#007AFF", "#AF52DE"]
    }

    private func createNewTheme() {
        let newTheme = NoteTheme(
            id: "custom-\(UUID().uuidString.prefix(8))",
            name: "新主题",
            backgroundColor: state.currentTheme.backgroundColor,
            backgroundTexture: state.currentTheme.backgroundTexture,
            textColor: state.currentTheme.textColor,
            secondaryTextColor: state.currentTheme.secondaryTextColor,
            accentColor: state.currentTheme.accentColor,
            fontConfiguration: state.currentTheme.fontConfiguration,
            isDark: state.currentTheme.isDark,
            noteListBgColor: state.currentTheme.noteListBgColor,
            sidebarBgColor: state.currentTheme.sidebarBgColor,
            cardColor: state.currentTheme.cardColor
        )
        editingTheme = newTheme
    }
}

// MARK: - Double Tap Modifier
extension View {
    func onDoubleTap(perform action: @escaping () -> Void) -> some View {
        self.onTapGesture(count: 2, perform: action)
    }
}
