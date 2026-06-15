import SwiftUI
import LocalAuthentication

// MARK: - 密码锁界面（解锁 & 设置密码共用）
struct LockScreenView: View {
    @Environment(AppState.self) private var state
    let folderId: String
    let mode: LockMode
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordHint: String = ""
    @State private var oldPasswordVerified: Bool = false  // 修改密码时：旧密码已验证
    @State private var isAuthenticating: Bool = false  // 指纹验证中

    enum LockMode {
        case unlock        // 解锁已有密码的文件夹
        case setPassword   // 首次设置密码
        case changePassword // 修改密码
        case deleteFolder  // 验证密码后删除文件夹
        case removePassword // 验证密码后移除密码
    }

    var body: some View {
        VStack(spacing: 20) {
            // 顶部图标
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(state.currentTheme.accentColorSwift)
                .padding(.top, 24)

            // 标题
            Text(titleText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(state.currentTheme.textColorSwift)

            // 文件夹名称
            if let folder = state.folders.first(where: { $0.id.uuidString == folderId }) {
                Text("「\(folder.name)」")
                    .font(.callout)
                    .foregroundColor(state.currentTheme.secondaryTextColorSwift)
            }

            // 密码输入
            VStack(spacing: 12) {
                if mode == .changePassword && !oldPasswordVerified {
                    // 修改密码第一步：验证旧密码
                    SecureField("输入当前密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .frame(width: 260)
                        .onSubmit { submit() }
                } else {
                    SecureField(mode == .changePassword ? "输入新密码" : "输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .frame(width: 260)
                        .onSubmit { submit() }

                    if mode == .setPassword || mode == .changePassword {
                        SecureField("确认密码", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                            .frame(width: 260)
                            .onSubmit { submit() }

                        TextField("密码提示（可选）", text: $passwordHint)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                            .frame(width: 260)
                    }
                }
            }

            // 错误/提示信息
            if let errorMsg = state.passwordErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(errorMsg)
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }

            // 按钮
            HStack(spacing: 16) {
                Button("取消") {
                    resetState()
                }
                .keyboardShortcut(.escape)

                if mode == .unlock && isBiometricAvailable {
                    Button(action: authenticateWithBiometrics) {
                        Label("指纹解锁", systemImage: "touchid")
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAuthenticating)
                }

                Button(action: submit) {
                    Text(buttonText)
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.currentTheme.accentColorSwift)
                .disabled(isSubmitDisabled)
            }
            .frame(minHeight: 32)

            Spacer()
        }
        .frame(width: 340, height: mode == .changePassword && !oldPasswordVerified ? 300 :
               (mode == .unlock || mode == .deleteFolder || mode == .removePassword ? 300 : 400))
        .background(state.currentTheme.backgroundColorSwift)
        .foregroundColor(state.currentTheme.textColorSwift)
    }

    private var isSubmitDisabled: Bool {
        if password.isEmpty { return true }
        if mode == .changePassword && !oldPasswordVerified { return false }
        if mode == .unlock || mode == .deleteFolder || mode == .removePassword { return false }
        return password != confirmPassword
    }

    private var titleText: String {
        switch mode {
        case .unlock: return "输入密码解锁"
        case .setPassword: return "设置文件夹密码"
        case .changePassword: return oldPasswordVerified ? "设置新密码" : "验证当前密码"
        case .deleteFolder: return "验证密码删除文件夹"
        case .removePassword: return "验证密码移除密码"
        }
    }

    private var buttonText: String {
        switch mode {
        case .unlock: return "解锁"
        case .setPassword: return "确认设置"
        case .changePassword: return oldPasswordVerified ? "确认修改" : "验证旧密码"
        case .deleteFolder: return "验证并删除"
        case .removePassword: return "验证并移除"
        }
    }

    private func submit() {
        switch mode {
        case .unlock:
            let success = state.verifyFolderPassword(folderId, password: password)
            if success {
                state.showLockScreen = false
                state.pendingLockFolderId = nil
                resetState()
            }
        case .changePassword:
            if !oldPasswordVerified {
                // 第一步：验证旧密码（不关闭弹窗）
                let success = state.checkFolderPassword(folderId, password: password)
                if success {
                    oldPasswordVerified = true
                    password = ""
                    confirmPassword = ""
                    state.passwordErrorMessage = nil
                }
            } else {
                // 第二步：设置新密码
                guard !password.isEmpty, password == confirmPassword else { return }
                state.setFolderPassword(folderId, password: password, hint: passwordHint)
                resetState()
            }
        case .setPassword:
            guard !password.isEmpty, password == confirmPassword else { return }
            state.setFolderPassword(folderId, password: password, hint: passwordHint)
            resetState()
        case .deleteFolder:
            let success = state.verifyFolderPassword(folderId, password: password)
            if success {
                if let folder = state.folders.first(where: { $0.id.uuidString == folderId }) {
                    state.removeFolderPassword(folderId)
                    state.deleteFolder(folder)
                }
                state.showLockScreen = false
                state.pendingLockFolderId = nil
                resetState()
            }
        case .removePassword:
            let success = state.verifyFolderPassword(folderId, password: password)
            if success {
                state.removeFolderPassword(folderId)
                state.showLockScreen = false
                state.pendingLockFolderId = nil
                resetState()
            }
        }
    }

    // MARK: - 生物识别（Touch ID / Face ID）
    private var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        context.localizedReason = "解锁加密文件夹"
        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "使用指纹解锁「\(folderName)」文件夹") { success, error in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    // 生物识别通过 → 直接解锁
                    state.unlockedFolders.insert(folderId)
                    state.folderFailedAttempts[folderId] = 0
                    state.passwordErrorMessage = nil
                    state.showLockScreen = false
                    state.pendingLockFolderId = nil
                    resetState()
                } else if let laError = error as? LAError, laError.code != .userCancel {
                    state.passwordErrorMessage = "指纹验证失败，请使用密码解锁"
                }
            }
        }
    }

    private var folderName: String {
        state.folders.first(where: { $0.id.uuidString == folderId })?.name ?? ""
    }

    private func resetState() {
        password = ""
        confirmPassword = ""
        passwordHint = ""
        oldPasswordVerified = false
        state.showLockScreen = false
        state.pendingLockFolderId = nil
        state.isSettingPassword = false
        state.isDeleteFolderMode = false
        state.isRemovePasswordMode = false
        state.isChangePasswordMode = false
        state.passwordErrorMessage = nil
    }
}
