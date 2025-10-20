# Sparkify

<div align="center">
  <img src="assets/AppIcon-iOS-Default-1024x1024@1x.png" width="128" alt="Sparkify Icon" />
  <p><strong>为提示词而设的专注空间</strong></p>
  <p>一款专为 Mac 设计的 AI 提示词管理与版本化工具</p>
</div>

---

## 概览 (Overview)

<p align="center">
  <img src="assets/screenshot.jpg" alt="Sparkify Screenshot" width="800"/>
</p>

## 📖 关于 Sparkify

Sparkify 旨在帮助你组织并精炼你的 AI 提示词。作为一款专为 macOS 设计的原生应用，它是一个专注、直观且注重隐私的工作空间，致力于优化你的提示词工程工作流。

无论你是开发者、写作者还是 AI 研究者，Sparkify 都能让你的提示词管理变得井井有条。

## ✨ 核心功能

### 🔧 动态模板引擎
在提示词中使用 `{placeholder}` 来创建可复用的模板。你可为每个参数预设默认值，从而在不同场景下快速调整提示词。

### 📚 完整的版本历史
每当你修改模板，Sparkify 都会自动保存一个新版本。你可以轻松地并排比较任意两个版本的差异，查看变更，并随时恢复。它为你的提示词提供了清晰、可追溯的变更历史。

### 🔗 代理上下文与文件同步
将你的模板直接与本地的 Markdown 文件（例如，命令行代理的系统指令文档）相关联。你可以在 Sparkify 内编辑内容并一键覆写到文件，也可以在外部编辑器修改文件后，将最新内容同步回 Sparkify。让你的模板始终保持唯一数据源，永远同步。

### 🏷️ 标签与筛选
使用自定义标签来组织你的提示词库。通过标签、置顶状态或关键词进行筛选，在需要时即刻找到所需内容。

### 💾 简易导入与导出
将你的整个提示词库备份到一个单独的文件中。轻松分享你的收藏，或在新旧设备间迁移。

### 🔒 纯净体验
Sparkify 运行快速、稳定可靠且尊重你的隐私。所有数据都存储在你的设备上，我们不收集任何信息。

## 🚀 快速上手 (Quick Start)

1.  **创建新模板：** 在主界面点击 `+` 按钮，或使用快捷键 `⌘N`，即可创建一个新的空白模板。
2.  **编辑内容与占位符：** 在打开的编辑窗口中，为模板输入标题和正文。使用 `{placeholder}` 来定义可变参数，例如：`为我的社交媒体写一篇关于 {topic} 的帖子。` 然后保存模板。
3.  **填写参数：** 返回主界面，你会看到新模板卡片上出现了名为 `topic` 的输入框。直接在卡片上填写你需要的具体内容，例如：`AI 辅助编程`。
4.  **复制成品：** 点击卡片上的“复制”按钮。Sparkify 会自动将你填写的参数与模板结合，并将最终生成的完整提示词（例如：`为我的社交媒体写一篇关于 AI 辅助编程 的帖子。`）复制到你的剪贴板。

## 📦 获取 Sparkify

### 社区版（Community Edition）

社区版提供与核心功能，完全免费。

- 📥 [从 GitHub Releases 下载最新版本](https://github.com/SkyPixel-Studio/Sparkify/releases)
- ⏱️ 通常在 App Store 版本发布一段时间后更新
- 🔓 源代码始终保持最新

> **注意：** 本仓库的源代码通常领先于 GitHub Releases 中的社区版构建。

## 🔨 开发指南

### 构建项目

```bash
# 克隆仓库
git clone https://github.com/SkyPixel-Studio/Sparkify.git
cd Sparkify

# 构建
xcodebuild -scheme Sparkify -destination 'platform=macOS' build

# 运行测试
xcodebuild -scheme Sparkify -destination 'platform=macOS' test

# 在 Xcode 中打开
xed .
```

### 代码规范

- **缩进：** 4 空格
- **命名约定：**
  - 视图结构以 `View` 结尾（如 `TemplateCardView`）
  - 模型采用 PascalCase（如 `PromptItem`）
  - 属性使用 lowerCamelCase
- **提交信息：** 遵循 `type: scope` 格式
  - 示例：`feat: add version comparison view`
  - 示例：`fix: resolve template parsing escape issue`

### 测试要求

- 测试文件镜像源文件路径（如 `TemplateEngine.swift` ↔︎ `TemplateEngineTests.swift`）
- 测试命名遵循 `testScenarioExpectation` 模式
- 提交 PR 前必须通过所有测试：`xcodebuild -scheme Sparkify test`

## 🤝 贡献指南

我们欢迎社区贡献！

### 如何贡献

1. **Fork 本仓库**并创建你的功能分支（`git checkout -b feat/amazing-feature`）
2. **编写代码**并确保遵循项目的代码规范
3. **添加测试**覆盖新功能或修复的 bug
4. **运行完整测试**确保没有破坏现有功能
5. **提交更改**（`git commit -m 'feat: add amazing feature'`）
6. **推送分支**（`git push origin feat/amazing-feature`）
7. **创建 Pull Request**

### PR 检查清单

- [ ] 代码通过 `xcodebuild ... build`
- [ ] 所有测试通过 `xcodebuild ... test`
- [ ] UI 变更附带截图或录屏
- [ ] 更新相关文档
- [ ] 提交信息遵循规范


## 📄 许可证

本项目采用 [Apache License 2.0](LICENSE.md) 许可证。

你可以自由地使用、修改和分发本软件，无论是个人使用还是商业用途，只需遵守许可证条款。

## 🙏 致谢

Sparkify 由 **Guangzhou Meirui Overseas Consultancy Services Co., Ltd.**（广州美瑞海外咨询有限公司）维护。

感谢所有支持本项目的用户和贡献者。你们的反馈与贡献让 Sparkify 变得更好。

---

<div align="center">
  <p>为你的创作过程带来清晰的思路</p>
  <p><strong>立即下载 Sparkify，精炼你的 AI 工作流</strong></p>
</div>
