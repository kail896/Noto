<div align="center">
  <img src="Resources/Noto.icns" width="120" height="120" alt="Noto">
  <h1>Noto</h1>
  <p><strong>极简 · 优雅 · 个性</strong></p>
  <p>原生 macOS 笔记应用 · 适配 Apple Silicon</p>

  <p>
    <img src="https://img.shields.io/badge/macOS-15%2B-blue?logo=apple">
    <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift">
    <img src="https://img.shields.io/badge/SwiftUI-7-blue?logo=swift">
    <img src="https://img.shields.io/badge/license-MIT-green">
  </p>
</div>

---

## 📖 简介

**Noto** 是一款为 macOS 原生打造的笔记应用。简洁的界面、流畅的编辑体验、强大的自定义主题系统，以及安全的隐私文件夹保护，让你随时随地记录灵感。

> 🎨 **珊瑚金图标** — 暖色调渐变标识，在程序坞中一眼可辨

## ✨ 功能特性

### 📝 富文本编辑器
| 功能 | 说明 |
|------|------|
| **文字样式** | 粗体、斜体、下划线、删除线 |
| **对齐方式** | 左对齐、居中、右对齐、两端对齐 |
| **字号/行距** | 增大/减小字号、循环切换行距（1x/1.5x/2x） |
| **缩进控制** | 增加/减少段落缩进 |
| **列表** | 无序列表、有序列表、待办复选框 ☐ |
| **字体颜色** | 预设 9 色色板 |
| **背景高亮** | 黄色荧光笔效果（切换式） |
| **引用块** | 一键切换引用样式（缩进 + 灰色 + 斜体） |
| **超链接** | 弹出式链接插入框 |
| **代码块** | 等宽字体 + 灰色背景（切换式） |
| **插入图片** | 系统文件选择器 |
| **分割线** | 一键插入水平分隔线 |
| **清除格式** | 一键还原为纯文本 |

### 🎨 主题系统
- **6 套预设主题**：浅色、深色、羊皮纸、午夜、森林、海洋
- **自定义主题**：自由搭配背景色、文字色、强调色、卡片色
- **背景纹理**：9 种纹理效果（点阵、线条、网格、纸张、亚麻、噪点、波浪、碳纤）
- **字体配置**：自定义字族、字号、字重、行间距
- **圆角控制**：自定义卡片圆角大小

### 🌗 暗色模式
- **三种模式**：跟随系统 · 始终浅色 · 始终深色
- 系统控件自动适配暗色/亮色

### 🔒 隐私文件夹
- **密码保护**：SHA256 哈希加密
- **安全机制**：
  - 设置密码 → 解锁 → 自动锁定
  - 修改密码 → 需验证旧密码
  - 移除密码 → 需先验证
  - 删除文件夹 → 锁定文件夹需验证
- **密码提示**：3 次错误后显示
- **内容隐藏**：锁定文件夹的笔记在智能分类中自动隐藏

### 📂 批量操作
- **多选模式**：勾选多篇笔记
- **批量操作**：删除、移动、置顶
- **全选/清除**：一键全选或清除选择

### ☁️ iCloud 同步
- 数据存储在 iCloud Drive，多设备自动同步
- 无需开发者账号
- 支持迁移：本地 ↔ iCloud Drive

### 🗑️ 最近删除
- 软删除机制，笔记先移入回收站
- 恢复笔记到原位置
- 永久删除 / 批量恢复

## 🚀 快速开始

### 直接使用
1. 从 [Releases](https://github.com/kail896/Noto/releases) 下载最新的 `Noto.dmg`
2. 打开 DMG，将 `Noto.app` 拖入 `Applications` 文件夹
3. 首次打开可能需要右键 → 打开（Gatekeeper 提示）

### 从源码构建
```bash
git clone https://github.com/kail896/Noto.git
cd Noto
swift build -c release
bash build.sh
```

构建产物位于 `.build/Noto.dmg`。

## 🏗️ 技术架构

| 层级 | 技术 |
|------|------|
| **UI 框架** | SwiftUI 7 (macOS 15+) |
| **富文本** | NSTextView (NSViewRepresentable) |
| **持久化** | JSON 文件 (Codable) |
| **密码学** | CryptoKit (SHA256) |
| **存储** | Application Support / iCloud Drive |
| **图标生成** | Python (Pillow) → iconutil |
| **签名** | Ad-hoc codesign |

## 📁 项目结构
```
Noto/
├── Package.swift              # SwiftPM 配置
├── build.sh                   # 构建 & DMG 打包脚本
├── generate_icon.py           # 应用图标生成器
├── Resources/
│   ├── Info.plist             # 应用配置
│   └── Noto.icns              # 应用图标
└── Sources/Noto/
    ├── NotoApp.swift           # 应用入口
    ├── Models/
    │   ├── NoteModel.swift     # 笔记 & 文件夹模型
    │   ├── ThemeTypes.swift    # 主题类型定义
    │   └── ThemeModel.swift    # 主题渲染
    ├── ViewModels/
    │   └── AppState.swift      # 全局状态管理
    └── Views/
        ├── ContentView.swift   # 三栏主布局
        ├── SidebarView.swift   # 侧边栏
        ├── NoteListView.swift  # 笔记列表
        ├── NoteEditorView.swift # 富文本编辑器
        ├── LockScreenView.swift # 密码锁
        ├── ThemeEditorView.swift # 主题编辑器
        └── SettingsView.swift  # 设置页面
```

## 🖥️ 系统要求

- **macOS** 15.0 Sequoia 或更高
- **芯片** Apple Silicon（M 系列）或 Intel
- **存储** 约 10MB（不含用户数据）
- **iCloud**（可选）用于多设备同步

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。
